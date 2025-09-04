import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// CoinGecko-free provider
/// - TRX rates & history via Binance (TRX/USDT)
/// - USDT->FIAT via Coinbase spot
/// - USD->FIAT (proxy for USDT history daily) via Frankfurter
/// - 24H intraday:
///     * TRX: Binance 1h candles (24 points)
///     * USDT: proxy ~ flat (24 points at current USDT->FIAT)
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
      final trxUsdtF  = _fetchTrxUsdtFromBinance();
      final usdtFiatF = _fetchUsdtToFiatFromCoinbase(_fiat);

      final results = await Future.wait<double?>([trxUsdtF, usdtFiatF]);

      final trxUsdt   = results[0];
      final usdtToFiat= results[1];

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

  Future<double?> _fetchTrxUsdtFromBinance() async {
    final url = Uri.parse('https://api.binance.com/api/v3/ticker/price?symbol=TRXUSDT');
    final r = await http.get(url).timeout(httpTimeout);
    if (r.statusCode == 200) {
      final m = jsonDecode(r.body) as Map<String, dynamic>;
      final p = (m['price'] as String?) ?? '';
      return double.tryParse(p);
    }
    return null;
  }

  Future<double?> _fetchUsdtToFiatFromCoinbase(String fiat) async {
    final url = Uri.parse('https://api.coinbase.com/v2/exchange-rates?currency=USDT');
    final r = await http.get(url).timeout(httpTimeout);
    if (r.statusCode == 200) {
      final m = jsonDecode(r.body) as Map<String, dynamic>;
      final rates = (m['data']?['rates'] as Map?)?.cast<String, dynamic>();
      final val = rates?[fiat.toUpperCase()];
      if (val is String) return double.tryParse(val);
      if (val is num) return val.toDouble();
    }
    if (fiat.toLowerCase() == 'usd') return 1.0; // USDT≈USD fallback
    return null;
  }

  // ---- Histories (24H / 7D / 30D / 365D) ----
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

      final usdt24  = (results[0] as List<double>);
      final usdt7   = (results[1] as List<double>);
      final usdt30  = (results[2] as List<double>);
      final usdt365 = (results[3] as List<double>);

      final trx24u  = (results[4] as List<double>);
      final trx7u   = (results[5] as List<double>);
      final trx30u  = (results[6] as List<double>);
      final trx365u = (results[7] as List<double>);

      // Convert TRX(USDT) -> FIAT using latest/usual rate
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

  // --- Helpers for histories ---

  // 24H TRX: 1h candles (24 points)
  Future<List<double>> _fetchTrxIntradayUsdt({required int hours}) async {
    try {
      final url = Uri.parse(
        'https://api.binance.com/api/v3/klines?symbol=TRXUSDT&interval=1h&limit=$hours',
      );
      final res = await http.get(url).timeout(httpTimeout);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        final closes = list
            .map((e) => (e is List && e.length > 4) ? e[4] : null)
            .map((v) => (v is String) ? double.tryParse(v) : (v as num?)?.toDouble())
            .whereType<double>()
            .toList();
        return _normalizeSeries(closes, hours);
      }
    } catch (e) {
      debugPrint("Binance intraday error: $e");
    }

    // Fallback: derive TRX/USDT from current TRX->FIAT and USDT->FIAT, or a safe default
    double trxUsdt = 0;
    final usdt = _usdtRate > 0 ? _usdtRate : (_prevUsdtRate > 0 ? _prevUsdtRate : 1.0);
    if (usdt > 0 && _trxRate > 0) trxUsdt = _trxRate / usdt;
    final base = trxUsdt > 0 ? trxUsdt : 0.12;
    return List<double>.filled(hours, base);
  }

  // 7D/30D/365D TRX: daily closes (N points)
  Future<List<double>> _fetchTrxClosesUsdt({required int days}) async {
    try {
      final url = Uri.parse(
        'https://api.binance.com/api/v3/klines?symbol=TRXUSDT&interval=1d&limit=$days',
      );
      final res = await http.get(url).timeout(httpTimeout);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        final closesUsdt = list
            .map((e) => (e is List && e.length > 4) ? e[4] : null)
            .map((v) => (v is String) ? double.tryParse(v) : (v as num?)?.toDouble())
            .whereType<double>()
            .toList();
        return _normalizeSeries(closesUsdt, days);
      }
    } catch (e) {
      debugPrint("Binance klines error: $e");
    }

    double trxUsdt = 0;
    final usdt = _usdtRate > 0 ? _usdtRate : (_prevUsdtRate > 0 ? _prevUsdtRate : 1.0);
    if (usdt > 0 && _trxRate > 0) trxUsdt = _trxRate / usdt;
    final base = trxUsdt > 0 ? trxUsdt : 0.12;
    return List<double>.filled(days, base);
  }

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

  // USDT 24H proxy: we don't have reliable hourly USD->FIAT; use a flat line at current rate.
  Future<List<double>> _buildUsdt24hSeries({required int expectedLen}) async {
    final base = _usdtRate > 0 ? _usdtRate : (_prevUsdtRate > 0 ? _prevUsdtRate : 1.0);
    return List<double>.filled(expectedLen, base);
  }

  // Ensure series has exactly expectedLen points.
  // If too long -> keep the most recent expectedLen.
  // If too short -> pad at the start with the first value.
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
