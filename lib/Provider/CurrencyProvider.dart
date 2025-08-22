import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CurrencyProvider extends ChangeNotifier {
  /// Default base currency
  String _fiat = "php";

  /// USDT → fiat rate
  double _usdtRate = 0.0;

  /// Loading state for fetching rate
  bool _loading = true;

  /// Last fetch timestamp (optional)
  DateTime? _lastFetch;

  String get fiat => _fiat;
  double get usdtRate => _usdtRate;
  bool get loading => _loading;

  CurrencyProvider() {
    fetchRate();
  }

  /// Set fiat currency dynamically
  void setFiat(String newFiat) {
    final lower = newFiat.toLowerCase();
    if (lower != _fiat) {
      _fiat = lower;
      fetchRate();
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
        _lastFetch = DateTime.now();
      } else {
        debugPrint(
          "Failed to fetch rate: HTTP ${response.statusCode}",
        );
        _usdtRate = 0.0;
      }
    } catch (e) {
      debugPrint("Failed to fetch USDT → $_fiat rate: $e");
      _usdtRate = 0.0;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Convert USDT to selected fiat
  double convert(double usdt) => usdt * _usdtRate;

  /// Optional: Convert fiat → USDT
  double convertToUsdt(double amount) =>
      _usdtRate != 0 ? amount / _usdtRate : 0.0;
}
