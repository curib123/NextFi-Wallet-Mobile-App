import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

/// Production-ready Stellar XLM wallet using stellar_flutter_sdk 2.1.2
class StellarWalletService {
  final StellarSDK sdk;

  StellarWalletService({ bool testnet = false})
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
    required String profitAddress,
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

  /// Helper: format amounts to max 7 decimals (Stellar limit)
  String _formatAmount(double value) {
    return value
        .toStringAsFixed(7) // force 7 decimal places max
        .replaceFirst(RegExp(r'0+$'), '') // strip trailing zeros
        .replaceFirst(RegExp(r'\.$'), ''); // remove trailing dot
  }
  Future<void> createTrustLine({
    required String secretSeed,
    required Asset asset,
    String limit = "922337203685.4775807",
    bool isTestnet = false,
  }) async {
    try {
      print("Step 1: Validating secret seed...");
      if (secretSeed.isEmpty) throw Exception("Secret seed is empty");

      // Trim whitespace
      secretSeed = secretSeed.trim();
      print("Secret seed: $secretSeed");
      print("Secret seed length: ${secretSeed.length}, starts with: ${secretSeed[0]}");

      KeyPair trustorKeyPair;
      try {
        print("Step 2: Generating KeyPair from secret seed...");
        trustorKeyPair = KeyPair.fromSecretSeed(secretSeed);
        print("KeyPair generated: ${trustorKeyPair.accountId}");
      } catch (e) {
        print("Error generating KeyPair: $e");
        throw Exception("Invalid secret seed format or checksum");
      }

      String trustorAccountId = trustorKeyPair.accountId;

      // Load account
      AccountResponse trustor;
      try {
        print("Step 3: Loading account $trustorAccountId...");
        trustor = await sdk.accounts.account(trustorAccountId);
        print("Account loaded successfully");
      } catch (e) {
        print("Error loading account: $e");
        throw Exception("Failed to load trustor account: $e");
      }

      // Prepare ChangeTrust operation
      print("Step 4: Preparing ChangeTrust operation for asset )...");
      ChangeTrustOperationBuilder changeTrustOp = ChangeTrustOperationBuilder(asset, limit);

      // Build transaction
      print("Step 5: Building transaction...");
      Transaction transaction = TransactionBuilder(trustor)
          .addOperation(changeTrustOp.build())
          .build();
      print("Transaction built successfully");

      // Sign transaction
      print("Step 6: Signing transaction on network: ${isTestnet ? "TESTNET" : "PUBLIC"}");
      transaction.sign(trustorKeyPair, isTestnet ? Network.TESTNET : Network.PUBLIC);
      print("Transaction signed successfully");

      // Submit transaction
      print("Step 7: Submitting transaction...");
      SubmitTransactionResponse response = await sdk.submitTransaction(transaction);

      if (!response.success) {
        print("Transaction failed: ${response.resultXdr}");
        throw Exception("Trustline creation failed: ${response.resultXdr}");
      }
      print("Trustline created successfully!");
    } catch (e) {
      print("Error caught in createTrustLine: $e");
      throw Exception("Failed to create trustline: $e");
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
        _formatAmount(sendAmount), // clamp here
        sender.accountId,
        receiveAsset,
        _formatAmount(minReceive), // clamp here
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
