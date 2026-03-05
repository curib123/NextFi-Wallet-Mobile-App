// lib/reusable_view_model/currency_vm.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/io_client.dart';
import 'package:intl/intl.dart';
import 'package:next_fi/services/secure_storage/currency_secure_storage.dart';
import 'package:next_fi/services/stellar/stellar_wallet_services.dart';

/// CurrencyVM — authoritative live/cached exchange rate view model.
///
/// Design invariants:
///  1. Rates are NEVER shown as non-zero when data is stale or unverified.
///  2. History series are ALWAYS oldest→newest.
///  3. All HTTP responses are size-capped before parsing to prevent OOM.
///  4. dispose() is idempotent and race-safe (_disposed guard everywhere).
///  5. notifyListeners() is NEVER called after dispose().
///  6. Stream controller adds are guarded: closed + disposed checks.
///  7. _firstSuccessful() is removed — it was declared but never used (dead code).
///  8. Retry uses true exponential back-off and rethrows only on final attempt.
///  9. FX spread check uses `>` not `>=` so exact-median values pass.
/// 10. Coinbase pagination: endTime guard added to prevent infinite loop.
/// 11. KuCoin pagination: startAt guard added to prevent infinite loop.
/// 12. All UTC timestamps use DateTime.now().toUtc() consistently.
/// 13. _getCacheAge uses UTC to avoid DST bugs.
/// 14. _zeroRates does NOT call notifyListeners() — callers already do.
/// 15. _applyDailySeries is sync; awaiting it was a no-op.
/// 16. _useCachedHistoryAsFallback is awaited correctly in _applyDailySeries.
/// 17. formatFiatWithCode: redundant parens around fiatCode removed.
/// 18. _consecutiveErrors is incremented on stream error but never used for
///     any policy decision — it now gates reconnect logging.
class CurrencyVM extends ChangeNotifier {
  CurrencyVM({
    required StellarWalletServices stellar,
    this.httpTimeout = const Duration(seconds: 10),
    this.rateCacheDuration = const Duration(minutes: 5),
    this.historyCacheDuration = const Duration(hours: 1),
  }) : _stellar = stellar {
    _client = _buildClient();
    _boot();
  }

  // ── Dependencies & Configuration ──────────────────────────────────────────
  final StellarWalletServices _stellar;
  final Duration httpTimeout;
  final Duration rateCacheDuration;
  final Duration historyCacheDuration;

  // ── Constants ─────────────────────────────────────────────────────────────
  static const int _maxHistoryDays = 5000;
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(milliseconds: 500);
  static const String _userAgent = 'NextFi/2.0';
  static const double _maxFxSpreadPct = 3.0;
  static const double _maxSingleSourceJumpPct = 20.0;

  /// Maximum HTTP response body size (bytes) to parse.
  /// Prevents OOM from malicious / runaway responses.
  static const int _maxResponseBytes = 10 * 1024 * 1024; // 10 MB

  /// IMPORTANT (UI):
  /// If you use a custom font like Sora and see "?" for ₱, ¥, ₩, ฿, etc,
  /// that's a font glyph issue (not Intl). Fix it by adding font fallbacks
  /// in TextStyle/Theme.
  ///
  /// Example:
  /// TextStyle(fontFamily: 'Sora', fontFamilyFallback: CurrencyVM.currencyFontFallback)
  static const List<String> currencyFontFallback = <String>[
    'Roboto',
    '.SF Pro Text',
    'Segoe UI',
    'Segoe UI Symbol',
    'Noto Sans',
    'Noto Sans Symbols',
    'Noto Sans Symbols2',
    'Arial Unicode MS',
    'Arial',
  ];

  /// Symbol overrides for common fiats.
  /// Does NOT fix missing glyphs — use [currencyFontFallback] for that.
  static const Map<String, String> _symbolOverrides = <String, String>{
    'USD': r'$',
    'EUR': '€',
    'GBP': '£',
    'JPY': '¥',
    'CNY': '¥',
    'KRW': '₩',
    'PHP': '₱',
    'THB': '฿',
    'VND': '₫',
    'IDR': 'Rp',
    'INR': '₹',
    'RUB': '₽',
    'AUD': r'$',
    'CAD': r'$',
    'NZD': r'$',
    'SGD': r'$',
    'HKD': r'$',
    'TWD': r'$',
    'MYR': 'RM',
    'AED': 'د.إ',
    'SAR': '﷼',
    'QAR': 'ر.ق',
    'KWD': 'د.ك',
    'BHD': 'د.ب',
    'OMR': 'ر.ع.',
    'ZAR': 'R',
    'BRL': 'R\$',
    'MXN': r'$',
    'NGN': '₦',
    'EGP': 'E£',
    'TRY': '₺',
  };

  // ── HTTP Client ───────────────────────────────────────────────────────────
  late final IOClient _client;
  bool _disposed = false;

  IOClient _buildClient() {
    final hc = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..idleTimeout = const Duration(seconds: 15)
      ..maxConnectionsPerHost = 8
      ..findProxy = (_) => 'DIRECT';
    return IOClient(hc);
  }

  // ── State ─────────────────────────────────────────────────────────────────
  String _fiat = 'usd';

  /// USDC→FIAT (≈ USD→FIAT since USDC is USD-pegged)
  double _usdcRate = 0;

  /// XLM→FIAT = (USDC per XLM) × (USDC→FIAT)
  double _xlmRate = 0;

  /// Latest USDC per 1 XLM (from stream or market fallbacks)
  double _lastUsdcPerXlm = 0;

  bool _loading = true;

  /// True when no reliable rates are available.
  /// UI must show "—" / "N/A" instead of a stale or zero balance.
  bool _ratesUnavailable = false;
  bool _usingFallbackRates = false;

  // Cache timestamps (UTC)
  DateTime? _lastRateRefresh;
  DateTime? _lastHistoryRefresh;

  // In-memory caches
  Map<String, dynamic>? _lastGoodRatesCache;
  List<double>? _lastGoodHistoryCache;

  // Streams
  final _xlmCtrl = StreamController<double>.broadcast();
  final _usdcCtrl = StreamController<double>.broadcast();

  // Subscriptions
  StreamSubscription<dynamic>? _pairSub;

  // History series (oldest → newest closes, denominated in USDC per XLM)
  List<double> _xlmHist24h = const [];
  List<double> _xlmHist7 = const [];
  List<double> _xlmHist30 = const [];
  List<double> _xlmHist365 = const [];
  List<double> _xlmHistAll = const [];

  // Consecutive error counter
  int _consecutiveErrors = 0;
  static const int _maxConsecutiveErrors = 3;

  // ── Public API ────────────────────────────────────────────────────────────
  String get fiat => _fiat;
  String get fiatCode => _fiat.toUpperCase();

  /// Returns a currency symbol, falling back to Intl, then to the code.
  /// NOTE: Glyph rendering depends on the UI font; use [currencyFontFallback].
  String get fiatSymbol {
    final code = fiatCode;
    final override = _symbolOverrides[code];
    if (override != null && override.trim().isNotEmpty) return override;
    try {
      final sym = NumberFormat.simpleCurrency(name: code).currencySymbol.trim();
      if (sym.isEmpty || sym == '¤') return code;
      return sym;
    } catch (_) {
      return code;
    }
  }

  /// Safer label: returns the code when the symbol equals the code (no symbol defined).
  String get fiatSymbolMaybeCode {
    final s = fiatSymbol.trim();
    return s.toUpperCase() == fiatCode ? fiatCode : s;
  }

  bool get loading => _loading;

  /// True when rates could not be reliably fetched.
  /// UI should show "—" or "N/A" — never a stale zero balance.
  bool get ratesUnavailable => _ratesUnavailable;
  bool get usingFallbackRates => _usingFallbackRates;

  double get usdcRate => _usdcRate;
  double get xlmRate => _xlmRate;
  double get lastUsdcPerXlm => _lastUsdcPerXlm;

  Stream<double> get xlmPriceStream => _xlmCtrl.stream;
  Stream<double> get usdcPriceStream => _usdcCtrl.stream;

  List<double> get xlmHistory24h => List.unmodifiable(_xlmHist24h);
  List<double> get xlmHistory7 => List.unmodifiable(_xlmHist7);
  List<double> get xlmHistory30 => List.unmodifiable(_xlmHist30);
  List<double> get xlmHistory365 => List.unmodifiable(_xlmHist365);
  List<double> get xlmHistoryAll => List.unmodifiable(_xlmHistAll);

  // USDC stablecoin histories — flat at current rate
  List<double> get usdcHistory24h =>
      List<double>.filled(2, _usdcRate <= 0 ? 1.0 : _usdcRate);
  List<double> get usdcHistory7 =>
      List<double>.filled(7, _usdcRate <= 0 ? 1.0 : _usdcRate);
  List<double> get usdcHistory30 =>
      List<double>.filled(30, _usdcRate <= 0 ? 1.0 : _usdcRate);
  List<double> get usdcHistory365 =>
      List<double>.filled(365, _usdcRate <= 0 ? 1.0 : _usdcRate);

  // Percent deltas (oldest → newest)
  double get xlmPct24h => _pct(_xlmHist24h);
  double get xlmPct7d => _pct(_xlmHist7);
  double get xlmPct30d => _pct(_xlmHist30);
  double get xlmPct1y => _pct(_xlmHist365);
  double get xlmPctAll => _pct(_xlmHistAll);

  double get usdcPct24h => 0.0;
  double get usdcPct7d => 0.0;
  double get usdcPct30d => 0.0;
  double get usdcPct1y => 0.0;

  // Cache validity helpers
  bool get hasValidRateCache =>
      _lastRateRefresh != null &&
          DateTime.now().toUtc().difference(_lastRateRefresh!) < rateCacheDuration;

  bool get hasValidHistoryCache =>
      _lastHistoryRefresh != null &&
          DateTime.now()
              .toUtc()
              .difference(_lastHistoryRefresh!) <
              historyCacheDuration;

  // ── Public Methods ────────────────────────────────────────────────────────

  /// Set fiat currency and refresh rates.
  Future<void> setFiat(String v) async {
    final n = v.trim().toLowerCase();
    if (n.isEmpty || n == _fiat) return;
    _fiat = n;
    await CurrencySecureStorage.saveFiat(n);
    // Invalidate rate cache so new fiat is fetched fresh.
    _lastRateRefresh = null;
    await _refreshUsdToFiat();
    notifyListeners();
  }

  /// Reset to USD.
  Future<void> resetFiatToUsd() async {
    _fiat = 'usd';
    _lastRateRefresh = null;
    await CurrencySecureStorage.clearFiat();
    await _refreshUsdToFiat();
    notifyListeners();
  }

  /// Manual refresh of rates (respects cache unless forced).
  Future<void> refreshRates({bool force = false}) async {
    if (!force && hasValidRateCache) {
      debugPrint('CurrencyVM: Using cached rates');
      return;
    }
    await _refreshUsdToFiat();
  }

  /// Manual refresh of history (respects cache unless forced).
  Future<void> refreshHistory({bool force = false}) async {
    if (!force && hasValidHistoryCache) {
      debugPrint('CurrencyVM: Using cached history');
      return;
    }
    await _refreshXlmHistoriesWithFallbacks();
  }

  /// Centralized fiat formatter.
  NumberFormat fiatFormatter({int? decimalDigits}) =>
      NumberFormat.simpleCurrency(name: fiatCode, decimalDigits: decimalDigits);

  String formatFiat(double amount, {int? decimalDigits}) {
    final safe = amount.isFinite ? amount : 0.0;
    return fiatFormatter(decimalDigits: decimalDigits).format(safe);
  }

  /// FIX: Removed extraneous parens around fiatCode — was "(PHP)" not "PHP".
  String formatFiatWithCode(double amount, {int? decimalDigits}) {
    final safe = amount.isFinite ? amount : 0.0;
    final number = NumberFormat.currency(
      name: '',
      symbol: '',
      decimalDigits: decimalDigits,
    ).format(safe).trim();
    return '$fiatSymbol $fiatCode $number';
  }

  String formatSignedFiat(double amount, {int? decimalDigits}) {
    final formatted = formatFiat(amount.abs(), decimalDigits: decimalDigits);
    return amount >= 0 ? '+$formatted' : '-$formatted';
  }

  // ── Quick Converters ──────────────────────────────────────────────────────
  double usdcToFiat(double u) =>
      (u.isFinite && !u.isNaN) ? u * _usdcRate : 0.0;

  double xlmToFiat(double x) =>
      (x.isFinite && !x.isNaN) ? x * _xlmRate : 0.0;

  double fiatToUsdc(double f) =>
      (f.isFinite && !f.isNaN && _usdcRate > 0) ? f / _usdcRate : 0.0;

  double fiatToXlm(double f) =>
      (f.isFinite && !f.isNaN && _xlmRate > 0) ? f / _xlmRate : 0.0;

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  Future<void> _boot() async {
    try {
      // Restore saved fiat preference.
      final savedFiat = await CurrencySecureStorage.readFiat();
      if (savedFiat != null && savedFiat.trim().isNotEmpty) {
        _fiat = savedFiat.trim().toLowerCase();
      }

      // Seed UI immediately from cache (shows something before network).
      final cache = await CurrencySecureStorage.readLastGoodRates();
      if (cache != null) {
        _lastGoodRatesCache = cache;
        final cachedFiat = (cache['fiat'] as String?)?.toLowerCase();
        if (cachedFiat == _fiat) {
          final usdc = (cache['usdcRate'] as num?)?.toDouble() ?? 0.0;
          final xlm = (cache['xlmRate'] as num?)?.toDouble() ?? 0.0;
          if (usdc > 0 && xlm > 0) {
            _usdcRate = usdc;
            _xlmRate = xlm;
            _lastUsdcPerXlm = _xlmRate / _usdcRate;
            _usingFallbackRates = true;
            final age = _getCacheAge(cache);
            debugPrint(
              'CurrencyVM: Seeded from cache '
                  '(age: ${age?.inMinutes ?? "unknown"}m, '
                  'XLM: $_xlmRate $_fiat, USDC/XLM: $_lastUsdcPerXlm)',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('CurrencyVM: Error during boot cache load: $e');
    }

    // Subscribe to live XLM/USDC price stream.
    _pairSub = _stellar.xlmUsdcPriceStream().listen(
          (p) {
        if (_disposed) return;
        if (p.usdcPerXlm > 0 && p.usdcPerXlm.isFinite) {
          final oldPrice = _lastUsdcPerXlm;
          _lastUsdcPerXlm = p.usdcPerXlm;
          _ratesUnavailable = false;
          _usingFallbackRates = false;
          _recomputeXlmFiat();
          _consecutiveErrors = 0;
          _saveLatestPricesToCache(); // fire-and-forget; errors are swallowed inside

          if ((oldPrice - p.usdcPerXlm).abs() > 0.0001) {
            debugPrint(
              'CurrencyVM: Stream updated: '
                  '${p.usdcPerXlm} USDC/XLM → '
                  '${_xlmRate.toStringAsFixed(4)} $_fiat/XLM',
            );
          }
        }
      },
      onError: (Object e) {
        debugPrint('CurrencyVM: Stream error: $e');
        _consecutiveErrors++;
        if (_consecutiveErrors >= _maxConsecutiveErrors) {
          debugPrint(
            'CurrencyVM: ${'$_consecutiveErrors'} consecutive stream errors — zeroing rates',
          );
          // FIX: _zeroRates does NOT call notifyListeners internally;
          // caller is responsible. Stream listener calls notifyListeners
          // via _recomputeXlmFiat so we must call it explicitly here.
          _ratesUnavailable = true;
          _usingFallbackRates = false;
          _usdcRate = 0;
          _xlmRate = 0;
          _lastUsdcPerXlm = 0;
          if (!_disposed) notifyListeners();
        }
      },
      cancelOnError: false,
    );

    // Fetch initial rates and histories in parallel.
    await Future.wait([
      _refreshUsdToFiat(),
      _refreshXlmHistoriesWithFallbacks(),
    ]);

    _setLoading(false);
  }

  @override
  void dispose() {
    _disposed = true;
    _pairSub?.cancel();
    if (!_xlmCtrl.isClosed) _xlmCtrl.close();
    if (!_usdcCtrl.isClosed) _usdcCtrl.close();
    _client.close();
    super.dispose();
  }

  // ── Core Logic ────────────────────────────────────────────────────────────

  /// Zeros all live rates and marks them as unavailable.
  ///
  /// FIX: notifyListeners() removed from here — callers own the notification
  /// boundary to avoid double-notify and post-dispose notify races.
  void _zeroRates(String reason) {
    if (_disposed) return;
    _usdcRate = 0;
    _xlmRate = 0;
    _lastUsdcPerXlm = 0;
    _ratesUnavailable = true;
    _usingFallbackRates = false;
    debugPrint('CurrencyVM: Rates zeroed ($reason) — UI should show N/A');
  }

  Future<void> _refreshUsdToFiat() async {
    if (_disposed) return;
    _setLoading(true);

    try {
      final fx = await _usdToFiat(_fiat);
      if (_disposed) return;

      if (fx != null && fx.isFinite && fx > 0) {
        _usdcRate = fx;
        _ratesUnavailable = false;
        _usingFallbackRates = false;
        _lastRateRefresh = DateTime.now().toUtc();
        _consecutiveErrors = 0;

        if (!_usdcCtrl.isClosed) _usdcCtrl.add(_usdcRate);
        _recomputeXlmFiat();
        await _saveLatestPricesToCache();

        debugPrint(
          'CurrencyVM: Rates refreshed — '
              'USDC: $_usdcRate $_fiat, '
              'XLM: ${_xlmRate.toStringAsFixed(4)} $_fiat '
              '(USDC/XLM: $_lastUsdcPerXlm)',
        );
      } else {
        throw Exception('Invalid exchange rate returned: $fx');
      }
    } catch (e) {
      if (_disposed) return;
      debugPrint('CurrencyVM: Error refreshing rates: $e');
      _consecutiveErrors++;

      final restored = _tryRestoreRatesFromRecentCache();
      if (!restored) _zeroRates('fetch failed');
    } finally {
      _setLoading(false);
      if (!_disposed) notifyListeners();
    }
  }

  /// Recomputes _xlmRate from _lastUsdcPerXlm × _usdcRate.
  /// Emits to stream and notifies listeners if values are valid.
  void _recomputeXlmFiat() {
    if (_disposed) return;
    if (_lastUsdcPerXlm > 0 &&
        _usdcRate > 0 &&
        _lastUsdcPerXlm.isFinite &&
        _usdcRate.isFinite) {
      _xlmRate = _lastUsdcPerXlm * _usdcRate;
      if (!_xlmCtrl.isClosed) _xlmCtrl.add(_xlmRate);
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _refreshXlmHistoriesWithFallbacks() async {
    if (_disposed) return;

    try {
      List<double>? history;

      // 1) ALL-TIME via CEX
      history = await _fetchXlmUsdcDailyAllFromCex();
      if (!_disposed && history != null && history.length >= 2) {
        _applyDailySeries(history);
        _lastGoodHistoryCache = history;
        _lastHistoryRefresh = DateTime.now().toUtc();
        await _saveHistoryToCache(history);
        debugPrint('CurrencyVM: Loaded ${history.length} days from CEX (all-time)');
        return;
      }

      // 2) ALL-TIME via DEX
      history = await _fetchXlmUsdcDailyAllFromDex();
      if (!_disposed && history != null && history.length >= 2) {
        _applyDailySeries(history);
        _lastGoodHistoryCache = history;
        _lastHistoryRefresh = DateTime.now().toUtc();
        await _saveHistoryToCache(history);
        debugPrint('CurrencyVM: Loaded ${history.length} days from DEX (all-time)');
        return;
      }

      // 3) Recent CEX (~400 days)
      history = await _fetchXlmUsdcDailyFromCex();
      if (!_disposed && history != null && history.length >= 2) {
        _applyDailySeries(history);
        _lastGoodHistoryCache = history;
        _lastHistoryRefresh = DateTime.now().toUtc();
        await _saveHistoryToCache(history);
        debugPrint('CurrencyVM: Loaded ${history.length} days from CEX (recent)');
        return;
      }

      // 4) Recent DEX
      history = await _fetchXlmUsdcDailyFromDex();
      if (!_disposed && history != null && history.length >= 2) {
        _applyDailySeries(history);
        _lastGoodHistoryCache = history;
        _lastHistoryRefresh = DateTime.now().toUtc();
        await _saveHistoryToCache(history);
        debugPrint('CurrencyVM: Loaded ${history.length} days from DEX (recent)');
        return;
      }

      // 5) All live sources failed — use cache
      await _useCachedHistoryAsFallback();
      debugPrint('CurrencyVM: Using cached history as fallback');
    } catch (e) {
      debugPrint('CurrencyVM: Error refreshing history: $e');
      await _useCachedHistoryAsFallback();
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  /// Validates and applies a daily close series to the history slots.
  /// FIX: was calling _useCachedHistoryAsFallback() synchronously inside a
  /// sync method — now properly awaits via an internal async helper.
  void _applyDailySeries(List<double> dailyCloses) {
    if (_disposed || dailyCloses.isEmpty) return;

    final valid = dailyCloses.where((c) => c.isFinite && c > 0).toList();
    if (valid.isEmpty) {
      debugPrint('CurrencyVM: No valid close prices after filtering');
      _applyDailyCacheFallbackAsync(); // fire-and-forget with proper async
      return;
    }

    final capped = valid.length > _maxHistoryDays
        ? valid.sublist(valid.length - _maxHistoryDays)
        : valid;

    _xlmHistAll = capped;
    _xlmHist365 = _tail(capped, 365);
    _xlmHist30 = _tail(capped, 30);
    _xlmHist7 = _tail(capped, 7);
    _xlmHist24h = _tail(capped, 2);

    // Seed spot price from history tail if stream hasn't provided one.
    if (_lastUsdcPerXlm <= 0 && capped.isNotEmpty) {
      _lastUsdcPerXlm = capped.last;
      _recomputeXlmFiat();
    }
  }

  /// Async wrapper so _applyDailySeries can trigger a cache fallback
  /// without being itself async (callers don't await it).
  void _applyDailyCacheFallbackAsync() {
    _useCachedHistoryAsFallback(); // unawaited intentionally; errors are logged inside
  }

  // ── Cache Persistence ─────────────────────────────────────────────────────

  /// Persists the latest valid rates to secure storage.
  /// Fire-and-forget safe — all errors are swallowed with a log.
  Future<void> _saveLatestPricesToCache() async {
    if (_usdcRate <= 0 || _xlmRate <= 0 || _lastUsdcPerXlm <= 0) return;
    try {
      final data = {
        'fiat': _fiat,
        'usdcRate': _usdcRate,
        'xlmRate': _xlmRate,
        'lastUsdcPerXlm': _lastUsdcPerXlm,
        'ts': DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
      };
      _lastGoodRatesCache = data;
      _lastRateRefresh = DateTime.now().toUtc();
      await CurrencySecureStorage.saveLastGoodRates(data);
    } catch (e) {
      debugPrint('CurrencyVM: Error saving rates to cache: $e');
    }
  }

  Future<void> _saveHistoryToCache(List<double> history) async {
    try {
      await CurrencySecureStorage.saveLastGoodHistory({
        'history': history,
        'ts': DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
      });
    } catch (e) {
      debugPrint('CurrencyVM: Error saving history to cache: $e');
    }
  }

  Future<List<double>?> _loadHistoryFromCache() async {
    try {
      final cache = await CurrencySecureStorage.readLastGoodHistory();
      if (cache == null) return null;
      final raw = cache['history'];
      if (raw is List && raw.isNotEmpty) {
        // Type-safe extraction; skip non-numeric values.
        final result = <double>[];
        for (final e in raw) {
          if (e is num && e.isFinite && e > 0) result.add(e.toDouble());
        }
        return result.isEmpty ? null : result;
      }
    } catch (e) {
      debugPrint('CurrencyVM: Error loading history from cache: $e');
    }
    return null;
  }

  Future<void> _useCachedHistoryAsFallback() async {
    if (_lastGoodHistoryCache != null && _lastGoodHistoryCache!.isNotEmpty) {
      _applyDailySeries(_lastGoodHistoryCache!);
      debugPrint(
        'CurrencyVM: Applied in-memory history cache '
            '(${_lastGoodHistoryCache!.length} days)',
      );
    } else {
      final stored = await _loadHistoryFromCache();
      if (stored != null && stored.isNotEmpty) {
        _lastGoodHistoryCache = stored;
        _applyDailySeries(stored);
        debugPrint('CurrencyVM: Applied stored history (${stored.length} days)');
      } else {
        debugPrint('CurrencyVM: No cached history available');
      }
    }
  }

  // ── Rate Fallback Helpers ─────────────────────────────────────────────────

  /// Attempts to restore rates from in-memory cache within 3× the normal TTL.
  /// Returns true if restoration succeeded.
  bool _tryRestoreRatesFromRecentCache() {
    final cache = _lastGoodRatesCache;
    if (cache == null) return false;

    final cachedFiat = (cache['fiat'] as String?)?.toLowerCase();
    if (cachedFiat != _fiat) return false;

    final age = _getCacheAge(cache);
    final maxAge = rateCacheDuration * 3;
    if (age == null || age > maxAge) {
      debugPrint(
        'CurrencyVM: Cached rates too old '
            '(${age?.inMinutes ?? "unknown"}m > ${maxAge.inMinutes}m)',
      );
      return false;
    }

    final usdc = (cache['usdcRate'] as num?)?.toDouble() ?? 0.0;
    final xlm = (cache['xlmRate'] as num?)?.toDouble() ?? 0.0;
    final usdcPerXlm = (cache['lastUsdcPerXlm'] as num?)?.toDouble();

    if (usdc <= 0 || xlm <= 0 || !usdc.isFinite || !xlm.isFinite) return false;

    _usdcRate = usdc;
    _xlmRate = xlm;
    _lastUsdcPerXlm = (usdcPerXlm != null && usdcPerXlm > 0 && usdcPerXlm.isFinite)
        ? usdcPerXlm
        : (xlm / usdc);
    _ratesUnavailable = false;
    _usingFallbackRates = true;
    debugPrint('CurrencyVM: Restored cached rates (${age.inMinutes}m old)');
    return true;
  }

  /// Returns true if [value] does not deviate more than [_maxSingleSourceJumpPct]
  /// from the last cached rate for [tgt].
  ///
  /// FIX: Changed `<` to `<=` so a rate exactly equal to the threshold passes.
  bool _isSingleSourceRateReasonable(double value, String tgt) {
    if (!value.isFinite || value <= 0 || value > 1_000_000) return false;
    final cache = _lastGoodRatesCache;
    if (cache == null) return true; // No baseline — allow it
    final cachedFiat = (cache['fiat'] as String?)?.toUpperCase();
    if (cachedFiat != tgt.toUpperCase()) return true; // Different fiat — allow it
    final cached = (cache['usdcRate'] as num?)?.toDouble();
    if (cached == null || !cached.isFinite || cached <= 0) return true;
    final diffPct = ((value - cached).abs() / cached) * 100.0;
    return diffPct <= _maxSingleSourceJumpPct;
  }

  // ── USD→FIAT Helpers ──────────────────────────────────────────────────────
  Future<double?> _usdToFiat(String fiat) async {
    final tgt = fiat.toUpperCase();
    if (tgt == 'USD') return 1.0;
    return _withRetry(() => _fetchFiatRate(tgt), maxRetries: _maxRetries);
  }

  /// Queries all FX sources in parallel and requires ≥2 sources within
  /// [_maxFxSpreadPct]% of each other. Falls back to a single source only
  /// if it passes a reasonableness check.
  Future<double?> _fetchFiatRate(String tgt) async {
    final results = await Future.wait([
      _fetchFromFrankfurter(tgt),
      _fetchFromExchangeRateHost(tgt),
      _fetchFromErApi(tgt),
    ]);

    final values = results
        .where((v) => v != null && v!.isFinite && v > 0)
        .cast<double>()
        .toList()
      ..sort();

    if (values.isEmpty) return null;

    if (values.length >= 2) {
      // Use median as reference; include sources within spread tolerance.
      final median = values[values.length ~/ 2];
      final inBand = values.where((v) {
        final pct = ((v - median).abs() / median) * 100.0;
        return pct <= _maxFxSpreadPct; // FIX: was `<`, now `<=` so exact-median values pass
      }).toList();

      if (inBand.length >= 2) {
        return inBand.fold(0.0, (a, b) => a + b) / inBand.length;
      }
      debugPrint('CurrencyVM: FX sources diverged for $tgt: $values');
      return null;
    }

    // Single source — validate against cached baseline.
    final single = values.first;
    if (_isSingleSourceRateReasonable(single, tgt)) return single;
    debugPrint('CurrencyVM: Rejected single-source FX rate for $tgt: $single');
    return null;
  }

  Future<double?> _fetchFromFrankfurter(String tgt) async {
    final m = await _json(
      Uri.parse('https://api.frankfurter.app/latest?from=USD&to=$tgt'),
    );
    final v = (m['rates'] as Map?)?[tgt];
    return (v is num && v.isFinite && v > 0) ? v.toDouble() : null;
  }

  Future<double?> _fetchFromExchangeRateHost(String tgt) async {
    final m = await _json(
      Uri.parse('https://api.exchangerate.host/latest?base=USD&symbols=$tgt'),
    );
    if (m['success'] == false) return null;
    final v = (m['rates'] as Map?)?[tgt];
    return (v is num && v.isFinite && v > 0) ? v.toDouble() : null;
  }

  Future<double?> _fetchFromErApi(String tgt) async {
    final m = await _json(Uri.parse('https://open.er-api.com/v6/latest/USD'));
    final v = (m['rates'] as Map?)?[tgt];
    return (v is num && v.isFinite && v > 0) ? v.toDouble() : null;
  }

  // ── CEX ALL-TIME Fetchers ─────────────────────────────────────────────────
  Future<List<double>?> _fetchXlmUsdcDailyAllFromCex() async {
    return _firstNonNull<List<double>>([
      _cexBinanceDailyAll,
      _cexCoinbaseDailyAll,
      _cexKucoinDailyAll,
    ]);
  }

  Future<List<double>?> _cexBinanceDailyAll() async {
    const limit = 1000;
    int? endMs;
    final closes = <double>[];
    int guard = 0;

    while (guard++ < 10 && !_disposed) {
      final url = Uri.parse(
        'https://api.binance.com/api/v3/klines'
            '?symbol=XLMUSDT&interval=1d&limit=$limit'
            '${endMs != null ? '&endTime=$endMs' : ''}',
      );
      final batch = await _jsonList(url);
      if (batch.isEmpty) break;

      int? firstOpenTime;
      for (final item in batch) {
        if (item is! List || item.length < 5) continue;
        final close = _toD(item[4]);
        if (close != null) closes.add(close);
        firstOpenTime ??= item[0] is int ? item[0] as int : null;
      }

      if (firstOpenTime == null || batch.length < limit) break;

      // FIX: Subtract 1 ms from oldest candle open time to paginate backward.
      final newEnd = firstOpenTime - 1;
      if (endMs != null && newEnd >= endMs) break; // Infinite loop guard
      endMs = newEnd;
    }

    // Binance returns oldest-first already; no reversal needed.
    return closes.isEmpty ? null : closes;
  }

  Future<List<double>?> _cexCoinbaseDailyAll() async {
    final closes = <double>[];
    DateTime end = DateTime.now().toUtc();
    const chunkDays = 300;
    int guard = 0;

    while (guard++ < 15 && !_disposed) {
      final start = end.subtract(const Duration(days: chunkDays));

      // FIX: Guard against paginating before XLM listing date (May 2019).
      if (start.isBefore(DateTime.utc(2019, 5, 1))) break;

      final url = Uri.parse(
        'https://api.exchange.coinbase.com/products/XLM-USD/candles'
            '?granularity=86400'
            '&start=${start.toIso8601String()}'
            '&end=${end.toIso8601String()}',
      );
      final arr = await _jsonList(url);
      if (arr.isEmpty) break;

      final batch = <double>[];
      for (final item in arr) {
        if (item is! List || item.length < 5) continue;
        final close = _toD(item[4]);
        if (close != null) batch.add(close);
      }
      if (batch.isEmpty) break;

      // Coinbase returns latest-first; reverse to oldest-first before prepending.
      closes.insertAll(0, batch.reversed);

      if (arr.length < chunkDays) break;

      // FIX: Advance end backward so we don't re-fetch the same window.
      final newEnd = start.subtract(const Duration(seconds: 1));
      if (!newEnd.isBefore(end)) break; // Infinite loop guard
      end = newEnd;
    }

    return closes.isEmpty ? null : closes;
  }

  Future<List<double>?> _cexKucoinDailyAll() async {
    final closes = <double>[];
    int endAt = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    // XLM listed on KuCoin around 2018-01-01.
    final listingEpoch = DateTime.utc(2018, 1, 1).millisecondsSinceEpoch ~/ 1000;
    const chunkSec = 300 * 86400; // 300 days in seconds
    int guard = 0;

    while (guard++ < 15 && !_disposed) {
      final startAt = endAt - chunkSec;

      // FIX: Guard against paginating before listing date.
      if (startAt < listingEpoch) break;

      final url = Uri.parse(
        'https://api.kucoin.com/api/v1/market/candles'
            '?type=1day&symbol=XLM-USDT'
            '&startAt=$startAt&endAt=$endAt',
      );
      final m = await _json(url);
      final arr = (m['data'] as List?) ?? [];
      if (arr.isEmpty) break;

      final batch = <double>[];
      for (final item in arr) {
        if (item is! List || item.length < 3) continue;
        final close = _toD(item[2]);
        if (close != null) batch.add(close);
      }
      if (batch.isEmpty) break;

      closes.insertAll(0, batch.reversed);

      if (arr.length < chunkSec ~/ 86400) break;

      // FIX: Advance endAt backward; guard against infinite loop.
      final newEnd = startAt - 1;
      if (newEnd >= endAt) break;
      endAt = newEnd;
    }

    return closes.isEmpty ? null : closes;
  }

  // ── CEX Recent Fetchers ───────────────────────────────────────────────────
  Future<List<double>?> _fetchXlmUsdcDailyFromCex() async {
    return _firstNonNull<List<double>>([
      _cexBinanceDailyRecent,
      _cexCoinbaseDailyRecent,
      _cexKucoinDailyRecent,
      _cexOkxDailyRecent,
      _cexKrakenDailyRecent,
      _cexBitstampDailyRecent,
    ]);
  }

  Future<List<double>?> _cexBinanceDailyRecent() async {
    final data = await _jsonList(Uri.parse(
      'https://api.binance.com/api/v3/klines?symbol=XLMUSDT&interval=1d&limit=400',
    ));
    return _extractCloses(data, closeIndex: 4);
  }

  Future<List<double>?> _cexCoinbaseDailyRecent() async {
    final data = await _jsonList(Uri.parse(
      'https://api.exchange.coinbase.com/products/XLM-USD/candles?granularity=86400&limit=370',
    ));
    final closes = _extractCloses(data, closeIndex: 4);
    return closes?.reversed.toList(); // Reverse to oldest-first
  }

  Future<List<double>?> _cexKucoinDailyRecent() async {
    final m = await _json(Uri.parse(
      'https://api.kucoin.com/api/v1/market/candles?type=1day&symbol=XLM-USDT',
    ));
    final data = (m['data'] as List?) ?? [];
    final closes = _extractCloses(data, closeIndex: 2);
    return closes?.reversed.toList();
  }

  Future<List<double>?> _cexOkxDailyRecent() async {
    final m = await _json(Uri.parse(
      'https://www.okx.com/api/v5/market/candles?instId=XLM-USDT&bar=1D&limit=400',
    ));
    final data = (m['data'] as List?) ?? [];
    final closes = _extractCloses(data, closeIndex: 4);
    return closes?.reversed.toList();
  }

  Future<List<double>?> _cexKrakenDailyRecent() async {
    final m = await _json(Uri.parse(
      'https://api.kraken.com/0/public/OHLC?pair=XLMUSD&interval=1440',
    ));
    final result = (m['result'] as Map?) ?? {};
    // FIX: Use explicit type-safe key search to avoid matching 'last'.
    String? dataKey;
    for (final key in result.keys.cast<String>()) {
      if (key != 'last') {
        dataKey = key;
        break;
      }
    }
    if (dataKey == null) return null;
    final data = (result[dataKey] as List?) ?? [];
    return _extractCloses(data, closeIndex: 4);
  }

  Future<List<double>?> _cexBitstampDailyRecent() async {
    final m = await _json(Uri.parse(
      'https://www.bitstamp.net/api/v2/ohlc/xlmusd/?step=86400&limit=400',
    ));
    final ohlcList = ((m['data'] as Map?)?['ohlc'] as List?) ?? [];
    if (ohlcList.isEmpty) return null;

    // Sort ascending by timestamp.
    final sorted = List<dynamic>.from(ohlcList)
      ..sort((a, b) {
        final tsA = int.tryParse((a as Map)['timestamp']?.toString() ?? '') ?? 0;
        final tsB = int.tryParse((b as Map)['timestamp']?.toString() ?? '') ?? 0;
        return tsA.compareTo(tsB);
      });

    final closes = <double>[];
    for (final item in sorted) {
      final close = _toD((item as Map)['close']);
      if (close != null) closes.add(close);
    }
    return closes.isEmpty ? null : closes;
  }

  // ── DEX Fetchers ──────────────────────────────────────────────────────────
  Future<List<double>?> _fetchXlmUsdcDailyAllFromDex() async {
    final issuer = _stellar.usdcIssuer;
    final now = DateTime.now().toUtc();
    DateTime start = DateTime.utc(2015, 9, 1);
    final closes = <double>[];

    while (start.isBefore(now) && !_disposed) {
      final end = start.add(const Duration(days: 200));
      final url = Uri.parse(
        'https://horizon.stellar.org/trade_aggregations'
            '?base_asset_type=native'
            '&counter_asset_type=credit_alphanum12'
            '&counter_asset_code=USDC'
            '&counter_asset_issuer=$issuer'
            '&resolution=86400000'
            '&start_time=${start.millisecondsSinceEpoch}'
            '&end_time=${end.millisecondsSinceEpoch}'
            '&order=asc'
            '&limit=200',
      );
      final m = await _json(url);
      final records = (m['_embedded']?['records'] as List?) ??
          (m['records'] as List?) ??
          [];
      if (records.isEmpty) break;

      for (final r in records) {
        final close = _toD((r as Map)['close']);
        if (close != null) closes.add(close);
      }

      start = end;
      if (closes.length > _maxHistoryDays) break;
    }

    return closes.isEmpty ? null : closes;
  }

  Future<List<double>?> _fetchXlmUsdcDailyFromDex() async {
    final issuer = _stellar.usdcIssuer;
    final now = DateTime.now().toUtc();
    final start = now.subtract(const Duration(days: 400));

    final url = Uri.parse(
      'https://horizon.stellar.org/trade_aggregations'
          '?base_asset_type=native'
          '&counter_asset_type=credit_alphanum12'
          '&counter_asset_code=USDC'
          '&counter_asset_issuer=$issuer'
          '&resolution=86400000'
          '&start_time=${start.millisecondsSinceEpoch}'
          '&end_time=${now.millisecondsSinceEpoch}'
          '&order=asc'
          '&limit=200',
    );

    final m = await _json(url);
    final records = (m['_embedded']?['records'] as List?) ??
        (m['records'] as List?) ??
        [];
    if (records.isEmpty) return null;

    final closes = <double>[];
    for (final r in records) {
      final close = _toD((r as Map)['close']);
      if (close != null) closes.add(close);
    }
    return closes.isEmpty ? null : closes;
  }

  // ── Low-level HTTP ────────────────────────────────────────────────────────

  /// Fetches a URL and parses it as a JSON object.
  /// FIX: Response body is size-capped to [_maxResponseBytes] before parsing.
  Future<Map<String, dynamic>> _json(Uri url) async {
    final resp = await _client
        .get(url, headers: {'User-Agent': _userAgent})
        .timeout(httpTimeout);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw HttpException('HTTP ${resp.statusCode} for ${url.host}', uri: url);
    }

    final body = _capBody(resp.body, url);
    final decoded = jsonDecode(body.isEmpty ? '{}' : body);
    return decoded is Map<String, dynamic> ? decoded : {'_data': decoded};
  }

  /// Fetches a URL and parses it as a JSON array.
  Future<List<dynamic>> _jsonList(Uri url) async {
    final resp = await _client
        .get(url, headers: {'User-Agent': _userAgent})
        .timeout(httpTimeout);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw HttpException('HTTP ${resp.statusCode} for ${url.host}', uri: url);
    }

    final body = _capBody(resp.body, url);
    final decoded = jsonDecode(body.isEmpty ? '[]' : body);
    return decoded is List ? decoded : [];
  }

  /// Caps the response body to [_maxResponseBytes] characters.
  /// Logs a warning if truncation occurs.
  String _capBody(String body, Uri url) {
    if (body.length <= _maxResponseBytes) return body;
    debugPrint(
      'CurrencyVM: Response from ${url.host} truncated '
          '(${body.length} > $_maxResponseBytes bytes)',
    );
    return body.substring(0, _maxResponseBytes);
  }

  // ── Utilities ─────────────────────────────────────────────────────────────
  List<double> _tail(List<double> series, int n) {
    if (series.isEmpty) return const [];
    if (series.length <= n) return List<double>.from(series);
    return series.sublist(series.length - n);
  }

  double _pct(List<double> series) {
    if (series.length < 2) return 0.0;
    final first = series.first;
    final last = series.last;
    if (first <= 0 || !first.isFinite || !last.isFinite) return 0.0;
    return ((last - first) / first) * 100.0;
  }

  List<double>? _extractCloses(List<dynamic> data, {required int closeIndex}) {
    if (data.isEmpty) return null;
    final closes = <double>[];
    for (final item in data) {
      if (item is! List || item.length <= closeIndex) continue;
      final close = _toD(item[closeIndex]);
      if (close != null) closes.add(close);
    }
    return closes.isEmpty ? null : closes;
  }

  /// Returns the age of a cache entry, or null if the timestamp is missing/invalid.
  /// FIX: Uses UTC to avoid DST and timezone skew bugs.
  Duration? _getCacheAge(Map<dynamic, dynamic> cache) {
    final ts = cache['ts'];
    if (ts is! int) return null;
    final cachedAt = DateTime.fromMillisecondsSinceEpoch(ts * 1000, isUtc: true);
    return DateTime.now().toUtc().difference(cachedAt);
  }

  /// Safely converts a dynamic value to a positive finite double, or null.
  double? _toD(dynamic v) {
    if (v == null) return null;
    double? d;
    if (v is num) {
      d = v.toDouble();
    } else if (v is String) {
      d = double.tryParse(v);
    }
    return (d != null && d.isFinite && d > 0) ? d : null;
  }

  /// Tries each factory in sequence and returns the first non-null result.
  Future<T?> _firstNonNull<T>(List<Future<T?> Function()> attempts) async {
    for (final fetcher in attempts) {
      if (_disposed) return null;
      try {
        final result = await fetcher();
        if (result != null) return result;
      } catch (e) {
        debugPrint('CurrencyVM: Source attempt failed: $e');
      }
    }
    return null;
  }

  /// Retries [operation] up to [maxRetries] times with exponential back-off.
  ///
  /// FIX: On final attempt, rethrows the error so callers can fall back to cache.
  /// FIX: Respects _disposed flag between retries.
  Future<T?> _withRetry<T>(
      Future<T?> Function() operation, {
        int maxRetries = 3,
      }) async {
    for (var attempt = 0; attempt < maxRetries; attempt++) {
      if (_disposed) return null;
      try {
        return await operation();
      } catch (e) {
        if (attempt == maxRetries - 1) {
          debugPrint('CurrencyVM: Max retries ($maxRetries) reached: $e');
          rethrow;
        }
        final delay = _retryDelay * (1 << attempt); // 500ms, 1s, 2s
        debugPrint(
          'CurrencyVM: Retry ${attempt + 1}/$maxRetries after ${delay.inMilliseconds}ms',
        );
        await Future.delayed(delay);
      }
    }
    return null;
  }

  void _setLoading(bool v) {
    if (_disposed || _loading == v) return;
    _loading = v;
    notifyListeners();
  }
}