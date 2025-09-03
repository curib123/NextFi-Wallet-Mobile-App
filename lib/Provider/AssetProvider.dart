// lib/Provider/AssetProvider.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:next_fi/Model/asset_model.dart';

class AssetProvider with ChangeNotifier {
  AssetProvider({
    String vsCurrency = 'usd',
    Duration requestTimeout = const Duration(seconds: 6),
  })  : _vsCurrency = vsCurrency.toLowerCase(),
        _requestTimeout = requestTimeout;

  static const String _base = 'https://api.coingecko.com/api/v3';
  final String _vsCurrency;
  final Duration _requestTimeout;

  // No balances here.
  final List<AssetModel> _assets = <AssetModel>[
    AssetModel(id: "tron",         name: "Tron",           symbol: "TRX",  coingeckoId: "tron"),
    AssetModel(id: "tether_trc20", name: "Tether (TRC20)", symbol: "USDT", coingeckoId: "tether"),
  ];

  Map<String, String> _logos = <String, String>{};
  bool _loading = true;

  Timer? _timer;
  bool _isDisposed = false;
  bool _inFlight = false;

  List<AssetModel> get assets => _assets;
  Map<String, String> get logos => _logos;
  bool get loading => _loading;

  @override
  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    super.dispose();
  }

  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  Future<void> fetchLogosAndPriceChange() async {
    if (_inFlight) return;
    _inFlight = true;
    _loading = true;
    _safeNotify();

    try {
      final ids = _assets.map((a) => a.coingeckoId.trim()).where((s) => s.isNotEmpty).join(',');
      if (ids.isEmpty) {
        _loading = false; _inFlight = false; _safeNotify(); return;
      }

      final uri = Uri.parse(
        '$_base/coins/markets?vs_currency=$_vsCurrency&ids=$ids&price_change_percentage=24h',
      );
      final resp = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(_requestTimeout);

      if (resp.statusCode == 200) {
        final List<dynamic> list = json.decode(resp.body) as List<dynamic>;
        final Map<String, String> newLogos = <String, String>{};

        for (final item in list) {
          if (item is! Map<String, dynamic>) continue;
          final String id = (item['id'] ?? '').toString();
          final String image = (item['image'] ?? '').toString();
          final double pct =
              _toDouble(item['price_change_percentage_24h_in_currency']) ??
                  _toDouble(item['price_change_percentage_24h']) ??
                  0.0;

          final idx = _assets.indexWhere((a) => a.coingeckoId == id);
          if (idx != -1) {
            _assets[idx].priceChangePercent24h = pct;
            newLogos[_assets[idx].id] = image; // key by our id
          }
        }
        _logos = newLogos;
      } else {
        debugPrint('CoinGecko error ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      debugPrint('fetchLogosAndPriceChange error: $e');
    } finally {
      _loading = false;
      _inFlight = false;
      _safeNotify();
    }
  }

  void startRealtimeUpdates({Duration interval = const Duration(seconds: 30)}) {
    _timer?.cancel();
    unawaited(fetchLogosAndPriceChange());
    _timer = Timer.periodic(interval, (_) {
      if (!_isDisposed) {
        unawaited(fetchLogosAndPriceChange());
      }
    });
  }

  void stopRealtimeUpdates() {
    _timer?.cancel();
    _timer = null;
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}

void unawaited(Future<void> f) {}
