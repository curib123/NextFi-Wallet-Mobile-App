// lib/Provider/AssetProvider.dart (XLM / USDC on Stellar)
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:next_fi/Model/asset_model.dart';
import 'package:next_fi/Provider/CurrencyProvider.dart';

class AssetProvider with ChangeNotifier {
  AssetProvider(this.currency)
      : _assets = [
    AssetModel(id: 'stellar', name: 'Stellar Lumens', symbol: 'XLM'),
    AssetModel(id: 'usdc_stellar', name: 'USD Coin (Stellar)', symbol: 'USDC'),
  ] {
    // Primary logo map (first-choice URLs). Kept as Map<String,String> to avoid breaking callers.
    // XLM uses Trust Wallet's Stellar logo. USDC uses common icon packs.
    _logos = const {
      // XLM (Stellar)
      'stellar': 'https://cdn.jsdelivr.net/gh/trustwallet/assets@master/blockchains/stellar/info/logo.png',
      'xlm': 'https://cdn.jsdelivr.net/gh/trustwallet/assets@master/blockchains/stellar/info/logo.png',
      'XLM': 'https://cdn.jsdelivr.net/gh/trustwallet/assets@master/blockchains/stellar/info/logo.png',

      // USDC (generic)
      'usdc_stellar': 'https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/128/color/usdc.png',
      'usdc': 'https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/128/color/usdc.png',
      'USDC': 'https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/128/color/usdc.png',
    };

    startRealtimeUpdates(); // idempotent
    _recompute();
  }

  final CurrencyProvider currency;

  final List<AssetModel> _assets;
  late Map<String, String> _logos;

  bool _disposed = false;
  bool _started = false;

  StreamSubscription<double>? _xlmSub, _usdcSub;
  VoidCallback? _currencyListener; // listens to CurrencyProvider.notifyListeners

  // Optional: public fallback candidates you can try in your Image.errorBuilder
  static const List<String> usdcLogoFallbacks = [
    'https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/128/color/usdc.png',
    'https://cdn.jsdelivr.net/gh/Cryptofonts/cryptoicons@master/128/usdc.png',
    // SVGs work if your widget supports them (e.g., flutter_svg)
    'https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/svg/color/usdc.svg',
  ];

  // Public getters
  List<AssetModel> get assets => _assets;
  Map<String, String> get logos => _logos;
  String get vsCurrency => currency.fiat;
  bool get loading => currency.loading;

  /// Returns the best-known logo URL for a given asset key.
  /// Accepts id or symbol (case-insensitive), with a few aliases.
  String logoFor(String key) {
    final k = key.trim();
    final aliases = <String>[
      k,
      k.toLowerCase(),
      k.toUpperCase(),
      // convenience aliases
      if (k.toLowerCase().contains('xlm') || k.toLowerCase().contains('stellar')) 'stellar',
      if (k.toLowerCase().contains('usdc') || k.toLowerCase().contains('usd coin')) 'usdc_stellar',
    ];
    for (final a in aliases) {
      final url = _logos[a];
      if (url != null && url.isNotEmpty) return url;
    }
    // safe default
    return _logos['stellar']!;
  }

  // ---- lifecycle -----------------------------------------------------------

  void startRealtimeUpdates() {
    if (_started) return;
    _started = true;

    // Stream-based updates (prices)
    _xlmSub = currency.xlmPriceStream.listen((_) {
      _recompute();
      _safeNotify();
    });
    _usdcSub = currency.usdcPriceStream.listen((_) {
      _recompute();
      _safeNotify();
    });

    // ChangeNotifier updates (history / fiat / loading flips)
    _currencyListener = () {
      _recompute();
      _safeNotify();
    };
    currency.addListener(_currencyListener!);
  }

  void stopRealtimeUpdates() {
    if (!_started) return;
    _started = false;

    _xlmSub?.cancel();
    _xlmSub = null;
    _usdcSub?.cancel();
    _usdcSub = null;

    if (_currencyListener != null) {
      currency.removeListener(_currencyListener!);
      _currencyListener = null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    stopRealtimeUpdates();
    super.dispose();
  }

  /// Switch fiat via centralized CurrencyProvider (no await; returns void)
  void setVsCurrency(String vs) {
    currency.setFiat(vs);
    _recompute(); // immediate best-effort
    _safeNotify(); // UI updates now; will update again when streams/listener fire
  }

  // ---- core ----------------------------------------------------------------

  void _recompute() {
    double _pctFromHistory(List<double> h, int days) {
      if (h.isEmpty || days <= 0) return 0.0;
      if (h.length <= days) {
        final first = h.first, last = h.last;
        return (first > 0) ? ((last / first) - 1) * 100.0 : 0.0;
      }
      final last = h.last, ref = h[h.length - 1 - days];
      return (ref > 0) ? ((last / ref) - 1) * 100.0 : 0.0;
    }

    final xlmH = currency.xlmHistory;
    final usdcH = currency.usdcHistory;

    final x24h = _pctFromHistory(xlmH, 1);
    final x7d = _pctFromHistory(xlmH, 7);
    final x30d = _pctFromHistory(xlmH, 30);
    final x1y = _pctFromHistory(xlmH, 365);

    final u24h = _pctFromHistory(usdcH, 1);
    final u7d = _pctFromHistory(usdcH, 7);
    final u30d = _pctFromHistory(usdcH, 30);
    final u1y = _pctFromHistory(usdcH, 365);

    for (final a in _assets) {
      if (a.symbol.toUpperCase() == 'XLM') {
        a
          ..priceChangePercent24h = x24h
          ..priceChangePercent7d = x7d
          ..priceChangePercent30d = x30d
          ..priceChangePercent1y = x1y;
      } else if (a.symbol.toUpperCase() == 'USDC') {
        a
          ..priceChangePercent24h = u24h
          ..priceChangePercent7d = u7d
          ..priceChangePercent30d = u30d
          ..priceChangePercent1y = u1y;
      }
    }
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }
}
