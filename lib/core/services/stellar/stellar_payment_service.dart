// stellar_payment_service.dart
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'package:next_fi/core/services/stellar/stellar_base_service.dart';
import 'package:next_fi/core/services/stellar/stellar_account_service.dart';

/// Service for Stellar payments.
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

  String _assetLabel(Asset asset) {
    if (asset is AssetTypeNative) return 'XLM';
    if (asset is AssetTypeCreditAlphaNum) return asset.code;
    return 'asset';
  }

  Future<String> sendAsset({
    required KeyPair keyPair,
    required String destination,
    required Asset asset,
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

    final assetName = _assetLabel(asset);

    try {
      onProgress?.call('Validating address...');
      final dest = toClassicAccountId(destination);

      onProgress?.call('Checking balance...');
      final balance = await accountService.getAssetBalance(
        keyPair.accountId,
        asset,
      );
      if (balance < amount) {
        fail(
          'Not enough $assetName in your wallet',
          technicalError:
              'Have: ${StellarBaseService.fmt7(balance)} $assetName | '
              'Need: ${StellarBaseService.fmt7(amount)} $assetName',
          advice:
              'Reduce the amount or add more $assetName before sending.',
          code: 'INSUFFICIENT_BALANCE',
        );
      }

      onProgress?.call('Loading account...');
      final acc = await loadAccount(keyPair.accountId);

      onProgress?.call('Checking destination...');
      final destExists = await accountExists(dest);
      if (asset is! AssetTypeNative) {
        if (!destExists) {
          fail(
            'Recipient doesn\'t have a Stellar account yet',
            technicalError: 'Account not found: $dest',
            advice: 'The recipient needs to create their Stellar account first',
            code: 'DESTINATION_NOT_FOUND',
          );
        }
        if (!await accountService.hasTrustline(dest, asset)) {
          fail(
            'Recipient can\'t receive $assetName yet',
            technicalError: 'No $assetName trustline for: $dest',
            advice:
                'The recipient needs to add $assetName to their wallet first.',
            code: 'NO_DESTINATION_TRUSTLINE',
          );
        }
      }

      onProgress?.call('Preparing transaction...');
      final tb = TransactionBuilder(acc);
      if (asset is AssetTypeNative && !destExists) {
        tb.addOperation(
          CreateAccountOperationBuilder(
            dest,
            StellarBaseService.fmt7(amount),
          ).build(),
        );
      } else {
        tb.addOperation(
          PaymentOperationBuilder(
            dest,
            asset,
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
      if (!res.success) failSubmit(res, prefix: '$assetName payment failed');

      onProgress?.call('Payment sent successfully!');
      return res.hash!;
    } catch (e) {
      if (e is StellarWalletError) rethrow;
      fail(
        'Unable to send $assetName',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // XLM Payments
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<String> sendXlm({
    required KeyPair keyPair,
    required String destination,
    required double amount,
    String? memoText,
    ProgressCallback? onProgress,
  }) => sendAsset(
    keyPair: keyPair,
    destination: destination,
    asset: xlm,
    amount: amount,
    memoText: memoText,
    onProgress: onProgress,
  );

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // USDC Payments
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<String> sendUsdc({
    required KeyPair keyPair,
    required String destination,
    required double usdcAmount,
    String? memoText,
    ProgressCallback? onProgress,
  }) => sendAsset(
    keyPair: keyPair,
    destination: destination,
    asset: usdc,
    amount: usdcAmount,
    memoText: memoText,
    onProgress: onProgress,
  );

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
