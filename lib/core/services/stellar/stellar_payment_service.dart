// stellar_payment_service.dart
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'package:next_fi/core/services/stellar/stellar_base_service.dart';
import 'package:next_fi/core/services/stellar/stellar_account_service.dart';

/// Service for XLM and USDC payments
class StellarPaymentService extends StellarBaseService {
  final StellarAccountService accountService;

  StellarPaymentService({
    required this.accountService,
    required super.sdk,
    super.sdkQuickNode,
    super.quickNodeUrlMainnet,
    super.quickNodeUrlTestnet,
    super.quickNodeDefaultHeaders,
  });

  Asset get xlm => accountService.xlm;
  Asset get usdc => accountService.usdc;

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // XLM Payments
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<String> sendXlm({
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

      onProgress?.call('Loading account...');
      final acc = await loadAccount(keyPair.accountId);

      onProgress?.call('Checking destination...');
      final destExists = await accountExists(dest);

      final tb = TransactionBuilder(acc);

      if (destExists) {
        tb.addOperation(
          PaymentOperationBuilder(
            dest,
            xlm,
            StellarBaseService.fmt7(amount),
          ).build(),
        );
      } else {
        tb.addOperation(
          CreateAccountOperationBuilder(
            dest,
            StellarBaseService.fmt7(amount),
          ).build(),
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
      return res.hash!;
    } catch (e) {
      if (e is StellarWalletError) rethrow;
      fail(
        'Unable to send XLM',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // USDC Payments
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<String> sendUsdc({
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

      onProgress?.call('Preparing transaction...');
      final acc = await loadAccount(keyPair.accountId);

      final tb = TransactionBuilder(acc)
        ..addOperation(
          PaymentOperationBuilder(
            dest,
            usdc,
            StellarBaseService.fmt7(usdcAmount),
          ).build(),
        );

      if (memoText?.isNotEmpty == true) {
        tb.addMemo(Memo.text(memoText!));
      }

      final tx = tb.build();
      tx.sign(keyPair, network);

      onProgress?.call('Sending transaction...');
      final res = await _submitWithFallback(tx);
      if (!res.success) failSubmit(res, prefix: 'Payment failed');

      onProgress?.call('Payment sent successfully!');
      return res.hash!;
    } catch (e) {
      if (e is StellarWalletError) rethrow;
      fail(
        'Unable to send USDC',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // Helper
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
