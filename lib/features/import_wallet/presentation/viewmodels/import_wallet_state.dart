class ImportWalletState {
  final String rawText;
  final List<String> suggestions;
  final bool importing;
  final String? error;

  const ImportWalletState({
    this.rawText = "",
    this.suggestions = const [],
    this.importing = false,
    this.error,
  });

  int get wordCount => rawText.trim().isEmpty
      ? 0
      : rawText.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  ImportWalletState copyWith({
    String? rawText,
    List<String>? suggestions,
    bool? importing,
    String? error,
  }) {
    return ImportWalletState(
      rawText: rawText ?? this.rawText,
      suggestions: suggestions ?? this.suggestions,
      importing: importing ?? this.importing,
      error: error,
    );
  }
}
