import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CurrencyProvider extends ChangeNotifier {
  /// Default base fiat
  String _fiat = "usd";

  /// Latest rates
  double _usdtRate = 0.0;
  double _trxRate = 0.0;

  /// Price history (for charts)
  List<double> _trxHistory = [];
  List<double> _usdtHistory = [];

  /// Loading state
  bool _loading = true;

  Timer? _pollingTimer;

  /// Streams for realtime updates
  final StreamController<double> _trxPriceController = StreamController.broadcast();
  final StreamController<double> _usdtPriceController = StreamController.broadcast();

  String get fiat => _fiat;
  double get usdtRate => _usdtRate;
  double get trxRate => _trxRate;
  bool get loading => _loading;

  List<double> get trxHistory => _trxHistory;
  List<double> get usdtHistory => _usdtHistory;

  Stream<double> get trxPriceStream => _trxPriceController.stream;
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

  /// Fetch latest rates
  Future<void> fetchRates() async {
    _loading = true;
    notifyListeners();

    try {
      final url = Uri.parse(
        'https://api.coingecko.com/api/v3/simple/price?ids=tether,tron&vs_currencies=$_fiat',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _usdtRate = (data['tether'][_fiat] as num).toDouble();
        _trxRate = (data['tron'][_fiat] as num).toDouble();

        // push latest prices to streams
        _trxPriceController.add(_trxRate);
        _usdtPriceController.add(_usdtRate);
      } else {
        _usdtRate = 0.0;
        _trxRate = 0.0;
      }
    } catch (e) {
      _usdtRate = 0.0;
      _trxRate = 0.0;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Fetch 7-day history for charts
  Future<void> fetchHistory() async {
    try {
      // TRX history
      final trxUrl = Uri.parse(
          'https://api.coingecko.com/api/v3/coins/tron/market_chart?vs_currency=$_fiat&days=7');
      final trxResponse = await http.get(trxUrl);
      if (trxResponse.statusCode == 200) {
        final data = jsonDecode(trxResponse.body);
        _trxHistory = (data['prices'] as List)
            .map((e) => (e[1] as num).toDouble())
            .toList();
      }

      // USDT history
      final usdtUrl = Uri.parse(
          'https://api.coingecko.com/api/v3/coins/tether/market_chart?vs_currency=$_fiat&days=7');
      final usdtResponse = await http.get(usdtUrl);
      if (usdtResponse.statusCode == 200) {
        final data = jsonDecode(usdtResponse.body);
        _usdtHistory = (data['prices'] as List)
            .map((e) => (e[1] as num).toDouble())
            .toList();
      }

      notifyListeners();
    } catch (e) {
      debugPrint("Failed to fetch history: $e");
    }
  }

  /// Convert TRX amount to selected fiat
  double trxToFiat(double trxAmount) => trxAmount * _trxRate;

  /// Convert USDT amount to selected fiat
  double usdtToFiat(double usdtAmount) => usdtAmount * _usdtRate;

  /// Convert fiat amount to USDT
  double fiatToUsdt(double fiatAmount) => _usdtRate != 0 ? fiatAmount / _usdtRate : 0.0;

  /// Convert fiat amount to TRX
  double fiatToTrx(double fiatAmount) => _trxRate != 0 ? fiatAmount / _trxRate : 0.0;

  /// Convert TRX amount to USDT
  double trxToUsdt(double trxAmount) => _trxRate != 0 ? (trxAmount * _trxRate) / _usdtRate : 0.0;

  /// Convert USDT amount to TRX
  double usdtToTrx(double usdtAmount) => _usdtRate != 0 ? (usdtAmount * _usdtRate) / _trxRate : 0.0;

}
