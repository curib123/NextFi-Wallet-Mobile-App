import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// CoinGecko-free rates using Binance (TRX/USDT), Coinbase (USDT->fiat),
/// and Frankfurter (USD->fiat history as proxy for USDT history)
class CurrencyProvider extends ChangeNotifier {
  String _fiat = "usd";

  double _usdtRate = 0;   // current USDT->fiat
  double _trxRate  = 0;   // current TRX->fiat

  double _prevUsdtRate = 0;
  double _prevTrxRate  = 0;

  List<double> _trxHistory = [];
  List<double> _usdtHistory = [];

  bool _loading = true;
  Timer? _pollingTimer;

  final _trxPriceController  = StreamController<double>.broadcast();
  final _usdtPriceController = StreamController<double>.broadcast();

  String get fiat => _fiat;
  double get usdtRate => _usdtRate;
  double get trxRate  => _trxRate;
  bool get loading => _loading;

  List<double> get trxHistory => _trxHistory;
  List<double> get usdtHistory => _usdtHistory;

  Stream<double> get trxPriceStream  => _trxPriceController.stream;
  Stream<double> get usdtPriceStream => _usdtPriceController.stream;

  CurrencyProvider() {
    fetchRates();
    fetchHistory();
    _startPolling();
  }

  void setFiat(String newFiat) {
    final lower = newFiat.toLowerCase();
    if (lower != _fiat) {
      _fiat = lower;
      fetchRates();
      fetchHistory();
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      fetchRates();
      fetchHistory();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _trxPriceController.close();
    _usdtPriceController.close();
    super.dispose();
  }

  Future<void> fetchRates() async {
    _loading = true;
    notifyListeners();

    try {
      // 1) TRX/USDT from Binance
      final trxUsdt = await _fetchTrxUsdtFromBinance();

      // 2) USDT -> selected fiat from Coinbase (many fiats supported)
      final usdtToFiat = await _fetchUsdtToFiatFromCoinbase(_fiat);

      bool gotAny = false;

      if (usdtToFiat != null && usdtToFiat > 0) {
        _prevUsdtRate = _usdtRate;
        _usdtRate = usdtToFiat;
        gotAny = true;
      }

      if (trxUsdt != null && trxUsdt > 0 && (_usdtRate > 0 || _prevUsdtRate > 0)) {
        final fx = (_usdtRate > 0) ? _usdtRate : _prevUsdtRate; // multiply by USDT->fiat
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
    } finally {
      _loading = false;
      _trxPriceController.add(_trxRate);
      _usdtPriceController.add(_usdtRate);
      notifyListeners();
    }
  }

  void _applyPreviousIfCurrentInvalid() {
    if (_usdtRate <= 0 && _prevUsdtRate > 0) _usdtRate = _prevUsdtRate;
    if (_trxRate  <= 0 && _prevTrxRate  > 0) _trxRate  = _prevTrxRate;
  }

  Future<double?> _fetchTrxUsdtFromBinance() async {
    final url = Uri.parse('https://api.binance.com/api/v3/ticker/price?symbol=TRXUSDT');
    final r = await http.get(url).timeout(const Duration(seconds: 10));
    if (r.statusCode == 200) {
      final m = jsonDecode(r.body) as Map<String, dynamic>;
      final p = (m['price'] as String?) ?? '';
      return double.tryParse(p);
    }
    return null;
  }

  Future<double?> _fetchUsdtToFiatFromCoinbase(String fiat) async {
    // Coinbase returns a big map of rates for a base currency.
    // We want 1 USDT -> X FIAT (e.g., PHP, USD, EUR)
    final url = Uri.parse('https://api.coinbase.com/v2/exchange-rates?currency=USDT');
    final r = await http.get(url).timeout(const Duration(seconds: 10));
    if (r.statusCode == 200) {
      final m = jsonDecode(r.body) as Map<String, dynamic>;
      final rates = (m['data']?['rates'] as Map?)?.cast<String, dynamic>();
      final val = rates?[fiat.toUpperCase()];
      if (val is String) return double.tryParse(val);
      if (val is num) return val.toDouble();
    }
    // Fallback: treat USDT≈1 USD when fiat is USD
    if (fiat.toLowerCase() == 'usd') return 1.0;
    return null;
  }

  Future<void> fetchHistory() async {
    try {
      // A) USDT history ≈ USD->FIAT history over the last 7 days
      final now = DateTime.now();
      final from = now.subtract(const Duration(days: 7));
      final ymd = (DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

      List<double> usdToFiatSeries = [];
      if (_fiat.toLowerCase() == 'usd') {
        // If fiat is USD, USDT≈1 => series of 1.0
        usdToFiatSeries = List<double>.filled(7, 1.0);
      } else {
        final fUrl = Uri.parse(
          'https://api.frankfurter.app/${ymd(from)}..${ymd(now)}?from=USD&to=${_fiat.toUpperCase()}',
        );
        final r = await http.get(fUrl).timeout(const Duration(seconds: 10));
        if (r.statusCode == 200) {
          final m = jsonDecode(r.body) as Map<String, dynamic>;
          final rates = (m['rates'] as Map?)?.cast<String, dynamic>() ?? {};
          final keys = rates.keys.toList()..sort(); // chronological by date string
          usdToFiatSeries = keys.map((k) {
            final v = (rates[k] as Map?)?[_fiat.toUpperCase()];
            if (v is num) return v.toDouble();
            return 1.0;
          }).toList();
          // Ensure exactly 7 points (pad/trim)
          if (usdToFiatSeries.length > 7) {
            usdToFiatSeries = usdToFiatSeries.sublist(usdToFiatSeries.length - 7);
          } else if (usdToFiatSeries.length < 7 && usdToFiatSeries.isNotEmpty) {
            usdToFiatSeries = List<double>.filled(7 - usdToFiatSeries.length, usdToFiatSeries.first)
              ..addAll(usdToFiatSeries);
          }
        } else {
          usdToFiatSeries = List<double>.filled(7, _usdtRate > 0 ? _usdtRate : 1.0);
        }
      }
      _usdtHistory = usdToFiatSeries;

      // B) TRX history: Binance daily closes for 7 days * latest USDT->FIAT
      final trxUrl = Uri.parse(
          'https://api.binance.com/api/v3/klines?symbol=TRXUSDT&interval=1d&limit=7');
      final trxRes = await http.get(trxUrl).timeout(const Duration(seconds: 10));
      if (trxRes.statusCode == 200) {
        final list = jsonDecode(trxRes.body) as List<dynamic>;
        final closesUsdt = list
            .map((e) => (e is List && e.length > 4) ? e[4] : null) // index 4 = close
            .map((v) => (v is String) ? double.tryParse(v) : (v as num?)?.toDouble())
            .whereType<double>()
            .toList();
        final usdtFx = (_usdtRate > 0) ? _usdtRate : (_prevUsdtRate > 0 ? _prevUsdtRate : 1.0);
        _trxHistory = closesUsdt.map((c) => c * usdtFx).toList();
      }

      notifyListeners();
    } on TimeoutException catch (e) {
      debugPrint("History timeout: $e");
    } catch (e) {
      debugPrint("Failed to fetch history: $e");
    }
  }

  // Converters
  double trxToFiat(double trxAmount) => trxAmount * _trxRate;
  double usdtToFiat(double usdtAmount) => usdtAmount * _usdtRate;
  double fiatToUsdt(double fiatAmount) => (_usdtRate != 0) ? fiatAmount / _usdtRate : 0.0;
  double fiatToTrx(double fiatAmount)  => (_trxRate  != 0) ? fiatAmount / _trxRate  : 0.0;
  double trxToUsdt(double trxAmount)   => (_trxRate  != 0 && _usdtRate != 0) ? (trxAmount * _trxRate) / _usdtRate : 0.0;
  double usdtToTrx(double usdtAmount)  => (_trxRate  != 0 && _usdtRate != 0) ? (usdtAmount * _usdtRate) / _trxRate : 0.0;
}
