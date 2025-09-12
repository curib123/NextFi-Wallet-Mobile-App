// lib/Provider/CurrencyProvider.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/io_client.dart';

import 'package:next_fi/Services/currency_secure_storage.dart';
import 'package:next_fi/Services/stellar/stellar_wallet_services.dart';

class CurrencyProvider extends ChangeNotifier {
  CurrencyProvider({
    required StellarWalletService stellar,
    this.httpTimeout = const Duration(seconds: 10),
  }) : _stellar = stellar {
    _client = _buildClient();
    _boot();
  }

  // ── Deps & Config ─────────────────────────────────────────────────────────
  final StellarWalletService _stellar;
  final Duration httpTimeout;

  // ── HTTP client ───────────────────────────────────────────────────────────
  late final IOClient _client;
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

  // Streams exposed to UI
  final _xlmCtrl = StreamController<double>.broadcast();
  final _usdcCtrl = StreamController<double>.broadcast();

  // Subscriptions
  StreamSubscription? _pairSub;

  // Histories (oldest → newest closes, denominated in USDC per XLM)
  List<double> _xlmHist24h = const []; // last two daily closes
  List<double> _xlmHist7   = const [];
  List<double> _xlmHist30  = const [];
  List<double> _xlmHist365 = const [];
  List<double> _xlmHistAll = const []; // NEW: all available years

  // ── Public API ─────────────────────────────────────────────────────────────
  String get fiat => _fiat;
  bool get loading => _loading;
  double get usdcRate => _usdcRate;
  double get xlmRate => _xlmRate;

  Stream<double> get xlmPriceStream => _xlmCtrl.stream;
  Stream<double> get usdcPriceStream => _usdcCtrl.stream;

  List<double> get xlmHistory24h => _xlmHist24h;
  List<double> get xlmHistory7   => _xlmHist7;
  List<double> get xlmHistory30  => _xlmHist30;
  List<double> get xlmHistory365 => _xlmHist365;
  List<double> get xlmHistoryAll => _xlmHistAll; // NEW

  // USDC is a USD-pegged stablecoin; histories kept flat → ~0% deltas.
  List<double> get usdcHistory24h => List<double>.filled(2, _usdcRate <= 0 ? 1.0 : _usdcRate);
  List<double> get usdcHistory7   => List<double>.filled(7, _usdcRate <= 0 ? 1.0 : _usdcRate);
  List<double> get usdcHistory30  => List<double>.filled(30, _usdcRate <= 0 ? 1.0 : _usdcRate);
  List<double> get usdcHistory365 => List<double>.filled(365, _usdcRate <= 0 ? 1.0 : _usdcRate);

  // Percent deltas based on history (oldest → newest). Returns 0.0 if invalid.
  double get xlmPct24h => _pct(_xlmHist24h);
  double get xlmPct7d  => _pct(_xlmHist7);
  double get xlmPct30d => _pct(_xlmHist30);
  double get xlmPct1y  => _pct(_xlmHist365);
  double get xlmPctAll => _pct(_xlmHistAll); // NEW

  double get usdcPct24h => 0.0;
  double get usdcPct7d  => 0.0;
  double get usdcPct30d => 0.0;
  double get usdcPct1y  => 0.0;

  void setFiat(String v) {
    final n = v.trim().toLowerCase();
    if (n.isEmpty || n == _fiat) return;
    _fiat = n;
    CurrencySecureStorage.saveFiat(n);
    _refreshUsdToFiat(); // recompute USDC→FIAT (and thus XLM→FIAT)
    notifyListeners();
  }

  Future<void> resetFiatToUsd() async {
    _fiat = 'usd';
    await CurrencySecureStorage.clearFiat();
    await _refreshUsdToFiat();
    notifyListeners();
  }

  // Quick converters
  double usdcToFiat(double u) => u * _usdcRate;
  double xlmToFiat(double x)  => x * _xlmRate;
  double fiatToUsdc(double f) => _usdcRate != 0 ? f / _usdcRate : 0.0;
  double fiatToXlm(double f)  => _xlmRate  != 0 ? f / _xlmRate  : 0.0;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  void _boot() async {
    try {
      final savedFiat = await CurrencySecureStorage.readFiat();
      if (savedFiat != null && savedFiat.trim().isNotEmpty) {
        _fiat = savedFiat.trim().toLowerCase();
      }
      final cache = await CurrencySecureStorage.readLastGoodRates();
      if (cache != null && (cache['fiat'] as String?)?.toLowerCase() == _fiat) {
        _usdcRate = (cache['usdcRate'] as num?)?.toDouble() ?? _usdcRate;
        _xlmRate  = (cache['xlmRate']  as num?)?.toDouble() ?? _xlmRate;
      }
    } catch (_) {}

    // Subscribe to live XLM/USDC price from your Stellar service (preferred)
    _pairSub = _stellar.xlmUsdcPriceStream().listen((p) {
      if (p.usdcPerXlm > 0) {
        _lastUsdcPerXlm = p.usdcPerXlm;
        _recomputeXlmFiat();
      }
    }, onError: (_) { /* ignore, we have fallbacks */ });

    // Fetch initial USDC→FIAT (≈ USD→FIAT)
    await _refreshUsdToFiat();

    // Fetch XLM/USDC full histories (CEX → DEX)
    await _refreshXlmHistoriesWithFallbacks();

    _setLoading(false);
  }

  @override
  void dispose() {
    _pairSub?.cancel();
    _xlmCtrl.close();
    _usdcCtrl.close();
    _client.close();
    super.dispose();
  }

  // ── Core logic ────────────────────────────────────────────────────────────
  Future<void> _refreshUsdToFiat() async {
    _setLoading(true);
    try {
      final fx = await _usdToFiat(_fiat) ?? 1.0; // USDC≈USD peg
      _usdcRate = fx;
      _usdcCtrl.add(_usdcRate);
      _recomputeXlmFiat();

      await CurrencySecureStorage.saveLastGoodRates({
        'fiat': _fiat,
        'usdcRate': _usdcRate,
        'xlmRate': _xlmRate,
        'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      });
    } catch (_) {
      // If offline and we have cached rates, keep them.
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  void _recomputeXlmFiat() {
    if (_lastUsdcPerXlm > 0 && _usdcRate > 0) {
      _xlmRate = _lastUsdcPerXlm * _usdcRate;
      _xlmCtrl.add(_xlmRate);
      notifyListeners();
    }
  }

  Future<void> _refreshXlmHistoriesWithFallbacks() async {
    try {
      // 1) Try ALL-TIME via CEX paginated fallbacks
      final all = await _fetchXlmUsdcDailyAllFromCex();
      if (all != null && all.length >= 2) {
        _applyDailySeries(all);
        return;
      }

      // 2) Fallback to DEX ALL-TIME (Horizon trade_aggregations in chunks)
      final dexAll = await _fetchXlmUsdcDailyAllFromDex();
      if (dexAll != null && dexAll.length >= 2) {
        _applyDailySeries(dexAll);
        return;
      }

      // 3) Last resort: limited CEX (≈ recent ~400 days), then DEX recent
      final recent = await _fetchXlmUsdcDailyFromCex();
      if (recent != null && recent.length >= 2) {
        _applyDailySeries(recent);
        return;
      }
      final dexRecent = await _fetchXlmUsdcDailyFromDex();
      if (dexRecent != null && dexRecent.length >= 2) {
        _applyDailySeries(dexRecent);
        return;
      }
    } catch (_) {
      // keep last good
    } finally {
      notifyListeners();
    }
  }

  void _applyDailySeries(List<double> dailyCloses) {
    // Ensure oldest → newest
    final series = List<double>.from(dailyCloses);
    // Cap to avoid huge memory (keep up to 5000 days ≈ 13.7y)
    const cap = 5000;
    final capped = series.length > cap ? series.sublist(series.length - cap) : series;

    _xlmHistAll  = capped;
    _xlmHist365  = _tail(capped, 365);
    _xlmHist30   = _tail(capped, 30);
    _xlmHist7    = _tail(capped, 7);
    _xlmHist24h  = _tail(capped, 2); // yesterday, today

    // If live stream hasn’t set a price yet, seed it from market
    if (_lastUsdcPerXlm <= 0 && capped.isNotEmpty) {
      _lastUsdcPerXlm = capped.last;
      _recomputeXlmFiat();
    }
  }

  // ── USD→FIAT helpers (USDC≈USD) ───────────────────────────────────────────
  Future<double?> _usdToFiat(String fiat) async {
    final tgt = fiat.toUpperCase();
    if (tgt == 'USD') return 1.0;

    // Try a few reputable FX sources; first successful wins.
    return _firstNonNull<double>([
          () async {
        final m = await _json(Uri.parse('https://api.frankfurter.app/latest?from=USD&to=$tgt'));
        final v = (m['rates'] as Map?)?[tgt];
        return (v is num) ? v.toDouble() : null;
      },
          () async {
        final m = await _json(Uri.parse('https://api.exchangerate.host/latest?base=USD&symbols=$tgt'));
        final v = (m['rates'] as Map?)?[tgt];
        return (v is num) ? v.toDouble() : null;
      },
          () async {
        final m = await _json(Uri.parse('https://open.er-api.com/v6/latest/USD'));
        final v = (m['rates'] as Map?)?[tgt];
        return (v is num) ? v.toDouble() : null;
      },
    ]);
  }

  // ── CEX FALLBACKS (ALL-TIME daily closes in USDT/USD ≈ USDC per XLM) ──────
  Future<List<double>?> _fetchXlmUsdcDailyAllFromCex() async {
    return _firstNonNull<List<double>>([
      _cexBinanceDailyAll,
      _cexCoinbaseDailyAll,
      _cexKucoinDailyAll,
      // If ALL fails everywhere above, later fall back to recent CEX then DEX.
    ]);
  }

  // Binance: paginate backward using endTime & limit=1000 (oldest→newest per batch)
  Future<List<double>?> _cexBinanceDailyAll() async {
    const limit = 1000;
    int? endMs;
    final all = <List<dynamic>>[];
    int guard = 0;

    while (guard++ < 10) { // up to ~10k days if API allowed
      final url = Uri.parse(
        'https://api.binance.com/api/v3/klines?symbol=XLMUSDT&interval=1d&limit=$limit'
            '${endMs != null ? '&endTime=$endMs' : ''}',
      );
      final batch = await _jsonList(url);
      if (batch.isEmpty) break;
      all.addAll(batch as Iterable<List>);
      final firstOpen = (batch.first as List).first; // openTime ms
      final nextEnd = (firstOpen is int) ? firstOpen - 1 : null;
      if (nextEnd == null || batch.length < limit) break;
      endMs = nextEnd;
    }

    if (all.isEmpty) return null;
    // Flatten → closes
    final closes = <double>[];
    for (final it in all) {
      final c = _toD((it)[4]);
      if (c != null) closes.add(c);
    }
    return closes.isEmpty ? null : closes;
  }

  // Coinbase (GDAX): paginate with start/end ISO, latest-first per response
  Future<List<double>?> _cexCoinbaseDailyAll() async {
    final closes = <double>[];
    // Chunk≈300 days each to stay within limits
    DateTime end = DateTime.now().toUtc();
    const chunkDays = 300;
    int guard = 0;

    while (guard++ < 12) {
      final start = end.subtract(const Duration(days: chunkDays));
      final url = Uri.parse(
        'https://api.exchange.coinbase.com/products/XLM-USD/candles'
            '?granularity=86400&start=${start.toIso8601String()}&end=${end.toIso8601String()}',
      );
      final arr = await _jsonList(url);
      if (arr.isEmpty) break;

      // item: [time, low, high, open, close, volume] (latest first)
      var batch = <double>[];
      for (final it in arr) {
        final c = _toD((it as List)[4]);
        if (c != null) batch.add(c);
      }
      if (batch.isEmpty) break;
      batch = batch.reversed.toList(); // oldest→newest
      closes.insertAll(0, batch); // prepend to keep overall oldest→newest

      if (arr.length < 300) break; // reached earliest
      end = start; // move window back
    }

    return closes.isEmpty ? null : closes;
  }

  // KuCoin: paginate with startAt/endAt epoch seconds, latest-first per response
  Future<List<double>?> _cexKucoinDailyAll() async {
    final closes = <double>[];
    int endAt = (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000);
    const chunkDays = 300;
    int guard = 0;

    while (guard++ < 12) {
      final startAt = endAt - (chunkDays * 86400);
      final url = Uri.parse(
        'https://api.kucoin.com/api/v1/market/candles?type=1day&symbol=XLM-USDT'
            '&startAt=$startAt&endAt=$endAt',
      );
      final m = await _json(url);
      final arr = (m['data'] as List?) ?? const [];
      if (arr.isEmpty) break;

      var batch = <double>[];
      for (final it in arr) {
        // item: [time, open, close, high, low, volume, turnover] (latest first)
        final c = _toD((it as List)[2]);
        if (c != null) batch.add(c);
      }
      if (batch.isEmpty) break;
      batch = batch.reversed.toList(); // oldest→newest
      closes.insertAll(0, batch);

      if (arr.length < 300) break;
      endAt = startAt; // move window back
    }

    return closes.isEmpty ? null : closes;
  }

  // ── Limited CEX (≈ last ~400 days) for “recent” fallback ───────────────────
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
        'https://api.binance.com/api/v3/klines?symbol=XLMUSDT&interval=1d&limit=400');
    final d = await _jsonList(url);
    if (d.isEmpty) return null;
    final closes = <double>[];
    for (final it in d) {
      final c = _toD((it as List)[4]);
      if (c != null) closes.add(c);
    }
    return closes.isEmpty ? null : closes;
  }

  Future<List<double>?> _cexCoinbaseDailyRecent() async {
    final url = Uri.parse(
        'https://api.exchange.coinbase.com/products/XLM-USD/candles?granularity=86400&limit=370');
    final d = await _jsonList(url);
    if (d.isEmpty) return null;
    var closes = <double>[];
    for (final it in d) {
      final c = _toD((it as List)[4]);
      if (c != null) closes.add(c);
    }
    return closes.reversed.toList();
  }

  Future<List<double>?> _cexKucoinDailyRecent() async {
    final url = Uri.parse(
        'https://api.kucoin.com/api/v1/market/candles?type=1day&symbol=XLM-USDT');
    final m = await _json(url);
    final arr = (m['data'] as List?) ?? const [];
    if (arr.isEmpty) return null;
    var closes = <double>[];
    for (final it in arr) {
      final c = _toD((it as List)[2]);
      if (c != null) closes.add(c);
    }
    return closes.reversed.toList();
  }

  Future<List<double>?> _cexOkxDailyRecent() async {
    final url = Uri.parse(
        'https://www.okx.com/api/v5/market/candles?instId=XLM-USDT&bar=1D&limit=400');
    final m = await _json(url);
    final arr = (m['data'] as List?) ?? const [];
    if (arr.isEmpty) return null;
    var closes = <double>[];
    for (final it in arr) {
      final c = _toD((it as List)[4]);
      if (c != null) closes.add(c);
    }
    return closes.reversed.toList();
  }

  Future<List<double>?> _cexKrakenDailyRecent() async {
    final url = Uri.parse('https://api.kraken.com/0/public/OHLC?pair=XLMUSD&interval=1440');
    final m = await _json(url);
    final res = (m['result'] as Map?) ?? const {};
    String? k;
    for (final key in res.keys) {
      if (key != 'last') { k = key; break; }
    }
    final arr = (res[k] as List?) ?? const [];
    if (arr.isEmpty) return null;
    final closes = <double>[];
    for (final it in arr) {
      final c = _toD((it as List)[4]);
      if (c != null) closes.add(c);
    }
    return closes;
  }

  Future<List<double>?> _cexBitstampDailyRecent() async {
    final url = Uri.parse('https://www.bitstamp.net/api/v2/ohlc/xlmusd/?step=86400&limit=400');
    final m = await _json(url);
    final arr = ((m['data'] as Map?)?['ohlc'] as List?) ?? const [];
    if (arr.isEmpty) return null;
    arr.sort((a, b) => int.parse(a['timestamp']).compareTo(int.parse(b['timestamp'])));
    final closes = <double>[];
    for (final it in arr) {
      final c = _toD((it as Map)['close']);
      if (c != null) closes.add(c);
    }
    return closes;
  }

  // ── DEX FALLBACKS (ALL-TIME & recent) via Horizon trade_aggregations ──────
  Future<List<double>?> _fetchXlmUsdcDailyAllFromDex() async {
    final issuer = _stellar.usdcIssuer; // Circle USDC issuer on Stellar
    final now = DateTime.now().toUtc();
    DateTime start = DateTime.utc(2015, 9, 1); // Stellar launch era (safe early date)
    final closes = <double>[];

    // Horizon limit=200; page in 200-day windows
    while (start.isBefore(now)) {
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
      final recs = (m['records'] as List?) ?? const [];
      if (recs.isEmpty) break;

      for (final r in recs) {
        final c = _toD((r as Map)['close']);
        if (c != null) closes.add(c);
      }

      // Move window
      start = end;

      // Safety cap
      if (closes.length > 5000) break;
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
    final recs = (m['records'] as List?) ?? const [];
    if (recs.isEmpty) return null;

    final closes = <double>[];
    for (final r in recs) {
      final c = _toD((r as Map)['close']);
      if (c != null) closes.add(c);
    }
    return closes.isEmpty ? null : closes;
  }

  // ── Utilities ─────────────────────────────────────────────────────────────
  List<double> _tail(List<double> s, int n) {
    if (s.isEmpty) return const [];
    if (s.length <= n) return List<double>.from(s);
    return s.sublist(s.length - n);
  }

  double _pct(List<double> series) {
    if (series.length < 2) return 0.0;
    final first = series.first;
    final last = series.last;
    if (first <= 0) return 0.0;
    return ((last - first) / first) * 100.0;
  }

  Future<Map<String, dynamic>> _json(Uri url) async {
    final resp = await _client
        .get(url, headers: {'User-Agent': 'NextFi/1.0'})
        .timeout(httpTimeout);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final b = resp.body.isEmpty ? '{}' : resp.body;
      final d = jsonDecode(b);
      return d is Map<String, dynamic> ? d : {'_': d};
    }
    throw Exception('HTTP ${resp.statusCode} for $url');
  }

  Future<List<dynamic>> _jsonList(Uri url) async {
    final resp = await _client
        .get(url, headers: {'User-Agent': 'NextFi/1.0'})
        .timeout(httpTimeout);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final b = resp.body.isEmpty ? '[]' : resp.body;
      final d = jsonDecode(b);
      return d is List ? d : const [];
    }
    throw Exception('HTTP ${resp.statusCode} for $url');
  }

  double? _toD(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) {
      final x = double.tryParse(v);
      if (x != null && x.isFinite) return x;
    }
    if (v is List && v.isNotEmpty) return _toD(v.first);
    if (v is Map && v.containsKey('close')) return _toD(v['close']);
    return null;
  }

  Future<T?> _firstNonNull<T>(List<Future<T?> Function()> attempts) async {
    for (final f in attempts) {
      try {
        final v = await f();
        if (v != null) return v;
      } catch (_) {/* try next */}
    }
    return null;
  }

  void _setLoading(bool v) {
    if (_loading != v) { _loading = v; notifyListeners(); }
  }
}
