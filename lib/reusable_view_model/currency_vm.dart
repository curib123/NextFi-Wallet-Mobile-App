// lib/reusable_view_model/currency_vm.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/io_client.dart';
import 'package:next_fi/services/secure_storage/currency_secure_storage.dart';
import 'package:next_fi/services/stellar/stellar_wallet_services.dart';

/// Enhanced CurrencyVM with robust error handling, caching, and rate limiting
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

  /// USDC→FIAT (≈ USD→FIAT)
  double _usdcRate = 0;

  /// XLM→FIAT (computed as: (USDC per XLM) * (USDC→FIAT))
  double _xlmRate = 0;

  /// Latest USDC per 1 XLM (from stream or market fallbacks)
  double _lastUsdcPerXlm = 0;

  bool _loading = true;

  // Cache timestamps
  DateTime? _lastRateRefresh;
  DateTime? _lastHistoryRefresh;

  // Cached rates for fallback
  Map<String, dynamic>? _lastGoodRatesCache;
  List<double>? _lastGoodHistoryCache;

  // Streams exposed to UI
  final _xlmCtrl = StreamController<double>.broadcast();
  final _usdcCtrl = StreamController<double>.broadcast();

  // Subscriptions
  StreamSubscription? _pairSub;

  // Histories (oldest → newest closes, denominated in USDC per XLM)
  List<double> _xlmHist24h = const [];
  List<double> _xlmHist7 = const [];
  List<double> _xlmHist30 = const [];
  List<double> _xlmHist365 = const [];
  List<double> _xlmHistAll = const [];

  // Error tracking
  int _consecutiveErrors = 0;
  static const int _maxConsecutiveErrors = 3;

  // ── Public API ────────────────────────────────────────────────────────────
  String get fiat => _fiat;
  bool get loading => _loading;
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

  // USDC is a USD-pegged stablecoin; histories kept flat → ~0% deltas
  List<double> get usdcHistory24h =>
      List<double>.filled(2, _usdcRate <= 0 ? 1.0 : _usdcRate);
  List<double> get usdcHistory7 =>
      List<double>.filled(7, _usdcRate <= 0 ? 1.0 : _usdcRate);
  List<double> get usdcHistory30 =>
      List<double>.filled(30, _usdcRate <= 0 ? 1.0 : _usdcRate);
  List<double> get usdcHistory365 =>
      List<double>.filled(365, _usdcRate <= 0 ? 1.0 : _usdcRate);

  // Percent deltas based on history (oldest → newest)
  double get xlmPct24h => _pct(_xlmHist24h);
  double get xlmPct7d => _pct(_xlmHist7);
  double get xlmPct30d => _pct(_xlmHist30);
  double get xlmPct1y => _pct(_xlmHist365);
  double get xlmPctAll => _pct(_xlmHistAll);

  double get usdcPct24h => 0.0;
  double get usdcPct7d => 0.0;
  double get usdcPct30d => 0.0;
  double get usdcPct1y => 0.0;

  // Cache status
  bool get hasValidRateCache =>
      _lastRateRefresh != null &&
          DateTime.now().difference(_lastRateRefresh!) < rateCacheDuration;

  bool get hasValidHistoryCache =>
      _lastHistoryRefresh != null &&
          DateTime.now().difference(_lastHistoryRefresh!) < historyCacheDuration;

  /// Set fiat currency and refresh rates
  Future<void> setFiat(String v) async {
    final n = v.trim().toLowerCase();
    if (n.isEmpty || n == _fiat) return;

    _fiat = n;
    await CurrencySecureStorage.saveFiat(n);

    // Try to fetch new rates, fallback to cache if it fails
    await _refreshUsdToFiat();
    notifyListeners();
  }

  /// Reset to USD
  Future<void> resetFiatToUsd() async {
    _fiat = 'usd';
    await CurrencySecureStorage.clearFiat();
    await _refreshUsdToFiat();
    notifyListeners();
  }

  /// Manual refresh of rates (respects cache unless forced)
  Future<void> refreshRates({bool force = false}) async {
    if (!force && hasValidRateCache) {
      debugPrint('CurrencyVM: Using cached rates');
      return;
    }
    await _refreshUsdToFiat();
  }

  /// Manual refresh of history (respects cache unless forced)
  Future<void> refreshHistory({bool force = false}) async {
    if (!force && hasValidHistoryCache) {
      debugPrint('CurrencyVM: Using cached history');
      return;
    }
    await _refreshXlmHistoriesWithFallbacks();
  }

  // ── Quick Converters ──────────────────────────────────────────────────────
  double usdcToFiat(double u) {
    if (!u.isFinite || u.isNaN) return 0.0;
    return u * _usdcRate;
  }

  double xlmToFiat(double x) {
    if (!x.isFinite || x.isNaN) return 0.0;
    return x * _xlmRate;
  }

  double fiatToUsdc(double f) {
    if (!f.isFinite || f.isNaN || _usdcRate == 0) return 0.0;
    return f / _usdcRate;
  }

  double fiatToXlm(double f) {
    if (!f.isFinite || f.isNaN || _xlmRate == 0) return 0.0;
    return f / _xlmRate;
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  Future<void> _boot() async {
    try {
      // Load saved preferences
      final savedFiat = await CurrencySecureStorage.readFiat();
      if (savedFiat != null && savedFiat.trim().isNotEmpty) {
        _fiat = savedFiat.trim().toLowerCase();
      }

      // Load cached rates - ALWAYS use cache as initial state
      final cache = await CurrencySecureStorage.readLastGoodRates();
      if (cache != null) {
        _lastGoodRatesCache = cache;
        final cachedFiat = (cache['fiat'] as String?)?.toLowerCase();

        // Use cache regardless of age if it matches current fiat
        if (cachedFiat == _fiat) {
          _usdcRate = (cache['usdcRate'] as num?)?.toDouble() ?? 0.0;
          _xlmRate = (cache['xlmRate'] as num?)?.toDouble() ?? 0.0;
          _lastUsdcPerXlm = _xlmRate > 0 && _usdcRate > 0
              ? _xlmRate / _usdcRate
              : 0.0;

          final cacheAge = _getCacheAge(cache);
          debugPrint('CurrencyVM: Loaded cached rates (age: ${cacheAge?.inMinutes ?? "unknown"}m, XLM: $_xlmRate $_fiat, USDC per XLM: $_lastUsdcPerXlm)');
        }
      }
    } catch (e) {
      debugPrint('CurrencyVM: Error loading cache: $e');
    }

    // Subscribe to live XLM/USDC price stream
    _pairSub = _stellar.xlmUsdcPriceStream().listen(
          (p) {
        if (_disposed) return;
        if (p.usdcPerXlm > 0 && p.usdcPerXlm.isFinite) {
          final oldPrice = _lastUsdcPerXlm;
          _lastUsdcPerXlm = p.usdcPerXlm;
          _recomputeXlmFiat();
          _consecutiveErrors = 0; // Reset error counter on success

          // CRITICAL FIX: Save to cache IMMEDIATELY on every stream update
          _saveLatestPricesToCache();

          if ((oldPrice - p.usdcPerXlm).abs() > 0.0001) {
            debugPrint('CurrencyVM: Stream price updated: ${p.usdcPerXlm} USDC/XLM → ${_xlmRate.toStringAsFixed(4)} $_fiat/XLM');
          }
        }
      },
      onError: (e) {
        debugPrint('CurrencyVM: Stream error: $e');
        _consecutiveErrors++;

        // Use cached price if stream fails
        _useCachedPriceAsFallback();
      },
      cancelOnError: false,
    );

    // Fetch initial rates and histories
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
  Future<void> _refreshUsdToFiat() async {
    if (_disposed) return;

    _setLoading(true);
    try {
      final fx = await _usdToFiat(_fiat);

      if (fx != null && fx.isFinite && fx > 0) {
        _usdcRate = fx;
        _lastRateRefresh = DateTime.now();

        if (!_usdcCtrl.isClosed && !_disposed) {
          _usdcCtrl.add(_usdcRate);
        }

        _recomputeXlmFiat();
        _consecutiveErrors = 0;

        // CRITICAL FIX: Save to cache immediately after successful fetch
        await _saveLatestPricesToCache();

        debugPrint('CurrencyVM: Refreshed rates - USDC: $_usdcRate $_fiat, XLM: ${_xlmRate.toStringAsFixed(4)} $_fiat (USDC per XLM: $_lastUsdcPerXlm)');
      } else {
        throw Exception('Invalid exchange rate: $fx');
      }
    } catch (e) {
      debugPrint('CurrencyVM: Error refreshing rates: $e');
      _consecutiveErrors++;

      // ALWAYS fallback to latest cached rates
      await _useCachedRatesAsFallback();
    } finally {
      _setLoading(false);
      if (!_disposed) notifyListeners();
    }
  }

  void _recomputeXlmFiat() {
    if (_disposed) return;

    if (_lastUsdcPerXlm > 0 && _usdcRate > 0 &&
        _lastUsdcPerXlm.isFinite && _usdcRate.isFinite) {
      _xlmRate = _lastUsdcPerXlm * _usdcRate;

      if (!_xlmCtrl.isClosed && !_disposed) {
        _xlmCtrl.add(_xlmRate);
      }

      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _refreshXlmHistoriesWithFallbacks() async {
    if (_disposed) return;

    try {
      // Try strategies in order of preference
      List<double>? history;

      // 1) ALL-TIME via CEX
      history = await _fetchXlmUsdcDailyAllFromCex();
      if (history != null && history.length >= 2) {
        _applyDailySeries(history);
        _lastGoodHistoryCache = history;
        _lastHistoryRefresh = DateTime.now();
        await _saveHistoryToCache(history);
        debugPrint('CurrencyVM: Loaded ${history.length} days from CEX (all-time)');
        return;
      }

      // 2) ALL-TIME via DEX
      history = await _fetchXlmUsdcDailyAllFromDex();
      if (history != null && history.length >= 2) {
        _applyDailySeries(history);
        _lastGoodHistoryCache = history;
        _lastHistoryRefresh = DateTime.now();
        await _saveHistoryToCache(history);
        debugPrint('CurrencyVM: Loaded ${history.length} days from DEX (all-time)');
        return;
      }

      // 3) Recent CEX (~400 days)
      history = await _fetchXlmUsdcDailyFromCex();
      if (history != null && history.length >= 2) {
        _applyDailySeries(history);
        _lastGoodHistoryCache = history;
        _lastHistoryRefresh = DateTime.now();
        await _saveHistoryToCache(history);
        debugPrint('CurrencyVM: Loaded ${history.length} days from CEX (recent)');
        return;
      }

      // 4) Recent DEX
      history = await _fetchXlmUsdcDailyFromDex();
      if (history != null && history.length >= 2) {
        _applyDailySeries(history);
        _lastGoodHistoryCache = history;
        _lastHistoryRefresh = DateTime.now();
        await _saveHistoryToCache(history);
        debugPrint('CurrencyVM: Loaded ${history.length} days from DEX (recent)');
        return;
      }

      // 5) FALLBACK: Use cached history if all sources fail
      await _useCachedHistoryAsFallback();

      debugPrint('CurrencyVM: Using cached history as fallback');
    } catch (e) {
      debugPrint('CurrencyVM: Error refreshing history: $e');

      // ALWAYS fallback to cached history
      await _useCachedHistoryAsFallback();
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  void _applyDailySeries(List<double> dailyCloses) {
    if (_disposed || dailyCloses.isEmpty) return;

    // Validate data quality
    final validCloses = dailyCloses
        .where((c) => c.isFinite && c > 0)
        .toList();

    if (validCloses.isEmpty) {
      debugPrint('CurrencyVM: No valid price data after filtering');

      // Use cached history if validation fails
      _useCachedHistoryAsFallback();
      return;
    }

    // Cap to avoid memory issues
    final capped = validCloses.length > _maxHistoryDays
        ? validCloses.sublist(validCloses.length - _maxHistoryDays)
        : validCloses;

    _xlmHistAll = capped;
    _xlmHist365 = _tail(capped, 365);
    _xlmHist30 = _tail(capped, 30);
    _xlmHist7 = _tail(capped, 7);
    _xlmHist24h = _tail(capped, 2);

    // Seed current price if stream hasn't provided one yet
    if (_lastUsdcPerXlm <= 0 && capped.isNotEmpty) {
      _lastUsdcPerXlm = capped.last;
      _recomputeXlmFiat();
    }
  }

  // ── Fallback & Cache Helpers ──────────────────────────────────────────────

  /// CRITICAL FIX: New method to save latest prices to cache immediately
  /// This ensures cache always has the most recent successful data
  Future<void> _saveLatestPricesToCache() async {
    if (_usdcRate <= 0 || _xlmRate <= 0 || _lastUsdcPerXlm <= 0) {
      return; // Don't save invalid data
    }

    try {
      final cacheData = {
        'fiat': _fiat,
        'usdcRate': _usdcRate,
        'xlmRate': _xlmRate,
        'lastUsdcPerXlm': _lastUsdcPerXlm,
        'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      };

      // Update in-memory cache
      _lastGoodRatesCache = cacheData;

      // Persist to secure storage
      await CurrencySecureStorage.saveLastGoodRates(cacheData);

      // Update timestamp
      _lastRateRefresh = DateTime.now();
    } catch (e) {
      debugPrint('CurrencyVM: Error saving latest prices to cache: $e');
    }
  }

  /// Use cached rates as fallback when fetch fails
  Future<void> _useCachedRatesAsFallback() async {
    if (_lastGoodRatesCache != null) {
      final cachedFiat = (_lastGoodRatesCache!['fiat'] as String?)?.toLowerCase();

      // Use cache even if fiat doesn't match - better than nothing
      final cachedUsdcRate = (_lastGoodRatesCache!['usdcRate'] as num?)?.toDouble() ?? 0.0;
      final cachedXlmRate = (_lastGoodRatesCache!['xlmRate'] as num?)?.toDouble() ?? 0.0;
      final cachedUsdcPerXlm = (_lastGoodRatesCache!['lastUsdcPerXlm'] as num?)?.toDouble();

      if (cachedUsdcRate > 0) {
        _usdcRate = cachedUsdcRate;
        debugPrint('CurrencyVM: ✓ Using cached USDC rate: $_usdcRate $_fiat (from fiat: $cachedFiat)');
      } else if (_usdcRate == 0) {
        _usdcRate = 1.0; // Ultimate fallback
        debugPrint('CurrencyVM: ⚠ Using default USDC rate: 1.0');
      }

      if (cachedXlmRate > 0) {
        _xlmRate = cachedXlmRate;

        // Use cached USDC per XLM if available
        if (cachedUsdcPerXlm != null && cachedUsdcPerXlm > 0) {
          _lastUsdcPerXlm = cachedUsdcPerXlm;
        } else {
          _lastUsdcPerXlm = _xlmRate / _usdcRate;
        }

        debugPrint('CurrencyVM: ✓ Using cached XLM rate: ${_xlmRate.toStringAsFixed(4)} $_fiat (USDC per XLM: $_lastUsdcPerXlm)');
      }
    } else if (_usdcRate == 0) {
      // No cache available, use default
      _usdcRate = 1.0;
      debugPrint('CurrencyVM: ⚠ No cache available, using default rate');
    }

    if (!_disposed) notifyListeners();
  }

  /// Use cached price from stream as fallback
  void _useCachedPriceAsFallback() {
    if (_lastGoodRatesCache != null) {
      final cachedXlmRate = (_lastGoodRatesCache!['xlmRate'] as num?)?.toDouble() ?? 0.0;
      final cachedUsdcRate = (_lastGoodRatesCache!['usdcRate'] as num?)?.toDouble() ?? 0.0;
      final cachedUsdcPerXlm = (_lastGoodRatesCache!['lastUsdcPerXlm'] as num?)?.toDouble();

      if (cachedUsdcPerXlm != null && cachedUsdcPerXlm > 0) {
        _lastUsdcPerXlm = cachedUsdcPerXlm;
        _recomputeXlmFiat();
        debugPrint('CurrencyVM: ✓ Using cached stream price as fallback: $cachedUsdcPerXlm USDC/XLM');
      } else if (cachedXlmRate > 0 && cachedUsdcRate > 0) {
        _lastUsdcPerXlm = cachedXlmRate / cachedUsdcRate;
        _recomputeXlmFiat();
        debugPrint('CurrencyVM: ✓ Computed stream price from cached rates: $_lastUsdcPerXlm USDC/XLM');
      }
    }
  }

  /// Use cached history as fallback
  Future<void> _useCachedHistoryAsFallback() async {
    if (_lastGoodHistoryCache != null && _lastGoodHistoryCache!.isNotEmpty) {
      _applyDailySeries(_lastGoodHistoryCache!);
      debugPrint('CurrencyVM: Applied cached history (${_lastGoodHistoryCache!.length} days)');
    } else {
      // Try to load from storage
      final storedHistory = await _loadHistoryFromCache();
      if (storedHistory != null && storedHistory.isNotEmpty) {
        _lastGoodHistoryCache = storedHistory;
        _applyDailySeries(storedHistory);
        debugPrint('CurrencyVM: Applied stored history (${storedHistory.length} days)');
      } else {
        debugPrint('CurrencyVM: No cached history available');
      }
    }
  }

  /// Save history to cache
  Future<void> _saveHistoryToCache(List<double> history) async {
    try {
      // Store in secure storage with timestamp
      await CurrencySecureStorage.saveLastGoodHistory({
        'history': history,
        'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      });
    } catch (e) {
      debugPrint('CurrencyVM: Error saving history to cache: $e');
    }
  }

  /// Load history from cache
  Future<List<double>?> _loadHistoryFromCache() async {
    try {
      final cache = await CurrencySecureStorage.readLastGoodHistory();
      if (cache != null) {
        final historyData = cache['history'];
        if (historyData is List) {
          return historyData.map((e) => (e as num).toDouble()).toList();
        }
      }
    } catch (e) {
      debugPrint('CurrencyVM: Error loading history from cache: $e');
    }
    return null;
  }

  // ── USD→FIAT Helpers ──────────────────────────────────────────────────────
  Future<double?> _usdToFiat(String fiat) async {
    final tgt = fiat.toUpperCase();
    if (tgt == 'USD') return 1.0;

    return _withRetry(() => _fetchFiatRate(tgt), maxRetries: _maxRetries);
  }

  Future<double?> _fetchFiatRate(String tgt) async {
    // Try multiple FX sources in parallel for faster response
    final futures = [
      _fetchFromFrankfurter(tgt),
      _fetchFromExchangeRateHost(tgt),
      _fetchFromErApi(tgt),
    ];

    // Return first successful result
    return _firstSuccessful(futures);
  }

  Future<double?> _fetchFromFrankfurter(String tgt) async {
    final m = await _json(
      Uri.parse('https://api.frankfurter.app/latest?from=USD&to=$tgt'),
    );
    final v = (m['rates'] as Map?)?[tgt];
    return (v is num && v.isFinite) ? v.toDouble() : null;
  }

  Future<double?> _fetchFromExchangeRateHost(String tgt) async {
    final m = await _json(
      Uri.parse('https://api.exchangerate.host/latest?base=USD&symbols=$tgt'),
    );
    final v = (m['rates'] as Map?)?[tgt];
    return (v is num && v.isFinite) ? v.toDouble() : null;
  }

  Future<double?> _fetchFromErApi(String tgt) async {
    final m = await _json(
      Uri.parse('https://open.er-api.com/v6/latest/USD'),
    );
    final v = (m['rates'] as Map?)?[tgt];
    return (v is num && v.isFinite) ? v.toDouble() : null;
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
        'https://api.binance.com/api/v3/klines?symbol=XLMUSDT&interval=1d&limit=$limit'
            '${endMs != null ? '&endTime=$endMs' : ''}',
      );

      final batch = await _jsonList(url);
      if (batch.isEmpty) break;

      // Extract closes (index 4)
      for (final item in batch) {
        if (item is! List || item.length < 5) continue;
        final close = _toD(item[4]);
        if (close != null && close > 0) closes.add(close);
      }

      // Get timestamp of first candle for pagination
      final firstItem = batch.first;
      if (firstItem is List && firstItem.isNotEmpty) {
        final openTime = firstItem[0];
        endMs = (openTime is int) ? openTime - 1 : null;
        if (endMs == null || batch.length < limit) break;
      } else {
        break;
      }
    }

    return closes.isEmpty ? null : closes;
  }

  Future<List<double>?> _cexCoinbaseDailyAll() async {
    final closes = <double>[];
    DateTime end = DateTime.now().toUtc();
    const chunkDays = 300;
    int guard = 0;

    while (guard++ < 15 && !_disposed) {
      final start = end.subtract(const Duration(days: chunkDays));
      final url = Uri.parse(
        'https://api.exchange.coinbase.com/products/XLM-USD/candles'
            '?granularity=86400&start=${start.toIso8601String()}&end=${end.toIso8601String()}',
      );

      final arr = await _jsonList(url);
      if (arr.isEmpty) break;

      // Extract closes (index 4) - response is latest-first
      final batch = <double>[];
      for (final item in arr) {
        if (item is! List || item.length < 5) continue;
        final close = _toD(item[4]);
        if (close != null && close > 0) batch.add(close);
      }

      if (batch.isEmpty) break;

      // Reverse to oldest-first and prepend
      closes.insertAll(0, batch.reversed);

      if (arr.length < chunkDays) break;
      end = start;
    }

    return closes.isEmpty ? null : closes;
  }

  Future<List<double>?> _cexKucoinDailyAll() async {
    final closes = <double>[];
    int endAt = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    const chunkDays = 300;
    int guard = 0;

    while (guard++ < 15 && !_disposed) {
      final startAt = endAt - (chunkDays * 86400);
      final url = Uri.parse(
        'https://api.kucoin.com/api/v1/market/candles?type=1day&symbol=XLM-USDT'
            '&startAt=$startAt&endAt=$endAt',
      );

      final m = await _json(url);
      final arr = (m['data'] as List?) ?? [];
      if (arr.isEmpty) break;

      // Extract closes (index 2) - response is latest-first
      final batch = <double>[];
      for (final item in arr) {
        if (item is! List || item.length < 3) continue;
        final close = _toD(item[2]);
        if (close != null && close > 0) batch.add(close);
      }

      if (batch.isEmpty) break;

      // Reverse and prepend
      closes.insertAll(0, batch.reversed);

      if (arr.length < chunkDays) break;
      endAt = startAt;
    }

    return closes.isEmpty ? null : closes;
  }

  // ── CEX Recent Fetchers (~400 days) ───────────────────────────────────────
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
    final url = Uri.parse(
      'https://api.binance.com/api/v3/klines?symbol=XLMUSDT&interval=1d&limit=400',
    );
    final data = await _jsonList(url);
    return _extractCloses(data, closeIndex: 4);
  }

  Future<List<double>?> _cexCoinbaseDailyRecent() async {
    final url = Uri.parse(
      'https://api.exchange.coinbase.com/products/XLM-USD/candles?granularity=86400&limit=370',
    );
    final data = await _jsonList(url);
    final closes = _extractCloses(data, closeIndex: 4);
    return closes?.reversed.toList(); // Reverse to oldest-first
  }

  Future<List<double>?> _cexKucoinDailyRecent() async {
    final url = Uri.parse(
      'https://api.kucoin.com/api/v1/market/candles?type=1day&symbol=XLM-USDT',
    );
    final m = await _json(url);
    final data = (m['data'] as List?) ?? [];
    final closes = _extractCloses(data, closeIndex: 2);
    return closes?.reversed.toList();
  }

  Future<List<double>?> _cexOkxDailyRecent() async {
    final url = Uri.parse(
      'https://www.okx.com/api/v5/market/candles?instId=XLM-USDT&bar=1D&limit=400',
    );
    final m = await _json(url);
    final data = (m['data'] as List?) ?? [];
    final closes = _extractCloses(data, closeIndex: 4);
    return closes?.reversed.toList();
  }

  Future<List<double>?> _cexKrakenDailyRecent() async {
    final url = Uri.parse(
      'https://api.kraken.com/0/public/OHLC?pair=XLMUSD&interval=1440',
    );
    final m = await _json(url);
    final result = (m['result'] as Map?) ?? {};

    // Find the data key (not 'last')
    String? dataKey;
    for (final key in result.keys) {
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
    final url = Uri.parse(
      'https://www.bitstamp.net/api/v2/ohlc/xlmusd/?step=86400&limit=400',
    );
    final m = await _json(url);
    final ohlcList = ((m['data'] as Map?)?['ohlc'] as List?) ?? [];

    if (ohlcList.isEmpty) return null;

    // Sort by timestamp
    final sorted = List.from(ohlcList)
      ..sort((a, b) {
        final tsA = int.tryParse((a as Map)['timestamp']?.toString() ?? '0') ?? 0;
        final tsB = int.tryParse((b as Map)['timestamp']?.toString() ?? '0') ?? 0;
        return tsA.compareTo(tsB);
      });

    final closes = <double>[];
    for (final item in sorted) {
      final close = _toD((item as Map)['close']);
      if (close != null && close > 0) closes.add(close);
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
          (m['records'] as List?) ?? [];

      if (records.isEmpty) break;

      for (final r in records) {
        final close = _toD((r as Map)['close']);
        if (close != null && close > 0) closes.add(close);
      }

      start = end;

      // Safety cap
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
        (m['records'] as List?) ?? [];

    if (records.isEmpty) return null;

    final closes = <double>[];
    for (final r in records) {
      final close = _toD((r as Map)['close']);
      if (close != null && close > 0) closes.add(close);
    }

    return closes.isEmpty ? null : closes;
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

  List<double>? _extractCloses(List data, {required int closeIndex}) {
    if (data.isEmpty) return null;

    final closes = <double>[];
    for (final item in data) {
      if (item is! List || item.length <= closeIndex) continue;
      final close = _toD(item[closeIndex]);
      if (close != null && close > 0) closes.add(close);
    }

    return closes.isEmpty ? null : closes;
  }

  Duration? _getCacheAge(Map cache) {
    final ts = cache['ts'];
    if (ts is! int) return null;
    final cachedAt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    return DateTime.now().difference(cachedAt);
  }

  Future<Map<String, dynamic>> _json(Uri url) async {
    final resp = await _client
        .get(url, headers: {'User-Agent': _userAgent})
        .timeout(httpTimeout);

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final body = resp.body.isEmpty ? '{}' : resp.body;
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : {'_data': decoded};
    }

    throw HttpException(
      'HTTP ${resp.statusCode} for ${url.host}',
      uri: url,
    );
  }

  Future<List<dynamic>> _jsonList(Uri url) async {
    final resp = await _client
        .get(url, headers: {'User-Agent': _userAgent})
        .timeout(httpTimeout);

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final body = resp.body.isEmpty ? '[]' : resp.body;
      final decoded = jsonDecode(body);
      return decoded is List ? decoded : [];
    }

    throw HttpException(
      'HTTP ${resp.statusCode} for ${url.host}',
      uri: url,
    );
  }

  double? _toD(dynamic v) {
    if (v == null) return null;

    if (v is num) {
      final d = v.toDouble();
      return (d.isFinite && d > 0) ? d : null;
    }

    if (v is String) {
      final parsed = double.tryParse(v);
      return (parsed != null && parsed.isFinite && parsed > 0) ? parsed : null;
    }

    return null;
  }

  Future<T?> _firstNonNull<T>(List<Future<T?> Function()> attempts) async {
    for (final fetcher in attempts) {
      if (_disposed) return null;

      try {
        final result = await fetcher();
        if (result != null) return result;
      } catch (e) {
        debugPrint('CurrencyVM: Attempt failed: $e');
        continue;
      }
    }
    return null;
  }

  /// Run multiple futures in parallel and return first successful result
  Future<T?> _firstSuccessful<T>(List<Future<T?>> futures) async {
    if (futures.isEmpty) return null;

    try {
      return await Future.any(
        futures.map((f) => f.then((v) => v != null ? v : Future<T>.error('null'))),
      );
    } catch (_) {
      return null;
    }
  }

  /// Retry helper with exponential backoff
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
          debugPrint('CurrencyVM: Max retries reached: $e');
          rethrow;
        }

        final delay = _retryDelay * (1 << attempt); // Exponential backoff
        debugPrint('CurrencyVM: Retry $attempt after ${delay.inMilliseconds}ms');
        await Future.delayed(delay);
      }
    }
    return null;
  }

  void _setLoading(bool v) {
    if (_disposed) return;
    if (_loading != v) {
      _loading = v;
      notifyListeners();
    }
  }
}