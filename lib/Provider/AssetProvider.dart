// lib/Provider/AssetProvider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:next_fi/Model/asset_model.dart';
import 'package:next_fi/Provider/CurrencyProvider.dart';

class AssetProvider with ChangeNotifier {
  AssetProvider(this.currency)
      : _assets = [
    AssetModel(id: 'stellar', name: 'Tron', symbol: 'TRX'),
    AssetModel(id: 'tether_trc20', name: 'Tether (TRC20)', symbol: 'USDT'),
  ] {
    // Primary logo map (first-choice URLs). Kept as Map<String,String> to avoid breaking callers.
    // - TRX uses Trust Wallet's stellar/info logo (stable).
    // - USDT (TRC20 on TRON) switches to GitHub-hosted icon packs via jsDelivr CDN.
    // inside AssetProvider constructor:
    _logos = const {
      // TRON (via jsDelivr CDN)
      'stellar': 'https://cdn.jsdelivr.net/gh/trustwallet/assets@master/blockchains/stellar/info/logo.png',
      'trx' : 'https://cdn.jsdelivr.net/gh/trustwallet/assets@master/blockchains/stellar/info/logo.png',

      // USDT (TRC20) via CDN icon pack
      'tether_trc20': 'https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/128/color/usdt.png',
      'USDT'        : 'https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/128/color/usdt.png',
      'usdt'        : 'https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/128/color/usdt.png',
    };


    startRealtimeUpdates(); // idempotent
    _recompute();
  }

  final CurrencyProvider currency;

  final List<AssetModel> _assets;
  late Map<String, String> _logos;

  bool _disposed = false;
  bool _started = false;

  StreamSubscription<double>? _trxSub, _usdtSub;
  VoidCallback? _currencyListener; // listens to CurrencyProvider.notifyListeners

  // Optional: public fallback candidates you can try in your Image.errorBuilder
  static const List<String> usdtLogoFallbacks = [
    'https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/128/color/usdt.png',
    'https://cdn.jsdelivr.net/gh/Cryptofonts/cryptoicons@master/128/usdt.png',
    // SVGs work if your widget supports them (e.g., flutter_svg)
    'https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/svg/color/usdt.svg',
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
      // convenience aliases:
      if (k.toLowerCase().contains('usdt') || k.toLowerCase().contains('tether')) 'tether_trc20',
      if (k.toLowerCase().contains('trx') || k.toLowerCase().contains('stellar')) 'stellar',
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
    _trxSub = currency.xlmPriceStream.listen((_) {
      _recompute();
      _safeNotify();
    });
    _usdtSub = currency.usdcPriceStream.listen((_) {
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

    _trxSub?.cancel(); _trxSub = null;
    _usdtSub?.cancel(); _usdtSub = null;

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

    final trxH = currency.xlmHistory;
    final usdtH = currency.usdcHistory;

    final trx24h = _pctFromHistory(trxH, 1);
    final trx7d  = _pctFromHistory(trxH, 7);
    final trx30d = _pctFromHistory(trxH, 30);
    final trx1y  = _pctFromHistory(trxH, 365);

    final u24h = _pctFromHistory(usdtH, 1);
    final u7d  = _pctFromHistory(usdtH, 7);
    final u30d = _pctFromHistory(usdtH, 30);
    final u1y  = _pctFromHistory(usdtH, 365);

    for (final a in _assets) {
      if (a.symbol.toUpperCase() == 'TRX') {
        a
          ..priceChangePercent24h = trx24h
          ..priceChangePercent7d  = trx7d
          ..priceChangePercent30d = trx30d
          ..priceChangePercent1y  = trx1y;
      } else if (a.symbol.toUpperCase() == 'USDT') {
        a
          ..priceChangePercent24h = u24h
          ..priceChangePercent7d  = u7d
          ..priceChangePercent30d = u30d
          ..priceChangePercent1y  = u1y;
      }
    }
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }
}
