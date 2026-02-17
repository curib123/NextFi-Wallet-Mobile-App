import 'package:next_fi/services/secure_storage/token_storage.dart';

import 'api/federation_address_service.dart';
import 'models/federation_address_dtos.dart';
import 'models/federation_address_models.dart';

class FederationAddressCoreService {
  FederationAddressCoreService._();

  static final FederationAddressCoreService I =
      FederationAddressCoreService._();

  late final FederationAddressService _api = FederationAddressService(
    tokenProvider: _safeTokenProvider,
  );

  static Future<String?> _safeTokenProvider() async {
    try {
      final storage = TokenStorage();
      return await storage.accessToken;
    } catch (_) {
      return null;
    }
  }

  Future<FederationResolveResponse> resolveByName(
    String federationAddress, {
    String? domain,
  }) async {
    return _api.resolvePublic(
      FederationLookupQuery(q: federationAddress, type: 'name', domain: domain),
    );
  }

  Future<FederationResolveResponse> resolveByAccountId(
    String accountId, {
    String? domain,
  }) async {
    return _api.resolvePublic(
      FederationLookupQuery(q: accountId, type: 'id', domain: domain),
    );
  }

  Future<String> getStellarToml() => _api.getPublicStellarToml();

  Future<List<FederationAddressModel>> listMine() => _api.listMine();

  Future<FederationAddressModel> create(CreateFederationAddressRequest req) =>
      _api.create(req);

  Future<FederationAddressModel> update(
    String id,
    UpdateFederationAddressRequest req,
  ) => _api.update(id, req);

  Future<bool> delete(String id) => _api.delete(id);

  Future<FederationResolveResponse> resolveExternalByName(
    String federationAddress, {
    String? domain,
    bool useLegacyPath = false,
  }) {
    return _api.resolveExternal(
      FederationLookupQuery(q: federationAddress, type: 'name', domain: domain),
      useLegacyPath: useLegacyPath,
    );
  }
}
