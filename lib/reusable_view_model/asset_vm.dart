import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:next_fi/reusable_model/asset_model.dart';
import 'package:next_fi/reusable_view_model/currency_vm.dart';

class AssetVM with ChangeNotifier {
  /// If you're running a testnet build, set this to true when constructing the VM.
  AssetVM(this.currency, {this.isTestnet = false})
      : _assets = [] {
    // Defaults (you can override after construction if you need a custom issuer)
    usdcIssuerMainnet = 'GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN';
    usdcIssuerTestnet = 'GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5';

    // Build asset list with the correct issuer baked in.
    _assets.addAll([
      AssetModel(
        id: 'stellar',
        name: 'Stellar Lumens',
        symbol: 'XLM',
        chain: 'stellar',
        network: isTestnet ? 'testnet' : 'mainnet',
        kind: AssetKind.native,
        isNative: true,
        assetCode: 'XLM',
        decimals: 7,
        aliases: const ['xlm', 'stellar', 'lumens'],
        tags: const ['layer1', 'official', 'featured'],
        explorer: {
          'account': isTestnet
              ? 'https://stellar.expert/explorer/testnet/account/{account}'
              : 'https://stellar.expert/explorer/public/account/{account}',
          'tx': isTestnet
              ? 'https://stellar.expert/explorer/testnet/tx/{hash}'
              : 'https://stellar.expert/explorer/public/tx/{hash}',
        },
        logoUris: const [
          'https://cdn.jsdelivr.net/gh/trustwallet/assets@master/blockchains/stellar/info/logo.png',
        ],
        sortOrder: 0,
      ),
      AssetModel(
        id: 'usdc_stellar',
        name: 'USD Coin (Stellar)',
        symbol: 'USDC',
        chain: 'stellar',
        network: isTestnet ? 'testnet' : 'mainnet',
        kind: AssetKind.token,
        isNative: false,
        assetCode: 'USDC',
        issuer: isTestnet ? usdcIssuerTestnet : usdcIssuerMainnet,
        decimals: 7,
        aliases: const ['usdc', 'usd coin'],
        tags: const ['stablecoin', 'featured'],
        explorer: {
          'asset': isTestnet
              ? 'https://stellar.expert/explorer/testnet/asset/USDC-{issuer}'
              : 'https://stellar.expert/explorer/public/asset/USDC-{issuer}',
        },
        logoUris: const [
          'https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/128/color/usdc.png',
          'https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/svg/color/usdc.svg',
        ],
        sortOrder: 1,
      ),
    ]);

    startRealtimeUpdates(); // idempotent
    _recompute();
  }

  // ---- configuration --------------------------------------------------------
  final CurrencyVM currency;
  final bool isTestnet;

  /// You can override these after construction if needed (e.g., remote config).
  late String usdcIssuerMainnet;
  late String usdcIssuerTestnet;

  /// Current active issuer based on network.
  String get usdcIssuer => isTestnet ? usdcIssuerTestnet : usdcIssuerMainnet;

  /// Convenience when wiring to services outside of Flutter tree.
  String? issuerForSymbol(String symbol) {
    final s = symbol.trim().toUpperCase();
    final a = _assets.firstWhere(
          (x) => x.symbol.toUpperCase() == s || x.matchesKey(s),
      orElse: () => _assets.first,
    );
    return a.issuer;
  }

  // ---- state ----------------------------------------------------------------
  final List<AssetModel> _assets;

  bool _disposed = false;
  bool _started = false;

  StreamSubscription<double>? _xlmSub, _usdcSub;
  VoidCallback? _currencyListener;

  double _xlm24h = 0, _xlm7d = 0, _xlm30d = 0, _xlm1y = 0;
  double _usdc24h = 0, _usdc7d = 0, _usdc30d = 0, _usdc1y = 0;

  List<AssetModel> get assets =>
      _assets.where((a) => a.enabled).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  String get vsCurrency => currency.fiat;
  bool get loading => currency.loading;

  /// Best-known logo for an arbitrary key (id/symbol/alias/contract/etc).
  String logoFor(String key) {
    for (final a in _assets) {
      if (a.matchesKey(key)) {
        return a.primaryLogo.isNotEmpty ? a.primaryLogo : _fallbackLogo();
      }
    }
    return _fallbackLogo();
  }

  String _fallbackLogo() {
    final stellar = _assets.firstWhere((a) => a.id == 'stellar', orElse: () => _assets.first);
    return stellar.primaryLogo;
  }

  // ---- lifecycle -----------------------------------------------------------
  void startRealtimeUpdates() {
    if (_started) return;
    _started = true;

    _xlmSub = currency.xlmPriceStream.listen((_) { _recompute(); _safeNotify(); });
    _usdcSub = currency.usdcPriceStream.listen((_) { _recompute(); _safeNotify(); });

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

  void setVsCurrency(String vs) {
    currency.setFiat(vs);
    _recompute();
    _safeNotify();
  }

  // ---- core ----------------------------------------------------------------
  double _pctFromFirstLast(List<double> s) {
    if (s.length < 2) return double.nan;
    final first = s.first;
    final last  = s.last;
    if (first <= 0 || last <= 0) return double.nan;
    return ((last / first) - 1.0) * 100.0;
  }

  double _coalescePct(double maybe, double lastGood) {
    if (maybe.isNaN || maybe.isInfinite) return lastGood;
    return maybe;
  }

  void _recompute() {
    final x24 = _pctFromFirstLast(currency.xlmHistory24h);
    final x7  = _pctFromFirstLast(currency.xlmHistory7);
    final x30 = _pctFromFirstLast(currency.xlmHistory30);
    final x1y = _pctFromFirstLast(currency.xlmHistory365);

    final u24 = _pctFromFirstLast(currency.usdcHistory24h);
    final u7  = _pctFromFirstLast(currency.usdcHistory7);
    final u30 = _pctFromFirstLast(currency.usdcHistory30);
    final u1y = _pctFromFirstLast(currency.usdcHistory365);

    _xlm24h = _coalescePct(x24, _xlm24h);
    _xlm7d  = _coalescePct(x7,  _xlm7d);
    _xlm30d = _coalescePct(x30, _xlm30d);
    _xlm1y  = _coalescePct(x1y, _xlm1y);

    _usdc24h = _coalescePct(u24, _usdc24h);
    _usdc7d  = _coalescePct(u7,  _usdc7d);
    _usdc30d = _coalescePct(u30, _usdc30d);
    _usdc1y  = _coalescePct(u1y, _usdc1y);

    for (int i = 0; i < _assets.length; i++) {
      final a = _assets[i];
      if (a.symbol.toUpperCase() == 'XLM') {
        _assets[i] = a.copyWith(
          priceChangePercent24h: _xlm24h,
          priceChangePercent7d:  _xlm7d,
          priceChangePercent30d: _xlm30d,
          priceChangePercent1y:  _xlm1y,
        );
      } else if (a.symbol.toUpperCase() == 'USDC') {
        // ensure issuer stays in sync if you change network/overrides at runtime
        final correctIssuer = isTestnet ? usdcIssuerTestnet : usdcIssuerMainnet;
        _assets[i] = a.copyWith(
          issuer: correctIssuer,
          priceChangePercent24h: _usdc24h,
          priceChangePercent7d:  _usdc7d,
          priceChangePercent30d: _usdc30d,
          priceChangePercent1y:  _usdc1y,
        );
      }
    }
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }
}
