import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:next_fi/Model/asset_model.dart';

class AssetProvider with ChangeNotifier {
  final List<AssetModel> _assets = [
    AssetModel(
      id: "tron",
      name: "Tron",
      symbol: "TRX",
      balance: 1000,
      coingeckoId: "tron",
    ),
    AssetModel(
      id: "tether_trc20",
      name: "Tether (TRC20)",
      symbol: "USDT",
      balance: 10000,
      coingeckoId: "tether",
    ),
  ];

  Map<String, String> _logos = {};
  bool _loading = true;
  bool _isDisposed = false;

  List<AssetModel> get assets => _assets;
  Map<String, String> get logos => _logos;
  bool get loading => _loading;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void safeNotifyListeners() {
    if (!_isDisposed) notifyListeners();
  }

  /// Fetch logos for all assets
  Future<void> fetchLogos() async {
    _loading = true;
    safeNotifyListeners();

    try {
      final futures = _assets.map((asset) async {
        try {
          final url =
          Uri.parse("https://api.coingecko.com/api/v3/coins/${asset.coingeckoId}");
          final response = await http.get(url);

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final logoUrl = (data["image"]?["small"] ?? "") as String;
            return MapEntry(asset.id, logoUrl);
          }
        } catch (e) {
          debugPrint("Error fetching logo for ${asset.name}: $e");
        }
        return MapEntry(asset.id, "");
      }).toList();

      final results = await Future.wait(futures);
      _logos = Map.fromEntries(results);
    } catch (e) {
      debugPrint("Error fetching logos: $e");
    }

    _loading = false;
    safeNotifyListeners();
  }

  /// Fetch real-time 24h price change percent
  Future<void> fetchPriceChangePercent() async {
    try {
      final futures = _assets.map((asset) async {
        try {
          final url =
          Uri.parse("https://api.coingecko.com/api/v3/coins/${asset.coingeckoId}");
          final response = await http.get(url);

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final percentChange =
            (data["market_data"]?["price_change_percentage_24h"] ?? 0.0) as double;
            asset.priceChangePercent24h = percentChange;
          }
        } catch (e) {
          debugPrint("Error fetching price change for ${asset.name}: $e");
          asset.priceChangePercent24h = 0.0;
        }
      }).toList();

      await Future.wait(futures);
      safeNotifyListeners();
    } catch (e) {
      debugPrint("Error fetching price changes: $e");
    }
  }

  /// Start auto-updating price changes every interval
  void startRealtimeUpdates({Duration interval = const Duration(minutes: 5)}) {
    Future.doWhile(() async {
      await fetchPriceChangePercent();
      await Future.delayed(interval);
      return !_isDisposed;
    });
  }

  /// Update balance for a specific asset by id
  void updateBalance(String assetId, double amount) {
    final index = _assets.indexWhere((a) => a.id == assetId);
    if (index != -1) {
      _assets[index].balance += amount;
      safeNotifyListeners();
    }
  }

  /// Set balance for a specific asset by id
  void setBalance(String assetId, double amount) {
    final index = _assets.indexWhere((a) => a.id == assetId);
    if (index != -1) {
      _assets[index].balance = amount;
      safeNotifyListeners();
    }
  }
}
