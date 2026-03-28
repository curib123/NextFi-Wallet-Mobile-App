import 'package:next_fi/features/contact/data/models/recipient_address_model.dart';
import 'package:next_fi/core/models/asset_model.dart';
import 'package:next_fi/core/recipient_input/recipient_flow_controller.dart';

class SendControllerArgs {
  const SendControllerArgs({
    required this.address,
    required this.assetId,
    required this.balance,
    this.prefillAddress,
    this.prefillName,
    this.prefillRecipient,
    this.initialRecipientMode,
  });

  final String address;
  final String assetId;
  final double balance;
  final String? prefillAddress;
  final String? prefillName;
  final RecipientAddressModel? prefillRecipient;
  final RecipientInputMode? initialRecipientMode;

  @override
  bool operator ==(Object other) {
    return other is SendControllerArgs &&
        other.address == address &&
        other.assetId == assetId &&
        other.balance == balance &&
        other.prefillAddress == prefillAddress &&
        other.prefillName == prefillName &&
        other.prefillRecipient?.id == prefillRecipient?.id &&
        other.prefillRecipient?.address == prefillRecipient?.address &&
        other.initialRecipientMode == initialRecipientMode;
  }

  @override
  int get hashCode => Object.hash(
    address,
    assetId,
    balance,
    prefillAddress,
    prefillName,
    prefillRecipient?.id,
    prefillRecipient?.address,
    initialRecipientMode,
  );
}

class SendState {
  const SendState({
    required this.assetId,
    required this.senderAddress,
    required this.senderBalanceToken,
    required this.recipient,
    required this.typedAmount,
    required this.memo,
    required this.loading,
    required this.checking,
    required this.submitting,
    required this.asset,
    this.accountId,
    this.prefillName,
    this.error,
    this.estNetworkFeeXlm,
    this.destinationHasTrustline,
    this.destinationMemoRequired,
    this.destinationMemoHint,
    this.merchantProfile,
  });

  factory SendState.initial(
    SendControllerArgs args,
    String federationDomain,
    AssetModel asset,
  ) {
    final recipient = _buildInitialRecipientState(args, federationDomain);
    return SendState(
      assetId: args.assetId,
      senderAddress: args.address,
      senderBalanceToken: args.balance,
      recipient: recipient,
      typedAmount: 0,
      memo: '',
      loading: true,
      checking: false,
      submitting: false,
      asset: asset,
      prefillName: args.prefillName?.trim().isEmpty == true
          ? null
          : args.prefillName?.trim(),
    );
  }

  static RecipientInputState _buildInitialRecipientState(
    SendControllerArgs args,
    String federationDomain,
  ) {
    final prefillAddress = (args.prefillAddress ?? '').trim();
    final prefillRecipient = args.prefillRecipient;
    final mode =
        args.initialRecipientMode ??
        (prefillRecipient != null
            ? RecipientInputMode.savedRecipient
            : RecipientInputParser.isFederationAddress(prefillAddress)
            ? RecipientInputMode.federation
            : RecipientInputParser.isStellarPublicAddress(prefillAddress)
            ? RecipientInputMode.publicAddress
            : RecipientInputMode.publicAddress);

    return RecipientInputState.initial(
      federationDomain: federationDomain,
      mode: mode,
      savedRecipient: prefillRecipient,
      scannedRawValue: mode == RecipientInputMode.scannedQr
          ? prefillAddress
          : '',
      manualPublicAddress: mode == RecipientInputMode.publicAddress
          ? prefillAddress
          : '',
      federationInput: mode == RecipientInputMode.federation
          ? prefillAddress
          : '',
    );
  }

  final String assetId;
  final String senderAddress;
  final double senderBalanceToken;
  final RecipientInputState recipient;
  final double typedAmount;
  final String memo;
  final bool loading;
  final bool checking;
  final bool submitting;
  final AssetModel asset;
  final String? accountId;
  final String? prefillName;
  final String? error;
  final double? estNetworkFeeXlm;
  final bool? destinationHasTrustline;
  final bool? destinationMemoRequired;
  final String? destinationMemoHint;
  final Map<String, dynamic>? merchantProfile;

  bool get isXlm => asset.isNative;
  bool get requiresTrustline => asset.requiresTrustline;
  double get networkFee => estNetworkFeeXlm ?? 0;
  String? get recipientLabel => recipient.activeRecipient?.name ?? prefillName;
  String get assetSymbol => asset.symbol.toUpperCase();
  String get assetName => asset.name;
  String get destinationAddress => recipient.finalDestinationAddress ?? '';

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
    RecipientInputState? recipient,
    double? typedAmount,
    String? memo,
    bool? loading,
    bool? checking,
    bool? submitting,
    AssetModel? asset,
    Object? accountId = _sentinel,
    Object? prefillName = _sentinel,
    Object? error = _sentinel,
    Object? estNetworkFeeXlm = _sentinel,
    Object? destinationHasTrustline = _sentinel,
    Object? destinationMemoRequired = _sentinel,
    Object? destinationMemoHint = _sentinel,
    Object? merchantProfile = _sentinel,
  }) {
    return SendState(
      assetId: assetId ?? this.assetId,
      senderAddress: senderAddress ?? this.senderAddress,
      senderBalanceToken: senderBalanceToken ?? this.senderBalanceToken,
      recipient: recipient ?? this.recipient,
      typedAmount: typedAmount ?? this.typedAmount,
      memo: memo ?? this.memo,
      loading: loading ?? this.loading,
      checking: checking ?? this.checking,
      submitting: submitting ?? this.submitting,
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
