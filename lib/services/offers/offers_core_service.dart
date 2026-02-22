import 'package:next_fi/services/offers/api/offers_service.dart';
import 'package:next_fi/services/offers/models/offers_dtos.dart';
import 'package:next_fi/services/offers/models/offers_models.dart';
import 'package:next_fi/services/secure_storage/token_storage.dart';

class OffersCoreService {
  OffersCoreService._();

  static final OffersCoreService I = OffersCoreService._();

  late final OffersService _api = OffersService(tokenProvider: _safeTokenProvider);

  static Future<String?> _safeTokenProvider() async {
    try {
      final storage = TokenStorage();
      return await storage.accessToken;
    } catch (_) {
      return null;
    }
  }

  // Public routes
  Future<OffersPagedResponse> listPublicPaged({
    OffersListQuery query = const OffersListQuery(),
  }) async => _api.listPublicPaged(query: query);

  Future<List<OfferModel>> listPublic({
    OffersListQuery query = const OffersListQuery(),
  }) async => _api.listPublic(query: query);

  Future<OfferModel> getPublicById(String id) async => _api.getPublicById(id);

  // Merchant routes
  Future<OfferModel> create(CreateOfferRequest req) async => _api.create(req);

  Future<OfferModel> update(String id, UpdateOfferRequest req) async =>
      _api.update(id, req);

  Future<OfferModel> pause(String id) async => _api.pause(id);

  Future<OfferModel> resume(String id) async => _api.resume(id);

  Future<bool> cancel(String id) async => _api.cancel(id);

  Future<OffersPagedResponse> listMinePaged({
    OffersListQuery query = const OffersListQuery(),
  }) async => _api.listMinePaged(query: query);

  Future<List<OfferModel>> listMine({
    OffersListQuery query = const OffersListQuery(),
  }) async => _api.listMine(query: query);

  // Admin routes
  Future<OffersPagedResponse> listAdminPaged({
    OffersListQuery query = const OffersListQuery(),
  }) async => _api.listAdminPaged(query: query);

  Future<List<OfferModel>> listAdmin({
    OffersListQuery query = const OffersListQuery(),
  }) async => _api.listAdmin(query: query);

  void dispose() => _api.dispose();
}
