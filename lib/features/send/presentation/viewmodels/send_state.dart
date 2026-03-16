import 'package:next_fi/features/contact/data/models/recipient_address_model.dart';
import 'package:next_fi/features/send/data/models/send_token.dart';
import 'package:next_fi/core/services/federation_address/models/federation_address_models.dart';

class SendControllerArgs {
  const SendControllerArgs({
    required this.address,
    required this.token,
    required this.balance,
    this.prefillAddress,
    this.prefillName,
  });

  final String address;
  final String token;
  final double balance;
  final String? prefillAddress;
  final String? prefillName;

  SendToken get sendToken =>
      token.toUpperCase() == 'XLM' ? SendToken.xlm : SendToken.usdc;

  @override
  bool operator ==(Object other) {
    return other is SendControllerArgs &&
        other.address == address &&
        other.token == token &&
        other.balance == balance &&
        other.prefillAddress == prefillAddress &&
        other.prefillName == prefillName;
  }

  @override
  int get hashCode => Object.hash(
    address,
    token,
    balance,
    prefillAddress,
    prefillName,
  );
}

class SendState {
  const SendState({
    required this.token,
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
    this.accountId,
    this.prefillName,
    this.error,
    this.estNetworkFeeXlm,
    this.destHasUsdcTL,
    this.resolvedRecipient,
    this.resolvedFederation,
    this.federationError,
  });

  factory SendState.initial(SendControllerArgs args, String federationDomain) {
    final recipientInput = (args.prefillAddress ?? '').trim();
    return SendState(
      token: args.sendToken,
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
      prefillName: args.prefillName?.trim().isEmpty == true
          ? null
          : args.prefillName?.trim(),
    );
  }

  final SendToken token;
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
  final String? accountId;
  final String? prefillName;
  final String? error;
  final double? estNetworkFeeXlm;
  final bool? destHasUsdcTL;
  final RecipientAddressModel? resolvedRecipient;
  final FederationResolveResponse? resolvedFederation;
  final String? federationError;

  bool get isXlm => token == SendToken.xlm;
  double get networkFee => estNetworkFeeXlm ?? 0;
  String? get recipientLabel => resolvedRecipient?.name ?? prefillName;

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
      return 'Amount exceeds USDC balance';
    }
    if (destHasUsdcTL == false) return 'Recipient has no USDC trustline';
    return null;
  }

  SendState copyWith({
    SendToken? token,
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
    Object? accountId = _sentinel,
    Object? prefillName = _sentinel,
    Object? error = _sentinel,
    Object? estNetworkFeeXlm = _sentinel,
    Object? destHasUsdcTL = _sentinel,
    Object? resolvedRecipient = _sentinel,
    Object? resolvedFederation = _sentinel,
    Object? federationError = _sentinel,
  }) {
    return SendState(
      token: token ?? this.token,
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
      federationSuggestions: federationSuggestions ?? this.federationSuggestions,
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
      destHasUsdcTL: identical(destHasUsdcTL, _sentinel)
          ? this.destHasUsdcTL
          : destHasUsdcTL as bool?,
      resolvedRecipient: identical(resolvedRecipient, _sentinel)
          ? this.resolvedRecipient
          : resolvedRecipient as RecipientAddressModel?,
      resolvedFederation: identical(resolvedFederation, _sentinel)
          ? this.resolvedFederation
          : resolvedFederation as FederationResolveResponse?,
      federationError: identical(federationError, _sentinel)
          ? this.federationError
          : federationError as String?,
    );
  }
}

const Object _sentinel = Object();
