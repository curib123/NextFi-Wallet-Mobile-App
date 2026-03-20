import 'package:next_fi/core/services/federation_address/federation_address_core_service.dart';
import 'package:next_fi/core/services/federation_address/models/federation_address_dtos.dart';
import 'package:next_fi/core/services/federation_address/models/federation_address_models.dart';

class ReceiveFederationService {
  const ReceiveFederationService();

  String get defaultDomain => FederationAddressCoreService.defaultDomain;

  Future<List<FederationAddressModel>> listMine() {
    return FederationAddressCoreService.I.listMine();
  }

  Future<FederationResolveResponse> resolveByName(String address) {
    return FederationAddressCoreService.I.resolveByName(address);
  }

  Future<void> create(CreateFederationAddressRequest request) {
    return FederationAddressCoreService.I.create(request);
  }

  Future<void> update(String id, UpdateFederationAddressRequest request) {
    return FederationAddressCoreService.I.update(id, request);
  }
}
