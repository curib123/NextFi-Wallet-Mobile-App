// lib/features/wallet_settings/model/wallet_settings_state.dart
class WalletSettingsState {
  final String? activeWalletId;
  final String walletName;

  final String mnemonic;
  final List<String> words;

  final bool loading;
  final bool obscured;     // hidden until oath2.0
  final bool authorized;   // set true after AuthGate goNext
  final String? error;

  const WalletSettingsState({
    this.activeWalletId,
    this.walletName = "My Wallet",
    this.mnemonic = "",
    this.words = const [],
    this.loading = true,
    this.obscured = true,
    this.authorized = false,
    this.error,
  });

  int get wordCount => words.length;
  bool get hasSeed => mnemonic.trim().isNotEmpty;

  WalletSettingsState copyWith({
    String? activeWalletId,
    String? walletName,
    String? mnemonic,
    List<String>? words,
    bool? loading,
    bool? obscured,
    bool? authorized,
    String? error, // set '' to clear
  }) {
    return WalletSettingsState(
      activeWalletId: activeWalletId ?? this.activeWalletId,
      walletName: walletName ?? this.walletName,
      mnemonic: mnemonic ?? this.mnemonic,
      words: words ?? this.words,
      loading: loading ?? this.loading,
      obscured: obscured ?? this.obscured,
      authorized: authorized ?? this.authorized,
      error: error,
    );
  }
}
