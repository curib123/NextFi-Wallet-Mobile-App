import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:next_fi/Model/ChainModel.dart';

class ChainProvider with ChangeNotifier {
  final List<ChainData> _chains = [];
  bool _isLoading = false;

  List<ChainData> get chains => _chains;
  bool get isLoading => _isLoading;

  // Full EVM chain list (CoinGecko IDs)
  final List<String> evmIds = [
    'ethereum', 'binancecoin', 'polygon-pos', 'avalanche-2',
    'fantom', 'arbitrum-one', 'optimism', 'crypto-com-chain',
    'gnosis', 'celo', 'moonbeam', 'moonriver', 'metis-token',
    'harmony', 'okb', 'base', 'kava', 'telos', 'coredaoorg',
    // add all other EVM-compatible chain IDs from mapping
  ];

  Future<void> fetchChains() async {
    _isLoading = true;
    notifyListeners();
    _chains.clear();

    try {
      // Split into batches of 250
      final batches = <List<String>>[];
      for (var i = 0; i < evmIds.length; i += 250) {
        batches.add(evmIds.sublist(i, i + 250 > evmIds.length ? evmIds.length : i + 250));
      }

      for (var batch in batches) {
        final idsParam = batch.join(',');
        final response = await http.get(
          Uri.parse(
            'https://api.coingecko.com/api/v3/coins/markets'
                '?vs_currency=usd&ids=$idsParam',
          ),
        );

        if (response.statusCode == 200) {
          final List data = json.decode(response.body);
          for (var coin in data) {
            _chains.add(
              ChainData(
                title: '${coin["name"]} (USDT)',
                logoUrl: coin["image"],
                iconColor: _getIconColor(coin["id"]),
                amount: (coin["current_price"] as num).toDouble(),
              ),
            );
          }
        } else {
          throw Exception('Failed to fetch batch');
        }
      }
    } catch (e) {
      debugPrint('Error fetching chains: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Color _getIconColor(String id) {
    switch (id) {
      case 'ethereum': return Colors.blue;
      case 'binancecoin': return Colors.green;
      case 'polygon-pos': return Colors.purple;
      case 'avalanche-2': return Colors.red;
      default: return Colors.grey;
    }
  }
}
