import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// CoinGecko-free provider with multi-exchange fallbacks
/// - TRX/USDT spot & candles: Binance → OKX → KuCoin → Bybit → Kraken (spot)
/// - USDT→FIAT spot: Coinbase → OKX → Kraken → Bitstamp (USDT/USD) → compose w/ USD→FIAT
/// - USD→FIAT history: Frankfurter
/// - USDT 24H: flat proxy at current spot
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
  double _usdtRate = 0; // USDT -> FIAT
  double _trxRate  = 0; // TRX  -> FIAT

  double _prevUsdtRate = 0;
  double _prevTrxRate  = 0;

  // ---- Histories (normalized exact length) ----
  // 24H (24 hourly points)
  List<double> _trxHistory24h  = [];
  List<double> _usdtHistory24h = [];

  // 7D (7 daily points)
  List<double> _trxHistory7   = [];
  List<double> _usdtHistory7  = [];

  // 30D (30 daily points)
  List<double> _trxHistory30  = [];
  List<double> _usdtHistory30 = [];

  // 365D (365 daily points)
  List<double> _trxHistory365  = [];
  List<double> _usdtHistory365 = [];

  // ---- Loading + timers ----
  bool _loading = true;
  Timer? _pollingTimer;

  // ---- Streams (live price) ----
  final _trxPriceController  = StreamController<double>.broadcast();
  final _usdtPriceController = StreamController<double>.broadcast();

  // ---- Public API ----
  String get fiat => _fiat;
  bool get loading => _loading;

  double get usdtRate => _usdtRate;
  double get trxRate  => _trxRate;

  // Backward-compat (7D)
  List<double> get trxHistory  => _trxHistory7;
  List<double> get usdtHistory => _usdtHistory7;

  // Explicit ranges
  List<double> get trxHistory24h  => _trxHistory24h;
  List<double> get trxHistory7    => _trxHistory7;
  List<double> get trxHistory30   => _trxHistory30;
  List<double> get trxHistory365  => _trxHistory365;

  List<double> get usdtHistory24h  => _usdtHistory24h;
  List<double> get usdtHistory7    => _usdtHistory7;
  List<double> get usdtHistory30   => _usdtHistory30;
  List<double> get usdtHistory365  => _usdtHistory365;

  Stream<double> get trxPriceStream  => _trxPriceController.stream;
  Stream<double> get usdtPriceStream => _usdtPriceController.stream;

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
    _trxPriceController.close();
    _usdtPriceController.close();
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
      _trxPriceController.add(_trxRate);
      _usdtPriceController.add(_usdtRate);
      notifyListeners();
    }
  }

  // ---- Rates ----
  Future<void> _fetchRates() async {
    try {
      final trxUsdtF  = _fetchTrxUsdtMulti();
      final usdtFiatF = _fetchUsdtToFiatMulti(_fiat);

      final results = await Future.wait<double?>([trxUsdtF, usdtFiatF]);

      final trxUsdt    = results[0];
      final usdtToFiat = results[1];

      bool gotAny = false;

      if (usdtToFiat != null && usdtToFiat > 0) {
        _prevUsdtRate = _usdtRate;
        _usdtRate = usdtToFiat;
        gotAny = true;
      }

      if (trxUsdt != null && trxUsdt > 0 && (_usdtRate > 0 || _prevUsdtRate > 0)) {
        final fx = (_usdtRate > 0) ? _usdtRate : _prevUsdtRate;
        _prevTrxRate = _trxRate;
        _trxRate = trxUsdt * fx;
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
    if (_usdtRate <= 0 && _prevUsdtRate > 0) _usdtRate = _prevUsdtRate;
    if (_trxRate  <= 0 && _prevTrxRate  > 0) _trxRate  = _prevTrxRate;
  }

  /* =========================
   *   MULTI-EXCHANGE HELPERS
   * ========================= */

  // --- TRX/USDT spot (double?) ---
  Future<double?> _fetchTrxUsdtMulti() async {
    return await _tryFirstNonNull<double?>([
      _fetchTrxUsdtFromBinance, // https://api.binance.com/api/v3/ticker/price?symbol=TRXUSDT
      _fetchTrxUsdtFromOKX,     // https://www.okx.com/api/v5/market/ticker?instId=TRX-USDT
      _fetchTrxUsdtFromKuCoin,  // https://api.kucoin.com/api/v1/market/orderbook/level1?symbol=TRX-USDT
      _fetchTrxUsdtFromBybit,   // https://api.bybit.com/v5/market/tickers?category=spot&symbol=TRXUSDT
      _fetchTrxUsdtFromKraken,  // https://api.kraken.com/0/public/Ticker?pair=TRXUSDT
    ]);
  }

  Future<double?> _fetchTrxUsdtFromBinance() async {
    try {
      final url = Uri.parse('https://api.binance.com/api/v3/ticker/price?symbol=TRXUSDT');
      final r = await http.get(url).timeout(httpTimeout);
      if (r.statusCode == 200) {
        final m = jsonDecode(r.body) as Map<String, dynamic>;
        final p = (m['price'] as String?) ?? '';
        return double.tryParse(p);
      }
    } catch (_) {}
    return null;
  }

  Future<double?> _fetchTrxUsdtFromOKX() async {
    try {
      final url = Uri.parse('https://www.okx.com/api/v5/market/ticker?instId=TRX-USDT');
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

  Future<double?> _fetchTrxUsdtFromKuCoin() async {
    try {
      final url = Uri.parse('https://api.kucoin.com/api/v1/market/orderbook/level1?symbol=TRX-USDT');
      final r = await http.get(url).timeout(httpTimeout);
      if (r.statusCode == 200) {
        final m = jsonDecode(r.body) as Map<String, dynamic>;
        final p = (m['data']?['price'] as String?) ?? '';
        return double.tryParse(p);
      }
    } catch (_) {}
    return null;
  }

  Future<double?> _fetchTrxUsdtFromBybit() async {
    try {
      final url = Uri.parse('https://api.bybit.com/v5/market/tickers?category=spot&symbol=TRXUSDT');
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

  Future<double?> _fetchTrxUsdtFromKraken() async {
    try {
      final url = Uri.parse('https://api.kraken.com/0/public/Ticker?pair=TRXUSDT');
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

  // --- USDT -> FIAT spot (double?) ---
  Future<double?> _fetchUsdtToFiatMulti(String fiat) async {
    // 1) Coinbase direct USDT->FIAT
    final cb = await _fetchUsdtToFiatFromCoinbase(fiat);
    if (cb != null && cb > 0) return cb;

    // 2) If FIAT==USD, try direct USDT/USD from CEXs (OKX/Kraken/Bitstamp)
    if (fiat.toLowerCase() == 'usd') {
      final okx = await _fetchUsdtUsdFromOKX();
      if (okx != null && okx > 0) return okx;
      final krk = await _fetchUsdtUsdFromKraken();
      if (krk != null && krk > 0) return krk;
      final bst = await _fetchUsdtUsdFromBitstamp();
      if (bst != null && bst > 0) return bst;
      // fall back to peg
      return 1.0;
    }

    final usdToFiat = await _fetchUsdToFiatSpot(fiat);


    // 4) Last resort: treat USDT≈USD and just convert USD→FIAT
    if (usdToFiat != null && usdToFiat > 0) return usdToFiat;
    return null;
  }

  Future<double?> _fetchUsdtToFiatFromCoinbase(String fiat) async {
    try {
      final url = Uri.parse('https://api.coinbase.com/v2/exchange-rates?currency=USDT');
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

  Future<double?> _fetchUsdtUsdFromOKX() async {
    try {
      final url = Uri.parse('https://www.okx.com/api/v5/market/ticker?instId=USDT-USD');
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

  Future<double?> _fetchUsdtUsdFromKraken() async {
    try {
      final url = Uri.parse('https://api.kraken.com/0/public/Ticker?pair=USDTUSD');
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

  Future<double?> _fetchUsdtUsdFromBitstamp() async {
    try {
      // https://www.bitstamp.net/api/v2/ticker/usdtusd/
      final url = Uri.parse('https://www.bitstamp.net/api/v2/ticker/usdtusd/');
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

      // USDT series (proxy from USD->FIAT)
      final usdt24hF = _buildUsdt24hSeries(expectedLen: 24); // flat around current rate
      final usdt7F   = _fetchUsdToFiatSeries(f7, now, _fiat, expectedLen: 7);
      final usdt30F  = _fetchUsdToFiatSeries(f30, now, _fiat, expectedLen: 30);
      final usdt365F = _fetchUsdToFiatSeries(f365, now, _fiat, expectedLen: 365);

      // TRX series in USDT, then multiplied by USDT->FIAT (current/prev)
      final trx24F  = _fetchTrxIntradayUsdt(hours: 24);
      final trx7F   = _fetchTrxClosesUsdt(days: 7);
      final trx30F  = _fetchTrxClosesUsdt(days: 30);
      final trx365F = _fetchTrxClosesUsdt(days: 365);

      final results = await Future.wait([
        usdt24hF, usdt7F, usdt30F, usdt365F,
        trx24F,   trx7F,  trx30F,  trx365F,
      ]);

      final usdt24  = (results[0] );
      final usdt7   = (results[1] );
      final usdt30  = (results[2] );
      final usdt365 = (results[3]);

      final trx24u  = (results[4]);
      final trx7u   = (results[5]);
      final trx30u  = (results[6]);
      final trx365u = (results[7]);

      final fx = (_usdtRate > 0) ? _usdtRate : (_prevUsdtRate > 0 ? _prevUsdtRate : 1.0);

      _usdtHistory24h = usdt24;
      _usdtHistory7   = usdt7;
      _usdtHistory30  = usdt30;
      _usdtHistory365 = usdt365;

      _trxHistory24h  = trx24u.map((c) => c * fx).toList();
      _trxHistory7    = trx7u.map((c) => c * fx).toList();
      _trxHistory30   = trx30u.map((c) => c * fx).toList();
      _trxHistory365  = trx365u.map((c) => c * fx).toList();

      notifyListeners();
    } on TimeoutException catch (e) {
      debugPrint("History timeout: $e");
    } catch (e) {
      debugPrint("Failed to fetch history: $e");
    }
  }

  // 24H TRX: 1h candles (24 points) with fallbacks
  Future<List<double>> _fetchTrxIntradayUsdt({required int hours}) async {
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

    // Fallback: derive TRX/USDT from spot or use a safe default
    double trxUsdt = 0;
    final usdt = _usdtRate > 0 ? _usdtRate : (_prevUsdtRate > 0 ? _prevUsdtRate : 1.0);
    if (usdt > 0 && _trxRate > 0) trxUsdt = _trxRate / usdt;
    final base = trxUsdt > 0 ? trxUsdt : 0.12;
    return List<double>.filled(hours, base);
  }

  // 7D/30D/365D TRX: daily closes with fallbacks
  Future<List<double>> _fetchTrxClosesUsdt({required int days}) async {
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

    double trxUsdt = 0;
    final usdt = _usdtRate > 0 ? _usdtRate : (_prevUsdtRate > 0 ? _prevUsdtRate : 1.0);
    if (usdt > 0 && _trxRate > 0) trxUsdt = _trxRate / usdt;
    final base = trxUsdt > 0 ? trxUsdt : 0.12;
    return List<double>.filled(days, base);
  }

  // ---- Exchange-specific candles ----

  // Binance klines: interval e.g., 1h or 1d
  Future<List<double>?> _binanceKlines(String interval, int limit) async {
    try {
      final url = Uri.parse('https://api.binance.com/api/v3/klines?symbol=TRXUSDT&interval=$interval&limit=$limit');
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
      final url = Uri.parse('https://www.okx.com/api/v5/market/candles?instId=TRX-USDT&bar=$bar&limit=$limit');
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
      final url = Uri.parse('https://api.kucoin.com/api/v1/market/candles?type=$type&symbol=TRX-USDT');
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
        'https://api.bybit.com/v5/market/kline?category=spot&symbol=TRXUSDT&interval=$interval&limit=$limit',
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
        'https://api.kraken.com/0/public/OHLC?pair=TRXUSDT&interval=$intervalMinutes',
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

  // USD->FIAT series (proxy for USDT) via Frankfurter; normalized to expectedLen points.
  Future<List<double>> _fetchUsdToFiatSeries(
      DateTime from,
      DateTime to,
      String fiat, {
        required int expectedLen,
      }) async {
    // If fiat is USD, USDT≈1 => flat
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
    final base = _usdtRate > 0 ? _usdtRate : (_prevUsdtRate > 0 ? _prevUsdtRate : 1.0);
    return List<double>.filled(expectedLen, base);
  }

  // USDT 24H proxy: flat line at current rate (no reliable hourly USD->FIAT)
  Future<List<double>> _buildUsdt24hSeries({required int expectedLen}) async {
    final base = _usdtRate > 0 ? _usdtRate : (_prevUsdtRate > 0 ? _prevUsdtRate : 1.0);
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
  double trxToFiat(double trxAmount) => trxAmount * _trxRate;
  double usdtToFiat(double usdtAmount) => usdtAmount * _usdtRate;
  double fiatToUsdt(double fiatAmount) => (_usdtRate != 0) ? fiatAmount / _usdtRate : 0.0;
  double fiatToTrx(double fiatAmount)  => (_trxRate  != 0) ? fiatAmount / _trxRate  : 0.0;
  double trxToUsdt(double trxAmount)   => (_trxRate  != 0 && _usdtRate != 0) ? (trxAmount * _trxRate) / _usdtRate : 0.0;
  double usdtToTrx(double usdtAmount)  => (_trxRate  != 0 && _usdtRate != 0) ? (usdtAmount * _usdtRate) / _trxRate : 0.0;
}
