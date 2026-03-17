// stellar_swap_service.dart
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'package:next_fi/core/services/stellar/stellar_account_service.dart';
import 'package:next_fi/core/services/stellar/stellar_base_service.dart';
import 'package:next_fi/core/services/stellar/stellar_fee_service.dart';

/// Service for path payments (swaps).
///
/// Swap fee policy is loaded from backend fee config and deducted from input.
class StellarSwapService extends StellarBaseService {
  static const double _safetyBufferXlm = 0.0002;

  final StellarAccountService accountService;
  final StellarFeeService feeService;

  StellarSwapService({
    required this.accountService,
    required this.feeService,
    required super.sdk,
    super.sdkQuickNode,
    super.quickNodeUrlMainnet,
    super.quickNodeUrlTestnet,
    super.quickNodeDefaultHeaders,
  });

  Asset get xlm => accountService.xlm;
  Asset get usdc => accountService.usdc;

  String _assetLabel(Asset asset) {
    if (asset is AssetTypeNative) return 'XLM';
    if (asset is AssetTypeCreditAlphaNum) return asset.code;
    return 'asset';
  }

  Future<double> _trustlineReserveXlm() async {
    final activationMin = await accountService.getLatestAccountActivationMinXlm();
    return activationMin > 0 ? activationMin / 2.0 : 0.5;
  }

  Future<void> _ensureReceiverCanAccept({
    required KeyPair keyPair,
    required String destination,
    required Asset receiving,
    ProgressCallback? onProgress,
  }) async {
    if (receiving is AssetTypeNative) return;

    final self = keyPair.accountId;
    if (destination == self) {
      onProgress?.call('Setting up ${_assetLabel(receiving)}...');
      await accountService.ensureTrustline(
        keyPair,
        receiving,
        onProgress: onProgress,
      );
      return;
    }

    onProgress?.call('Checking destination...');
    if (!await accountExists(destination)) {
      fail(
        'Recipient doesn\'t have a Stellar account yet',
        technicalError: 'Account not found: $destination',
        advice: 'The recipient needs to create their Stellar account first',
        code: 'DESTINATION_NOT_FOUND',
      );
    }
    if (!await accountService.hasTrustline(destination, receiving)) {
      fail(
        'Recipient can\'t receive ${_assetLabel(receiving)} yet',
        technicalError:
            'No ${_assetLabel(receiving)} trustline for: $destination',
        advice:
            'The recipient needs to add ${_assetLabel(receiving)} to their wallet first',
        code: 'NO_DESTINATION_TRUSTLINE',
      );
    }
  }

  Future<void> _ensureAutoTrustlineBudget({
    required String accountId,
    required Asset sending,
    required Asset receiving,
    required double sendAmount,
    required int swapOpCount,
    required bool needsTrustline,
  }) async {
    if (!needsTrustline) return;

    final breakdown = await accountService.getXlmBalanceBreakdown(accountId);
    final spendableXlm = (breakdown['spendable'] ?? 0).toDouble();
    final swapFeeXlm = await feeService.estimateNetworkFeeXlm(
      opCount: swapOpCount,
      percentile: 90,
    );
    final trustlineFeeXlm = await feeService.estimateNetworkFeeXlm(
      opCount: 1,
      percentile: 90,
    );
    final trustlineReserveXlm = await _trustlineReserveXlm();

    final nonSwapBudget =
        swapFeeXlm + trustlineFeeXlm + trustlineReserveXlm + _safetyBufferXlm;
    final totalRequiredXlm = sending is AssetTypeNative
        ? sendAmount + nonSwapBudget
        : nonSwapBudget;

    if (spendableXlm >= totalRequiredXlm) return;

    final shortfall = totalRequiredXlm - spendableXlm;
    fail(
      'Not enough XLM to auto-add ${_assetLabel(receiving)} and complete this swap',
      technicalError:
          'Spendable XLM: ${StellarBaseService.fmt7(spendableXlm)} | '
          'Required XLM: ${StellarBaseService.fmt7(totalRequiredXlm)} | '
          'Swap fee: ${StellarBaseService.fmt7(swapFeeXlm)} | '
          'Trustline fee: ${StellarBaseService.fmt7(trustlineFeeXlm)} | '
          'Trustline reserve: ${StellarBaseService.fmt7(trustlineReserveXlm)} | '
          'Sending asset: ${_assetLabel(sending)} | '
          'Receiving asset: ${_assetLabel(receiving)}',
      advice:
          'Add at least ${StellarBaseService.fmt7(shortfall)} XLM so the wallet can create the trustline automatically before swapping.',
      code: 'INSUFFICIENT_XLM_FOR_TRUSTLINE',
    );
  }

  Future<String> swapAssets({
    required KeyPair keyPair,
    required Asset sending,
    required Asset receiving,
    required double sendAmount,
    required double minOut,
    String? destination,
    String? memoText,
    ProgressCallback? onProgress,
  }) async {
    if (sendAmount <= 0) {
      fail(
        'Please enter a valid amount',
        technicalError: 'Amount: $sendAmount',
        advice: 'Try entering an amount like 10 or 25',
        code: 'INVALID_AMOUNT',
      );
    }
    if (minOut <= 0) {
      fail(
        'Minimum output must be greater than 0',
        technicalError: 'Min output: $minOut',
        advice: 'Please set a valid minimum receive amount',
        code: 'INVALID_MIN_OUTPUT',
      );
    }

    try {
      await feeService.ensureFeeConfigLoaded();
      final swapFeeRate = await feeService.getSwapFeeRate();
      final hasSwapFee = swapFeeRate > 0;
      final swapOpCount = hasSwapFee ? 2 : 1;

      final self = keyPair.accountId;
      final dest = (destination?.trim().isNotEmpty == true)
          ? toClassicAccountId(destination!.trim())
          : self;
      final needsReceiverTrustline = dest == self &&
          receiving is! AssetTypeNative &&
          !await accountService.hasTrustline(self, receiving);

      await _ensureAutoTrustlineBudget(
        accountId: self,
        sending: sending,
        receiving: receiving,
        sendAmount: sendAmount,
        swapOpCount: swapOpCount,
        needsTrustline: needsReceiverTrustline,
      );

      await _ensureReceiverCanAccept(
        keyPair: keyPair,
        destination: dest,
        receiving: receiving,
        onProgress: onProgress,
      );

      String? feeAddr;
      if (hasSwapFee) {
        onProgress?.call('Loading fee configuration...');
        feeAddr = toClassicAccountId(await feeService.getSwapFeeAddress());
      }

      final actualSwapAmount = sendAmount * (1 - swapFeeRate);
      final swapFeeAmount = sendAmount * swapFeeRate;
      final feePercentLabel = (swapFeeRate * 100).toStringAsFixed(3);
      final sendLabel = _assetLabel(sending);

      onProgress?.call('Checking balance...');
      final senderBalance = await accountService.getAssetBalance(self, sending);

      if (senderBalance < sendAmount) {
        fail(
          'Not enough $sendLabel in your wallet',
          technicalError:
              'Have: ${StellarBaseService.fmt7(senderBalance)} $sendLabel | '
              'Need: ${StellarBaseService.fmt7(sendAmount)} $sendLabel',
          advice:
              'Breakdown: ${StellarBaseService.fmt7(actualSwapAmount)} to swap + '
              '${StellarBaseService.fmt7(swapFeeAmount)} swap fee ($feePercentLabel%). '
              'You need ${StellarBaseService.fmt7(sendAmount - senderBalance)} more $sendLabel',
          code: 'INSUFFICIENT_BALANCE',
        );
      }

      onProgress?.call('Preparing swap...');
      final acc = await loadAccount(self);

      final feeXlmNet = await feeService.estimateNetworkFeeXlm(
        opCount: swapOpCount,
        percentile: 90,
      );
      final senderXlmBal = await accountService.getXlmBalance(self);

      if (sending is AssetTypeNative) {
        final totalRequiredXlm = sendAmount + feeXlmNet + _safetyBufferXlm;
        if (senderXlmBal < totalRequiredXlm) {
          fail(
            'Not enough XLM for swap and network fees',
            technicalError:
                'Have: ${StellarBaseService.fmt7(senderXlmBal)} XLM | '
                'Need: ${StellarBaseService.fmt7(totalRequiredXlm)} XLM '
                '(send ${StellarBaseService.fmt7(sendAmount)} + net fee ${StellarBaseService.fmt7(feeXlmNet)} + buffer ${StellarBaseService.fmt7(_safetyBufferXlm)})',
            advice:
                'Keep extra XLM for network fees. '
                'You need ${StellarBaseService.fmt7(totalRequiredXlm - senderXlmBal)} more XLM.',
            code: 'INSUFFICIENT_BALANCE',
          );
        }
      } else {
        final requiredXlmForFees = feeXlmNet + _safetyBufferXlm;
        if (senderXlmBal < requiredXlmForFees) {
          fail(
            'Not enough XLM for network fees',
            technicalError:
                'Have: ${StellarBaseService.fmt7(senderXlmBal)} XLM | '
                'Need: ${StellarBaseService.fmt7(requiredXlmForFees)} XLM '
                '(net fee ${StellarBaseService.fmt7(feeXlmNet)} + buffer ${StellarBaseService.fmt7(_safetyBufferXlm)})',
            advice:
                '$sendLabel swaps still require XLM for network fees. '
                'Please add at least ${StellarBaseService.fmt7(requiredXlmForFees - senderXlmBal)} XLM.',
            code: 'INSUFFICIENT_XLM_FOR_FEES',
          );
        }
      }

      final perOpStroops = (feeXlmNet * 1e7 / swapOpCount).ceil();

      final tb = TransactionBuilder(acc)
        ..setMaxOperationFee(perOpStroops)
        ..addOperation(
          PathPaymentStrictSendOperationBuilder(
            sending,
            StellarBaseService.fmt7(actualSwapAmount),
            dest,
            receiving,
            StellarBaseService.fmt7(minOut),
          ).build(),
        );

      if (hasSwapFee) {
        tb.addOperation(
          PaymentOperationBuilder(
            feeAddr!,
            sending,
            StellarBaseService.fmt7(swapFeeAmount),
          ).build(),
        );
      }

      if (memoText?.isNotEmpty == true) tb.addMemo(Memo.text(memoText!));

      final tx = tb.build()..sign(keyPair, network);

      onProgress?.call('Executing swap...');
      final res = await sdk.submitTransaction(tx);
      if (!res.success) failSubmit(res, prefix: 'Swap failed');

      onProgress?.call('Swap completed successfully!');
      return res.hash!;
    } catch (e) {
      if (e is StellarWalletError) rethrow;
      fail(
        'Unable to swap ${_assetLabel(sending)} to ${_assetLabel(receiving)}',
        technicalError: e,
        advice:
            'The swap may have failed due to price slippage. '
            'Try adjusting your minimum output or check market conditions',
      );
    }
  }

  Future<String> swapXlmToUsdc({
    required KeyPair keyPair,
    required double sendAmountXlm,
    required double minUsdcOut,
    String? destination,
    String? memoText,
    ProgressCallback? onProgress,
  }) => swapAssets(
    keyPair: keyPair,
    sending: xlm,
    receiving: usdc,
    sendAmount: sendAmountXlm,
    minOut: minUsdcOut,
    destination: destination,
    memoText: memoText,
    onProgress: onProgress,
  );

  Future<String> swapUsdcToXlm({
    required KeyPair keyPair,
    required double sendAmountUsdc,
    required double minXlmOut,
    String? destination,
    String? memoText,
    ProgressCallback? onProgress,
  }) => swapAssets(
    keyPair: keyPair,
    sending: usdc,
    receiving: xlm,
    sendAmount: sendAmountUsdc,
    minOut: minXlmOut,
    destination: destination,
    memoText: memoText,
    onProgress: onProgress,
  );
}
