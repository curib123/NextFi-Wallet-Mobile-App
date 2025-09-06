import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// CoinGecko-free provider with multi-exchange fallbacks
/// - XLM/USDT spot & candles: Binance → OKX → KuCoin → Bybit → Kraken (spot)
/// - USDC→FIAT spot: Coinbase → OKX → Kraken → Bitstamp (USDC/USD) → compose w/ USD→FIAT
/// - USD→FIAT history: Frankfurter
/// - USDC 24H: flat proxy at current spot
class CurrencyProvider extends ChangeNotifier {
  CurrencyProvider({
    this.pollEvery = const Duration(seconds: 30),
    this.httpTimeout = const Duration(seconds: 10),
  }) {
    _refreshAll();
    _startPolling();
  }

  // ---- Config ----
  final Duration pollEvery;
  final Duration httpTimeout;

  // ---- State: fiat + rates ----
  String _fiat = "usd";
  double _usdcRate = 0; // USDC -> FIAT
  double _xlmRate  = 0; // XLM  -> FIAT

  double _prevUsdcRate = 0;
  double _prevXlmRate  = 0;

  // ---- Histories (normalized exact length) ----
  // 24H (24 hourly points)
  List<double> _xlmHistory24h  = [];
  List<double> _usdcHistory24h = [];

  // 7D (7 daily points)
  List<double> _xlmHistory7   = [];
  List<double> _usdcHistory7  = [];

  // 30D (30 daily points)
  List<double> _xlmHistory30  = [];
  List<double> _usdcHistory30 = [];

  // 365D (365 daily points)
  List<double> _xlmHistory365  = [];
  List<double> _usdcHistory365 = [];

  // ---- Loading + timers ----
  bool _loading = true;
  Timer? _pollingTimer;

  // ---- Streams (live price) ----
  final _xlmPriceController  = StreamController<double>.broadcast();
  final _usdcPriceController = StreamController<double>.broadcast();

  // ---- Public API ----
  String get fiat => _fiat;
  bool get loading => _loading;

  double get usdcRate => _usdcRate;
  double get xlmRate  => _xlmRate;

  // Backward-compat (7D) — renamed for clarity
  List<double> get xlmHistory  => _xlmHistory7;
  List<double> get usdcHistory => _usdcHistory7;

  // Explicit ranges
  List<double> get xlmHistory24h  => _xlmHistory24h;
  List<double> get xlmHistory7    => _xlmHistory7;
  List<double> get xlmHistory30   => _xlmHistory30;
  List<double> get xlmHistory365  => _xlmHistory365;

  List<double> get usdcHistory24h  => _usdcHistory24h;
  List<double> get usdcHistory7    => _usdcHistory7;
  List<double> get usdcHistory30   => _usdcHistory30;
  List<double> get usdcHistory365  => _usdcHistory365;

  Stream<double> get xlmPriceStream  => _xlmPriceController.stream;
  Stream<double> get usdcPriceStream => _usdcPriceController.stream;

  // ---- Lifecycle ----
  void setFiat(String newFiat) {
    final lower = newFiat.toLowerCase();
    if (lower != _fiat) {
      _fiat = lower;
      _refreshAll();
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(pollEvery, (_) => _refreshAll());
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _xlmPriceController.close();
    _usdcPriceController.close();
    super.dispose();
  }

  // ---- Orchestrator ----
  Future<void> _refreshAll() async {
    _loading = true;
    notifyListeners();

    try {
      await _fetchRates();
      await _fetchHistoryAll();
    } finally {
      _loading = false;
      _xlmPriceController.add(_xlmRate);
      _usdcPriceController.add(_usdcRate);
      notifyListeners();
    }
  }

  // ---- Rates ----
  Future<void> _fetchRates() async {
    try {
      final xlmUsdtF  = _fetchXlmUsdtMulti();
      final usdcFiatF = _fetchUsdcToFiatMulti(_fiat);

      final results = await Future.wait<double?>([xlmUsdtF, usdcFiatF]);

      final xlmUsdt    = results[0];
      final usdcToFiat = results[1];

      bool gotAny = false;

      if (usdcToFiat != null && usdcToFiat > 0) {
        _prevUsdcRate = _usdcRate;
        _usdcRate = usdcToFiat;
        gotAny = true;
      }

      if (xlmUsdt != null && xlmUsdt > 0 && (_usdcRate > 0 || _prevUsdcRate > 0)) {
        final fx = (_usdcRate > 0) ? _usdcRate : _prevUsdcRate;
        _prevXlmRate = _xlmRate;
        _xlmRate = xlmUsdt * fx;
        gotAny = true;
      }

      if (!gotAny) _applyPreviousIfCurrentInvalid();
    } on TimeoutException {
      _applyPreviousIfCurrentInvalid();
    } catch (e) {
      debugPrint("fetchRates error: $e");
      _applyPreviousIfCurrentInvalid();
    }
  }

  void _applyPreviousIfCurrentInvalid() {
    if (_usdcRate <= 0 && _prevUsdcRate > 0) _usdcRate = _prevUsdcRate;
    if (_xlmRate  <= 0 && _prevXlmRate  > 0) _xlmRate  = _prevXlmRate;
  }

  /* =========================
   *   MULTI-EXCHANGE HELPERS
   * ========================= */

  // --- XLM/USDT spot (double?) ---
  Future<double?> _fetchXlmUsdtMulti() async {
    return await _tryFirstNonNull<double?>([
      _fetchXlmUsdtFromBinance, // https://api.binance.com/api/v3/ticker/price?symbol=XLMUSDT
      _fetchXlmUsdtFromOKX,     // https://www.okx.com/api/v5/market/ticker?instId=XLM-USDT
      _fetchXlmUsdtFromKuCoin,  // https://api.kucoin.com/api/v1/market/orderbook/level1?symbol=XLM-USDT
      _fetchXlmUsdtFromBybit,   // https://api.bybit.com/v5/market/tickers?category=spot&symbol=XLMUSDT
      _fetchXlmUsdtFromKraken,  // https://api.kraken.com/0/public/Ticker?pair=XLMUSDT
    ]);
  }

  Future<double?> _fetchXlmUsdtFromBinance() async {
    try {
      final url = Uri.parse('https://api.binance.com/api/v3/ticker/price?symbol=XLMUSDT');
      final r = await http.get(url).timeout(httpTimeout);
      if (r.statusCode == 200) {
        final m = jsonDecode(r.body) as Map<String, dynamic>;
        final p = (m['price'] as String?) ?? '';
        return double.tryParse(p);
      }
    } catch (_) {}
    return null;
  }

  Future<double?> _fetchXlmUsdtFromOKX() async {
    try {
      final url = Uri.parse('https://www.okx.com/api/v5/market/ticker?instId=XLM-USDT');
      final r = await http.get(url).timeout(httpTimeout);
      if (r.statusCode == 200) {
        final m = jsonDecode(r.body) as Map<String, dynamic>;
        final data = (m['data'] as List?)?.cast<dynamic>();
        final last = (data != null && data.isNotEmpty) ? (data.first['last'] as String?) : null;
        return last != null ? double.tryParse(last) : null;
      }
    } catch (_) {}
    return null;
  }

  Future<double?> _fetchXlmUsdtFromKuCoin() async {
    try {
      final url = Uri.parse('https://api.kucoin.com/api/v1/market/orderbook/level1?symbol=XLM-USDT');
      final r = await http.get(url).timeout(httpTimeout);
      if (r.statusCode == 200) {
        final m = jsonDecode(r.body) as Map<String, dynamic>;
        final p = (m['data']?['price'] as String?) ?? '';
        return double.tryParse(p);
      }
    } catch (_) {}
    return null;
  }

  Future<double?> _fetchXlmUsdtFromBybit() async {
    try {
      final url = Uri.parse('https://api.bybit.com/v5/market/tickers?category=spot&symbol=XLMUSDT');
      final r = await http.get(url).timeout(httpTimeout);
      if (r.statusCode == 200) {
        final m = jsonDecode(r.body) as Map<String, dynamic>;
        final list = (m['result']?['list'] as List?)?.cast<dynamic>() ?? const [];
        final lastPrice = list.isNotEmpty ? (list.first['lastPrice'] as String?) : null;
        return lastPrice != null ? double.tryParse(lastPrice) : null;
      }
    } catch (_) {}
    return null;
  }

  Future<double?> _fetchXlmUsdtFromKraken() async {
    try {
      final url = Uri.parse('https://api.kraken.com/0/public/Ticker?pair=XLMUSDT');
      final r = await http.get(url).timeout(httpTimeout);
      if (r.statusCode == 200) {
        final m = jsonDecode(r.body) as Map<String, dynamic>;
        final result = (m['result'] as Map?)?.cast<String, dynamic>() ?? {};
        if (result.isNotEmpty) {
          final first = result.values.first as Map<String, dynamic>;
          final c = (first['c'] as List?)?.cast<dynamic>(); // ["last", "lot"]
          if (c != null && c.isNotEmpty) {
            return double.tryParse(c.first.toString());
          }
        }
      }
    } catch (_) {}
    return null;
  }

  // --- USDC -> FIAT spot (double?) ---
  Future<double?> _fetchUsdcToFiatMulti(String fiat) async {
    // 1) Coinbase direct USDC->FIAT
    final cb = await _fetchUsdcToFiatFromCoinbase(fiat);
    if (cb != null && cb > 0) return cb;

    // 2) If FIAT==USD, try direct USDC/USD from CEXs (OKX/Kraken/Bitstamp)
    if (fiat.toLowerCase() == 'usd') {
      final okx = await _fetchUsdcUsdFromOKX();
      if (okx != null && okx > 0) return okx;
      final krk = await _fetchUsdcUsdFromKraken();
      if (krk != null && krk > 0) return krk;
      final bst = await _fetchUsdcUsdFromBitstamp();
      if (bst != null && bst > 0) return bst;
      // fall back to peg
      return 1.0;
    }

    final usdToFiat = await _fetchUsdToFiatSpot(fiat);

    // 4) Last resort: treat USDC≈USD and just convert USD→FIAT
    if (usdToFiat != null && usdToFiat > 0) return usdToFiat;
    return null;
  }

  Future<double?> _fetchUsdcToFiatFromCoinbase(String fiat) async {
    try {
      final url = Uri.parse('https://api.coinbase.com/v2/exchange-rates?currency=USDC');
      final r = await http.get(url).timeout(httpTimeout);
      if (r.statusCode == 200) {
        final m = jsonDecode(r.body) as Map<String, dynamic>;
        final rates = (m['data']?['rates'] as Map?)?.cast<String, dynamic>();
        final val = rates?[fiat.toUpperCase()];
        if (val is String) return double.tryParse(val);
        if (val is num) return val.toDouble();
      }
      if (fiat.toLowerCase() == 'usd') return 1.0;
    } catch (_) {}
    return null;
  }

  Future<double?> _fetchUsdToFiatSpot(String fiat) async {
    if (fiat.toLowerCase() == 'usd') return 1.0;
    try {
      final url = Uri.parse('https://api.frankfurter.app/latest?from=USD&to=${fiat.toUpperCase()}');
      final r = await http.get(url).timeout(httpTimeout);
      if (r.statusCode == 200) {
        final m = jsonDecode(r.body) as Map<String, dynamic>;
        final v = (m['rates'] as Map?)?[fiat.toUpperCase()];
        if (v is num) return v.toDouble();
      }
    } catch (_) {}
    return null;
  }

  Future<double?> _fetchUsdcUsdFromOKX() async {
    try {
      final url = Uri.parse('https://www.okx.com/api/v5/market/ticker?instId=USDC-USD');
      final r = await http.get(url).timeout(httpTimeout);
      if (r.statusCode == 200) {
        final m = jsonDecode(r.body) as Map<String, dynamic>;
        final data = (m['data'] as List?)?.cast<dynamic>() ?? const [];
        final last = data.isNotEmpty ? (data.first['last'] as String?) : null;
        return last != null ? double.tryParse(last) : null;
      }
    } catch (_) {}
    return null;
  }

  Future<double?> _fetchUsdcUsdFromKraken() async {
    try {
      final url = Uri.parse('https://api.kraken.com/0/public/Ticker?pair=USDCUSD');
      final r = await http.get(url).timeout(httpTimeout);
      if (r.statusCode == 200) {
        final m = jsonDecode(r.body) as Map<String, dynamic>;
        final result = (m['result'] as Map?)?.cast<String, dynamic>() ?? {};
        if (result.isNotEmpty) {
          final first = result.values.first as Map<String, dynamic>;
          final c = (first['c'] as List?)?.cast<dynamic>();
          if (c != null && c.isNotEmpty) {
            return double.tryParse(c.first.toString());
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<double?> _fetchUsdcUsdFromBitstamp() async {
    try {
      // https://www.bitstamp.net/api/v2/ticker/usdcusd/
      final url = Uri.parse('https://www.bitstamp.net/api/v2/ticker/usdcusd/');
      final r = await http.get(url).timeout(httpTimeout);
      if (r.statusCode == 200) {
        final m = jsonDecode(r.body) as Map<String, dynamic>;
        final last = (m['last'] as String?) ?? '';
        return double.tryParse(last);
      }
    } catch (_) {}
    return null;
  }

  // Utility: try functions in order and return the first non-null
  Future<T?> _tryFirstNonNull<T>(List<Future<T?> Function()> fns) async {
    for (final fn in fns) {
      try {
        final v = await fn();
        if (v != null) return v;
      } catch (_) {}
    }
    return null;
  }

  /* =========================
   *         HISTORIES
   * ========================= */

  Future<void> _fetchHistoryAll() async {
    try {
      final now  = DateTime.now();
      final f7   = now.subtract(const Duration(days: 7));
      final f30  = now.subtract(const Duration(days: 30));
      final f365 = now.subtract(const Duration(days: 365));

      // USDC series (proxy from USD->FIAT)
      final usdc24hF = _buildUsdc24hSeries(expectedLen: 24); // flat around current rate
      final usdc7F   = _fetchUsdToFiatSeries(f7, now, _fiat, expectedLen: 7);
      final usdc30F  = _fetchUsdToFiatSeries(f30, now, _fiat, expectedLen: 30);
      final usdc365F = _fetchUsdToFiatSeries(f365, now, _fiat, expectedLen: 365);

      // XLM series in USDT, then multiplied by USDC->FIAT (current/prev)
      final xlm24F  = _fetchXlmIntradayUsdt(hours: 24);
      final xlm7F   = _fetchXlmClosesUsdt(days: 7);
      final xlm30F  = _fetchXlmClosesUsdt(days: 30);
      final xlm365F = _fetchXlmClosesUsdt(days: 365);

      final results = await Future.wait([
        usdc24hF, usdc7F, usdc30F, usdc365F,
        xlm24F,   xlm7F,  xlm30F,  xlm365F,
      ]);

      final usdc24  = (results[0] as List<double>);
      final usdc7   = (results[1] as List<double>);
      final usdc30  = (results[2] as List<double>);
      final usdc365 = (results[3] as List<double>);

      final xlm24u  = (results[4] as List<double>);
      final xlm7u   = (results[5] as List<double>);
      final xlm30u  = (results[6] as List<double>);
      final xlm365u = (results[7] as List<double>);

      final fx = (_usdcRate > 0) ? _usdcRate : (_prevUsdcRate > 0 ? _prevUsdcRate : 1.0);

      _usdcHistory24h = usdc24;
      _usdcHistory7   = usdc7;
      _usdcHistory30  = usdc30;
      _usdcHistory365 = usdc365;

      _xlmHistory24h  = xlm24u.map((c) => c * fx).toList();
      _xlmHistory7    = xlm7u.map((c) => c * fx).toList();
      _xlmHistory30   = xlm30u.map((c) => c * fx).toList();
      _xlmHistory365  = xlm365u.map((c) => c * fx).toList();

      notifyListeners();
    } on TimeoutException catch (e) {
      debugPrint("History timeout: $e");
    } catch (e) {
      debugPrint("Failed to fetch history: $e");
    }
  }

  // 24H XLM: 1h candles (24 points) with fallbacks
  Future<List<double>> _fetchXlmIntradayUsdt({required int hours}) async {
    // Binance → OKX → KuCoin → Bybit → Kraken
    final tryOrder = <Future<List<double>?> Function()>[
          () => _binanceKlines('1h', hours),
          () => _okxCandles('1H', hours),
          () => _kucoinCandles('1hour', hours),
          () => _bybitKline('60', hours),   // interval minutes
          () => _krakenOhlc(60, hours),     // interval minutes
    ];

    for (final fn in tryOrder) {
      try {
        final v = await fn();
        if (v != null && v.isNotEmpty) return _normalizeSeries(v, hours);
      } catch (_) {}
    }

    // Fallback: derive XLM/USDT from spot or use a safe default
    double xlmUsdt = 0;
    final usdc = _usdcRate > 0 ? _usdcRate : (_prevUsdcRate > 0 ? _prevUsdcRate : 1.0);
    if (usdc > 0 && _xlmRate > 0) xlmUsdt = _xlmRate / usdc;
    final base = xlmUsdt > 0 ? xlmUsdt : 0.12; // conservative default
    return List<double>.filled(hours, base);
  }

  // 7D/30D/365D XLM: daily closes with fallbacks
  Future<List<double>> _fetchXlmClosesUsdt({required int days}) async {
    final tryOrder = <Future<List<double>?> Function()>[
          () => _binanceKlines('1d', days),
          () => _okxCandles('1D', days),
          () => _kucoinCandles('1day', days),
          () => _bybitKline('D', days),     // Bybit accepts 'D' for 1 day
          () => _krakenOhlc(1440, days),    // 1440 minutes = 1 day
    ];

    for (final fn in tryOrder) {
      try {
        final v = await fn();
        if (v != null && v.isNotEmpty) return _normalizeSeries(v, days);
      } catch (_) {}
    }

    double xlmUsdt = 0;
    final usdc = _usdcRate > 0 ? _usdcRate : (_prevUsdcRate > 0 ? _prevUsdcRate : 1.0);
    if (usdc > 0 && _xlmRate > 0) xlmUsdt = _xlmRate / usdc;
    final base = xlmUsdt > 0 ? xlmUsdt : 0.12;
    return List<double>.filled(days, base);
  }

  // ---- Exchange-specific candles (XLM/USDT) ----

  // Binance klines: interval e.g., 1h or 1d
  Future<List<double>?> _binanceKlines(String interval, int limit) async {
    try {
      final url = Uri.parse('https://api.binance.com/api/v3/klines?symbol=XLMUSDT&interval=$interval&limit=$limit');
      final res = await http.get(url).timeout(httpTimeout);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        return list
            .map((e) => (e is List && e.length > 4) ? e[4] : null)
            .map((v) => (v is String) ? double.tryParse(v) : (v as num?)?.toDouble())
            .whereType<double>()
            .toList();
      }
    } catch (_) {}
    return null;
  }

  // OKX candles: bar e.g., 1H or 1D, response rows: [ts,o,h,l,c,vol,...]
  Future<List<double>?> _okxCandles(String bar, int limit) async {
    try {
      final url = Uri.parse('https://www.okx.com/api/v5/market/candles?instId=XLM-USDT&bar=$bar&limit=$limit');
      final r = await http.get(url).timeout(httpTimeout);
      if (r.statusCode == 200) {
        final m = jsonDecode(r.body) as Map<String, dynamic>;
        final data = (m['data'] as List?)?.cast<List>() ?? const [];
        // OKX returns newest first; reverse to chronological
        final closes = data.reversed
            .map((row) => (row.length > 4) ? row[4] : null)
            .map((v) => (v is String) ? double.tryParse(v) : (v as num?)?.toDouble())
            .whereType<double>()
            .toList();
        return closes;
      }
    } catch (_) {}
    return null;
  }

  // KuCoin candles: [time, open, close, high, low, volume, turnover]
  Future<List<double>?> _kucoinCandles(String type, int limit) async {
    try {
      final url = Uri.parse('https://api.kucoin.com/api/v1/market/candles?type=$type&symbol=XLM-USDT');
      final r = await http.get(url).timeout(httpTimeout);
      if (r.statusCode == 200) {
        final m = jsonDecode(r.body) as Map<String, dynamic>;
        final data = (m['data'] as List?)?.cast<List>() ?? const [];
        // KuCoin returns newest first; reverse to chronological; close at index 2
        final closes = data.reversed
            .map((row) => row.length > 2 ? row[2] : null)
            .map((v) => (v is String) ? double.tryParse(v) : (v as num?)?.toDouble())
            .whereType<double>()
            .toList();
        return closes.take(limit).toList();
      }
    } catch (_) {}
    return null;
  }

  // Bybit kline: result.list entries [start,open,high,low,close,volume,turnover]
  // interval: "60" (1h) or "D" (1day)
  Future<List<double>?> _bybitKline(String interval, int limit) async {
    try {
      final url = Uri.parse(
        'https://api.bybit.com/v5/market/kline?category=spot&symbol=XLMUSDT&interval=$interval&limit=$limit',
      );
      final r = await http.get(url).timeout(httpTimeout);
      if (r.statusCode == 200) {
        final m = jsonDecode(r.body) as Map<String, dynamic>;
        final list = (m['result']?['list'] as List?)?.cast<List>() ?? const [];
        // Bybit returns newest first; reverse, close at index 4
        final closes = list.reversed
            .map((row) => row.length > 4 ? row[4] : null)
            .map((v) => (v is String) ? double.tryParse(v) : (v as num?)?.toDouble())
            .whereType<double>()
            .toList();
        return closes;
      }
    } catch (_) {}
    return null;
  }

  // Kraken OHLC: result.<pair>: [time, open, high, low, close, vwap, volume, count]
  Future<List<double>?> _krakenOhlc(int intervalMinutes, int limit) async {
    try {
      final url = Uri.parse(
        'https://api.kraken.com/0/public/OHLC?pair=XLMUSDT&interval=$intervalMinutes',
      );
      final r = await http.get(url).timeout(httpTimeout);
      if (r.statusCode == 200) {
        final m = jsonDecode(r.body) as Map<String, dynamic>;
        final result = (m['result'] as Map?)?.cast<String, dynamic>() ?? {};
        if (result.isNotEmpty) {
          final arr = (result.values.first as List?)?.cast<List>() ?? const [];
          final closes = arr
              .map((row) => row.length > 4 ? row[4] : null)
              .map((v) => (v is String) ? double.tryParse(v) : (v as num?)?.toDouble())
              .whereType<double>()
              .toList();
          // Kraken is chronological already
          if (closes.length > limit) {
            return closes.sublist(closes.length - limit);
          }
          return closes;
        }
      }
    } catch (_) {}
    return null;
  }

  /* =========================
   *    USD->FIAT (history)
   * ========================= */

  // USD->FIAT series (proxy for USDC) via Frankfurter; normalized to expectedLen points.
  Future<List<double>> _fetchUsdToFiatSeries(
      DateTime from,
      DateTime to,
      String fiat, {
        required int expectedLen,
      }) async {
    // If fiat is USD, USDC≈1 => flat
    if (fiat.toLowerCase() == 'usd') {
      return List<double>.filled(expectedLen, 1.0);
    }

    String ymd(DateTime d) =>
        "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

    try {
      final url = Uri.parse(
        'https://api.frankfurter.app/${ymd(from)}..${ymd(to)}?from=USD&to=${fiat.toUpperCase()}',
      );
      final r = await http.get(url).timeout(httpTimeout);
      if (r.statusCode == 200) {
        final m = jsonDecode(r.body) as Map<String, dynamic>;
        final rates = (m['rates'] as Map?)?.cast<String, dynamic>() ?? {};
        final keys = rates.keys.toList()..sort(); // chronological by date
        var series = keys.map((k) {
          final v = (rates[k] as Map?)?[fiat.toUpperCase()];
          if (v is num) return v.toDouble();
          return 1.0;
        }).toList();

        // Normalize to expectedLen (weekends/holidays missing)
        series = _normalizeSeries(series, expectedLen);
        return series;
      }
    } catch (e) {
      debugPrint("Frankfurter error: $e");
    }

    // Fallback: flat using current rate
    final base = _usdcRate > 0 ? _usdcRate : (_prevUsdcRate > 0 ? _prevUsdcRate : 1.0);
    return List<double>.filled(expectedLen, base);
  }

  // USDC 24H proxy: flat line at current rate (no reliable hourly USD->FIAT)
  Future<List<double>> _buildUsdc24hSeries({required int expectedLen}) async {
    final base = _usdcRate > 0 ? _usdcRate : (_prevUsdcRate > 0 ? _prevUsdcRate : 1.0);
    return List<double>.filled(expectedLen, base);
  }

  // Ensure series has exactly expectedLen points.
  List<double> _normalizeSeries(List<double> series, int expectedLen) {
    if (series.isEmpty) return List<double>.filled(expectedLen, 1.0);
    if (series.length == expectedLen) return series;
    if (series.length > expectedLen) {
      return series.sublist(series.length - expectedLen);
    }
    final pad = expectedLen - series.length;
    return List<double>.filled(pad, series.first)..addAll(series);
  }

  // ---- Converters ----
  double xlmToFiat(double xlmAmount)  => xlmAmount * _xlmRate;
  double usdcToFiat(double usdcAmount) => usdcAmount * _usdcRate;

  double fiatToUsdc(double fiatAmount) => (_usdcRate != 0) ? fiatAmount / _usdcRate : 0.0;
  double fiatToXlm(double fiatAmount)  => (_xlmRate  != 0) ? fiatAmount / _xlmRate  : 0.0;

  double xlmToUsdc(double xlmAmount)   =>
      (_xlmRate != 0 && _usdcRate != 0) ? (xlmAmount * _xlmRate) / _usdcRate : 0.0;
  double usdcToXlm(double usdcAmount)  =>
      (_xlmRate != 0 && _usdcRate != 0) ? (usdcAmount * _usdcRate) / _xlmRate : 0.0;
}
