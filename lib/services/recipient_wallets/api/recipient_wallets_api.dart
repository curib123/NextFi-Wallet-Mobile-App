import 'api_client.dart';
import '../models/recipient_wallet_models.dart';

class RecipientWalletsApi {
  final ApiClient _api;
  const RecipientWalletsApi(this._api);

  // POST /recipient-wallets
  Future<RecipientWallet> create(CreateRecipientWalletRequest req) async {
    final response = await _api.post('/recipient-wallets', req.toJson(), auth: true);
    return RecipientWallet.fromJson(response);
  }

  // GET /recipient-wallets?q=&network=&activeOnly=true
  Future<List<RecipientWallet>> list({
    String? q,
    String? network,
    bool? activeOnly,
  }) async {
    final queryParams = <String, String>{};
    if (q != null && q.isNotEmpty) queryParams['q'] = q;
    if (network != null && network.isNotEmpty) queryParams['network'] = network;
    if (activeOnly != null) queryParams['activeOnly'] = activeOnly.toString();

    final response = await _api.get(
      '/recipient-wallets',
      auth: true,
      queryParams: queryParams.isNotEmpty ? queryParams : null,
    );

    if (response is List) {
      return response.map((item) => RecipientWallet.fromJson(item)).toList();
    }
    return [];
  }

  // GET /recipient-wallets/:id
  Future<RecipientWallet> getById(String id) async {
    final response = await _api.get('/recipient-wallets/$id', auth: true);
    return RecipientWallet.fromJson(response);
  }

  // PATCH /recipient-wallets/:id
  Future<RecipientWallet> update({
    required String id,
    String? name,
    String? publicAddress,
    String? network,
    String? memo,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (publicAddress != null) body['publicAddress'] = publicAddress;
    if (network != null) body['network'] = network;
    if (memo != null) body['memo'] = memo;
    if (isActive != null) body['isActive'] = isActive;

    final response = await _api.patch('/recipient-wallets/$id', body, auth: true);
    return RecipientWallet.fromJson(response);
  }

  // PATCH /recipient-wallets/:id/toggle
  Future<RecipientWallet> toggleActive(String id) async {
    final response = await _api.patch('/recipient-wallets/$id/toggle', {}, auth: true);
    return RecipientWallet.fromJson(response);
  }

  // DELETE /recipient-wallets/:id
  Future<bool> delete(String id) async {
    final response = await _api.delete('/recipient-wallets/$id', auth: true);
    return response != null && response['success'] == true;
  }
}