import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:next_fi/app/config/app_providers.dart';
import 'package:next_fi/core/models/asset_model.dart';
import 'package:next_fi/core/services/assets/asset_stellar_helper.dart';
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
  int _federationResolveSeq = 0;

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
      if (state.recipientInput.isNotEmpty) {
        await onRecipientInputChanged(state.recipientInput);
      }
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

  Future<void> onRecipientInputChanged(String rawInput) async {
    final input = rawInput.trim();
    final suggestions = _buildFederationSuggestions(input);
    state = state.copyWith(
      recipientInput: input,
      destinationAddress: _looksLikeStellarPk(input) ? input : '',
      resolvedRecipient: _looksLikeStellarPk(input)
          ? state.resolvedRecipient
          : null,
      resolvedFederation: null,
      federationError: null,
      federationSuggestions: suggestions,
      recipientLoading: false,
      federationLoading: false,
      merchantProfile: null,
    );

    if (input.isEmpty) {
      state = state.copyWith(
        destinationAddress: '',
        resolvedRecipient: null,
        resolvedFederation: null,
        federationError: null,
        destinationHasTrustline: null,
        merchantProfile: null,
      );
      return;
    }

    if (_looksLikeStellarPk(input)) {
      await _lookupRecipient(input);
      _debounceCheckTrustline();
      return;
    }

    if (_looksLikeFederation(input)) {
      await _resolveFederation(input);
      return;
    }

    _debounceCheckTrustline();
  }

  void applyPickedRecipient(String address, {String? displayName}) {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return;
    state = state.copyWith(
      recipientInput: trimmed,
      destinationAddress: trimmed,
      prefillName: displayName?.trim().isEmpty == true
          ? null
          : displayName?.trim(),
      resolvedFederation: null,
      federationError: null,
      federationSuggestions: _buildFederationSuggestions(trimmed),
    );
    unawaited(_lookupRecipient(trimmed));
    _debounceCheckTrustline();
  }

  Future<String> submit() async {
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

  List<String> _buildFederationSuggestions(String input) {
    final domain = state.federationDomain.trim();
    if (domain.isEmpty ||
        input.isEmpty ||
        input.contains('*') ||
        !_looksLikeFederationAliasInput(input)) {
      return const [];
    }
    return ['${input.toLowerCase()}*$domain'];
  }

  Future<void> _resolveFederation(String federationAddress) async {
    final requestId = ++_federationResolveSeq;
    state = state.copyWith(
      federationLoading: true,
      federationError: null,
      resolvedFederation: null,
      recipientLoading: true,
      resolvedRecipient: null,
      destinationAddress: '',
      destinationHasTrustline: null,
      merchantProfile: null,
    );

    try {
      final resolved = await ref
          .read(sendFederationAddressServiceProvider)
          .resolveByName(federationAddress, domain: state.federationDomain);
      if (requestId != _federationResolveSeq) return;
      final accountId = resolved.accountId.trim();
      if (accountId.isEmpty || !_looksLikeStellarPk(accountId)) {
        throw StateError('Resolved federation has no valid Stellar account id');
      }
      state = state.copyWith(
        resolvedFederation: resolved,
        destinationAddress: accountId,
        federationLoading: false,
      );
      await _lookupRecipient(accountId);
      _debounceCheckTrustline();
    } catch (_) {
      if (requestId != _federationResolveSeq) return;
      state = state.copyWith(
        federationLoading: false,
        recipientLoading: false,
        resolvedFederation: null,
        destinationAddress: '',
        federationError: 'Federation not found or unavailable.',
        merchantProfile: null,
      );
    }
  }

  Future<void> _lookupRecipient(String address) async {
    state = state.copyWith(recipientLoading: true, resolvedRecipient: null);
    try {
      await ref.read(contactListProvider.notifier).ensureLoaded();
      final match = ref.read(contactListProvider).byAddress(address);
      state = state.copyWith(
        resolvedRecipient: match,
        recipientLoading: false,
        prefillName: match?.name ?? state.prefillName,
      );
    } catch (_) {
      state = state.copyWith(recipientLoading: false);
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
    _debounce = Timer(
      const Duration(milliseconds: 300),
      _checkTrustlineIfNeeded,
    );
  }

  Future<void> _checkTrustlineIfNeeded() async {
    final destination = state.destinationAddress.trim();
    if (!_looksLikeStellarPk(destination) || !state.requiresTrustline) {
      state = state.copyWith(destinationHasTrustline: null, checking: false);
      return;
    }
    state = state.copyWith(checking: true, destinationHasTrustline: null);
    try {
      final hasTrustline = await _service.hasTrustline(
        destination,
        AssetStellarHelper.toStellarAsset(state.asset),
      );
      state = state.copyWith(
        checking: false,
        destinationHasTrustline: hasTrustline,
      );
    } catch (_) {
      state = state.copyWith(checking: false, destinationHasTrustline: null);
    }
  }

  bool _looksLikeStellarPk(String value) =>
      value.isNotEmpty && value.startsWith('G') && value.length == 56;

  bool _looksLikeFederation(String value) =>
      RegExp(r'^[^*\s]+\*[^*\s]+$').hasMatch(value);

  bool _looksLikeFederationAliasInput(String value) =>
      RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(value);

  double _floor7(double value) => (value * 1e7).floor() / 1e7;
}

