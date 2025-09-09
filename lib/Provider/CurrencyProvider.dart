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
    this.pollEvery = const Duration(seconds: 30),
    this.httpTimeout = const Duration(seconds: 10),
  }) {
    _client = _buildClient();
    _boot();
  }

  // ── Config ─────────────────────────────────────────────────────────────────
  final Duration pollEvery;
  final Duration httpTimeout;

  // Stellar USDC issuer (Circle)
  static final String _USDC_ISSUER = StellarWalletService().usdcIssuer;

  // Multiple Horizon bases (diverse infra/vendors)
  static const List<String> _HORIZON_BASES = [
    'https://horizon.stellar.org',          // SDF
    'https://horizon-public.stellar.expert',// StellarExpert
    'https://horizon.stellar.lobstr.co',    // Lobstr
  ];

  // ── HTTP ───────────────────────────────────────────────────────────────────
  late final IOClient _client;
  IOClient _buildClient() {
    final hc = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..idleTimeout = const Duration(seconds: 15)
      ..maxConnectionsPerHost = 8
      ..findProxy = (_) => 'DIRECT';
    return IOClient(hc);
  }

  // ── State ──────────────────────────────────────────────────────────────────
  String _fiat = 'usd';
  double _usdcRate = 0; // USDC→FIAT
  double _xlmRate  = 0; // XLM→FIAT
  double _prevUsdcRate = 0, _prevXlmRate = 0;

  List<double> _xlm24 = [], _xlm7 = [], _xlm30 = [], _xlm365 = [];
  List<double> _usdc24 = [], _usdc7 = [], _usdc30 = [], _usdc365 = [];

  bool _loading = true;
  Timer? _t;

  final _xlmCtrl = StreamController<double>.broadcast();
  final _usdcCtrl = StreamController<double>.broadcast();

  // ── Public API ─────────────────────────────────────────────────────────────
  String get fiat => _fiat;
  bool get loading => _loading;
  double get usdcRate => _usdcRate;
  double get xlmRate  => _xlmRate;

  List<double> get xlmHistory      => _xlm7;  // back-compat
  List<double> get usdcHistory     => _usdc7; // back-compat
  List<double> get xlmHistory24h   => _xlm24;
  List<double> get xlmHistory7     => _xlm7;
  List<double> get xlmHistory30    => _xlm30;
  List<double> get xlmHistory365   => _xlm365;
  List<double> get usdcHistory24h  => _usdc24;
  List<double> get usdcHistory7    => _usdc7;
  List<double> get usdcHistory30   => _usdc30;
  List<double> get usdcHistory365  => _usdc365;

  Stream<double> get xlmPriceStream  => _xlmCtrl.stream;
  Stream<double> get usdcPriceStream => _usdcCtrl.stream;

  void setFiat(String v) {
    final n = v.trim().toLowerCase();
    if (n.isEmpty || n == _fiat) return;
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

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  void _boot() {
    () async {
      try {
        final saved = await CurrencySecureStorage.readFiat();
        if (saved != null && saved.trim().isNotEmpty) {
          _fiat = saved.trim().toLowerCase();
        }
        final cache = await CurrencySecureStorage.readLastGoodRates();
        if (cache != null && cache['fiat'] == _fiat) {
          _usdcRate = (cache['usdcRate'] as num?)?.toDouble() ?? _usdcRate;
          _xlmRate  = (cache['xlmRate']  as num?)?.toDouble() ?? _xlmRate;
        }
      } catch (_) {} finally {
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

  // ── Orchestrator ──────────────────────────────────────────────────────────
  Future<void> _refreshAll() async {
    final hadPrev = _usdcRate > 0 && _xlmRate > 0;
    Map<String, dynamic>? cached;
    try { cached = await CurrencySecureStorage.readLastGoodRates(); } catch (_) {}

    if (!await _hasInternet()) {
      if (!hadPrev && cached != null && (cached['fiat'] as String?)?.toLowerCase() == _fiat) {
        _usdcRate = (cached['usdcRate'] as num?)?.toDouble() ?? _usdcRate;
        _xlmRate  = (cached['xlmRate']  as num?)?.toDouble() ?? _xlmRate;
      }
      _setLoading(false);
      _xlmCtrl.add(_xlmRate); _usdcCtrl.add(_usdcRate);
      notifyListeners();
      return;
    }

    _setLoading(true);
    try {
      await _fetchRates();
      await _fetchHistories();
      if (_usdcRate > 0 && _xlmRate > 0) {
        unawaited(CurrencySecureStorage.saveLastGoodRates({
          'fiat': _fiat,
          'usdcRate': _usdcRate,
          'xlmRate': _xlmRate,
          'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        }));
      }
    } finally {
      if (_usdcRate <= 0 || _xlmRate <= 0) {
        if (cached != null && (cached['fiat'] as String?)?.toLowerCase() == _fiat) {
          _usdcRate = _usdcRate > 0 ? _usdcRate : (cached['usdcRate'] as num?)?.toDouble() ?? _usdcRate;
          _xlmRate  = _xlmRate  > 0 ? _xlmRate  : (cached['xlmRate']  as num?)?.toDouble() ?? _xlmRate;
        }
        if (_usdcRate <= 0) _usdcRate = 1.0 * (await _usdToFiat(_fiat) ?? 1.0);
        if (_xlmRate  <= 0) {
          final xlmUsdt = await _xlmUsdt().catchError((_) => null);
          final usdtUsd = await _usdtUsdApprox().catchError((_) => 1.0);
          final fx = _usdcRate > 0 ? _usdcRate : 1.0;
          if (xlmUsdt != null && xlmUsdt > 0) _xlmRate = xlmUsdt * usdtUsd * fx;
        }
      }
      _setLoading(false);
      _xlmCtrl.add(_xlmRate); _usdcCtrl.add(_usdcRate);
      notifyListeners();
    }
  }

  void _setLoading(bool v) { if (_loading != v) { _loading = v; notifyListeners(); } }

  // ── Rates (CEX → DEX → USDT-peg) ──────────────────────────────────────────
  Future<void> _fetchRates() async {
    try {
      final res = await Future.wait<double?>([
        _usdcToFiat().catchError((_) => null), // USDC→FIAT
        _xlmUsdc().catchError((_) => null),    // XLM/USDC price
      ]);

      final usdcFiat = res[0], xlmUsdc = res[1];
      var updated = false;

      if (usdcFiat != null && usdcFiat > 0) { _prevUsdcRate = _usdcRate; _usdcRate = usdcFiat; updated = true; }
      if (xlmUsdc  != null && xlmUsdc  > 0) {
        final fx = (_usdcRate > 0) ? _usdcRate : (_prevUsdcRate > 0 ? _prevUsdcRate : (await _usdToFiat(_fiat) ?? 1.0));
        _prevXlmRate = _xlmRate; _xlmRate = xlmUsdc * fx; updated = true;
      }

      if (!updated) _usePrevIfValid();
    } catch (_) { _usePrevIfValid(); }
  }

  void _usePrevIfValid() {
    if (_usdcRate <= 0 && _prevUsdcRate > 0) _usdcRate = _prevUsdcRate;
    if (_xlmRate  <= 0 && _prevXlmRate  > 0) _xlmRate  = _prevXlmRate;
  }

  // USDC→FIAT = (USDC→USD multi-venue w/ peg) * (USD→FIAT multi-source)
  Future<double?> _usdcToFiat() async {
    final usdcUsd = await _firstNonNull<double>([
          () => _coinbaseRate(base: 'USDC', quote: 'USD'),
          () => _krakenPrice('USDCUSD'),
          () => _binancePrice('USDCUSDT'), // ≈1 vs USDT
          () async => 1.0,
    ]);
    final usdFiat = await _usdToFiat(_fiat) ?? 1.0;
    return (usdcUsd ?? 1.0) * usdFiat;
  }

  // XLM/USDC: try CEX, then DEX across multiple Horizon hosts (order book → trade → trade_agg),
  // finally derive from XLM/USDT + pegs.
  Future<double?> _xlmUsdc() async {
    // 1) CEX paths
    final cex = await _firstNonNull<double>([
          () async { final m = await _json(Uri.parse('https://www.okx.com/api/v5/market/ticker?instId=XLM-USDC'));
      final d = (m['data'] as List?)?.cast<dynamic>();
      final s = (d != null && d.isNotEmpty) ? d.first['last'] as String? : null;
      return s != null ? double.tryParse(s) : null; },
          () async { final m = await _json(Uri.parse('https://api.bybit.com/v5/market/tickers?category=spot&symbol=XLMUSDC'));
      final l = (m['result']?['list'] as List?) ?? const [];
      final s = l.isNotEmpty ? l.first['lastPrice'] as String? : null;
      return s != null ? double.tryParse(s) : null; },
          () async { final m = await _json(Uri.parse('https://api.kucoin.com/api/v1/market/orderbook/level1?symbol=XLM-USDC'));
      final s = m['data']?['price'] as String?;
      return s != null ? double.tryParse(s) : null; },
          () async { final m = await _json(Uri.parse('https://api.binance.com/api/v3/ticker/price?symbol=XLMUSDC'));
      final s = m['price'] as String?;
      return s != null ? double.tryParse(s) : null; },
    ]);
    if (cex != null && cex > 0) return cex;

    // 2) DEX paths across Horizon hosts
    // Try order_book mid, then last trade price, then last trade_agg close/avg
    for (final base in _HORIZON_BASES) {
      final ob = await _dexOrderBookMid(base).catchError((_) => null);
      if (ob != null && ob > 0) return ob;
    }
    for (final base in _HORIZON_BASES) {
      final tr = await _dexLastTrade(base).catchError((_) => null);
      if (tr != null && tr > 0) return tr;
    }
    for (final base in _HORIZON_BASES) {
      final ta = await _dexTradeAggLast(base).catchError((_) => null);
      if (ta != null && ta > 0) return ta;
    }

    // 3) Last resort: XLM/USDT × (USDT≈USD / USDC≈USD)
    final xlmUsdt = await _xlmUsdt();
    if (xlmUsdt == null) return null;
    final usdtUsd = await _usdtUsdApprox();
    final usdcUsd = await _firstNonNull<double>([
          () => _coinbaseRate(base: 'USDC', quote: 'USD'),
          () => _krakenPrice('USDCUSD'),
          () => _binancePrice('USDCUSDT'),
          () async => 1.0,
    ]) ?? 1.0;
    return usdcUsd <= 0 ? xlmUsdt * usdtUsd : xlmUsdt * (usdtUsd / usdcUsd);
  }

  // ── DEX helpers (Horizon) ─────────────────────────────────────────────────
  // Order book mid-price (USDC per 1 XLM)
  Future<double?> _dexOrderBookMid(String base) async {
    final uri = Uri.parse('$base/order_book').replace(queryParameters: {
      'selling_asset_type': 'native',          // XLM
      'buying_asset_type': 'credit_alphanum4', // USDC
      'buying_asset_code': 'USDC',
      'buying_asset_issuer': _USDC_ISSUER,
      'limit': '10',
    });
    final m = await _json(uri);
    final bids = (m['bids'] as List?) ?? const [];
    final asks = (m['asks'] as List?) ?? const [];
    final bb = bids.isNotEmpty ? _dexParsePrice(bids.first) : null;
    final ba = asks.isNotEmpty ? _dexParsePrice(asks.first) : null;
    if (bb != null && ba != null && bb > 0 && ba > 0) return (bb + ba) / 2.0;
    return bb ?? ba;
  }

  // Last trade price (USDC per 1 XLM) from /trades
  Future<double?> _dexLastTrade(String base) async {
    final uri = Uri.parse('$base/trades').replace(queryParameters: {
      'base_asset_type': 'native',                  // XLM
      'counter_asset_type': 'credit_alphanum4',     // USDC
      'counter_asset_code': 'USDC',
      'counter_asset_issuer': _USDC_ISSUER,
      'order': 'desc',
      'limit': '1',
    });
    final m = await _json(uri);
    final recs = (m['_embedded']?['records'] as List?) ?? const [];
    if (recs.isEmpty) return null;
    return _dexParsePrice(recs.first);
  }

  // Trade aggregations (5m bucket) close/avg
  Future<double?> _dexTradeAggLast(String base) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final res = 5 * 60 * 1000; // 5 minutes
    final uri = Uri.parse('$base/trade_aggregations').replace(queryParameters: {
      'base_asset_type': 'native',
      'counter_asset_type': 'credit_alphanum4',
      'counter_asset_code': 'USDC',
      'counter_asset_issuer': _USDC_ISSUER,
      'resolution': '$res',
      'start_time': '${now - res * 2}',
      'end_time': '$now',
      'order': 'desc',
      'limit': '1',
    });
    final m = await _json(uri);
    final recs = (m['_embedded']?['records'] as List?) ?? const [];
    if (recs.isEmpty) return null;
    final r = recs.first as Map;
    // Prefer close, fall back to avg, else open
    double? _num(x) => (x is num) ? x.toDouble() : (x is String ? double.tryParse(x) : null);
    return _num(r['close']) ?? _num(r['avg']) ?? _num(r['open']);
  }

  double? _dexParsePrice(dynamic e) {
    if (e is Map) {
      final p = e['price'];
      if (p is String) return double.tryParse(p);
      if (p is num) return p.toDouble();
      final pr = e['price_r'];
      if (pr is Map) {
        final n = pr['n'], d = pr['d'];
        if (n is num && d is num && d != 0) return n.toDouble() / d.toDouble();
      }
    }
    return null;
  }

  // ── XLM/USDT (multi-venue) ────────────────────────────────────────────────
  Future<double?> _xlmUsdt() async {
    return _firstNonNull<double>([
          () async { final m = await _json(Uri.parse('https://api.binance.com/api/v3/ticker/price?symbol=XLMUSDT'));
      final s = m['price']; return s is String ? double.tryParse(s) : (s is num ? s.toDouble() : null); },
          () async { final m = await _json(Uri.parse('https://www.okx.com/api/v5/market/ticker?instId=XLM-USDT'));
      final d = (m['data'] as List?) ?? const []; final s = d.isNotEmpty ? d.first['last'] as String? : null;
      return s != null ? double.tryParse(s) : null; },
          () async { final m = await _json(Uri.parse('https://api.kucoin.com/api/v1/market/orderbook/level1?symbol=XLM-USDT'));
      final s = m['data']?['price'] as String?; return s != null ? double.tryParse(s) : null; },
          () async { final m = await _json(Uri.parse('https://api.bybit.com/v5/market/tickers?category=spot&symbol=XLMUSDT'));
      final l = (m['result']?['list'] as List?) ?? const []; final s = l.isNotEmpty ? l.first['lastPrice'] as String? : null;
      return s != null ? double.tryParse(s) : null; },
          () async { final m = await _json(Uri.parse('https://api.kraken.com/0/public/Ticker?pair=XLMUSDT'));
      final r = (m['result'] as Map?) ?? {}; if (r.isNotEmpty) { final c = (r.values.first as Map)['c'] as List?;
      return (c != null && c.isNotEmpty) ? double.tryParse(c.first.toString()) : null; } return null; },
    ]);
  }

  // ── Histories (USDT klines → scale by USDC→FIAT) ──────────────────────────
  Future<void> _fetchHistories() async {
    final now  = DateTime.now();
    final f7   = now.subtract(const Duration(days: 7));
    final f30  = now.subtract(const Duration(days: 30));
    final f365 = now.subtract(const Duration(days: 365));

    final usdcBase = _usdcRate > 0 ? _usdcRate : (_prevUsdcRate > 0 ? _prevUsdcRate : 1.0);
    final usdc24 = List<double>.filled(24, usdcBase);
    final usdc7  = await _usdToFiatSeries(f7, now, _fiat, 7);
    final usdc30 = await _usdToFiatSeries(f30, now, _fiat, 30);
    final usdc365= await _usdToFiatSeries(f365, now, _fiat, 365);

    final fx = _usdcRate > 0 ? _usdcRate : (_prevUsdcRate > 0 ? _prevUsdcRate : 1.0);
    final x24u  = await _klines('1h', 24);
    final x7u   = await _klines('1d', 7);
    final x30u  = await _klines('1d', 30);
    final x365u = await _klines('1d', 365);

    _usdc24 = usdc24; _usdc7 = usdc7; _usdc30 = usdc30; _usdc365 = usdc365;
    _xlm24  = x24u.map((e) => e * fx).toList();
    _xlm7   = x7u.map((e)  => e * fx).toList();
    _xlm30  = x30u.map((e) => e * fx).toList();
    _xlm365 = x365u.map((e)=> e * fx).toList();
  }

  Future<List<double>> _usdToFiatSeries(DateTime from, DateTime to, String fiat, int len) async {
    if (fiat.toLowerCase() == 'usd') return List<double>.filled(len, 1.0);
    String ymd(DateTime d) => '${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
    try {
      final m = await _json(Uri.parse('https://api.frankfurter.app/${ymd(from)}..${ymd(to)}?from=USD&to=${fiat.toUpperCase()}'));
      final rates = (m['rates'] as Map?) ?? {};
      final keys = rates.keys.toList()..sort();
      final series = keys.map((k) {
        final v = (rates[k] as Map?)?[fiat.toUpperCase()];
        return (v is num) ? v.toDouble() : 1.0;
      }).toList();
      return _normalize(series, len);
    } catch (_) {
      final base = _usdcRate > 0 ? _usdcRate : (_prevUsdcRate > 0 ? _prevUsdcRate : 1.0);
      return List<double>.filled(len, base);
    }
  }

  // XLM/USDT klines (Binance → OKX → KuCoin)
  Future<List<double>> _klines(String interval, int limit) async {
    final tries = <Future<List<double>?> Function()>[
          () async {
        final m = await _json(Uri.parse('https://api.binance.com/api/v3/klines?symbol=XLMUSDT&interval=$interval&limit=$limit'));
        final raw = m['_'];
        if (raw is List) {
          final l = raw.cast<dynamic>();
          final out = l.map((e) => (e is List && e.length > 4) ? double.tryParse(e[4].toString()) : null)
              .whereType<double>().toList();
          return out.isNotEmpty ? out : null;
        }
        return null;
      },
          () async {
        final m = await _json(Uri.parse('https://www.okx.com/api/v5/market/candles?instId=XLM-USDT&bar=${interval == '1h' ? '1H':'1D'}&limit=$limit'));
        final l = (m['data'] as List?)?.cast<List>() ?? const [];
        final c = l.reversed.map((r) => (r.length > 4) ? double.tryParse(r[4].toString()) : null)
            .whereType<double>().toList();
        return c.length >= 1 ? _normalize(c, limit) : null;
      },
          () async {
        final m = await _json(Uri.parse('https://api.kucoin.com/api/v1/market/candles?type=${interval == "1h" ? "1hour":"1day"}&symbol=XLM-USDT'));
        final l = (m['data'] as List?)?.cast<List>() ?? const [];
        final c = l.reversed.map((r) => (r.length > 2) ? double.tryParse(r[2].toString()) : null)
            .whereType<double>().toList();
        return c.length >= 1 ? _normalize(c, limit) : null;
      },
    ];
    for (final f in tries) {
      try { final v = await f(); if (v != null && v.isNotEmpty) return _normalize(v, limit); } catch (_) {}
    }
    final xlmUsdcGuess = (_xlmRate > 0 && _usdcRate > 0) ? _xlmRate / _usdcRate : 0.12;
    return List<double>.filled(limit, xlmUsdcGuess);
  }

  // ── FX helpers ─────────────────────────────────────────────────────────────
  Future<double?> _usdToFiat(String fiat) async {
    final tgt = fiat.toUpperCase();
    if (tgt == 'USD') return 1.0;
    return _firstNonNull<double>([
          () async { final m = await _json(Uri.parse('https://api.frankfurter.app/latest?from=USD&to=$tgt'));
      final v = (m['rates'] as Map?)?[tgt]; return (v is num) ? v.toDouble() : null; },
          () async { final m = await _json(Uri.parse('https://api.exchangerate.host/latest?base=USD&symbols=$tgt'));
      final v = (m['rates'] as Map?)?[tgt]; return (v is num) ? v.toDouble() : null; },
          () async { final m = await _json(Uri.parse('https://open.er-api.com/v6/latest/USD'));
      final v = (m['rates'] as Map?)?[tgt]; return (v is num) ? v.toDouble() : null; },
    ]);
  }

  Future<double?> _coinbaseRate({required String base, required String quote}) async {
    return _firstNonNull<double>([
          () async { final m = await _json(Uri.parse('https://api.coinbase.com/v2/exchange-rates?currency=$base'));
      final rates = (m['data']?['rates'] as Map?) ?? {};
      final v = rates[quote];
      if (v is String) return double.tryParse(v);
      if (v is num) return v.toDouble();
      return null; },
          () async {
        if (quote.toUpperCase() == 'USD') {
          final m = await _json(Uri.parse('https://api.exchange.coinbase.com/products/${base.toUpperCase()}-$quote/ticker'));
          final p = m['price'];
          if (p is String) return double.tryParse(p);
          if (p is num) return p.toDouble();
        }
        return null;
      },
    ]);
  }

  Future<double?> _krakenPrice(String pair) async {
    final m = await _json(Uri.parse('https://api.kraken.com/0/public/Ticker?pair=$pair'));
    final r = (m['result'] as Map?) ?? {};
    if (r.isNotEmpty) {
      final c = (r.values.first as Map)['c'] as List?;
      return (c != null && c.isNotEmpty) ? double.tryParse(c.first.toString()) : null;
    }
    return null;
  }

  Future<double?> _binancePrice(String symbol) async {
    final m = await _json(Uri.parse('https://api.binance.com/api/v3/ticker/price?symbol=$symbol'));
    final s = m['price'];
    if (s is String) return double.tryParse(s);
    if (s is num) return s.toDouble();
    return null;
  }

  Future<double> _usdtUsdApprox() async {
    final v = await _firstNonNull<double>([
          () => _krakenPrice('USDTUSD'),
          () => _binancePrice('USDTUSD'),
          () async => 1.0,
    ]);
    return v ?? 1.0;
  }

  // ── Utils ─────────────────────────────────────────────────────────────────
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

  // Central GET+JSON with retries + per-request timeout + UA header
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
      try { return await f(); }
      catch (e) { last = e; if (i < times - 1) await Future.delayed(Duration(milliseconds: 300 * (i + 1))); }
    }
    // ignore: only_throw_errors
    throw last;
  }

  // Internet probe (handles captive portals & DNS interception)
  Future<bool> _hasInternet() async {
    try {
      final ok204 = await _retry(() async {
        final r = await _client.get(Uri.parse('https://www.gstatic.com/generate_204'),
            headers: {'User-Agent': 'NextFi/1.0'}).timeout(const Duration(seconds: 4));
        return r.statusCode == 204;
      }, times: 2).catchError((_) => false);
      if (ok204 == true) return true;

      final cf = await _retry(() async {
        final r = await _client.get(Uri.parse('https://1.1.1.1/cdn-cgi/trace'),
            headers: {'User-Agent': 'NextFi/1.0'}).timeout(const Duration(seconds: 4));
        return r.statusCode >= 200 && r.statusCode < 400;
      }, times: 2).catchError((_) => false);
      if (cf == true) return true;

      final dns = await InternetAddress.lookup('one.one.one.one')
          .timeout(const Duration(seconds: 3));
      return dns.isNotEmpty;
    } catch (_) { return false; }
  }

  // First non-null among async attempts (sequential; simple & robust)
  Future<T?> _firstNonNull<T>(List<Future<T?> Function()> attempts) async {
    for (final f in attempts) {
      try { final v = await f(); if (v != null) return v; } catch (_) {}
    }
    return null;
  }
}
