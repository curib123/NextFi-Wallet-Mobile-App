import 'package:next_fi/features/wallet_home/data/models/incoming_hint.dart';

enum PriceWindow { h24, d7, d30, y1 }

const Object _noChange = Object();

class WalletHomeState {
  final String? address;
  final String? walletName;

  final Map<String, double> balancesByAssetId;

  final double xlmBaseReserve;
  final double xlmTrustlineReserve;
  final double xlmTotalReserve;
  final int trustlineCount;

  final bool loadingWallet;
  final bool loadingBalances;
  final bool loadingReserves;
  final bool hasHydratedBalances;

  final DateTime? lastBalancesAt;
  final DateTime? lastReservesAt;

  final List<IncomingHint> hints;

  final PriceWindow selectedWindow;

  const WalletHomeState({
    this.address,
    this.walletName,
    this.balancesByAssetId = const {},
    this.xlmBaseReserve = 1.0,
    this.xlmTrustlineReserve = 0.0,
    this.xlmTotalReserve = 1.0,
    this.trustlineCount = 0,
    this.loadingWallet = false,
    this.loadingBalances = false,
    this.loadingReserves = false,
    this.hasHydratedBalances = false,
    this.lastBalancesAt,
    this.lastReservesAt,
    this.hints = const [],
    this.selectedWindow = PriceWindow.h24,
  });

  bool get hasWallet => (address != null && address!.isNotEmpty);

  double balanceFor(String assetId) => balancesByAssetId[assetId] ?? 0.0;

  double get xlm => balanceFor('stellar');
  double get usdc => balanceFor('usdc_stellar');

  double get spendableXlm => xlm;

  double get totalLockedReserve => xlmTotalReserve;

  static Map<String, double> _normalizeBalancesMap(Object? value) {
    if (value is Map<String, double>) {
      return Map<String, double>.unmodifiable(value);
    }

    if (value is Map) {
      final next = <String, double>{};
      for (final entry in value.entries) {
        final key = entry.key?.toString();
        if (key == null || key.isEmpty) continue;

        final raw = entry.value;
        final amount = raw is num ? raw.toDouble() : double.tryParse('$raw');
        next[key] = amount ?? 0.0;
      }
      return Map<String, double>.unmodifiable(next);
    }

    return const <String, double>{};
  }

  WalletHomeState copyWith({
    Object? address = _noChange,
    Object? walletName = _noChange,
    Object? balancesByAssetId = _noChange,
    double? xlmBaseReserve,
    double? xlmTrustlineReserve,
    double? xlmTotalReserve,
    int? trustlineCount,
    bool? loadingWallet,
    bool? loadingBalances,
    bool? loadingReserves,
    bool? hasHydratedBalances,
    Object? lastBalancesAt = _noChange,
    Object? lastReservesAt = _noChange,
    List<IncomingHint>? hints,
    PriceWindow? selectedWindow,
  }) {
    return WalletHomeState(
      address: identical(address, _noChange)
          ? this.address
          : address as String?,
      walletName: identical(walletName, _noChange)
          ? this.walletName
          : walletName as String?,
      balancesByAssetId: identical(balancesByAssetId, _noChange)
          ? this.balancesByAssetId
          : _normalizeBalancesMap(balancesByAssetId),
      xlmBaseReserve: xlmBaseReserve ?? this.xlmBaseReserve,
      xlmTrustlineReserve: xlmTrustlineReserve ?? this.xlmTrustlineReserve,
      xlmTotalReserve: xlmTotalReserve ?? this.xlmTotalReserve,
      trustlineCount: trustlineCount ?? this.trustlineCount,
      loadingWallet: loadingWallet ?? this.loadingWallet,
      loadingBalances: loadingBalances ?? this.loadingBalances,
      loadingReserves: loadingReserves ?? this.loadingReserves,
      hasHydratedBalances: hasHydratedBalances ?? this.hasHydratedBalances,
      lastBalancesAt: identical(lastBalancesAt, _noChange)
          ? this.lastBalancesAt
          : lastBalancesAt as DateTime?,
      lastReservesAt: identical(lastReservesAt, _noChange)
          ? this.lastReservesAt
          : lastReservesAt as DateTime?,
      hints: hints ?? this.hints,
      selectedWindow: selectedWindow ?? this.selectedWindow,
    );
  }
}
