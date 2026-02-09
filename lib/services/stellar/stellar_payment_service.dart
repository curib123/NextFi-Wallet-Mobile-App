// stellar_payment_service.dart
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'package:next_fi/services/stellar/stellar_base_service.dart';
import 'package:next_fi/services/stellar/stellar_account_service.dart';
import 'package:next_fi/services/stellar/stellar_fee_service.dart';

/// Service for XLM and USDC payments
class StellarPaymentService extends StellarBaseService {
  final StellarAccountService accountService;
  final StellarFeeService feeService;

  StellarPaymentService({
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
  // XLM Payments
  // ──────────────────────────────────────────────────────────────────────────

  Future<List<String>> sendXlmWithFee({
    required KeyPair keyPair,
    required String destination,
    required double amount,
    String? memoText,
    ProgressCallback? onProgress,
  }) async {
    if (amount <= 0) {
      fail(
        'Please enter a valid amount',
        technicalError: 'Amount: $amount',
        advice: 'Try entering an amount like 10 or 25.50',
        code: 'INVALID_AMOUNT',
      );
    }

    try {
      onProgress?.call('Validating address...');
      final dest = toClassicAccountId(destination);
      final feeAddr = toClassicAccountId(await feeService.getTransactionFeeAddress());

      onProgress?.call('Calculating fees...');
      final feeStroops = await feeService.getCurrentFeeStroops();
      final feeXlm = fromStroops(feeStroops);
      final totalStroops = toStroops(amount);

      if (totalStroops <= feeStroops) {
        fail(
          'Amount is too small to send',
          technicalError: 'Amount must be greater than fee: ${StellarBaseService.fmt7(feeXlm)} XLM',
          advice:
          'Please enter an amount greater than ${StellarBaseService.fmt7(feeXlm)} XLM to cover the transaction fee',
          code: 'AMOUNT_TOO_SMALL',
        );
      }

      final recvXlm = fromStroops(totalStroops - feeStroops);

      onProgress?.call('Loading account...');
      final acc = await loadAccount(keyPair.accountId);

      final needsFeeOp = feeStroops > 0;
      final opCount = needsFeeOp ? 2 : 1;
      final feeXlmNet =
      await feeService.estimateNetworkFeeXlm(opCount: opCount, percentile: 90);
      final perOpStroops = (feeXlmNet * 1e7 / opCount).ceil();

      final tb = TransactionBuilder(acc)..setMaxOperationFee(perOpStroops);

      onProgress?.call('Checking destination...');
      final destExists = await accountExists(dest);
      if (destExists) {
        tb.addOperation(
          PaymentOperationBuilder(dest, xlm, StellarBaseService.fmt7(recvXlm)).build(),
        );
      } else {
        if (recvXlm < 1.0) {
          fail(
            'Cannot create new account with this amount',
            technicalError:
            'Need 1 XLM minimum, but only ${StellarBaseService.fmt7(recvXlm)} XLM available after fees',
            advice:
            'New Stellar accounts need at least 1 XLM. Try sending ${StellarBaseService.fmt7(1.0 + feeXlm)} XLM or more',
            code: 'INSUFFICIENT_FOR_ACCOUNT_CREATION',
          );
        }
        tb.addOperation(
          CreateAccountOperationBuilder(dest, StellarBaseService.fmt7(recvXlm)).build(),
        );
      }

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

      onProgress?.call('Sending transaction...');
      final res = await _submitWithFallback(tx);
      if (!res.success) failSubmit(res, prefix: 'Payment failed');

      onProgress?.call('Payment sent successfully!');
      return [res.hash!];
    } catch (e) {
      if (e is StellarWalletError) rethrow;
      fail(
        'Unable to send XLM',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // USDC Payments
  // ──────────────────────────────────────────────────────────────────────────

  Future<List<String>> sendUsdcWithFee({
    required KeyPair keyPair,
    required String destination,
    required double usdcAmount,
    String? memoText,
    ProgressCallback? onProgress,
  }) async {
    if (usdcAmount <= 0) {
      fail(
        'Please enter a valid amount',
        technicalError: 'Amount: $usdcAmount',
        advice: 'Try entering an amount like 10 or 25.50',
        code: 'INVALID_AMOUNT',
      );
    }

    try {
      onProgress?.call('Validating address...');
      final dest = toClassicAccountId(destination);
      final feeAddr = toClassicAccountId(await feeService.getTransactionFeeAddress());

      onProgress?.call('Checking destination account...');
      if (!await accountExists(dest)) {
        fail(
          'Recipient doesn\'t have a Stellar account yet',
          technicalError: 'Account not found: $dest',
          advice:
          'The recipient needs to create their Stellar account first. They can do this by receiving XLM from another wallet or using an exchange',
          code: 'DESTINATION_NOT_FOUND',
        );
      }

      await accountService.ensureUsdcTrustline(keyPair, onProgress: onProgress);

      onProgress?.call('Checking recipient USDC setup...');
      if (!await accountService.hasUsdcTrustline(dest)) {
        fail(
          'Recipient can\'t receive USDC yet',
          technicalError: 'No USDC trustline for: $dest',
          advice:
          'The recipient needs to add USDC to their wallet first. This is a one-time setup they can do in their Stellar wallet settings',
          code: 'NO_DESTINATION_TRUSTLINE',
        );
      }

      onProgress?.call('Calculating fees...');
      final feeStroops = await feeService.getCurrentFeeStroops();
      final feeXlm = fromStroops(feeStroops);

      onProgress?.call('Checking balances...');
      final senderXlmBal = await accountService.getXlmBalance(keyPair.accountId);
      if (senderXlmBal < feeXlm) {
        fail(
          'Not enough XLM for transaction fee',
          technicalError: 'Have: ${StellarBaseService.fmt7(senderXlmBal)} XLM, Need: ${StellarBaseService.fmt7(feeXlm)} XLM',
          advice:
          'You need ${StellarBaseService.fmt7(feeXlm - senderXlmBal)} more XLM to pay the transaction fee',
          code: 'INSUFFICIENT_XLM_FOR_FEE',
        );
      }

      final senderUsdcBal = await accountService.getUsdcBalance(keyPair.accountId);
      if (senderUsdcBal < usdcAmount) {
        fail(
          'Not enough USDC in your wallet',
          technicalError: 'Have: ${StellarBaseService.fmt7(senderUsdcBal)} USDC, Need: ${StellarBaseService.fmt7(usdcAmount)} USDC',
          advice:
          'You need ${StellarBaseService.fmt7(usdcAmount - senderUsdcBal)} more USDC to complete this transaction',
          code: 'INSUFFICIENT_USDC',
        );
      }

      onProgress?.call('Preparing transaction...');
      final acc = await loadAccount(keyPair.accountId);

      final needsFeeOp = feeStroops > 0;
      final opCount = needsFeeOp ? 2 : 1;
      final feeXlmNet =
      await feeService.estimateNetworkFeeXlm(opCount: opCount, percentile: 90);
      final perOpStroops = (feeXlmNet * 1e7 / opCount).ceil();

      final tb = TransactionBuilder(acc)
        ..setMaxOperationFee(perOpStroops)
        ..addOperation(
          PaymentOperationBuilder(dest, usdc, StellarBaseService.fmt7(usdcAmount)).build(),
        );

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

      onProgress?.call('Sending transaction...');
      final res = await _submitWithFallback(tx);
      if (!res.success) failSubmit(res, prefix: 'Payment failed');

      onProgress?.call('Payment sent successfully!');
      return [res.hash!];
    } catch (e) {
      if (e is StellarWalletError) rethrow;
      fail(
        'Unable to send USDC',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Helper
  // ──────────────────────────────────────────────────────────────────────────

  Future<SubmitTransactionResponse> _submitWithFallback(Transaction tx) async {
    try {
      return await sdk.submitTransaction(tx);
    } catch (e) {
      if (sdk != _sdkQuickNode && _sdkQuickNode != null) {
        try {
          return await _sdkQuickNode!.submitTransaction(tx);
        } catch (_) {
          rethrow;
        }
      }
      rethrow;
    }
  }

  StellarSDK? get _sdkQuickNode => super.quickNodeSdk;
}