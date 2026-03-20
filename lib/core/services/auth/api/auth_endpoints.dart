import 'package:next_fi/core/services/base_url/base_url.dart';

class AuthEndpoints {
  AuthEndpoints._();

  static const googleRedirect = '/auth/google';
  static const googleCallback = '/auth/google/callback';
  static const googleToken = '/auth/google/token';

  static const facebookRedirect = '/auth/facebook';
  static const facebookCallback = '/auth/facebook/callback';
  static const facebookToken = '/auth/facebook/token';

  static const refresh = '/auth/refresh';
  static const logout = '/auth/logout';
  static const me = '/auth/me';

  static String fullUrl(String path) => '$centralizedBaseUrl$path';
}
