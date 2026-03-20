import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'package:next_fi/core/services/stellar/stellar_base_service.dart';
import 'package:next_fi/core/services/stellar/stellar_account_service.dart';

class StellarDexService extends StellarBaseService {
  final StellarAccountService accountService;

  StellarDexService({
    required this.accountService,
    required super.sdk,
    super.sdkQuickNode,
    super.quickNodeUrlMainnet,
    super.quickNodeUrlTestnet,
    super.quickNodeDefaultHeaders,
  });

  Future<String> createSellOffer({
    required KeyPair keyPair,
    required Asset selling,
    required Asset buying,
    required double amount,
    required double price,
    int? offerId,
    ProgressCallback? onProgress,
  }) async {
    try {
      await accountService.ensureTrustline(
        keyPair,
        selling,
        onProgress: onProgress,
      );
      await accountService.ensureTrustline(
        keyPair,
        buying,
        onProgress: onProgress,
      );

      onProgress?.call('Creating sell order...');
      final acc = await loadAccount(keyPair.accountId);

      final builder = ManageSellOfferOperationBuilder(
        selling,
        buying,
        StellarBaseService.fmt7(amount),
        StellarBaseService.fmt7(price),
      );

      if (offerId != null) {
        builder.setOfferId(offerId.toString());
      }

      final tx = TransactionBuilder(
        acc,
      ).setMaxOperationFee(100).addOperation(builder.build()).build();
      tx.sign(keyPair, network);

      final res = await sdk.submitTransaction(tx);
      if (!res.success) failSubmit(res, prefix: 'Unable to create sell order');

      onProgress?.call('Sell order created!');
      return res.hash!;
    } catch (e) {
      if (e is StellarWalletError) rethrow;
      fail(
        'Unable to create sell order',
        technicalError: e,
        advice: 'Please check your balance and internet connection',
      );
    }
  }

  Future<String> createBuyOffer({
    required KeyPair keyPair,
    required Asset buying,
    required Asset selling,
    required double amount,
    required double price,
    int? offerId,
    ProgressCallback? onProgress,
  }) async {
    try {
      await accountService.ensureTrustline(
        keyPair,
        selling,
        onProgress: onProgress,
      );
      await accountService.ensureTrustline(
        keyPair,
        buying,
        onProgress: onProgress,
      );

      onProgress?.call('Creating buy order...');
      final acc = await loadAccount(keyPair.accountId);

      final builder = ManageBuyOfferOperationBuilder(
        selling,
        buying,
        StellarBaseService.fmt7(amount),
        StellarBaseService.fmt7(price),
      );

      if (offerId != null) {
        builder.setOfferId(offerId.toString());
      }

      final tx = TransactionBuilder(
        acc,
      ).setMaxOperationFee(100).addOperation(builder.build()).build();
      tx.sign(keyPair, network);

      final res = await sdk.submitTransaction(tx);
      if (!res.success) failSubmit(res, prefix: 'Unable to create buy order');

      onProgress?.call('Buy order created!');
      return res.hash!;
    } catch (e) {
      if (e is StellarWalletError) rethrow;
      fail(
        'Unable to create buy order',
        technicalError: e,
        advice: 'Please check your balance and internet connection',
      );
    }
  }

  Future<String> cancelOffer({
    required KeyPair keyPair,
    required int offerId,
    required Asset selling,
    required Asset buying,
    ProgressCallback? onProgress,
  }) async {
    try {
      onProgress?.call('Canceling order...');
      final acc = await loadAccount(keyPair.accountId);

      final builder = ManageSellOfferOperationBuilder(selling, buying, '0', '1')
        ..setOfferId(offerId.toString());

      final tx = TransactionBuilder(
        acc,
      ).setMaxOperationFee(100).addOperation(builder.build()).build();
      tx.sign(keyPair, network);

      final res = await sdk.submitTransaction(tx);
      if (!res.success) failSubmit(res, prefix: 'Unable to cancel order');

      onProgress?.call('Order canceled!');
      return res.hash!;
    } catch (e) {
      if (e is StellarWalletError) rethrow;
      fail(
        'Unable to cancel order',
        technicalError: e,
        advice: 'The order may have already been filled or canceled',
      );
    }
  }

  Future<List<OfferResponse>> getAccountOffers({
    required String accountId,
    int limit = 200,
  }) async {
    try {
      final page = await sdk.offers
          .forAccount(accountId)
          .limit(limit)
          .execute();
      return page.records;
    } catch (e) {
      fail(
        'Unable to fetch open orders',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }

  Future<OrderBookResponse> getOrderBook({
    required Asset selling,
    required Asset buying,
    int limit = 20,
  }) async {
    try {
      return await sdk.orderBook
          .sellingAsset(selling)
          .buyingAsset(buying)
          .limit(limit)
          .execute();
    } catch (e) {
      fail(
        'Unable to fetch order book',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }
}
