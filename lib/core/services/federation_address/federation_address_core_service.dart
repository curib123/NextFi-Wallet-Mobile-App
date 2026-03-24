import 'package:next_fi/app/config/app_config.dart';
import 'package:next_fi/core/services/wallet_sync/wallet_backend_client.dart';

import 'api/federation_address_service.dart';
import 'models/federation_address_dtos.dart';
import 'models/federation_address_models.dart';

class FederationAddressCoreService {
  FederationAddressCoreService._();

  static final FederationAddressCoreService I =
      FederationAddressCoreService._();
  static String get defaultDomain => AppConfig.instance.federationDomain;

  late final FederationAddressService _api = FederationAddressService(
    tokenProvider: _safeTokenProvider,
  );

  static Future<String?> _safeTokenProvider() async {
    try {
      return await WalletBackendClient.I.currentActiveToken();
    } catch (_) {
      return null;
    }
  }

  Future<FederationResolveResponse> resolveByName(
    String federationAddress, {
    String? domain,
  }) async {
    final effectiveDomain = _sanitizeDomain(domain);
    return _api.resolvePublic(
      FederationLookupQuery(
        q: federationAddress,
        type: 'name',
        domain: effectiveDomain,
      ),
    );
  }

  Future<FederationResolveResponse> resolveByAccountId(
    String accountId, {
    String? domain,
  }) async {
    final effectiveDomain = _sanitizeDomain(domain);
    return _api.resolvePublic(
      FederationLookupQuery(q: accountId, type: 'id', domain: effectiveDomain),
    );
  }

  Future<String> getStellarToml() => _api.getPublicStellarToml();

  Future<List<FederationAddressModel>> listMine() => _api.listMine();

  Future<FederationAddressModel> create(CreateFederationAddressRequest req) {
    final normalized = CreateFederationAddressRequest(
      alias: req.alias,
      domain: _sanitizeDomain(req.domain),
      accountId: req.accountId,
      memo: req.memo,
      memoType: req.memoType,
      isActive: req.isActive,
    );
    return _api.create(normalized);
  }

  Future<FederationAddressModel> update(
    String id,
    UpdateFederationAddressRequest req,
  ) {
    final normalized = UpdateFederationAddressRequest(
      alias: req.alias,
      domain: _sanitizeDomain(req.domain),
      accountId: req.accountId,
      memo: req.memo,
      memoType: req.memoType,
      isActive: req.isActive,
    );
    return _api.update(id, normalized);
  }

  Future<bool> delete(String id) => _api.delete(id);

  Future<FederationResolveResponse> resolveExternalByName(
    String federationAddress, {
    String? domain,
    bool useLegacyPath = false,
  }) {
    final effectiveDomain = _sanitizeDomain(domain);
    return _api.resolveExternal(
      FederationLookupQuery(
        q: federationAddress,
        type: 'name',
        domain: effectiveDomain,
      ),
      useLegacyPath: useLegacyPath,
    );
  }

  String _sanitizeDomain(String? input) {
    final d = input?.trim();
    if (d == null || d.isEmpty) return defaultDomain;
    return defaultDomain;
  }
}
