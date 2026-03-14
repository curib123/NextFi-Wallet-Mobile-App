class VerificationEndpoints {
  static const String base = '/verification';

  static String me() => '$base/me';

  static String submit() => '$base/submit';
  static String resubmit() => '$base/resubmit';
}
