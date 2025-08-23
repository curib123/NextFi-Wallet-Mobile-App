import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

/// Production-ready Stellar XLM wallet using stellar_flutter_sdk 2.1.2
class StellarWalletService {
  final StellarSDK sdk;

  /// Profit address for 1% fee
  final String profitAddress;

  StellarWalletService({required this.profitAddress, bool testnet = false})
      : sdk = testnet ? StellarSDK.TESTNET : StellarSDK.PUBLIC;

  /// Generate a 24-word mnemonic
  static Future<String> generateMnemonic() async {
    return await Wallet.generate24WordsMnemonic();
  }

  /// Create wallet from mnemonic
  static Future<Wallet> walletFromMnemonic(String mnemonic) async {
    return await Wallet.from(mnemonic);
  }

  /// Get key pair by index
  static Future<KeyPair> getKeyPair(Wallet wallet, {int index = 0}) async {
    return await wallet.getKeyPair(index: index);
  }

  /// Get XLM balance
  Future<double> getXlmBalance(String accountId) async {
    try {
      AccountResponse account = await sdk.accounts.account(accountId);
      for (Balance balance in account.balances) {
        if (balance.assetType == Asset.TYPE_NATIVE) {
          return double.parse(balance.balance);
        }
      }
      return 0.0;
    } catch (e) {
      throw Exception('Failed to fetch XLM balance: $e');
    }
  }

  /// Send XLM with 1% profit fee
  Future<List<String>> sendXlmWithFee({
    required String secretSeed,
    required String destination,
    required double amount,
    String? memoText,
  }) async {
    if (amount <= 0) throw ArgumentError('Amount must be greater than 0');
    if (destination.isEmpty) throw ArgumentError('Destination cannot be empty');

    KeyPair sender = KeyPair.fromSecretSeed(secretSeed);

    final double receiverAmount = double.parse((amount * 0.99).toStringAsFixed(7));
    final double feeAmount = double.parse((amount * 0.01).toStringAsFixed(7));

    // Send main payment
    final tx1Hash = await _sendXlm(sender, destination, receiverAmount, memoText: memoText);

    // Send 1% profit fee
    final tx2Hash = await _sendXlm(sender, profitAddress, feeAmount, memoText: 'Profit Fee');

    return [tx1Hash, tx2Hash];
  }

  Future<String> _sendXlm(
      KeyPair sender,
      String destination,
      double amount, {
        String? memoText,
      }) async {
    try {
      AccountResponse account = await sdk.accounts.account(sender.accountId);

      TransactionBuilder txBuilder = TransactionBuilder(account)
          .addOperation(PaymentOperationBuilder(destination, Asset.NATIVE, amount.toString()).build());

      if (memoText != null && memoText.isNotEmpty) {
        txBuilder.addMemo(Memo.text(memoText));
      }

      Transaction tx = txBuilder.build();

      // Determine network from SDK
      final Network network = sdk == StellarSDK.TESTNET ? Network.TESTNET : Network.PUBLIC;

      // SIGN TRANSACTION
      tx.sign(sender, network);

      SubmitTransactionResponse response = await sdk.submitTransaction(tx);
      if (!response.success) {
        throw Exception('Transaction failed: ${response.resultXdr}');
      }
      return response.hash!;
    } catch (e) {
      throw Exception('Failed to send XLM: $e');
    }
  }

  /// Check if an account has a trustline for a given asset
  Future<bool> hasTrustline(String accountId, Asset asset) async {
    try {
      AccountResponse account = await sdk.accounts.account(accountId);
      for (Balance balance in account.balances) {
        if (balance.assetType != Asset.TYPE_NATIVE &&
            balance.assetCode == (asset as AssetTypeCreditAlphaNum).code &&
            balance.assetIssuer == asset.issuerId) {
          return true;
        }
      }
      return false;
    } catch (e) {
      throw Exception('Failed to check trustline: $e');
    }
  }

  /// Create trustline for an asset (if missing)
  Future<void> createTrustLine({
    required String secretSeed,
    required Asset asset,
    double limit = double.maxFinite,
  }) async {
    try {
      KeyPair keyPair = KeyPair.fromSecretSeed(secretSeed);
      AccountResponse account = await sdk.accounts.account(keyPair.accountId);

      ChangeTrustOperationBuilder trustOp = ChangeTrustOperationBuilder(asset, limit.toString());
      Transaction tx = TransactionBuilder(account)
          .addOperation(trustOp.build())
          .build();

      tx.sign(keyPair, sdk == StellarSDK.TESTNET ? Network.TESTNET : Network.PUBLIC);

      SubmitTransactionResponse response = await sdk.submitTransaction(tx);
      if (!response.success) {
        throw Exception('Trustline creation failed: ${response.resultXdr}');
      }
    } catch (e) {
      throw Exception('Failed to create trustline: $e');
    }
  }

  /// Swap XLM ↔ USDT (or any assets) with auto trustline creation
  Future<String> swap({
    required String secretSeed,
    required Asset sendAsset,
    required Asset receiveAsset,
    required double sendAmount,
    double slippagePercent = 0.5, // 0.5% default slippage
    String? memoText,
  }) async {
    KeyPair sender = KeyPair.fromSecretSeed(secretSeed);

    // Auto-create trustline if missing (only needed for non-native assets)
    if (receiveAsset.type != Asset.TYPE_NATIVE) {
      bool hasLine = await hasTrustline(sender.accountId, receiveAsset);
      if (!hasLine) {
        await createTrustLine(secretSeed: secretSeed, asset: receiveAsset);
      }
    }

    try {
      AccountResponse account = await sdk.accounts.account(sender.accountId);

      // Min receive considering slippage
      double minReceive = sendAmount * (1 - slippagePercent / 100);

      PathPaymentStrictSendOperationBuilder pathPaymentOp =
      PathPaymentStrictSendOperationBuilder(
        sendAsset,
        sendAmount.toString(),
        sender.accountId,
        receiveAsset,
        minReceive.toString(),
      );

      Transaction tx = TransactionBuilder(account)
          .addOperation(pathPaymentOp.build())
          .build();

      tx.sign(sender, sdk == StellarSDK.TESTNET ? Network.TESTNET : Network.PUBLIC);

      SubmitTransactionResponse response = await sdk.submitTransaction(tx);

      if (!response.success) {
        throw Exception('Swap failed: ${response.resultXdr}');
      }

      return response.hash!;
    } catch (e) {
      throw Exception('Swap operation failed: $e');
    }
  }

  /// Resolve a Stellar Federation address
  Future<FederationResponse> resolveFederationAddress(String stellarAddress) async {
    return await Federation.resolveStellarAddress(stellarAddress);
  }

  /// Stream incoming payments for an account
  void streamPayments(String accountId, void Function(PaymentOperationResponse) onPayment) {
    sdk.payments.forAccount(accountId).cursor("now").stream().listen((response) {
      if (response is PaymentOperationResponse && response.transactionSuccessful) {
        onPayment(response);
      }
    });
  }
}
