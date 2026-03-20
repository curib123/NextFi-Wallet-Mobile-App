import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'package:next_fi/core/services/stellar/stellar_base_service.dart';
import 'package:next_fi/core/services/stellar/stellar_account_service.dart';

class StellarClaimableBalanceService extends StellarBaseService {
  final StellarAccountService accountService;

  StellarClaimableBalanceService({
    required this.accountService,
    required super.sdk,
    super.sdkQuickNode,
    super.quickNodeUrlMainnet,
    super.quickNodeUrlTestnet,
    super.quickNodeDefaultHeaders,
  });

  Future<String> createClaimableBalance({
    required KeyPair keyPair,
    required Asset asset,
    required double amount,
    required List<Claimant> claimants,
    String? memoText,
    ProgressCallback? onProgress,
  }) async {
    if (amount <= 0) {
      fail(
        'Invalid amount entered',
        technicalError: 'Amount: $amount',
        advice: 'Please enter an amount greater than 0',
        code: 'INVALID_AMOUNT',
      );
    }
    if (claimants.isEmpty) {
      fail(
        'No recipient specified',
        technicalError: 'Claimants list is empty',
        advice: 'Please add at least one recipient who can claim this payment',
        code: 'NO_CLAIMANTS',
      );
    }

    try {
      if (asset is! AssetTypeNative) {
        await accountService.ensureTrustline(
          keyPair,
          asset,
          onProgress: onProgress,
        );
      }

      onProgress?.call('Checking balance...');
      final balance = await accountService.getAssetBalance(
        keyPair.accountId,
        asset,
      );
      if (balance < amount) {
        final assetName = asset is AssetTypeCreditAlphaNum ? asset.code : 'XLM';
        fail(
          'Not enough $assetName in your wallet',
          technicalError:
              'Have: ${StellarBaseService.fmt7(balance)}, Need: ${StellarBaseService.fmt7(amount)}',
          advice:
              'You need ${StellarBaseService.fmt7(amount - balance)} more $assetName to create this payment',
          code: 'INSUFFICIENT_BALANCE',
        );
      }

      onProgress?.call('Creating claimable payment...');
      final acc = await loadAccount(keyPair.accountId);

      final tb = TransactionBuilder(acc)
        ..setMaxOperationFee(100)
        ..addOperation(
          CreateClaimableBalanceOperationBuilder(
            claimants,
            asset,
            StellarBaseService.fmt7(amount),
          ).build(),
        );

      if (memoText?.isNotEmpty == true) {
        tb.addMemo(Memo.text(memoText!));
      }

      final tx = tb.build();
      tx.sign(keyPair, network);

      final res = await sdk.submitTransaction(tx);
      if (!res.success) failSubmit(res, prefix: 'Unable to create payment');

      onProgress?.call('Payment created successfully!');
      return res.hash!;
    } catch (e) {
      if (e is StellarWalletError) rethrow;
      fail(
        'Unable to create claimable payment',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }

  Future<String> createUnconditionalClaimableBalance({
    required KeyPair keyPair,
    required Asset asset,
    required double amount,
    required String recipientId,
    ProgressCallback? onProgress,
  }) async {
    final claimant = Claimant(recipientId, Claimant.predicateUnconditional());

    return createClaimableBalance(
      keyPair: keyPair,
      asset: asset,
      amount: amount,
      claimants: [claimant],
      onProgress: onProgress,
    );
  }

  Future<String> createTimeLockedPayment({
    required KeyPair keyPair,
    required Asset asset,
    required double amount,
    required String recipientId,
    required DateTime unlockTime,
    ProgressCallback? onProgress,
  }) async {
    final unlockTimestamp = unlockTime.millisecondsSinceEpoch ~/ 1000;

    final claimant = Claimant(
      recipientId,
      Claimant.predicateNot(
        Claimant.predicateBeforeAbsoluteTime(unlockTimestamp),
      ),
    );

    return createClaimableBalance(
      keyPair: keyPair,
      asset: asset,
      amount: amount,
      claimants: [claimant],
      onProgress: onProgress,
    );
  }

  Future<String> createUnconditionalWithExpiry({
    required KeyPair keyPair,
    required Asset asset,
    required double amount,
    required String recipientId,
    required DateTime expiryTime,
    ProgressCallback? onProgress,
  }) async {
    if (expiryTime.isBefore(DateTime.now())) {
      fail(
        'Expiration time must be in the future',
        advice: 'Choose a date and time after right now',
        code: 'EXPIRY_IN_PAST',
      );
    }

    final expiryTimestamp = expiryTime.millisecondsSinceEpoch ~/ 1000;

    final recipientClaimant = Claimant(
      recipientId,
      Claimant.predicateBeforeAbsoluteTime(expiryTimestamp),
    );

    final senderClaimant = Claimant(
      keyPair.accountId,
      Claimant.predicateNot(
        Claimant.predicateBeforeAbsoluteTime(expiryTimestamp),
      ),
    );

    return createClaimableBalance(
      keyPair: keyPair,
      asset: asset,
      amount: amount,
      claimants: [recipientClaimant, senderClaimant],
      onProgress: onProgress,
    );
  }

  Future<String> createTimeLockedWithExpiry({
    required KeyPair keyPair,
    required Asset asset,
    required double amount,
    required String recipientId,
    required DateTime unlockTime,
    required DateTime expiryTime,
    ProgressCallback? onProgress,
  }) async {
    if (unlockTime.isBefore(DateTime.now())) {
      fail(
        'Unlock time must be in the future',
        advice: 'Choose a date and time after right now',
        code: 'UNLOCK_IN_PAST',
      );
    }

    if (expiryTime.isBefore(unlockTime)) {
      fail(
        'Expiration must be after unlock time',
        advice:
            'The expiration date needs to be after the unlock date so the recipient has a window to claim',
        code: 'EXPIRY_BEFORE_UNLOCK',
      );
    }

    final unlockTimestamp = unlockTime.millisecondsSinceEpoch ~/ 1000;
    final expiryTimestamp = expiryTime.millisecondsSinceEpoch ~/ 1000;

    final recipientClaimant = Claimant(
      recipientId,
      Claimant.predicateAnd(
        Claimant.predicateNot(
          Claimant.predicateBeforeAbsoluteTime(unlockTimestamp),
        ),
        Claimant.predicateBeforeAbsoluteTime(expiryTimestamp),
      ),
    );

    final senderClaimant = Claimant(
      keyPair.accountId,
      Claimant.predicateNot(
        Claimant.predicateBeforeAbsoluteTime(expiryTimestamp),
      ),
    );

    return createClaimableBalance(
      keyPair: keyPair,
      asset: asset,
      amount: amount,
      claimants: [recipientClaimant, senderClaimant],
      onProgress: onProgress,
    );
  }

  Future<String> claimClaimableBalance({
    required KeyPair keyPair,
    required String balanceId,
    ProgressCallback? onProgress,
  }) async {
    try {
      onProgress?.call('Claiming payment...');
      final acc = await loadAccount(keyPair.accountId);

      final tx = TransactionBuilder(acc)
          .setMaxOperationFee(100)
          .addOperation(
            ClaimClaimableBalanceOperationBuilder(balanceId).build(),
          )
          .build();
      tx.sign(keyPair, network);

      final res = await sdk.submitTransaction(tx);
      if (!res.success) failSubmit(res, prefix: 'Unable to claim payment');

      onProgress?.call('Payment claimed successfully!');
      return res.hash!;
    } catch (e) {
      if (e is StellarWalletError) rethrow;
      fail(
        'Unable to claim payment',
        technicalError: e,
        advice:
            'The payment may have expired or already been claimed. Please check and try again',
      );
    }
  }

  Future<List<ClaimableBalanceResponse>> getClaimableBalances({
    required String accountId,
    int limit = 200,
  }) async {
    try {
      final page = await sdk.claimableBalances
          .forClaimant(accountId)
          .limit(limit)
          .execute();
      return page.records;
    } catch (e) {
      fail(
        'Unable to fetch claimable payments',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }

  Future<List<ClaimableBalanceResponse>> getSentClaimableBalances({
    required String accountId,
    int limit = 200,
  }) async {
    try {
      final page = await sdk.claimableBalances
          .forSponsor(accountId)
          .limit(limit)
          .execute();
      return page.records;
    } catch (e) {
      fail(
        'Unable to fetch sent claimable payments',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }

  Future<Map<String, List<ClaimableBalanceResponse>>> getAllClaimableBalances({
    required String accountId,
    int limit = 200,
  }) async {
    try {
      final received = await getClaimableBalances(
        accountId: accountId,
        limit: limit,
      );
      final sent = await getSentClaimableBalances(
        accountId: accountId,
        limit: limit,
      );

      return {'received': received, 'sent': sent};
    } catch (e) {
      fail(
        'Unable to fetch claimable payments',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }

  Future<ClaimableBalanceResponse?> getClaimableBalanceById({
    required String balanceId,
  }) async {
    try {
      return await sdk.claimableBalances.claimableBalance(balanceId as Uri);
    } catch (e) {
      return null;
    }
  }

  Future<bool> canClaimBalance({
    required String accountId,
    required String balanceId,
  }) async {
    try {
      final balance = await getClaimableBalanceById(balanceId: balanceId);
      if (balance == null) return false;

      for (final claimant in balance.claimants) {
        if (claimant.destination == accountId) {
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
