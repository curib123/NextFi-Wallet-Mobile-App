// lib/ViewModel/asset_vm.dart (XLM / USDC on Stellar)
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:next_fi/Model/asset_model.dart';
import 'package:next_fi/features/ViewModel/currency_vm.dart';

class AssetVM with ChangeNotifier {
  AssetVM(this.currency)
      : _assets = [
    AssetModel(id: 'stellar',      name: 'Stellar Lumens',     symbol: 'XLM'),
    AssetModel(id: 'usdc_stellar', name: 'USD Coin (Stellar)', symbol: 'USDC'),
  ] {
    _logos = const {
      // XLM (Stellar)
      'stellar': 'https://cdn.jsdelivr.net/gh/trustwallet/assets@master/blockchains/stellar/info/logo.png',
      'xlm':     'https://cdn.jsdelivr.net/gh/trustwallet/assets@master/blockchains/stellar/info/logo.png',
      'XLM':     'https://cdn.jsdelivr.net/gh/trustwallet/assets@master/blockchains/stellar/info/logo.png',
      // USDC (generic)
      'usdc_stellar': 'https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/128/color/usdc.png',
      'usdc':         'https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/128/color/usdc.png',
      'USDC':         'https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/128/color/usdc.png',
    };

    startRealtimeUpdates(); // idempotent
    _recompute();
  }

  final CurrencyVM currency;

  final List<AssetModel> _assets;
  late Map<String, String> _logos;

  bool _disposed = false;
  bool _started = false;

  StreamSubscription<double>? _xlmSub, _usdcSub;
  VoidCallback? _currencyListener; // listens to CurrencyProvider.notifyListeners

  // Keep last non-zero pct values to avoid flicker to 0 when data blips
  double _xlm24h = 0, _xlm7d = 0, _xlm30d = 0, _xlm1y = 0;
  double _usdc24h = 0, _usdc7d = 0, _usdc30d = 0, _usdc1y = 0;

  // Optional: public fallback candidates for logos
  static const List<String> usdcLogoFallbacks = [
    'https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/128/color/usdc.png',
    'https://cdn.jsdelivr.net/gh/Cryptofonts/cryptoicons@master/128/usdc.png',
    'https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/svg/color/usdc.svg',
  ];

  // Public getters
  List<AssetModel> get assets => _assets;
  Map<String, String> get logos => _logos;
  String get vsCurrency => currency.fiat;
  bool get loading => currency.loading;

  /// Returns the best-known logo URL for a given asset key.
  String logoFor(String key) {
    final k = key.trim();
    final aliases = <String>[
      k,
      k.toLowerCase(),
      k.toUpperCase(),
      if (k.toLowerCase().contains('xlm') || k.toLowerCase().contains('stellar')) 'stellar',
      if (k.toLowerCase().contains('usdc') || k.toLowerCase().contains('usd coin')) 'usdc_stellar',
    ];
    for (final a in aliases) {
      final url = _logos[a];
      if (url != null && url.isNotEmpty) return url;
    }
    return _logos['stellar']!;
  }

  // ---- lifecycle -----------------------------------------------------------
  void startRealtimeUpdates() {
    if (_started) return;
    _started = true;

    // Stream-based updates (prices)
    _xlmSub  = currency.xlmPriceStream.listen((_) { _recompute(); _safeNotify(); });
    _usdcSub = currency.usdcPriceStream.listen((_) { _recompute(); _safeNotify(); });

    // ChangeNotifier updates (history / fiat / loading flips)
    _currencyListener = () { _recompute(); _safeNotify(); };
    currency.addListener(_currencyListener!);
  }

  void stopRealtimeUpdates() {
    if (!_started) return;
    _started = false;
    _xlmSub?.cancel();  _xlmSub  = null;
    _usdcSub?.cancel(); _usdcSub = null;
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
    _recompute();   // immediate best-effort
    _safeNotify();  // UI updates now; will update again when streams/listener fire
  }

  // ---- core ----------------------------------------------------------------
  // % change helpers
  double _pctFromFirstLast(List<double> s) {
    if (s.isEmpty) return double.nan;
    final first = s.first;
    final last  = s.last;
    if (first <= 0 || last <= 0) return double.nan;
    return ((last / first) - 1.0) * 100.0;
  }

  double _coalescePct(double maybe, double lastGood) {
    // If NaN or crazy due to short/empty series, stick to last good value
    if (maybe.isNaN || maybe.isInfinite) return lastGood;
    return maybe;
  }

  void _recompute() {
    // Use the explicit histories exposed by CurrencyProvider
    final x24 = _pctFromFirstLast(currency.xlmHistory24h);
    final x7  = _pctFromFirstLast(currency.xlmHistory7);
    final x30 = _pctFromFirstLast(currency.xlmHistory30);
    final x1y = _pctFromFirstLast(currency.xlmHistory365);

    final u24 = _pctFromFirstLast(currency.usdcHistory24h);
    final u7  = _pctFromFirstLast(currency.usdcHistory7);
    final u30 = _pctFromFirstLast(currency.usdcHistory30);
    final u1y = _pctFromFirstLast(currency.usdcHistory365);

    // Stabilize to avoid flicker to 0 on transient network/host failures
    _xlm24h = _coalescePct(x24, _xlm24h);
    _xlm7d  = _coalescePct(x7,  _xlm7d);
    _xlm30d = _coalescePct(x30, _xlm30d);
    _xlm1y  = _coalescePct(x1y, _xlm1y);

    _usdc24h = _coalescePct(u24, _usdc24h);
    _usdc7d  = _coalescePct(u7,  _usdc7d);
    _usdc30d = _coalescePct(u30, _usdc30d);
    _usdc1y  = _coalescePct(u1y, _usdc1y);

    // Apply to asset models
    for (final a in _assets) {
      if (a.symbol.toUpperCase() == 'XLM') {
        a
          ..priceChangePercent24h = _xlm24h
          ..priceChangePercent7d  = _xlm7d
          ..priceChangePercent30d = _xlm30d
          ..priceChangePercent1y  = _xlm1y;
      } else if (a.symbol.toUpperCase() == 'USDC') {
        a
          ..priceChangePercent24h = _usdc24h
          ..priceChangePercent7d  = _usdc7d
          ..priceChangePercent30d = _usdc30d
          ..priceChangePercent1y  = _usdc1y;
      }
    }
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }
}
