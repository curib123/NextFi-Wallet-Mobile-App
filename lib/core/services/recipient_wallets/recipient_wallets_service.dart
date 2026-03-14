import 'api/api_client.dart';
import 'api/recipient_wallets_api.dart';

class RecipientWalletsService {
  final ApiClient _api;

  late final RecipientWalletsApi recipientWallets;

  RecipientWalletsService({
    required String baseUrl,
    required Future<String?> Function() tokenProvider,
  }) : _api = ApiClient(baseUrl: baseUrl, tokenProvider: tokenProvider) {
    recipientWallets = RecipientWalletsApi(_api);
  }

  void dispose() => _api.dispose();
}