import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/io_client.dart';
import 'package:next_fi/Services/currency_secure_storage.dart';

/// Compact, hotspot-resilient provider
/// - Prefers XLM/USDC; falls back to XLM/USDT → convert to USDC
/// - USDC→FIAT via Coinbase (fallback: USD peg) × USD→FIAT via Frankfurter
class CurrencyProvider extends ChangeNotifier {
  CurrencyProvider({
    this.pollEvery = const Duration(seconds: 30),
    this.httpTimeout = const Duration(seconds: 10),
  }) {
    _client = _buildClient();
    _boot();
  }

  // ---- Config --------------------------------------------------------------
  final Duration pollEvery;
  final Duration httpTimeout;

  // ---- HTTP client (timeouts, no proxy). No ConnectionTask.connect used. ---
  late final IOClient _client;
  IOClient _buildClient() {
    final hc = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..idleTimeout = const Duration(seconds: 15)
      ..maxConnectionsPerHost = 8
      ..findProxy = (_) => 'DIRECT';
    return IOClient(hc);
  }

  // ---- State: fiat + rates -------------------------------------------------
  String _fiat = 'usd';
  double _usdcRate = 0; // USDC→FIAT
  double _xlmRate  = 0; // XLM→FIAT

  double _prevUsdcRate = 0, _prevXlmRate = 0;

  // Histories (exact sizes)
  List<double> _xlm24 = [], _xlm7 = [], _xlm30 = [], _xlm365 = [];
  List<double> _usdc24 = [], _usdc7 = [], _usdc30 = [], _usdc365 = [];

  bool _loading = true;
  Timer? _t;

  // Streams
  final _xlmCtrl = StreamController<double>.broadcast();
  final _usdcCtrl = StreamController<double>.broadcast();

  // ---- Public API (unchanged) ----------------------------------------------
  String get fiat => _fiat;
  bool get loading => _loading;
  double get usdcRate => _usdcRate;
  double get xlmRate  => _xlmRate;

  // Back-compat (7D)
  List<double> get xlmHistory  => _xlm7;
  List<double> get usdcHistory => _usdc7;

  // Explicit ranges
  List<double> get xlmHistory24h => _xlm24;
  List<double> get xlmHistory7   => _xlm7;
  List<double> get xlmHistory30  => _xlm30;
  List<double> get xlmHistory365 => _xlm365;

  List<double> get usdcHistory24h => _usdc24;
  List<double> get usdcHistory7   => _usdc7;
  List<double> get usdcHistory30  => _usdc30;
  List<double> get usdcHistory365 => _usdc365;

  Stream<double> get xlmPriceStream  => _xlmCtrl.stream;
  Stream<double> get usdcPriceStream => _usdcCtrl.stream;

  void setFiat(String v) {
    final n = v.trim().toLowerCase();
    if (n == _fiat || n.isEmpty) return;
    _fiat = n;
    CurrencySecureStorage.saveFiat(n);
    _refreshAll();
    notifyListeners();
  }

  Future<void> resetFiatToUsd() async {
    _fiat = 'usd';
    await CurrencySecureStorage.clearFiat();
    await _refreshAll();
    notifyListeners();
  }

  // ---- Boot / lifecycle ----------------------------------------------------
  void _boot() {
    () async {
      try {
        final saved = await CurrencySecureStorage.readFiat();
        if (saved != null && saved.trim().isNotEmpty) _fiat = saved.trim().toLowerCase();

        // Warm start (optional)
        final cache = await CurrencySecureStorage.readLastGoodRates();
        if (cache != null && cache['fiat'] == _fiat) {
          _usdcRate = (cache['usdcRate'] as num?)?.toDouble() ?? _usdcRate;
          _xlmRate  = (cache['xlmRate']  as num?)?.toDouble() ?? _xlmRate;
        }
      } catch (e) {
        debugPrint('CurrencyProvider boot warn: $e');
      } finally {
        await _refreshAll();
        _t?.cancel();
        _t = Timer.periodic(pollEvery, (_) => _refreshAll());
      }
    }();
  }

  @override
  void dispose() {
    _t?.cancel();
    _xlmCtrl.close();
    _usdcCtrl.close();
    _client.close();
    super.dispose();
  }

  // ---- Orchestrator --------------------------------------------------------
  Future<void> _refreshAll() async {
    if (!await _hasInternet()) {
      _setLoading(true);
      return;
    }
    _setLoading(true);
    try {
      await _fetchRates();
      await _fetchHistories();
      // save last good
      unawaited(CurrencySecureStorage.saveLastGoodRates({
        'fiat': _fiat, 'usdcRate': _usdcRate, 'xlmRate': _xlmRate,
        'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      }));
    } finally {
      _setLoading(false);
      _xlmCtrl.add(_xlmRate);
      _usdcCtrl.add(_usdcRate);
      notifyListeners();
    }
  }

  void _setLoading(bool v) { if (_loading != v) { _loading = v; notifyListeners(); } }

  // ---- Rates (compact) -----------------------------------------------------
  Future<void> _fetchRates() async {
    try {
      final usdcFiatF = _usdcToFiat();
      final xlmUsdcF  = _xlmUsdc(); // prefers XLM/USDC; falls back to USDT→USDC

      final res = await Future.wait([usdcFiatF, xlmUsdcF]);
      final usdcFiat = (res[0] as double?) ?? 0;
      final xlmUsdc  = (res[1] as double?) ?? 0;

      var updated = false;

      if (usdcFiat > 0) {
        _prevUsdcRate = _usdcRate;
        _usdcRate = usdcFiat;
        updated = true;
      }
      if (xlmUsdc > 0 && (_usdcRate > 0 || _prevUsdcRate > 0)) {
        final fx = _usdcRate > 0 ? _usdcRate : _prevUsdcRate;
        _prevXlmRate = _xlmRate;
        _xlmRate = xlmUsdc * fx;
        updated = true;
      }
      if (!updated) _usePrevIfValid();
    } catch (e) {
      debugPrint('fetchRates error: $e');
      _usePrevIfValid();
    }
  }

  void _usePrevIfValid() {
    if (_usdcRate <= 0 && _prevUsdcRate > 0) _usdcRate = _prevUsdcRate;
    if (_xlmRate  <= 0 && _prevXlmRate  > 0) _xlmRate  = _prevXlmRate;
  }

  // USDC→FIAT = (USDC→USD from Coinbase, fallback 1) * (USD→FIAT from Frankfurter)
  Future<double?> _usdcToFiat() async {
    final usdcUsd = await _coinbaseRate(base: 'USDC', quote: 'USD') ?? 1.0;
    final usdFiat = await _usdToFiat(_fiat) ?? 1.0;
    return usdcUsd * usdFiat;
  }

  // Prefer XLM/USDC from multiple venues; else XLM/USDT × (USDT→USDC)
  Future<double?> _xlmUsdc() async {
    final parsers = <Future<double?> Function()>[
      // OKX XLM-USDC
          () async {
        final m = await _json(Uri.parse('https://www.okx.com/api/v5/market/ticker?instId=XLM-USDC'));
        final d = (m['data'] as List?)?.cast<dynamic>();
        final s = (d != null && d.isNotEmpty) ? d.first['last'] as String? : null;
        return s != null ? double.tryParse(s) : null;
      },
      // Bybit XLMUSDC
          () async {
        final m = await _json(Uri.parse('https://api.bybit.com/v5/market/tickers?category=spot&symbol=XLMUSDC'));
        final l = (m['result']?['list'] as List?) ?? const [];
        final s = l.isNotEmpty ? l.first['lastPrice'] as String? : null;
        return s != null ? double.tryParse(s) : null;
      },
      // KuCoin XLM-USDC (not always listed)
          () async {
        final m = await _json(Uri.parse('https://api.kucoin.com/api/v1/market/orderbook/level1?symbol=XLM-USDC'));
        final s = m['data']?['price'] as String?;
        return s != null ? double.tryParse(s) : null;
      },
      // Binance XLMUSDC (if listed)
          () async {
        final m = await _json(Uri.parse('https://api.binance.com/api/v3/ticker/price?symbol=XLMUSDC'));
        final s = m['price'] as String?;
        return s != null ? double.tryParse(s) : null;
      },
    ];

    // try USDC pair first
    for (final f in parsers) {
      try { final v = await f(); if (v != null && v > 0) return v; } catch (_) {}
    }

    // fallback: XLM/USDT × (USDT→USDC)
    final xlmUsdt = await _xlmUsdt();
    if (xlmUsdt == null) return null;
    final usdtUsdc = await _usdtToUsdc() ?? 1.0; // ≈1
    return xlmUsdt * usdtUsdc;
  }

  Future<double?> _xlmUsdt() async {
    final fns = <Future<double?> Function()>[
          () async {
        final m = await _json(Uri.parse('https://api.binance.com/api/v3/ticker/price?symbol=XLMUSDT'));
        final s = m['price'] as String?;
        return s != null ? double.tryParse(s) : null;
      },
          () async {
        final m = await _json(Uri.parse('https://www.okx.com/api/v5/market/ticker?instId=XLM-USDT'));
        final d = (m['data'] as List?) ?? const [];
        final s = d.isNotEmpty ? d.first['last'] as String? : null;
        return s != null ? double.tryParse(s) : null;
      },
          () async {
        final m = await _json(Uri.parse('https://api.kucoin.com/api/v1/market/orderbook/level1?symbol=XLM-USDT'));
        final s = m['data']?['price'] as String?;
        return s != null ? double.tryParse(s) : null;
      },
          () async {
        final m = await _json(Uri.parse('https://api.bybit.com/v5/market/tickers?category=spot&symbol=XLMUSDT'));
        final l = (m['result']?['list'] as List?) ?? const [];
        final s = l.isNotEmpty ? l.first['lastPrice'] as String? : null;
        return s != null ? double.tryParse(s) : null;
      },
          () async {
        final m = await _json(Uri.parse('https://api.kraken.com/0/public/Ticker?pair=XLMUSDT'));
        final r = (m['result'] as Map?) ?? {};
        if (r.isNotEmpty) {
          final c = (r.values.first as Map)['c'] as List?;
          return (c != null && c.isNotEmpty) ? double.tryParse(c.first.toString()) : null;
        }
        return null;
      },
    ];
    for (final f in fns) { try { final v = await f(); if (v != null && v > 0) return v; } catch (_) {} }
    return null;
  }

  Future<double?> _usdtToUsdc() async {
    // Use Coinbase rates to approximate USDT→USDC
    // USDT→USD and USDC→USD => USDT/USDC = (USDT→USD)/(USDC→USD)
    final usdtUsd = await _coinbaseRate(base: 'USDT', quote: 'USD') ?? 1.0;
    final usdcUsd = await _coinbaseRate(base: 'USDC', quote: 'USD') ?? 1.0;
    if (usdcUsd <= 0) return 1.0;
    return usdtUsd / usdcUsd;
  }

  Future<double?> _coinbaseRate({required String base, required String quote}) async {
    final m = await _json(Uri.parse('https://api.coinbase.com/v2/exchange-rates?currency=$base'));
    final rates = (m['data']?['rates'] as Map?) ?? {};
    final v = rates[quote] ;
    if (v is String) return double.tryParse(v);
    if (v is num) return v.toDouble();
    return null;
  }

  Future<double?> _usdToFiat(String fiat) async {
    if (fiat.toLowerCase() == 'usd') return 1.0;
    final m = await _json(Uri.parse('https://api.frankfurter.app/latest?from=USD&to=${fiat.toUpperCase()}'));
    final r = (m['rates'] as Map?) ?? {};
    final v = r[fiat.toUpperCase()];
    if (v is num) return v.toDouble();
    return null;
  }

  // ---- Histories (compact: derive from USDT klines, scale to FIAT) ---------
  Future<void> _fetchHistories() async {
    final now  = DateTime.now();
    final f7   = now.subtract(const Duration(days: 7));
    final f30  = now.subtract(const Duration(days: 30));
    final f365 = now.subtract(const Duration(days: 365));

    // USDC series: USD→FIAT daily (proxy), flat intraday
    final usdc24 = List<double>.filled(24, _usdcRate > 0 ? _usdcRate : (_prevUsdcRate > 0 ? _prevUsdcRate : 1.0));
    final usdc7  = await _usdToFiatSeries(f7, now, _fiat, 7);
    final usdc30 = await _usdToFiatSeries(f30, now, _fiat, 30);
    final usdc365= await _usdToFiatSeries(f365, now, _fiat, 365);

    // XLM series: take XLM/USDT klines; multiply by USDC→FIAT (current/prev)
    final fx = _usdcRate > 0 ? _usdcRate : (_prevUsdcRate > 0 ? _prevUsdcRate : 1.0);
    final x24u  = await _klines('1h', 24);   // intraday
    final x7u   = await _klines('1d', 7);
    final x30u  = await _klines('1d', 30);
    final x365u = await _klines('1d', 365);

    _usdc24 = usdc24; _usdc7 = usdc7; _usdc30 = usdc30; _usdc365 = usdc365;
    _xlm24  = x24u.map((e) => e * fx).toList();
    _xlm7   = x7u.map((e)  => e * fx).toList();
    _xlm30  = x30u.map((e) => e * fx).toList();
    _xlm365 = x365u.map((e)=> e * fx).toList();
  }

  // USD→FIAT daily series via Frankfurter (normalized length)
  Future<List<double>> _usdToFiatSeries(DateTime from, DateTime to, String fiat, int len) async {
    if (fiat.toLowerCase() == 'usd') return List<double>.filled(len, 1.0);
    String ymd(DateTime d) => '${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
    try {
      final m = await _json(Uri.parse('https://api.frankfurter.app/${ymd(from)}..${ymd(to)}?from=USD&to=${fiat.toUpperCase()}'));
      final rates = (m['rates'] as Map?) ?? {};
      final keys = rates.keys.toList()..sort();
      var series = keys.map((k) {
        final v = (rates[k] as Map?)?[fiat.toUpperCase()];
        return (v is num) ? v.toDouble() : 1.0;
      }).toList();
      return _normalize(series, len);
    } catch (e) {
      final base = _usdcRate > 0 ? _usdcRate : (_prevUsdcRate > 0 ? _prevUsdcRate : 1.0);
      return List<double>.filled(len, base);
    }
  }

  // XLM/USDT klines (Binance). If fails, try OKX/KuCoin quickly.
  Future<List<double>> _klines(String interval, int limit) async {
    final tries = <Future<List<double>?> Function()>[
          () async {
        final m = await _json(Uri.parse('https://api.binance.com/api/v3/klines?symbol=XLMUSDT&interval=$interval&limit=$limit'));
        final l = (m['_'] as List).cast<dynamic>();
        return l.map((e) => (e is List && e.length > 4) ? double.tryParse(e[4].toString()) : null)
            .whereType<double>().toList();
      },
          () async { // OKX
        final m = await _json(Uri.parse('https://www.okx.com/api/v5/market/candles?instId=XLM-USDT&bar=${interval == '1h' ? '1H':'1D'}&limit=$limit'));
        final l = (m['data'] as List?)?.cast<List>() ?? const [];
        final c = l.reversed.map((r) => (r.length > 4) ? double.tryParse(r[4].toString()) : null).whereType<double>().toList();
        return c.length >= 1 ? _normalize(c, limit) : null;
      },
          () async { // KuCoin
        final m = await _json(Uri.parse('https://api.kucoin.com/api/v1/market/candles?type=${interval == "1h" ? "1hour":"1day"}&symbol=XLM-USDT'));
        final l = (m['data'] as List?)?.cast<List>() ?? const [];
        final c = l.reversed.map((r) => (r.length > 2) ? double.tryParse(r[2].toString()) : null).whereType<double>().toList();
        return c.length >= 1 ? _normalize(c, limit) : null;
      },
    ];
    for (final f in tries) { try { final v = await f(); if (v != null && v.isNotEmpty) return _normalize(v, limit); } catch (_) {} }
    // Conservative flat fallback
    final xlmUsdc = (_xlmRate > 0 && _usdcRate > 0) ? _xlmRate / _usdcRate : 0.12;
    return List<double>.filled(limit, xlmUsdc);
  }

  // ---- utils ---------------------------------------------------------------
  List<double> _normalize(List<double> s, int n) {
    if (s.isEmpty) return List<double>.filled(n, 1.0);
    if (s.length == n) return s;
    if (s.length > n) return s.sublist(s.length - n);
    return List<double>.filled(n - s.length, s.first)..addAll(s);
  }

  double xlmToFiat(double x) => x * _xlmRate;
  double usdcToFiat(double u) => u * _usdcRate;
  double fiatToUsdc(double f) => _usdcRate != 0 ? f / _usdcRate : 0.0;
  double fiatToXlm (double f) => _xlmRate  != 0 ? f / _xlmRate  : 0.0;
  double xlmToUsdc(double x)  => (_xlmRate != 0 && _usdcRate != 0) ? (x * _xlmRate) / _usdcRate : 0.0;
  double usdcToXlm(double u)  => (_xlmRate != 0 && _usdcRate != 0) ? (u * _usdcRate) / _xlmRate : 0.0;

  // Central GET+JSON with retries/backoff + per-request timeout + UA header
  Future<Map<String,dynamic>> _json(Uri url) async {
    final resp = await _retry(() => _client
        .get(url, headers: {'User-Agent': 'NextFi/1.0'})
        .timeout(httpTimeout));
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final b = resp.body.isEmpty ? '{}' : resp.body;
      final d = jsonDecode(b);
      return d is Map<String,dynamic> ? d : {'_': d};
    }
    throw Exception('HTTP ${resp.statusCode} for $url');
  }

  Future<T> _retry<T>(Future<T> Function() f, {int times = 3}) async {
    dynamic last;
    for (var i = 0; i < times; i++) {
      try { return await f(); } catch (e) { last = e; if (i < times - 1) await Future.delayed(Duration(milliseconds: 300 * (i + 1))); }
    }
    // ignore: only_throw_errors
    throw last;
  }

  Future<bool> _hasInternet() async {
    try {
      final r = await InternetAddress.lookup('one.one.one.one').timeout(const Duration(seconds: 3));
      return r.isNotEmpty;
    } catch (_) { return false; }
  }
}
