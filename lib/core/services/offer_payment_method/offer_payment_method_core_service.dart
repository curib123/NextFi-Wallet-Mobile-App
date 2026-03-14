import 'package:flutter/foundation.dart';
import 'package:next_fi/core/services/offers/models/offers_models.dart';
import 'package:next_fi/core/services/payment_method_and_accounts/models/payment_method_and_accounts_models.dart';
import 'package:next_fi/core/services/secure_storage/token_storage.dart';

import 'api/offer_payment_method_service.dart';
import 'models/offer_payment_method_dtos.dart';
import 'models/offer_payment_method_models.dart';

class OfferPaymentMethodCoreService {
  OfferPaymentMethodCoreService._()
    : _service = OfferPaymentMethodService(tokenProvider: _safeTokenProvider);

  static final OfferPaymentMethodCoreService I =
      OfferPaymentMethodCoreService._();

  final OfferPaymentMethodService _service;

  static Future<String?> _safeTokenProvider() async {
    try {
      final storage = TokenStorage();
      return await storage.accessToken;
    } catch (_) {
      return null;
    }
  }

  // Get all payment methods for a specific offer
  Future<List<PaymentMethodModel>> getPaymentMethodsForOffer(
    String offerId,
  ) async {
    try {
      final response = await _service.getPaymentMethodsForOffer(offerId);
      // The response contains OfferPaymentMethodResponse objects with paymentMethod field
      return response.items.map((item) => item.paymentMethod).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching payment methods for offer: $e');
      }
      return [];
    }
  }

  // Get all offers that accept a specific payment method
  Future<List<OfferModel?>> getOffersForPaymentMethod(
    String paymentMethodId,
  ) async {
    try {
      final response = await _service.getOffersForPaymentMethod(
        paymentMethodId,
      );
      return response.items.map((item) => item.offer).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching offers for payment method: $e');
      }
      return [];
    }
  }

  // Get all offer-payment method relationships with filtering
  Future<List<OfferPaymentMethodModel>> getAllRelationships({
    String? offerId,
    String? paymentMethodId,
    bool? activeOnly,
    String? searchQuery,
  }) async {
    try {
      final response = await _service.listAll(
        offerId: offerId,
        paymentMethodId: paymentMethodId,
        activeOnly: activeOnly,
        searchQuery: searchQuery,
      );
      return response.items
          .map(
            (item) => OfferPaymentMethodModel(
              id: item.id,
              offerId: item.offerId,
              paymentMethodId: item.paymentMethodId,
              paymentMethod: item.paymentMethod,
              offer: item.offer,
            ),
          )
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching offer-payment method relationships: $e');
      }
      return [];
    }
  }

  // Get a specific relationship by ID
  Future<OfferPaymentMethodModel?> getRelationshipById(String id) async {
    try {
      final response = await _service.getById(id);
      return OfferPaymentMethodModel(
        id: response.id,
        offerId: response.offerId,
        paymentMethodId: response.paymentMethodId,
        paymentMethod: response.paymentMethod,
        offer: response.offer,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching relationship by ID: $e');
      }
      return null;
    }
  }

  /// Get full OfferPaymentMethodResponse records for an offer.
  /// Use `paymentMethodId` when creating trades.
  Future<List<OfferPaymentMethodResponse>> getOfferPaymentMethodsWithId(
    String offerId,
  ) async {
    try {
      final response = await _service.getPaymentMethodsForOffer(offerId);
      return response.items.whereType<OfferPaymentMethodResponse>().toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching offer payment method records: $e');
      }
      return [];
    }
  }

  void dispose() {
    _service.dispose();
  }
}
