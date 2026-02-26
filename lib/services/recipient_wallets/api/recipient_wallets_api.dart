import 'api_client.dart';
import '../models/recipient_wallet_models.dart';

class RecipientWalletsApi {
  final ApiClient _api;
  const RecipientWalletsApi(this._api);

  List<RecipientWallet> _parseListFromResponse(dynamic response) {
    List<dynamic>? rawList;

    if (response is List) {
      rawList = response;
    } else if (response is Map) {
      final map = Map<String, dynamic>.from(response);
      final items = map['items'];
      final data = map['data'];

      if (items is List) {
        rawList = items;
      } else if (data is List) {
        rawList = data;
      } else if (data is Map && data['items'] is List) {
        rawList = data['items'] as List;
      }
    }

    if (rawList == null) return const <RecipientWallet>[];

    return rawList
        .whereType<Map>()
        .map(
          (item) => RecipientWallet.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  // POST /recipient-wallets
  Future<RecipientWallet> create(CreateRecipientWalletRequest req) async {
    final response = await _api.post(
      '/recipient-wallets',
      req.toJson(),
      auth: true,
    );
    if (response is Map) {
      return RecipientWallet.fromJson(Map<String, dynamic>.from(response));
    }
    throw Exception('Invalid response shape from POST /recipient-wallets');
  }

  // GET /recipient-wallets?q=&network=&activeOnly=true
  Future<List<RecipientWallet>> list({
    String? q,
    String? network,
    bool? activeOnly,
    int? page,
    int? limit,
  }) async {
    final queryParams = <String, String>{};
    if (q != null && q.isNotEmpty) queryParams['q'] = q;
    if (network != null && network.isNotEmpty) queryParams['network'] = network;
    if (activeOnly != null) queryParams['activeOnly'] = activeOnly.toString();
    if (page != null) queryParams['page'] = page.toString();
    if (limit != null) queryParams['limit'] = limit.toString();

    final response = await _api.get(
      '/recipient-wallets',
      auth: true,
      queryParams: queryParams.isNotEmpty ? queryParams : null,
    );

    return _parseListFromResponse(response);
  }

  // GET /recipient-wallets/:id
  Future<RecipientWallet> getById(String id) async {
    final response = await _api.get('/recipient-wallets/$id', auth: true);
    if (response is Map) {
      return RecipientWallet.fromJson(Map<String, dynamic>.from(response));
    }
    throw Exception('Invalid response shape from GET /recipient-wallets/$id');
  }

  // PATCH /recipient-wallets/:id
  Future<RecipientWallet> update({
    required String id,
    String? name,
    String? publicAddress,
    String? network,
    String? colorTag,
    bool? isActive,
    String? memo,
    String? memoType,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (publicAddress != null) body['publicAddress'] = publicAddress;
    if (network != null) body['network'] = network;
    if (colorTag != null) body['colorTag'] = colorTag;
    if (isActive != null) body['isActive'] = isActive;
    if (memo != null) body['memo'] = memo;
    if (memoType != null) body['memoType'] = memoType;

    final response = await _api.patch(
      '/recipient-wallets/$id',
      body,
      auth: true,
    );
    if (response is Map) {
      return RecipientWallet.fromJson(Map<String, dynamic>.from(response));
    }
    throw Exception('Invalid response shape from PATCH /recipient-wallets/$id');
  }

  // PATCH /recipient-wallets/:id/toggle
  Future<RecipientWallet> toggleActive(String id) async {
    final response = await _api.patch(
      '/recipient-wallets/$id/toggle',
      {},
      auth: true,
    );
    if (response is Map) {
      return RecipientWallet.fromJson(Map<String, dynamic>.from(response));
    }
    throw Exception(
      'Invalid response shape from PATCH /recipient-wallets/$id/toggle',
    );
  }

  // DELETE /recipient-wallets/:id
  Future<bool> delete(String id) async {
    final response = await _api.delete('/recipient-wallets/$id', auth: true);
    if (response == null) return true;
    if (response is Map<String, dynamic>) {
      final success = response['success'];
      if (success is bool) return success;
    }
    return true;
  }
}
