import 'package:next_fi/services/base_url/base_url.dart';

/// Single source of truth for the NextFi backend URLs.
///
/// Usage:
/// ```dart
/// import 'package:next_fi/services/oauth2.0/endpoints/auth_endpoints.dart';
///
/// final url = AuthEndpoints.me;           // '/auth/me'
/// final base = AuthEndpoints.baseUrl;     // 'https://...'
/// final full = AuthEndpoints.fullUrl(AuthEndpoints.me);
/// ```
class AuthEndpoints {
  AuthEndpoints._();

  // ── Google OAuth ──────────────────────────────────────────────────
  static const googleRedirect    = '/auth/google';
  static const googleCallback    = '/auth/google/callback';
  static const googleToken       = '/auth/google/token';

  // ── Facebook OAuth ────────────────────────────────────────────────
  static const facebookRedirect  = '/auth/facebook';
  static const facebookCallback  = '/auth/facebook/callback';
  static const facebookToken     = '/auth/facebook/token';

  // ── Session ───────────────────────────────────────────────────────
  static const refresh           = '/auth/refresh';
  static const logout            = '/auth/logout';
  static const me                = '/auth/me';

  // ── Helper ────────────────────────────────────────────────────────
  /// Returns the full URL for a given path.
  /// e.g. `AuthEndpoints.fullUrl(AuthEndpoints.me)`
  /// → `https://nextfi-backend.onrender.com/api/v1/auth/me`
  static String fullUrl(String path) => '$centralized_baseUrl$path';
}