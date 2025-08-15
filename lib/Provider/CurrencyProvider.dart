import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CurrencyProvider extends ChangeNotifier {
  // Default base currency
  String _fiat = "php";
  double _usdtRate = 0.0; // USDT → fiat
  bool _loading = true;

  String get fiat => _fiat;
  double get usdtRate => _usdtRate;
  bool get loading => _loading;

  /// Set fiat currency dynamically
  void setFiat(String newFiat) {
    if (newFiat.toLowerCase() != _fiat) {
      _fiat = newFiat.toLowerCase();
      fetchRate(); // Refresh rate
    }
  }

  /// Fetch USDT → Fiat rate from CoinGecko
  Future<void> fetchRate() async {
    _loading = true;
    notifyListeners();

    try {
      final url = Uri.parse(
        'https://api.coingecko.com/api/v3/simple/price?ids=tether&vs_currencies=$_fiat',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _usdtRate = (data['tether'][_fiat] as num).toDouble();
      }
    } catch (e) {
      debugPrint("Failed to fetch USDT → $_fiat rate: $e");
      _usdtRate = 0.0;
    }

    _loading = false;
    notifyListeners();
  }

  /// Convert USDT to selected fiat
  double convert(double usdt) => usdt * _usdtRate;
}
