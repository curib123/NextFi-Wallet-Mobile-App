// stellar_swap_service.dart
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'package:next_fi/services/stellar/stellar_base_service.dart';
import 'package:next_fi/services/stellar/stellar_account_service.dart';
import 'package:next_fi/services/stellar/stellar_fee_service.dart';

/// Service for path payments (swaps)
class StellarSwapService extends StellarBaseService {
  final StellarAccountService accountService;
  final StellarFeeService feeService;

  StellarSwapService({
    required this.accountService,
    required this.feeService,
    required StellarSDK sdk,
    StellarSDK? sdkQuickNode,
    String? quickNodeUrlMainnet,
    String? quickNodeUrlTestnet,
    Map<String, String>? quickNodeDefaultHeaders,
  }) : super(
    sdk: sdk,
    sdkQuickNode: sdkQuickNode,
    quickNodeUrlMainnet: quickNodeUrlMainnet,
    quickNodeUrlTestnet: quickNodeUrlTestnet,
    quickNodeDefaultHeaders: quickNodeDefaultHeaders,
  );

  Asset get xlm => accountService.xlm;
  Asset get usdc => accountService.usdc;

  // ──────────────────────────────────────────────────────────────────────────
  // XLM to USDC Swap
  // ──────────────────────────────────────────────────────────────────────────

  Future<String> swapXlmToUsdc({
    required KeyPair keyPair,
    required double sendAmountXlm,
    required double minUsdcOut,
    String? destination,
    String? memoText,
    ProgressCallback? onProgress,
  }) async {
    if (sendAmountXlm <= 0) {
      fail(
        'Please enter a valid amount',
        technicalError: 'Amount: $sendAmountXlm',
        advice: 'Try entering an amount like 10 or 25',
        code: 'INVALID_AMOUNT',
      );
    }
    if (minUsdcOut <= 0) {
      fail(
        'Minimum output must be greater than 0',
        technicalError: 'Min output: $minUsdcOut',
        advice: 'Please set a valid minimum USDC amount to receive',
        code: 'INVALID_MIN_OUTPUT',
      );
    }

    try {
      final self = keyPair.accountId;
      final dest = (destination?.trim().isNotEmpty == true)
          ? toClassicAccountId(destination!.trim())
          : self;

      onProgress?.call('Setting up USDC...');
      await accountService.ensureUsdcTrustline(keyPair, onProgress: onProgress);

      onProgress?.call('Checking destination...');
      if (!await accountExists(dest)) {
        fail(
          'Recipient doesn\'t have a Stellar account yet',
          technicalError: 'Account not found: $dest',
          advice: 'The recipient needs to create their Stellar account first',
          code: 'DESTINATION_NOT_FOUND',
        );
      }

      if (!await accountService.hasUsdcTrustline(dest)) {
        fail(
          'Recipient can\'t receive USDC yet',
          technicalError: 'No USDC trustline for: $dest',
          advice: 'The recipient needs to add USDC to their wallet first',
          code: 'NO_DESTINATION_TRUSTLINE',
        );
      }

      onProgress?.call('Calculating fees...');
      final feeAddr = toClassicAccountId(await feeService.getTransactionFeeAddress());
      final feeStroops = await feeService.getCurrentFeeStroops();
      final feeXlm = fromStroops(feeStroops);

      onProgress?.call('Checking balance...');
      final senderXlmBal = await accountService.getXlmBalance(self);

      const minReserve = 1.5;
      final totalNeeded = sendAmountXlm + feeXlm + minReserve;

      if (senderXlmBal < totalNeeded) {
        fail(
          'Not enough XLM for this swap',
          technicalError: 'Have: ${StellarBaseService.fmt7(senderXlmBal)} XLM | Need: ${StellarBaseService.fmt7(totalNeeded)} XLM',
          advice:
          'Breakdown: ${StellarBaseService.fmt7(sendAmountXlm)} to swap + ${StellarBaseService.fmt7(feeXlm)} network fee + ${StellarBaseService.fmt7(minReserve)} account reserve. You need ${StellarBaseService.fmt7(totalNeeded - senderXlmBal)} more XLM',
          code: 'INSUFFICIENT_BALANCE',
        );
      }

      onProgress?.call('Preparing swap...');
      final acc = await loadAccount(self);

      final needsFeeOp = feeStroops > 0;
      final opCount = needsFeeOp ? 2 : 1;
      final feeXlmNet =
      await feeService.estimateNetworkFeeXlm(opCount: opCount, percentile: 90);
      final perOpStroops = (feeXlmNet * 1e7 / opCount).ceil();

      final opPath = PathPaymentStrictSendOperationBuilder(
        xlm,
        StellarBaseService.fmt7(sendAmountXlm),
        dest,
        usdc,
        StellarBaseService.fmt7(minUsdcOut),
      ).build();

      final tb = TransactionBuilder(acc)
        ..setMaxOperationFee(perOpStroops)
        ..addOperation(opPath);

      if (needsFeeOp) {
        tb.addOperation(
          PaymentOperationBuilder(feeAddr, xlm, StellarBaseService.fmt7(feeXlm)).build(),
        );
      }

      if (memoText?.isNotEmpty == true) {
        tb.addMemo(Memo.text(memoText!));
      }

      final tx = tb.build();
      tx.sign(keyPair, network);

      onProgress?.call('Executing swap...');
      final res = await sdk.submitTransaction(tx);
      if (!res.success) failSubmit(res, prefix: 'Swap failed');

      onProgress?.call('Swap completed successfully!');
      return res.hash!;
    } catch (e) {
      if (e is StellarWalletError) rethrow;
      fail(
        'Unable to swap XLM to USDC',
        technicalError: e,
        advice:
        'The swap may have failed due to price slippage. Try adjusting your minimum output or check market conditions',
      );
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // USDC to XLM Swap
  // ──────────────────────────────────────────────────────────────────────────

  Future<String> swapUsdcToXlm({
    required KeyPair keyPair,
    required double sendAmountUsdc,
    required double minXlmOut,
    String? destination,
    String? memoText,
    ProgressCallback? onProgress,
  }) async {
    if (sendAmountUsdc <= 0) {
      fail(
        'Please enter a valid amount',
        technicalError: 'Amount: $sendAmountUsdc',
        advice: 'Try entering an amount like 10 or 25',
        code: 'INVALID_AMOUNT',
      );
    }
    if (minXlmOut <= 0) {
      fail(
        'Minimum output must be greater than 0',
        technicalError: 'Min output: $minXlmOut',
        advice: 'Please set a valid minimum XLM amount to receive',
        code: 'INVALID_MIN_OUTPUT',
      );
    }

    try {
      final self = keyPair.accountId;
      final dest = (destination?.trim().isNotEmpty == true)
          ? toClassicAccountId(destination!.trim())
          : self;

      onProgress?.call('Checking USDC setup...');
      await accountService.ensureUsdcTrustline(keyPair, onProgress: onProgress);

      onProgress?.call('Checking balance...');
      final senderUsdcBal = await accountService.getUsdcBalance(self);
      if (senderUsdcBal < sendAmountUsdc) {
        fail(
          'Not enough USDC in your wallet',
          technicalError: 'Have: ${StellarBaseService.fmt7(senderUsdcBal)} USDC, Need: ${StellarBaseService.fmt7(sendAmountUsdc)} USDC',
          advice:
          'You need ${StellarBaseService.fmt7(sendAmountUsdc - senderUsdcBal)} more USDC to complete this swap',
          code: 'INSUFFICIENT_USDC',
        );
      }

      onProgress?.call('Calculating fees...');
      final feeAddr = toClassicAccountId(await feeService.getTransactionFeeAddress());
      final feeStroops = await feeService.getCurrentFeeStroops();
      final feeXlm = fromStroops(feeStroops);

      onProgress?.call('Preparing swap...');
      final acc = await loadAccount(self);

      final needsFeeOp = feeStroops > 0;
      final opCount = needsFeeOp ? 2 : 1;
      final feeXlmNet =
      await feeService.estimateNetworkFeeXlm(opCount: opCount, percentile: 90);
      final perOpStroops = (feeXlmNet * 1e7 / opCount).ceil();

      final tb = TransactionBuilder(acc)..setMaxOperationFee(perOpStroops);

      if (dest == self) {
        if (minXlmOut < feeXlm) {
          fail(
            'Swap amount too low to cover fees',
            technicalError: 'Minimum output: ${StellarBaseService.fmt7(minXlmOut)} XLM | Fee required: ${StellarBaseService.fmt7(feeXlm)} XLM',
            advice:
            'The swap needs to receive at least ${StellarBaseService.fmt7(feeXlm)} XLM to cover the transaction fee. Try increasing your swap amount',
            code: 'MIN_OUTPUT_TOO_LOW',
          );
        }

        final opPath = PathPaymentStrictSendOperationBuilder(
          usdc,
          StellarBaseService.fmt7(sendAmountUsdc),
          self,
          xlm,
          StellarBaseService.fmt7(minXlmOut),
        ).build();

        tb
          ..addOperation(opPath)
          ..addOperation(
            PaymentOperationBuilder(feeAddr, xlm, StellarBaseService.fmt7(feeXlm)).build(),
          );
      } else {
        final senderXlmBal = await accountService.getXlmBalance(self);
        if (senderXlmBal < feeXlm) {
          fail(
            'Not enough XLM for transaction fee',
            technicalError: 'Have: ${StellarBaseService.fmt7(senderXlmBal)} XLM, Need: ${StellarBaseService.fmt7(feeXlm)} XLM',
            advice:
            'You need ${StellarBaseService.fmt7(feeXlm - senderXlmBal)} more XLM to pay the network fee for this swap',
            code: 'INSUFFICIENT_XLM_FOR_FEE',
          );
        }

        onProgress?.call('Checking destination...');
        if (!await accountExists(dest)) {
          fail(
            'Recipient doesn\'t have a Stellar account yet',
            technicalError: 'Account not found: $dest',
            advice: 'The recipient needs to create their Stellar account first',
            code: 'DESTINATION_NOT_FOUND',
          );
        }

        final opPath = PathPaymentStrictSendOperationBuilder(
          usdc,
          StellarBaseService.fmt7(sendAmountUsdc),
          dest,
          xlm,
          StellarBaseService.fmt7(minXlmOut),
        ).build();

        tb
          ..addOperation(opPath)
          ..addOperation(
            PaymentOperationBuilder(feeAddr, xlm, StellarBaseService.fmt7(feeXlm)).build(),
          );
      }

      if (memoText?.isNotEmpty == true) {
        tb.addMemo(Memo.text(memoText!));
      }

      final tx = tb.build();
      tx.sign(keyPair, network);

      onProgress?.call('Executing swap...');
      final res = await sdk.submitTransaction(tx);
      if (!res.success) {
        failSubmit(res, prefix: 'Swap failed');
      }

      onProgress?.call('Swap completed successfully!');
      return res.hash!;
    } catch (e) {
      if (e is StellarWalletError) rethrow;
      fail(
        'Unable to swap USDC to XLM',
        technicalError: e,
        advice:
        'The swap may have failed due to price slippage. Try adjusting your minimum output or check market conditions',
      );
    }
  }
}