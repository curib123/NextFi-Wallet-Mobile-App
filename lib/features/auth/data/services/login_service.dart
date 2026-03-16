import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:next_fi/core/services/auth/auth_service.dart';
import 'package:next_fi/core/services/auth/models/user_model.dart';
import 'package:next_fi/core/services/wallet/wallet_manager.dart';

class LoginLegalLinks {
  const LoginLegalLinks({
    required this.termsUrl,
    required this.privacyUrl,
  });

  final String termsUrl;
  final String privacyUrl;
}

class LoginService {
  LoginService({
    AuthService? authService,
    http.Client? httpClient,
  }) : _authService = authService ?? AuthService(),
       _httpClient = httpClient ?? http.Client();

  final AuthService _authService;
  final http.Client _httpClient;

  Future<User?> signInWithGoogle() => _authService.signInWithGoogle();

  Future<User?> signInWithFacebook() => _authService.signInWithFacebook();

  Future<void> syncWalletsAfterLogin() async {
    try {
      await WalletManager.I.syncToBackend();
    } catch (_) {
      // Best effort only. Login should still succeed.
    }
  }

  Future<LoginLegalLinks> fetchLegalLinks(String backendBaseUrl) async {
    var base = backendBaseUrl.replaceFirst(RegExp(r'/api/v1/?$'), '');
    base = base.replaceFirst(RegExp(r'/$'), '');
    final fallback = '$base/download';

    try {
      final response = await _httpClient
          .get(Uri.parse('$base/download/meta'))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          final terms = data['termsAndConditionsUrl']?.toString().trim() ?? '';
          final privacy = data['privacyPolicyUrl']?.toString().trim() ?? '';
          return LoginLegalLinks(
            termsUrl: terms.isNotEmpty ? terms : fallback,
            privacyUrl: privacy.isNotEmpty ? privacy : fallback,
          );
        }
      }
    } catch (_) {
      // Fall through to fallback links.
    }

    return LoginLegalLinks(
      termsUrl: fallback,
      privacyUrl: fallback,
    );
  }

  void dispose() {
    _httpClient.close();
  }
}

