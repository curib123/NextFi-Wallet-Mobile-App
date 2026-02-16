// lib/features/wallet_creation/model/wallet_creation_state.dart
class WalletCreationState {
  final bool isSplash;
  final String title;
  final String subtitle;
  final String logoAsset;

  const WalletCreationState({
    this.isSplash = false,
    this.title = 'NextFI Wallet',
    this.subtitle = 'Simple\u202F•\u202FUser Controlled\u202F•\u202FSecure',
    this.logoAsset = 'assets/icon/ic_stat_notification.png',
  });

  WalletCreationState copyWith({
    bool? isSplash,
    String? title,
    String? subtitle,
    String? logoAsset,
  }) {
    return WalletCreationState(
      isSplash: isSplash ?? this.isSplash,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      logoAsset: logoAsset ?? this.logoAsset,
    );
  }
}