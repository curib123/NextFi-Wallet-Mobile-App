// lib/features/import_wallet/model/import_wallet_state.dart
class ImportWalletState {
  final String rawText;              // user-entered text (unvalidated)
  final List<String> suggestions;    // completion suggestions (<=6)
  final bool importing;              // in-flight flag
  final String? error;               // optional error string

  const ImportWalletState({
    this.rawText = "",
    this.suggestions = const [],
    this.importing = false,
    this.error,
  });

  int get wordCount =>
      rawText.trim().isEmpty
          ? 0
          : rawText.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  ImportWalletState copyWith({
    String? rawText,
    List<String>? suggestions,
    bool? importing,
    String? error, // set '' to clear
  }) {
    return ImportWalletState(
      rawText: rawText ?? this.rawText,
      suggestions: suggestions ?? this.suggestions,
      importing: importing ?? this.importing,
      error: error,
    );
  }
}
