// stellar_swap_service.dart
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'package:next_fi/core/services/stellar/stellar_account_service.dart';
import 'package:next_fi/core/services/stellar/stellar_base_service.dart';
import 'package:next_fi/core/services/stellar/stellar_fee_service.dart';

/// Service for path payments (swaps).
///
/// Swap fee policy is loaded from backend fee config and deducted from input.
class StellarSwapService extends StellarBaseService {
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
      await feeService.ensureFeeConfigLoaded();
      final swapFeeRate = await feeService.getSwapFeeRate();
      final hasSwapFee = swapFeeRate > 0;

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

      String? feeAddr;
      if (hasSwapFee) {
        onProgress?.call('Loading fee configuration...');
        feeAddr = toClassicAccountId(await feeService.getSwapFeeAddress());
      }

      final actualSwapXlm = sendAmountXlm * (1 - swapFeeRate);
      final swapFeeXlm = sendAmountXlm * swapFeeRate;
      final feePercentLabel = (swapFeeRate * 100).toStringAsFixed(3);

      onProgress?.call('Checking balance...');
      final senderXlmBal = await accountService.getXlmBalance(self);

      if (senderXlmBal < sendAmountXlm) {
        fail(
          'Not enough XLM for this swap',
          technicalError:
              'Have: ${StellarBaseService.fmt7(senderXlmBal)} XLM | '
              'Need: ${StellarBaseService.fmt7(sendAmountXlm)} XLM',
          advice:
              'Breakdown: ${StellarBaseService.fmt7(actualSwapXlm)} to swap + '
              '${StellarBaseService.fmt7(swapFeeXlm)} swap fee ($feePercentLabel%). '
              'You need ${StellarBaseService.fmt7(sendAmountXlm - senderXlmBal)} more XLM',
          code: 'INSUFFICIENT_BALANCE',
        );
      }

      onProgress?.call('Preparing swap...');
      final acc = await loadAccount(self);

      final opCount = hasSwapFee ? 2 : 1;
      final feeXlmNet = await feeService.estimateNetworkFeeXlm(
        opCount: opCount,
        percentile: 90,
      );
      const safetyBufferXlm = 0.0002;
      final totalRequiredXlm = sendAmountXlm + feeXlmNet + safetyBufferXlm;
      if (senderXlmBal < totalRequiredXlm) {
        fail(
          'Not enough XLM for swap and network fees',
          technicalError:
              'Have: ${StellarBaseService.fmt7(senderXlmBal)} XLM | '
              'Need: ${StellarBaseService.fmt7(totalRequiredXlm)} XLM '
              '(send ${StellarBaseService.fmt7(sendAmountXlm)} + net fee ${StellarBaseService.fmt7(feeXlmNet)} + buffer ${StellarBaseService.fmt7(safetyBufferXlm)})',
          advice:
              'Keep extra XLM for network fees. '
              'You need ${StellarBaseService.fmt7(totalRequiredXlm - senderXlmBal)} more XLM.',
          code: 'INSUFFICIENT_BALANCE',
        );
      }
      final perOpStroops = (feeXlmNet * 1e7 / opCount).ceil();

      final tb = TransactionBuilder(acc)
        ..setMaxOperationFee(perOpStroops)
        ..addOperation(
          PathPaymentStrictSendOperationBuilder(
            xlm,
            StellarBaseService.fmt7(actualSwapXlm),
            dest,
            usdc,
            StellarBaseService.fmt7(minUsdcOut),
          ).build(),
        );

      if (hasSwapFee) {
        tb.addOperation(
          PaymentOperationBuilder(
            feeAddr!,
            xlm,
            StellarBaseService.fmt7(swapFeeXlm),
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
        'Unable to swap XLM to USDC',
        technicalError: e,
        advice:
            'The swap may have failed due to price slippage. '
            'Try adjusting your minimum output or check market conditions',
      );
    }
  }

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
      await feeService.ensureFeeConfigLoaded();
      final swapFeeRate = await feeService.getSwapFeeRate();
      final hasSwapFee = swapFeeRate > 0;

      final self = keyPair.accountId;
      final dest = (destination?.trim().isNotEmpty == true)
          ? toClassicAccountId(destination!.trim())
          : self;

      onProgress?.call('Checking USDC setup...');
      await accountService.ensureUsdcTrustline(keyPair, onProgress: onProgress);

      String? feeAddr;
      if (hasSwapFee) {
        onProgress?.call('Loading fee configuration...');
        feeAddr = toClassicAccountId(await feeService.getSwapFeeAddress());
      }

      final actualSwapUsdc = sendAmountUsdc * (1 - swapFeeRate);
      final swapFeeUsdc = sendAmountUsdc * swapFeeRate;
      final feePercentLabel = (swapFeeRate * 100).toStringAsFixed(3);

      onProgress?.call('Checking balance...');
      final senderUsdcBal = await accountService.getUsdcBalance(self);

      if (senderUsdcBal < sendAmountUsdc) {
        fail(
          'Not enough USDC in your wallet',
          technicalError:
              'Have: ${StellarBaseService.fmt7(senderUsdcBal)} USDC | '
              'Need: ${StellarBaseService.fmt7(sendAmountUsdc)} USDC',
          advice:
              'Breakdown: ${StellarBaseService.fmt7(actualSwapUsdc)} to swap + '
              '${StellarBaseService.fmt7(swapFeeUsdc)} swap fee ($feePercentLabel%). '
              'You need ${StellarBaseService.fmt7(sendAmountUsdc - senderUsdcBal)} more USDC',
          code: 'INSUFFICIENT_USDC',
        );
      }

      onProgress?.call('Preparing swap...');
      final acc = await loadAccount(self);

      final opCount = hasSwapFee ? 2 : 1;
      final feeXlmNet = await feeService.estimateNetworkFeeXlm(
        opCount: opCount,
        percentile: 90,
      );
      final senderXlmBal = await accountService.getXlmBalance(self);
      const safetyBufferXlm = 0.0002;
      final requiredXlmForFees = feeXlmNet + safetyBufferXlm;
      if (senderXlmBal < requiredXlmForFees) {
        fail(
          'Not enough XLM for network fees',
          technicalError:
              'Have: ${StellarBaseService.fmt7(senderXlmBal)} XLM | '
              'Need: ${StellarBaseService.fmt7(requiredXlmForFees)} XLM '
              '(net fee ${StellarBaseService.fmt7(feeXlmNet)} + buffer ${StellarBaseService.fmt7(safetyBufferXlm)})',
          advice:
              'USDC swaps still require XLM for network fees. '
              'Please add at least ${StellarBaseService.fmt7(requiredXlmForFees - senderXlmBal)} XLM.',
          code: 'INSUFFICIENT_XLM_FOR_FEES',
        );
      }
      final perOpStroops = (feeXlmNet * 1e7 / opCount).ceil();

      final tb = TransactionBuilder(acc)..setMaxOperationFee(perOpStroops);

      if (dest == self) {
        tb.addOperation(
          PathPaymentStrictSendOperationBuilder(
            usdc,
            StellarBaseService.fmt7(actualSwapUsdc),
            self,
            xlm,
            StellarBaseService.fmt7(minXlmOut),
          ).build(),
        );
        if (hasSwapFee) {
          tb.addOperation(
            PaymentOperationBuilder(
              feeAddr!,
              usdc,
              StellarBaseService.fmt7(swapFeeUsdc),
            ).build(),
          );
        }
      } else {
        onProgress?.call('Checking destination...');
        if (!await accountExists(dest)) {
          fail(
            'Recipient doesn\'t have a Stellar account yet',
            technicalError: 'Account not found: $dest',
            advice: 'The recipient needs to create their Stellar account first',
            code: 'DESTINATION_NOT_FOUND',
          );
        }
        tb.addOperation(
          PathPaymentStrictSendOperationBuilder(
            usdc,
            StellarBaseService.fmt7(actualSwapUsdc),
            dest,
            xlm,
            StellarBaseService.fmt7(minXlmOut),
          ).build(),
        );
        if (hasSwapFee) {
          tb.addOperation(
            PaymentOperationBuilder(
              feeAddr!,
              usdc,
              StellarBaseService.fmt7(swapFeeUsdc),
            ).build(),
          );
        }
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
        'Unable to swap USDC to XLM',
        technicalError: e,
        advice:
            'The swap may have failed due to price slippage. '
            'Try adjusting your minimum output or check market conditions',
      );
    }
  }
}
