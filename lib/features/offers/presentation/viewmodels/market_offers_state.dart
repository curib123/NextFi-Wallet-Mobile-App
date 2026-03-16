import 'package:next_fi/core/services/offers/models/offers_dtos.dart';
import 'package:next_fi/core/services/offers/models/offers_models.dart';
import 'package:next_fi/core/services/payment_method_and_accounts/models/payment_method_and_accounts_models.dart';
import 'package:next_fi/core/widgets/modal/marketplace_filters_modal.dart';

const Object _sentinel = Object();

class MarketOffersState {
  const MarketOffersState({
    this.loading = true,
    this.error,
    this.selectedType = OfferType.buy,
    this.offers = const <OfferModel>[],
    this.paymentMethods = const <PaymentMethodModel>[],
    this.filters = const MarketOfferFilters(),
    this.lastBoundAddress,
    this.lastTrustlineCheckedAddress,
    this.lastHasUsdcTrustline = false,
  });

  final bool loading;
  final String? error;
  final OfferType selectedType;
  final List<OfferModel> offers;
  final List<PaymentMethodModel> paymentMethods;
  final MarketOfferFilters filters;
  final String? lastBoundAddress;
  final String? lastTrustlineCheckedAddress;
  final bool lastHasUsdcTrustline;

  MarketOffersState copyWith({
    bool? loading,
    Object? error = _sentinel,
    OfferType? selectedType,
    List<OfferModel>? offers,
    List<PaymentMethodModel>? paymentMethods,
    MarketOfferFilters? filters,
    Object? lastBoundAddress = _sentinel,
    Object? lastTrustlineCheckedAddress = _sentinel,
    bool? lastHasUsdcTrustline,
  }) {
    return MarketOffersState(
      loading: loading ?? this.loading,
      error: identical(error, _sentinel) ? this.error : error as String?,
      selectedType: selectedType ?? this.selectedType,
      offers: offers ?? this.offers,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      filters: filters ?? this.filters,
      lastBoundAddress: identical(lastBoundAddress, _sentinel)
          ? this.lastBoundAddress
          : lastBoundAddress as String?,
      lastTrustlineCheckedAddress:
          identical(lastTrustlineCheckedAddress, _sentinel)
          ? this.lastTrustlineCheckedAddress
          : lastTrustlineCheckedAddress as String?,
      lastHasUsdcTrustline: lastHasUsdcTrustline ?? this.lastHasUsdcTrustline,
    );
  }
}
