import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:next_fi/app/config/app_providers.dart';
import 'package:next_fi/app/viewmodels/seed_keypair_vm.dart';
import 'package:next_fi/core/services/merchant_profile/merchant_profile_core_service.dart';
import 'package:next_fi/core/services/merchant_profile/models/merchant_profile_models.dart';
import 'package:next_fi/core/services/offers/models/offers_dtos.dart';
import 'package:next_fi/core/services/offers/models/offers_models.dart';
import 'package:next_fi/core/services/offers/offers_core_service.dart';
import 'package:next_fi/core/services/payment_method_and_accounts/payment_method_and_accounts_core_service.dart';
import 'package:next_fi/core/services/stellar/stellar_wallet_services.dart';
import 'package:next_fi/core/widgets/modal/marketplace_filters_modal.dart';
import 'package:next_fi/features/offers/presentation/viewmodels/market_offers_state.dart';

final marketOffersCoreServiceProvider = Provider<OffersCoreService>(
  (Ref ref) => OffersCoreService.I,
);

final marketPaymentMethodsServiceProvider =
    Provider<PaymentMethodAndAccountsCoreService>(
      (Ref ref) => PaymentMethodAndAccountsCoreService.I,
    );

final marketMerchantProfileServiceProvider =
    Provider<MerchantProfileCoreService>(
      (Ref ref) => MerchantProfileCoreService.I,
    );

final marketOffersControllerProvider = NotifierProvider.autoDispose
    .family<MarketOffersController, MarketOffersState, OfferType>(
      MarketOffersController.new,
    );

class MarketOffersController extends Notifier<MarketOffersState> {
  MarketOffersController(this.initialType);

  final OfferType initialType;
  final Map<String, MerchantProfileModel?> _merchantProfileCache = {};

  @override
  MarketOffersState build() {
    final seedVm = ref.read(seedKeypairProvider);
    Future<void>.microtask(load);
    return MarketOffersState(
      selectedType: initialType,
      lastBoundAddress: seedVm.accountId,
    );
  }

  SeedKeypairVM get _seedVm => ref.read(seedKeypairProvider);
  StellarWalletServices get _stellarService =>
      ref.read(stellarWalletServiceProvider);
  OffersCoreService get _offersCore =>
      ref.read(marketOffersCoreServiceProvider);
  PaymentMethodAndAccountsCoreService get _paymentCore =>
      ref.read(marketPaymentMethodsServiceProvider);
  MerchantProfileCoreService get _merchantCore =>
      ref.read(marketMerchantProfileServiceProvider);

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(loading: true, error: null);
    }

    try {
      final hasUsdc = await _activeAddressHasUsdcTrustline();
      final paymentMethods = await _paymentCore.listPaymentMethods(
        activeOnly: true,
      );
      final offers = await _offersCore.listPublic(
        query: state.filters.toQuery(type: state.selectedType),
      );
      final filtered = offers.where((OfferModel offer) {
        final asset = offer.asset.trim().toUpperCase();
        return asset != 'USDC' || hasUsdc;
      }).toList();
      final ranked = await _rankOffers(filtered);

      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        error: null,
        paymentMethods: paymentMethods,
        offers: ranked,
        lastHasUsdcTrustline: hasUsdc,
      );
    } catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(loading: false, error: error.toString());
    }
  }

  Future<void> setOfferType(OfferType type) async {
    if (state.selectedType == type) return;
    state = state.copyWith(selectedType: type);
    await load();
  }

  Future<void> applyFilters(MarketOfferFilters filters) async {
    if (filters == state.filters) return;
    state = state.copyWith(filters: filters);
    await load();
  }

  Future<void> handleActiveWalletChanged(String? accountId) async {
    if (accountId == state.lastBoundAddress) return;
    state = state.copyWith(
      lastBoundAddress: accountId,
      lastTrustlineCheckedAddress: null,
      lastHasUsdcTrustline: false,
    );
    await load();
  }

  Future<bool> _activeAddressHasUsdcTrustline() async {
    var accountId = _seedVm.accountId?.trim();
    if (accountId == null || accountId.isEmpty) {
      await _seedVm.refresh();
      accountId = _seedVm.accountId?.trim();
    }
    if (accountId == null || accountId.isEmpty) return false;
    if (state.lastTrustlineCheckedAddress == accountId) {
      return state.lastHasUsdcTrustline;
    }

    try {
      final has = await _stellarService.accountService.hasUsdcTrustline(
        accountId,
      );
      if (!ref.mounted) return false;
      state = state.copyWith(
        lastTrustlineCheckedAddress: accountId,
        lastHasUsdcTrustline: has,
      );
      return has;
    } catch (_) {
      if (!ref.mounted) return false;
      state = state.copyWith(
        lastTrustlineCheckedAddress: accountId,
        lastHasUsdcTrustline: false,
      );
      return false;
    }
  }

  Future<List<OfferModel>> _rankOffers(List<OfferModel> offers) async {
    if (offers.length < 2) return offers;
    if (state.filters.sortBy != null || state.filters.sortOrder != null) {
      return offers;
    }

    await _primeMerchantProfiles(offers);

    final ranked = [...offers];
    ranked.sort((OfferModel a, OfferModel b) {
      final aProfile = _profileForOffer(a);
      final bProfile = _profileForOffer(b);

      final ratingCompare = _safeRatingOf(
        b,
        bProfile,
      ).compareTo(_safeRatingOf(a, aProfile));
      if (ratingCompare != 0) return ratingCompare;

      final tradesCompare = _completedTradesOf(
        b,
        bProfile,
      ).compareTo(_completedTradesOf(a, aProfile));
      if (tradesCompare != 0) return tradesCompare;

      final successCompare = _safeSuccessRateOf(
        b,
      ).compareTo(_safeSuccessRateOf(a));
      if (successCompare != 0) return successCompare;

      final updatedAtCompare = (b.updatedAt ?? b.createdAt ?? DateTime(1970))
          .compareTo(a.updatedAt ?? a.createdAt ?? DateTime(1970));
      if (updatedAtCompare != 0) return updatedAtCompare;

      return a.id.compareTo(b.id);
    });
    return ranked;
  }

  Future<void> _primeMerchantProfiles(List<OfferModel> offers) async {
    final sellerIds = <String>{};
    for (final offer in offers) {
      sellerIds.addAll(_resolveSellerIds(offer));
    }

    final pending = sellerIds
        .where(
          (String sellerId) => !_merchantProfileCache.containsKey(sellerId),
        )
        .toList();
    if (pending.isEmpty) return;

    await Future.wait(
      pending.map((String sellerId) async {
        try {
          _merchantProfileCache[sellerId] = await _merchantCore.getPublic(
            sellerId,
          );
        } catch (_) {
          _merchantProfileCache[sellerId] = null;
        }
      }),
    );
  }

  List<String> _resolveSellerIds(OfferModel offer) {
    final ids = <String>[];

    void add(dynamic raw) {
      final value = raw?.toString().trim() ?? '';
      if (value.isEmpty || ids.contains(value)) return;
      ids.add(value);
    }

    final seller = offer.seller;
    if (seller != null) {
      add(seller['userId']);
      add(seller['user_id']);
      add(seller['id']);
    }
    add(offer.sellerId);
    return ids;
  }

  MerchantProfileModel? _profileForOffer(OfferModel offer) {
    for (final sellerId in _resolveSellerIds(offer)) {
      final profile = _merchantProfileCache[sellerId];
      if (profile != null) return profile;
    }
    return null;
  }

  double _safeRatingOf(OfferModel offer, MerchantProfileModel? profile) {
    final seller = offer.seller;
    final sellerRating = _readDoubleFromMap(seller, const [
      'avgRating',
      'avg_rating',
    ]);
    return profile?.avgRating ?? sellerRating ?? 0;
  }

  int _completedTradesOf(OfferModel offer, MerchantProfileModel? profile) {
    final seller = offer.seller;
    final sellerTrades = _readIntFromMap(seller, const [
      'completedTrades',
      'completed_trades',
      'tradeCount',
      'trade_count',
    ]);
    return profile?.completedTrades ?? sellerTrades ?? 0;
  }

  double _safeSuccessRateOf(OfferModel offer) => offer.successRate ?? 0;

  double? _readDoubleFromMap(Map<String, dynamic>? map, List<String> keys) {
    if (map == null) return null;
    for (final key in keys) {
      final value = map[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  int? _readIntFromMap(Map<String, dynamic>? map, List<String> keys) {
    if (map == null) return null;
    for (final key in keys) {
      final value = map[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }
    return null;
  }
}

