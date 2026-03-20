import 'package:next_fi/features/contact/data/models/recipient_address_model.dart';
import 'package:next_fi/core/models/asset_model.dart';
import 'package:next_fi/core/services/federation_address/models/federation_address_models.dart';

class SendControllerArgs {
  const SendControllerArgs({
    required this.address,
    required this.assetId,
    required this.balance,
    this.prefillAddress,
    this.prefillName,
  });

  final String address;
  final String assetId;
  final double balance;
  final String? prefillAddress;
  final String? prefillName;

  @override
  bool operator ==(Object other) {
    return other is SendControllerArgs &&
        other.address == address &&
        other.assetId == assetId &&
        other.balance == balance &&
        other.prefillAddress == prefillAddress &&
        other.prefillName == prefillName;
  }

  @override
  int get hashCode =>
      Object.hash(address, assetId, balance, prefillAddress, prefillName);
}

class SendState {
  const SendState({
    required this.assetId,
    required this.senderAddress,
    required this.senderBalanceToken,
    required this.recipientInput,
    required this.destinationAddress,
    required this.typedAmount,
    required this.memo,
    required this.loading,
    required this.checking,
    required this.submitting,
    required this.recipientLoading,
    required this.federationLoading,
    required this.federationDomain,
    required this.federationSuggestions,
    required this.asset,
    this.accountId,
    this.prefillName,
    this.error,
    this.estNetworkFeeXlm,
    this.destinationHasTrustline,
    this.resolvedRecipient,
    this.resolvedFederation,
    this.federationError,
    this.destinationMemoRequired,
    this.destinationMemoHint,
    this.merchantProfile,
  });

  factory SendState.initial(
    SendControllerArgs args,
    String federationDomain,
    AssetModel asset,
  ) {
    final recipientInput = (args.prefillAddress ?? '').trim();
    return SendState(
      assetId: args.assetId,
      senderAddress: args.address,
      senderBalanceToken: args.balance,
      recipientInput: recipientInput,
      destinationAddress: recipientInput,
      typedAmount: 0,
      memo: '',
      loading: true,
      checking: false,
      submitting: false,
      recipientLoading: false,
      federationLoading: false,
      federationDomain: federationDomain,
      federationSuggestions: const [],
      asset: asset,
      prefillName: args.prefillName?.trim().isEmpty == true
          ? null
          : args.prefillName?.trim(),
    );
  }

  final String assetId;
  final String senderAddress;
  final double senderBalanceToken;
  final String recipientInput;
  final String destinationAddress;
  final double typedAmount;
  final String memo;
  final bool loading;
  final bool checking;
  final bool submitting;
  final bool recipientLoading;
  final bool federationLoading;
  final String federationDomain;
  final List<String> federationSuggestions;
  final AssetModel asset;
  final String? accountId;
  final String? prefillName;
  final String? error;
  final double? estNetworkFeeXlm;
  final bool? destinationHasTrustline;
  final RecipientAddressModel? resolvedRecipient;
  final FederationResolveResponse? resolvedFederation;
  final String? federationError;
  final bool? destinationMemoRequired;
  final String? destinationMemoHint;
  final Map<String, dynamic>? merchantProfile;

  bool get isXlm => asset.isNative;
  bool get requiresTrustline => asset.requiresTrustline;
  double get networkFee => estNetworkFeeXlm ?? 0;
  String? get recipientLabel => resolvedRecipient?.name ?? prefillName;
  String get assetSymbol => asset.symbol.toUpperCase();
  String get assetName => asset.name;

  double _floor7(double v) => (v * 1e7).floor() / 1e7;

  double get recipientWillReceive => typedAmount <= 0 ? 0 : typedAmount;

  double get totalDeductFromBalance {
    if (typedAmount <= 0) return 0;
    if (isXlm) return _floor7(typedAmount + networkFee);
    return typedAmount;
  }

  double get remainingExpendable =>
      (senderBalanceToken - totalDeductFromBalance).clamp(0, double.infinity);

  String? get blockingReason {
    final destination = destinationAddress.trim();
    if (destination.isEmpty ||
        !(destination.startsWith('G') && destination.length == 56)) {
      return 'Enter a valid Stellar address (G...)';
    }
    if (typedAmount <= 0) return 'Enter amount';
    if (isXlm) {
      if (totalDeductFromBalance > senderBalanceToken + 1e-9) {
        return 'Amount + network fee exceeds XLM balance';
      }
      return null;
    }
    if (typedAmount > senderBalanceToken + 1e-9) {
      return 'Amount exceeds $assetSymbol balance';
    }
    if (destinationHasTrustline == false) {
      return 'Recipient needs a $assetSymbol trustline first';
    }
    return null;
  }

  SendState copyWith({
    String? assetId,
    String? senderAddress,
    double? senderBalanceToken,
    String? recipientInput,
    String? destinationAddress,
    double? typedAmount,
    String? memo,
    bool? loading,
    bool? checking,
    bool? submitting,
    bool? recipientLoading,
    bool? federationLoading,
    String? federationDomain,
    List<String>? federationSuggestions,
    AssetModel? asset,
    Object? accountId = _sentinel,
    Object? prefillName = _sentinel,
    Object? error = _sentinel,
    Object? estNetworkFeeXlm = _sentinel,
    Object? destinationHasTrustline = _sentinel,
    Object? resolvedRecipient = _sentinel,
    Object? resolvedFederation = _sentinel,
    Object? federationError = _sentinel,
    Object? destinationMemoRequired = _sentinel,
    Object? destinationMemoHint = _sentinel,
    Object? merchantProfile = _sentinel,
  }) {
    return SendState(
      assetId: assetId ?? this.assetId,
      senderAddress: senderAddress ?? this.senderAddress,
      senderBalanceToken: senderBalanceToken ?? this.senderBalanceToken,
      recipientInput: recipientInput ?? this.recipientInput,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      typedAmount: typedAmount ?? this.typedAmount,
      memo: memo ?? this.memo,
      loading: loading ?? this.loading,
      checking: checking ?? this.checking,
      submitting: submitting ?? this.submitting,
      recipientLoading: recipientLoading ?? this.recipientLoading,
      federationLoading: federationLoading ?? this.federationLoading,
      federationDomain: federationDomain ?? this.federationDomain,
      federationSuggestions:
          federationSuggestions ?? this.federationSuggestions,
      asset: asset ?? this.asset,
      accountId: identical(accountId, _sentinel)
          ? this.accountId
          : accountId as String?,
      prefillName: identical(prefillName, _sentinel)
          ? this.prefillName
          : prefillName as String?,
      error: identical(error, _sentinel) ? this.error : error as String?,
      estNetworkFeeXlm: identical(estNetworkFeeXlm, _sentinel)
          ? this.estNetworkFeeXlm
          : estNetworkFeeXlm as double?,
      destinationHasTrustline: identical(destinationHasTrustline, _sentinel)
          ? this.destinationHasTrustline
          : destinationHasTrustline as bool?,
      resolvedRecipient: identical(resolvedRecipient, _sentinel)
          ? this.resolvedRecipient
          : resolvedRecipient as RecipientAddressModel?,
      resolvedFederation: identical(resolvedFederation, _sentinel)
          ? this.resolvedFederation
          : resolvedFederation as FederationResolveResponse?,
      federationError: identical(federationError, _sentinel)
          ? this.federationError
          : federationError as String?,
      destinationMemoRequired: identical(destinationMemoRequired, _sentinel)
          ? this.destinationMemoRequired
          : destinationMemoRequired as bool?,
      destinationMemoHint: identical(destinationMemoHint, _sentinel)
          ? this.destinationMemoHint
          : destinationMemoHint as String?,
      merchantProfile: identical(merchantProfile, _sentinel)
          ? this.merchantProfile
          : merchantProfile as Map<String, dynamic>?,
    );
  }
}

const Object _sentinel = Object();
