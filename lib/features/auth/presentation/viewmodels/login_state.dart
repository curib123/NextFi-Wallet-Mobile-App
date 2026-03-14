class LoginState {
  const LoginState({
    this.googleLoading = false,
    this.facebookLoading = false,
    this.postLoginLoading = false,
    this.termsUrl = '',
    this.privacyUrl = '',
  });

  final bool googleLoading;
  final bool facebookLoading;
  final bool postLoginLoading;
  final String termsUrl;
  final String privacyUrl;

  bool get isBusy => googleLoading || facebookLoading || postLoginLoading;

  LoginState copyWith({
    bool? googleLoading,
    bool? facebookLoading,
    bool? postLoginLoading,
    String? termsUrl,
    String? privacyUrl,
  }) {
    return LoginState(
      googleLoading: googleLoading ?? this.googleLoading,
      facebookLoading: facebookLoading ?? this.facebookLoading,
      postLoginLoading: postLoginLoading ?? this.postLoginLoading,
      termsUrl: termsUrl ?? this.termsUrl,
      privacyUrl: privacyUrl ?? this.privacyUrl,
    );
  }
}
