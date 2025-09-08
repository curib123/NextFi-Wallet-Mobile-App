// lib/Provider/CurrencyProvider.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/io_client.dart';

import 'package:next_fi/Services/currency_secure_storage.dart';
import 'package:next_fi/Services/stellar/stellar_wallet_services.dart';

/// Compact, hotspot/ISP-resilient provider
/// - Prefers XLM/USDC; falls back to XLM/USDT → convert/approx to USDC
/// - USDC→FIAT via Coinbase (fallbacks + USD peg) × USD→FIAT via multiple FX sources
/// - When CEX hosts are blocked: falls back to Stellar DEX via Horizon (paths + orderbook + trade aggs)
/// - Never persists zeros; reuses last-good cache when hosts are blocked
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

  // ---- HTTP client (honor system proxy; timeouts) --------------------------
  late final IOClient _client;
  IOClient _buildClient() {
    final hc = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..idleTimeout = const Duration(seconds: 15)
      ..maxConnectionsPerHost = 8
    // Honor system/OS proxy settings (Wi-Fi proxy, VPN/WARP, etc.)
      ..findProxy = HttpClient.findProxyFromEnvironment;
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

  // ---- Public API ----------------------------------------------------------
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
        if (saved != null && saved.trim().isNotEmpty) {
          _fiat = saved.trim().toLowerCase();
        }

        // Warm start from cache (if same fiat)
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
    final hadPrev = _usdcRate > 0 && _xlmRate > 0;
    Map<String, dynamic>? cached;
    try {
      cached = await CurrencySecureStorage.readLastGoodRates();
    } catch (_) {}

    if (!await _hasInternet()) {
      // Offline → use cache (if we don't already have valid rates)
      if (!hadPrev && cached != null && (cached['fiat'] as String?)?.toLowerCase() == _fiat) {
        _usdcRate = (cached['usdcRate'] as num?)?.toDouble() ?? _usdcRate;
        _xlmRate  = (cached['xlmRate']  as num?)?.toDouble() ?? _xlmRate;
      }
      _setLoading(false);
      _xlmCtrl.add(_xlmRate);
      _usdcCtrl.add(_usdcRate);
      notifyListeners();
      return;
    }

    _setLoading(true);
    try {
      await _fetchRates();
      await _fetchHistories();

      // Only save if both are positive (avoid committing zeros)
      if (_usdcRate > 0 && _xlmRate > 0) {
        CurrencySecureStorage.saveLastGoodRates({
          'fiat': _fiat,
          'usdcRate': _usdcRate,
          'xlmRate': _xlmRate,
          'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        });
      }
    } finally {
      // If still zeros, fallback to cache or safe pegs
      if (_usdcRate <= 0 || _xlmRate <= 0) {
        if (cached != null && (cached['fiat'] as String?)?.toLowerCase() == _fiat) {
          _usdcRate = _usdcRate > 0 ? _usdcRate : (cached['usdcRate'] as num?)?.toDouble() ?? _usdcRate;
          _xlmRate  = _xlmRate  > 0 ? _xlmRate  : (cached['xlmRate']  as num?)?.toDouble() ?? _xlmRate;
        }
        // Last resort: peg USDC≈USD and derive XLM from USDT venues if available
        if (_usdcRate <= 0) _usdcRate = 1.0 * (await _usdToFiat(_fiat) ?? 1.0);
        if (_xlmRate  <= 0) {
          final xlmUsdt = await _xlmUsdt().catchError((_) => null);
          final usdtUsd = await _usdtUsdApprox().catchError((_) => 1.0);
          final fx      = _usdcRate > 0 ? _usdcRate : 1.0;
          if (xlmUsdt != null && xlmUsdt > 0) _xlmRate = xlmUsdt * usdtUsd * fx;
        }
      }

      _setLoading(false);
      _xlmCtrl.add(_xlmRate);
      _usdcCtrl.add(_usdcRate);
      notifyListeners();
    }
  }

  void _setLoading(bool v) {
    if (_loading != v) {
      _loading = v;
      notifyListeners();
    }
  }

  // ---- Rates (CEX + DEX fallback) ------------------------------------------
  Future<void> _fetchRates() async {
    try {
      final res = await Future.wait<double?>([
        _usdcToFiat().catchError((_) => null),
        _xlmUsdc().catchError((_) => null),
      ]);

      final usdcFiat = res[0];
      final xlmUsdc  = res[1];

      var updated = false;

      if (usdcFiat != null && usdcFiat > 0) {
        _prevUsdcRate = _usdcRate;
        _usdcRate = usdcFiat;
        updated = true;
      }
      if (xlmUsdc != null && xlmUsdc > 0) {
        final fx = (_usdcRate > 0
            ? _usdcRate
            : (_prevUsdcRate > 0 ? _prevUsdcRate : (await _usdToFiat(_fiat) ?? 1.0)));
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

  // USDC→FIAT = (USDC→USD multi-venue with peg fallback) * (USD→FIAT multi-source)
  Future<double?> _usdcToFiat() async {
    final usdcUsd = await _firstNonNullConcurrent<double?>([
          () => _coinbaseRate(base: 'USDC', quote: 'USD'),
          () => _krakenPrice('USDCUSD'),
          () => _binancePrice('USDCUSDT'), // ≈1 vs USDT
          () async => 1.0, // safe peg if all fail
    ]);
    final usdFiat = await _usdToFiat(_fiat) ?? 1.0;
    return (usdcUsd ?? 1.0) * usdFiat;
  }

  // ---- DEX (on-chain) config ----------------------------------------------
  // Circle USDC issuer on Stellar mainnet:
  // GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN

  // Use your Stellar wallet service’s override when present; fall back to Circle issuer.
  final StellarWalletService _stellar = StellarWalletService();
  static const String _FALLBACK_USDC_ISSUER =
      'GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN';
  String get _usdcIssuer => _stellar.usdcIssuerOverrideMainnet ?? _FALLBACK_USDC_ISSUER;

  final List<String> _horizonBases = [
    'https://horizon.stellar.org',
    // Optional public mirrors:
    'https://horizon.stellar.lobstr.co',
    'https://horizon-public.stellar.lobstr.co',
  ];

  // Prefer XLM/USDC from CEX; else DEX via Horizon; else XLM/USDT route
  Future<double?> _xlmUsdc() async {
    final parsersCex = <Future<double?> Function()>[
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
      // KuCoin XLM-USDC
          () async {
        final m = await _json(Uri.parse('https://api.kucoin.com/api/v1/market/orderbook/level1?symbol=XLM-USDC'));
        final s = m['data']?['price'] as String?;
        return s != null ? double.tryParse(s) : null;
      },
      // Binance XLMUSDC (try alt hosts)
          () async {
        for (final host in const [
          'api.binance.com',
          'api1.binance.com',
          'api2.binance.com',
          'api3.binance.com',
        ]) {
          if (_isBannedHost(host)) continue;
          final m = await _json(Uri.parse('https://$host/api/v3/ticker/price?symbol=XLMUSDC'));
          final s = m['price'] as String?;
          final v = s != null ? double.tryParse(s) : null;
          if (v != null && v > 0) return v;
        }
        return null;
      },
    ];

    // Try CEX in parallel first
    final cex = await _firstNonNullConcurrent<double?>(parsersCex);
    if (cex != null && cex > 0) return cex;

    // DEX fallback (on-chain): strict-send path → orderbook mid → trade agg
    final dex = await _xlmUsdcViaDex();
    if (dex != null && dex > 0) return dex;

    // Final fallback: XLM/USDT × (USDT/USD) / (USDC/USD)
    final xlmUsdt = await _xlmUsdt();
    if (xlmUsdt == null) return null;
    final usdtUsd = await _usdtUsdApprox(); // ~1.0
    final usdcUsd = await _firstNonNullConcurrent<double?>([
          () => _coinbaseRate(base: 'USDC', quote: 'USD'),
          () => _krakenPrice('USDCUSD'),
          () => _binancePrice('USDCUSDT'),
          () async => 1.0,
    ]) ??
        1.0;
    if (usdcUsd <= 0) return xlmUsdt * usdtUsd;
    return xlmUsdt * (usdtUsd / usdcUsd);
  }

  /// DEX fallback chain:
  /// 1) Paths (strict-send) quote: how much USDC for 1 XLM
  /// 2) Order book midprice: avg(top ask, top bid) in USDC/XLM
  /// 3) Trade aggregation (1h) average price
  Future<double?> _xlmUsdcViaDex() async {
    // 1) Strict-send path quote (1 XLM → USDC)
    final q1 = await _dexStrictSendQuoteXlmToUsdc(sourceAmount: 1.0);
    if (q1 != null && q1 > 0) return q1;

    // 2) Orderbook mid (USDC per XLM)
    final q2 = await _dexOrderbookMidXlmUsdc();
    if (q2 != null && q2 > 0) return q2;

    // 3) Trade aggregation (1h)
    final q3 = await _xlmUsdcViaTradeAgg();
    return q3;
  }

  // ---- DEX helpers ---------------------------------------------------------

  // Strict-send path quote via Horizon:
  // GET /paths/strict-send?source_asset_type=native&source_amount=1&destination_assets=USDC:ISSUER
  Future<double?> _dexStrictSendQuoteXlmToUsdc({double sourceAmount = 1.0}) async {
    final amt = sourceAmount <= 0 ? 1.0 : sourceAmount;
    final dest = 'USDC:$_usdcIssuer';

    return _firstNonNullConcurrent<double?>([
      for (final base in _horizonBases)
            () async {
          final uri = Uri.parse(
              '$base/paths/strict-send?source_asset_type=native&source_amount=${amt.toString()}&destination_assets=$dest&limit=3');
          final m = await _json(uri);
          final recs = (m['records'] as List?) ?? const [];
          if (recs.isEmpty) return null;
          // Take the highest destination_amount among returned paths
          double best = 0;
          for (final r in recs) {
            final v = (r is Map) ? r['destination_amount'] : null;
            final d = (v is String) ? double.tryParse(v) : (v is num ? v.toDouble() : null);
            if (d != null && d > best) best = d;
          }
          return best > 0 ? best / amt : null; // normalize to USDC per 1 XLM
        },
    ], attemptTimeout: const Duration(seconds: 6));
  }

  // Orderbook midprice: selling XLM, buying USDC
  // GET /order_book?selling_asset_type=native&buying_asset_type=credit_alphanum4&buying_asset_code=USDC&buying_asset_issuer=ISSUER
  Future<double?> _dexOrderbookMidXlmUsdc() async {
    return _firstNonNullConcurrent<double?>([
      for (final base in _horizonBases)
            () async {
          final uri = Uri.parse(
              '$base/order_book?selling_asset_type=native'
                  '&buying_asset_type=credit_alphanum4&buying_asset_code=USDC&buying_asset_issuer=$_usdcIssuer'
                  '&limit=10');
          final m = await _json(uri);
          final bids = (m['bids'] as List?) ?? const [];
          final asks = (m['asks'] as List?) ?? const [];

          double? parsePx(dynamic e) {
            if (e is Map) {
              final p = e['price'];
              if (p is String) return double.tryParse(p);
              if (p is num) return p.toDouble();
              final pr = e['price_r'];
              if (pr is Map && pr['n'] != null && pr['d'] != null) {
                final n = (pr['n'] as num).toDouble();
                final d = (pr['d'] as num).toDouble();
                if (d != 0) return n / d;
              }
            }
            return null;
          }

          final bestAsk = asks.isNotEmpty ? parsePx(asks.first) : null; // USDC per XLM
          final bestBid = bids.isNotEmpty ? parsePx(bids.first) : null; // USDC per XLM
          if (bestAsk != null && bestBid != null) return (bestAsk + bestBid) / 2.0;
          return bestAsk ?? bestBid;
        },
    ], attemptTimeout: const Duration(seconds: 6));
  }

  // Trade aggregation (1h) average USDC per XLM
  Future<double?> _xlmUsdcViaTradeAgg() async {
    return _firstNonNullConcurrent<double?>([
      for (final base in _horizonBases)
            () async {
          final uri = Uri.parse(
            '$base/trade_aggregations'
                '?base_asset_type=native'
                '&counter_asset_type=credit_alphanum4'
                '&counter_asset_code=USDC'
                '&counter_asset_issuer=$_usdcIssuer'
                '&resolution=3600000' // 1h
                '&limit=1&order=desc',
          );
          final m = await _json(uri);
          final recs = (m['records'] as List?) ?? const [];
          if (recs.isEmpty) return null;
          final avg = recs.first['avg'];
          if (avg is String) return double.tryParse(avg);
          if (avg is num) return avg.toDouble();
          return null;
        },
    ], attemptTimeout: const Duration(seconds: 6));
  }

  // ---- CEX helpers ---------------------------------------------------------
  Future<double?> _xlmUsdt() async {
    return _firstNonNullConcurrent<double?>([
      // Binance family
          () async {
        for (final host in const [
          'api.binance.com',
          'api1.binance.com',
          'api2.binance.com',
          'api3.binance.com',
        ]) {
          if (_isBannedHost(host)) continue;
          final m = await _json(Uri.parse('https://$host/api/v3/ticker/price?symbol=XLMUSDT'));
          final s = m['price'] as String?;
          final v = s != null ? double.tryParse(s) : null;
          if (v != null && v > 0) return v;
        }
        return null;
      },
      // OKX
          () async {
        final m = await _json(Uri.parse('https://www.okx.com/api/v5/market/ticker?instId=XLM-USDT'));
        final d = (m['data'] as List?) ?? const [];
        final s = d.isNotEmpty ? d.first['last'] as String? : null;
        return s != null ? double.tryParse(s) : null;
      },
      // KuCoin
          () async {
        final m = await _json(Uri.parse('https://api.kucoin.com/api/v1/market/orderbook/level1?symbol=XLM-USDT'));
        final s = m['data']?['price'] as String?;
        return s != null ? double.tryParse(s) : null;
      },
      // Bybit
          () async {
        final m = await _json(Uri.parse('https://api.bybit.com/v5/market/tickers?category=spot&symbol=XLMUSDT'));
        final l = (m['result']?['list'] as List?) ?? const [];
        final s = l.isNotEmpty ? l.first['lastPrice'] as String? : null;
        return s != null ? double.tryParse(s) : null;
      },
      // Kraken
          () async {
        final m = await _json(Uri.parse('https://api.kraken.com/0/public/Ticker?pair=XLMUSDT'));
        final r = (m['result'] as Map?) ?? {};
        if (r.isNotEmpty) {
          final c = (r.values.first as Map)['c'] as List?;
          return (c != null && c.isNotEmpty) ? double.tryParse(c.first.toString()) : null;
        }
        return null;
      },
    ]);
  }

  // ---- Histories (derive from USDT klines, scale to FIAT) ------------------
  Future<void> _fetchHistories() async {
    final now  = DateTime.now();
    final f7   = now.subtract(const Duration(days: 7));
    final f30  = now.subtract(const Duration(days: 30));
    final f365 = now.subtract(const Duration(days: 365));

    // USDC series: USD→FIAT daily (proxy), flat intraday
    final usdcBase = _usdcRate > 0 ? _usdcRate : (_prevUsdcRate > 0 ? _prevUsdcRate : 1.0);
    final usdc24 = List<double>.filled(24, usdcBase);
    final usdc7  = await _usdToFiatSeries(f7, now, _fiat, 7);
    final usdc30 = await _usdToFiatSeries(f30, now, _fiat, 30);
    final usdc365= await _usdToFiatSeries(f365, now, _fiat, 365);

    // XLM series: take XLM/USDT klines; multiply by USDC→FIAT (current/prev)
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
    } catch (_) {
      final base = _usdcRate > 0 ? _usdcRate : (_prevUsdcRate > 0 ? _prevUsdcRate : 1.0);
      return List<double>.filled(len, base);
    }
  }

  // XLM/USDT klines (Binance → Vision mirror → OKX → KuCoin). Safe parsing + flat fallback.
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
          () async { // Binance "vision" mirror
        final m = await _json(Uri.parse('https://data-api.binance.vision/api/v3/klines?symbol=XLMUSDT&interval=$interval&limit=$limit'));
        final raw = m['_'];
        if (raw is List) {
          final l = raw.cast<dynamic>();
          final out = l.map((e) => (e is List && e.length > 4) ? double.tryParse(e[4].toString()) : null)
              .whereType<double>().toList();
          return out.isNotEmpty ? out : null;
        }
        return null;
      },
          () async { // OKX
        final m = await _json(Uri.parse('https://www.okx.com/api/v5/market/candles?instId=XLM-USDT&bar=${interval == '1h' ? '1H':'1D'}&limit=$limit'));
        final l = (m['data'] as List?)?.cast<List>() ?? const [];
        final c = l.reversed.map((r) => (r.length > 4) ? double.tryParse(r[4].toString()) : null)
            .whereType<double>().toList();
        return c.length >= 1 ? _normalize(c, limit) : null;
      },
          () async { // KuCoin
        final m = await _json(Uri.parse('https://api.kucoin.com/api/v1/market/candles?type=${interval == "1h" ? "1hour":"1day"}&symbol=XLM-USDT'));
        final l = (m['data'] as List?)?.cast<List>() ?? const [];
        final c = l.reversed.map((r) => (r.length > 2) ? double.tryParse(r[2].toString()) : null)
            .whereType<double>().toList();
        return c.length >= 1 ? _normalize(c, limit) : null;
      },
    ];
    for (final f in tries) {
      try {
        final v = await f();
        if (v != null && v.isNotEmpty) return _normalize(v, limit);
      } catch (_) {}
    }
    // Conservative flat fallback (estimate XLM/USDC≈XLM/USDT)
    final xlmUsdcGuess = (_xlmRate > 0 && _usdcRate > 0) ? _xlmRate / _usdcRate : 0.12;
    return List<double>.filled(limit, xlmUsdcGuess);
  }

  // ---- FX helpers ----------------------------------------------------------
  Future<double?> _usdToFiat(String fiat) async {
    final tgt = fiat.toUpperCase();
    if (tgt == 'USD') return 1.0;

    return _firstNonNullConcurrent<double?>([
      // Frankfurter
          () async {
        final m = await _json(Uri.parse('https://api.frankfurter.app/latest?from=USD&to=$tgt'));
        final v = (m['rates'] as Map?)?[tgt];
        return (v is num) ? v.toDouble() : null;
      },
      // exchangerate.host
          () async {
        final m = await _json(Uri.parse('https://api.exchangerate.host/latest?base=USD&symbols=$tgt'));
        final v = (m['rates'] as Map?)?[tgt];
        return (v is num) ? v.toDouble() : null;
      },
      // open.er-api.com
          () async {
        final m = await _json(Uri.parse('https://open.er-api.com/v6/latest/USD'));
        final v = (m['rates'] as Map?)?[tgt];
        return (v is num) ? v.toDouble() : null;
      },
    ]);
  }

  Future<double?> _coinbaseRate({required String base, required String quote}) async {
    return _firstNonNullConcurrent<double?>([
          () async {
        final m = await _json(Uri.parse('https://api.coinbase.com/v2/exchange-rates?currency=$base'));
        final rates = (m['data']?['rates'] as Map?) ?? {};
        final v = rates[quote];
        if (v is String) return double.tryParse(v);
        if (v is num) return v.toDouble();
        return null;
      },
          () async { // Coinbase Advanced
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
    final v = await _firstNonNullConcurrent<double?>([
          () => _krakenPrice('USDTUSD'),
          () => _binancePrice('USDTUSD'),
          () async => 1.0,
    ]);
    return v ?? 1.0;
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
    if (_isBannedHost(url.host)) throw Exception('Host banned temporarily: ${url.host}');
    try {
      final resp = await _retry(() => _client
          .get(url, headers: {'User-Agent': 'NextFi/1.0', 'Accept': 'application/json'})
          .timeout(httpTimeout));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        _noteHostSuccess(url.host);
        final b = resp.body.isEmpty ? '{}' : resp.body;
        final d = jsonDecode(b);
        return d is Map<String,dynamic> ? d : {'_': d};
      }
      _noteHostFailure(url.host);
      throw Exception('HTTP ${resp.statusCode} for $url');
    } catch (e) {
      _noteHostFailure(url.host);
      rethrow;
    }
  }

  Future<T> _retry<T>(Future<T> Function() f, {int times = 3}) async {
    dynamic last;
    for (var i = 0; i < times; i++) {
      try {
        return await f();
      } catch (e) {
        last = e;
        if (i < times - 1) {
          await Future.delayed(Duration(milliseconds: 300 * (i + 1)));
        }
      }
    }
    // ignore: only_throw_errors
    throw last;
  }

  // Better probe: detect captive portals & DNS interception
  Future<bool> _hasInternet() async {
    try {
      final checks = [
            () async { // HTTPS 204
          final r = await _client.get(Uri.parse('https://www.gstatic.com/generate_204'))
              .timeout(const Duration(seconds: 4));
          return r.statusCode == 204;
        },
            () async { // HTTP 204
          final r = await _client.get(Uri.parse('http://connectivitycheck.gstatic.com/generate_204'))
              .timeout(const Duration(seconds: 4));
          return r.statusCode == 204;
        },
            () async { // Cloudflare trace
          final r = await _client.get(Uri.parse('https://1.1.1.1/cdn-cgi/trace'))
              .timeout(const Duration(seconds: 4));
          return r.statusCode >= 200 && r.statusCode < 400;
        },
            () async { // DNS lookup
          final a = await InternetAddress.lookup('one.one.one.one')
              .timeout(const Duration(seconds: 3));
          if (a.isNotEmpty) return true;
          final b = await InternetAddress.lookup('dns.google')
              .timeout(const Duration(seconds: 3));
          return b.isNotEmpty;
        },
      ];
      for (final c in checks) {
        try { if (await c()) return true; } catch (_) {}
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // Utility: first non-null among async attempts (sequential)
  Future<T?> _firstNonNull<T>(List<Future<T?> Function()> attempts) async {
    for (final f in attempts) {
      try {
        final v = await f();
        if (v != null) return v;
      } catch (_) {}
    }
    return null;
  }

  // Utility: first non-null among async attempts (parallel race)
  Future<T?> _firstNonNullConcurrent<T>(
      List<Future<T?> Function()> attempts, {
        Duration attemptTimeout = const Duration(seconds: 5),
      }) async {
    final futures = <Future<T?>>[];
    for (final fn in attempts) {
      futures.add(
            () async {
          try {
            final v = await fn().timeout(attemptTimeout);
            return v;
          } catch (_) {
            return null;
          }
        }(),
      );
    }
    T? picked;
    for (final f in futures) {
      final v = await f;
      if (picked == null && v != null) picked = v;
    }
    return picked;
  }

  // --- Host circuit breaker (ban failing hosts for a bit) -------------------
  final Map<String, int> _hostFails = {}; // host -> failures in window
  final Map<String, DateTime> _bannedUntil = {}; // host -> until

  bool _isBannedHost(String host) {
    final t = _bannedUntil[host];
    if (t == null) return false;
    if (DateTime.now().isAfter(t)) {
      _bannedUntil.remove(host);
      _hostFails.remove(host);
      return false;
    }
    return true;
  }

  void _noteHostSuccess(String host) {
    _hostFails.remove(host);
    _bannedUntil.remove(host);
  }

  void _noteHostFailure(String host) {
    final n = (_hostFails[host] ?? 0) + 1;
    _hostFails[host] = n;
    if (n >= 3) {
      _bannedUntil[host] = DateTime.now().add(const Duration(minutes: 10));
    }
  }
}
