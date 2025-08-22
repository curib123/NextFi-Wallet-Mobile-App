import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CurrencyProvider extends ChangeNotifier {
  /// Default base fiat
  String _fiat = "usd"; // ✅ Default changed to USD

  /// USDT → fiat rate
  double _usdtRate = 0.0;

  /// XLM → fiat rate
  double _xlmRate = 0.0;

  /// Loading state
  bool _loading = true;

  /// Last fetch timestamp
  DateTime? _lastFetch;

  String get fiat => _fiat;
  double get usdtRate => _usdtRate;
  double get xlmRate => _xlmRate;
  bool get loading => _loading;

  CurrencyProvider() {
    fetchRates();
  }

  /// Set fiat currency dynamically
  void setFiat(String newFiat) {
    final lower = newFiat.toLowerCase();
    if (lower != _fiat) {
      _fiat = lower;
      fetchRates();
    }
  }

  /// Fetch USDT and XLM rates from CoinGecko
  Future<void> fetchRates() async {
    _loading = true;
    notifyListeners();

    try {
      final url = Uri.parse(
        'https://api.coingecko.com/api/v3/simple/price?ids=tether,stellar&vs_currencies=$_fiat',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _usdtRate = (data['tether'][_fiat] as num).toDouble();
        _xlmRate = (data['stellar'][_fiat] as num).toDouble();
        _lastFetch = DateTime.now();
      } else {
        debugPrint("Failed to fetch rates: HTTP ${response.statusCode}");
        _usdtRate = 0.0;
        _xlmRate = 0.0;
      }
    } catch (e) {
      debugPrint("Failed to fetch rates: $e");
      _usdtRate = 0.0;
      _xlmRate = 0.0;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Convert USDT → fiat
  double convertUsdt(double usdt) => usdt * _usdtRate;

  /// Convert XLM → fiat
  double convertXlm(double xlm) => xlm * _xlmRate;

  /// Convert fiat → USDT
  double convertToUsdt(double amount) => _usdtRate != 0 ? amount / _usdtRate : 0.0;

  /// Convert fiat → XLM
  double convertToXlm(double amount) => _xlmRate != 0 ? amount / _xlmRate : 0.0;
}
