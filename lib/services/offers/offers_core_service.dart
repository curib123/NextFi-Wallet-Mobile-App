import 'package:next_fi/services/secure_storage/token_storage.dart';

import 'api/offers_service.dart';
import 'models/offers_dtos.dart';
import 'models/offers_models.dart';

class OffersCoreService {
  OffersCoreService._();

  static final OffersCoreService I = OffersCoreService._();

  late final OffersService _api = OffersService(
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

  Future<List<OfferModel>> listPublicOffers(OffersQuery query) async =>
      _api.listPublicOffers(query);

  Future<List<OfferModel>> listRecommendedOffers(OffersQuery query) async =>
      _api.listRecommendedOffers(query);

  Future<OfferModel> getPublicOffer(String id) async => _api.getPublicOffer(id);

  Future<List<OfferModel>> listMyOffers(OffersQuery query) async =>
      _api.listMyOffers(query);

  Future<OfferModel> createMyOffer(CreateOfferRequest req) async =>
      _api.createMyOffer(req);

  Future<OfferModel> patchMyOffer(String id, UpdateOfferRequest req) async =>
      _api.patchMyOffer(id, req);

  Future<bool> deleteMyOffer(String id) async => _api.deleteMyOffer(id);
}
