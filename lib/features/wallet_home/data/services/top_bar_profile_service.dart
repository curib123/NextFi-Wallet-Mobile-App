import 'package:next_fi/core/services/oath2.0/api/auth_http_client.dart';
import 'package:next_fi/core/services/oath2.0/api/endpoints.dart';
import 'package:next_fi/core/services/oath2.0/models/user_model.dart';
import 'package:next_fi/core/services/secure_storage/token_storage.dart';

class TopBarProfileService {
  TopBarProfileService({TokenStorage? tokenStorage})
    : _tokenStorage = tokenStorage ?? TokenStorage();

  final TokenStorage _tokenStorage;

  Future<User?> loadCurrentUser() async {
    final hasTokens = await _tokenStorage.hasTokens;
    if (!hasTokens) return null;

    final client = AuthHttpClient(tokenStorage: _tokenStorage);
    try {
      final json = await client.get(AuthEndpoints.me);
      return User.fromJson(json);
    } catch (_) {
      return null;
    } finally {
      client.dispose();
    }
  }
}
