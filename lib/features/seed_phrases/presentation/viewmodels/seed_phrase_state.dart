// lib/features/seed_phrase/model/seed_phrase_state.dart
class SeedPhraseState {
  final String mnemonic;
  final List<String> words;
  final bool loading;
  final bool obscured;
  final bool ack1;
  final bool ack2;
  final String? error;

  const SeedPhraseState({
    this.mnemonic = "",
    this.words = const [],
    this.loading = false,
    this.obscured = true,
    this.ack1 = false,
    this.ack2 = false,
    this.error,
  });

  int get wordCount => words.length;
  bool get isTwentyFour => wordCount == 24;

  SeedPhraseState copyWith({
    String? mnemonic,
    List<String>? words,
    bool? loading,
    bool? obscured,
    bool? ack1,
    bool? ack2,
    String? error, // pass '' to clear
  }) {
    return SeedPhraseState(
      mnemonic: mnemonic ?? this.mnemonic,
      words: words ?? this.words,
      loading: loading ?? this.loading,
      obscured: obscured ?? this.obscured,
      ack1: ack1 ?? this.ack1,
      ack2: ack2 ?? this.ack2,
      error: error ?? this.error,
    );
  }
}
