import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CoinGeckoService {
  /// Get the coin info for TRX (including image)
  static Future<String?> getTrxImage() async {
    try {
      final url = Uri.parse('https://api.coingecko.com/api/v3/coins/tron');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['image']['small']; // 32x32 px image
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching TRX image: $e");
      return null;
    }
  }

  /// Get the coin info for USDT (including image)
  static Future<String?> getUsdtImage() async {
    try {
      final url = Uri.parse('https://api.coingecko.com/api/v3/coins/tether');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['image']['small']; // 32x32 px image
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching USDT image: $e");
      return null;
    }
  }
}
