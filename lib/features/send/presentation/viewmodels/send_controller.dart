import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:next_fi/app/config/app_providers.dart';
import 'package:next_fi/core/models/asset_model.dart';
import 'package:next_fi/core/recipient_input/recipient_flow_controller.dart';
import 'package:next_fi/core/services/assets/asset_stellar_helper.dart';
import 'package:next_fi/features/contact/data/models/recipient_address_model.dart';
import 'package:next_fi/features/contact/presentation/viewmodels/contact_list_notifier.dart';
import 'package:next_fi/features/send/presentation/viewmodels/send_state.dart';
import 'package:next_fi/app/viewmodels/seed_keypair_vm.dart';
import 'package:next_fi/core/services/federation_address/federation_address_core_service.dart';
import 'package:next_fi/core/services/stellar/stellar_wallet_services.dart';

final sendFederationAddressServiceProvider =
    Provider<FederationAddressCoreService>(
      (Ref ref) => FederationAddressCoreService.I,
    );

final sendFederationDomainProvider = Provider<String>(
  (Ref ref) => FederationAddressCoreService.defaultDomain,
);

final sendControllerProvider = NotifierProvider.autoDispose
    .family<SendController, SendState, SendControllerArgs>(SendController.new);

class SendController extends Notifier<SendState> {
  SendController(this.args);

  final SendControllerArgs args;
  StreamSubscription? _feeSub;
  Timer? _debounce;
  RecipientFlowController? _recipientFlow;
  int _trustlineCheckSeq = 0;

  @override
  SendState build() {
    ref.onDispose(() {
      _feeSub?.cancel();
      _debounce?.cancel();
    });
    final asset = _resolveAsset();
    final initial = SendState.initial(
      args,
      ref.read(sendFederationDomainProvider),
      asset,
    );
    _recipientFlow = RecipientFlowController(
      initialState: initial.recipient,
      lookupRecipient: _lookupRecipientMatch,
      resolveFederation: (String federationAddress, {required String domain}) {
        return ref
            .read(sendFederationAddressServiceProvider)
            .resolveByName(federationAddress, domain: domain);
      },
      onStateChanged: _onRecipientStateChanged,
    );
    Future.microtask(_start);
    return initial;
  }

  StellarWalletServices get _service => ref.read(stellarWalletServiceProvider);
  SeedKeypairVM get _seedVM => ref.read(seedKeypairProvider);
  AssetModel _resolveAsset() {
    final assetVm = ref.read(assetVmProvider);
    return assetVm.findAsset(args.assetId) ??
        assetVm.assets.firstWhere((asset) => asset.isNative);
  }

  Future<void> _start() async {
    try {
      final keyPair = await _seedVM.deriveKeyPair();
      _resubscribeFeeStream();
      final fee = await _estimateFee();
      final liveBalance = await _refreshLiveSenderBalance();
      state = state.copyWith(
        accountId: keyPair.accountId,
        estNetworkFeeXlm: fee,
        senderBalanceToken: liveBalance,
        loading: false,
        error: null,
      );
      await _recipientFlow?.initialize();
    } catch (_) {
      state = state.copyWith(loading: false, error: 'No wallet found.');
    }
  }

  void setTypedAmount(double value) {
    state = state.copyWith(typedAmount: value.clamp(0, double.infinity));
  }

  void setMemo(String value) {
    state = state.copyWith(memo: value);
  }

  Future<void> refreshFees() async {
    _resubscribeFeeStream();
    final fee = await _estimateFee();
    state = state.copyWith(estNetworkFeeXlm: fee);
  }

  Future<void> refreshRecipientState() async {
    await _recipientFlow?.initialize();
  }

  Future<void> setRecipientMode(RecipientInputMode mode) async {
    await _recipientFlow?.switchMode(mode);
  }

  Future<void> setManualPublicAddress(String value) async {
    await _recipientFlow?.setManualPublicAddress(value);
  }

  Future<void> setFederationInput(String value) async {
    await _recipientFlow?.setFederationInput(value);
  }

  Future<void> selectSavedRecipient(RecipientAddressModel? recipient) async {
    state = state.copyWith(prefillName: recipient?.name ?? state.prefillName);
    await _recipientFlow?.selectSavedRecipient(recipient);
  }

  Future<void> applyScannedValue(String rawValue) async {
    await _recipientFlow?.setScannedValue(rawValue);
  }

  Future<void> clearFederationSelection() async {
    await _recipientFlow?.clearFederationSelection();
  }

  Future<String> submit() async {
    if (state.submitting) {
      throw StateError('A send transaction is already being submitted.');
    }

    final reason = state.blockingReason;
    if (reason != null) throw StateError(reason);

    state = state.copyWith(submitting: true);
    try {
      await refreshFees();
      final keyPair = await _seedVM.deriveKeyPair();
      final expectedSender = state.senderAddress.trim();
      if (expectedSender.isNotEmpty &&
          expectedSender.startsWith('G') &&
          expectedSender.length == 56 &&
          keyPair.accountId != expectedSender) {
        throw StateError(
          'Active wallet mismatch. Expected sender: $expectedSender, '
          'Active signer: ${keyPair.accountId}. Please reopen Send from the current wallet.',
        );
      }

      final destination = state.destinationAddress.trim();
      final memo = state.memo.trim().isEmpty ? null : state.memo.trim();
      late final String txId;

      if (state.isXlm) {
        final liveBreakdown = await _service
            .getXlmBalanceBreakdown(keyPair.accountId)
            .catchError((_) => <String, double>{});
        final spendable =
            (liveBreakdown['spendable'] ?? state.senderBalanceToken).toDouble();
        final totalNeeded = state.totalDeductFromBalance;
        if (totalNeeded > spendable + 1e-9) {
          state = state.copyWith(senderBalanceToken: spendable);
          throw StateError(
            'Insufficient spendable XLM. '
            'Spendable: ${_floor7(spendable).toStringAsFixed(7)} XLM, '
            'Required (amount + fee): ${_floor7(totalNeeded).toStringAsFixed(7)} XLM.',
          );
        }
        txId = await _service.sendXlm(
          keyPair: keyPair,
          destination: destination,
          amount: state.typedAmount,
          memoText: memo,
        );
      } else {
        txId = await _service.sendAsset(
          keyPair: keyPair,
          destination: destination,
          asset: AssetStellarHelper.toStellarAsset(state.asset),
          amount: state.typedAmount,
          memoText: memo,
        );
      }

      final refreshedBalance = await _refreshLiveSenderBalance();
      state = state.copyWith(
        senderBalanceToken: refreshedBalance,
        typedAmount: 0,
        memo: '',
        submitting: false,
      );
      return txId;
    } catch (e) {
      state = state.copyWith(submitting: false);
      rethrow;
    }
  }

  Future<RecipientAddressModel?> _lookupRecipientMatch(String address) async {
    try {
      await ref.read(contactListProvider.notifier).ensureLoaded();
      return ref.read(contactListProvider).byAddress(address);
    } catch (_) {
      return null;
    }
  }

  Future<double> _estimateFee() async {
    try {
      return await _service.estimateNetworkFeeXlm(opCount: 1, percentile: 90);
    } catch (_) {
      return state.estNetworkFeeXlm ?? 0;
    }
  }

  void _resubscribeFeeStream() {
    _feeSub?.cancel();
    _feeSub = _service.feeEstimateStream(opCount: 1, percentile: 90).listen((
      fee,
    ) {
      state = state.copyWith(estNetworkFeeXlm: fee.totalXlm);
    }, onError: (_) {});
  }

  Future<double> _refreshLiveSenderBalance() async {
    final id = (state.accountId ?? state.senderAddress).trim();
    if (id.isEmpty) return state.senderBalanceToken;
    try {
      return await _service.getAssetBalance(
        id,
        AssetStellarHelper.toStellarAsset(state.asset),
      );
    } catch (_) {
      return state.senderBalanceToken;
    }
  }

  void _debounceCheckTrustline() {
    _debounce?.cancel();
    final requestId = ++_trustlineCheckSeq;
    final destination = state.destinationAddress.trim();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _checkTrustlineIfNeeded(requestId, destination),
    );
  }

  Future<void> _checkTrustlineIfNeeded(
    int requestId,
    String destination,
  ) async {
    if (requestId != _trustlineCheckSeq) return;
    if (!RecipientInputParser.isStellarPublicAddress(destination) ||
        !state.requiresTrustline) {
      state = state.copyWith(destinationHasTrustline: null, checking: false);
      return;
    }
    state = state.copyWith(checking: true, destinationHasTrustline: null);
    try {
      final hasTrustline = await _service.hasTrustline(
        destination,
        AssetStellarHelper.toStellarAsset(state.asset),
      );
      if (requestId != _trustlineCheckSeq) return;
      state = state.copyWith(
        checking: false,
        destinationHasTrustline: hasTrustline,
      );
    } catch (_) {
      if (requestId != _trustlineCheckSeq) return;
      state = state.copyWith(checking: false, destinationHasTrustline: null);
    }
  }

  void _onRecipientStateChanged(RecipientInputState recipientState) {
    final previousDestination = state.recipient.finalDestinationAddress;
    final nextDestination = recipientState.finalDestinationAddress;
    state = state.copyWith(
      recipient: recipientState,
      destinationHasTrustline: previousDestination == nextDestination
          ? state.destinationHasTrustline
          : null,
      merchantProfile: previousDestination == nextDestination
          ? state.merchantProfile
          : null,
    );
    if (previousDestination != nextDestination) {
      _debounceCheckTrustline();
    }
  }

  double _floor7(double value) => (value * 1e7).floor() / 1e7;
}
