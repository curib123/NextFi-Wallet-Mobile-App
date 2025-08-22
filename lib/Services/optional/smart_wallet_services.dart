import 'dart:typed_data';
import 'dart:convert';
import 'package:hashlib/hashlib.dart';
import 'package:next_fi/Model/NetworkConfigModel.dart';
import 'package:next_fi/Model/wallet_transaction_model.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';

/// SmartWalletService
class SmartWalletService {
  final EthereumAddress userEOA;
  final Credentials credentials;
  final Map<String, NetworkConfigModel> _networks = {};

  SmartWalletService({required this.userEOA, required this.credentials});

  /// Add or update a network dynamically
  void addNetwork(NetworkConfigModel config) {
    _networks[config.name] = config;
  }

  /// Get existing wallet or create a new one for the user
  Future<EthereumAddress> getOrCreateWallet({
    required String networkName,
    required EthereumAddress profitWallet,
    required String walletFactoryAbi,
    required EthereumAddress walletFactoryAddress,
    required String pin,
    required int chainId,
  }) async {
    final config = _networks[networkName];
    if (config == null) throw Exception("Network not found");

    final client = Web3Client(config.rpcUrl, Client());

    final factoryContract = DeployedContract(
      ContractAbi.fromJson(walletFactoryAbi, "WalletFactory"),
      walletFactoryAddress,
    );

    final userWalletFn = factoryContract.function("userWallets");
    final createWalletFn = factoryContract.function("createWallet");

    // Check if wallet exists for this EOA
    final walletAddrList = await client.call(
      contract: factoryContract,
      function: userWalletFn,
      params: [userEOA],
    );

    final walletAddress = walletAddrList.first as EthereumAddress;

    if (walletAddress.hex !=
        '0x0000000000000000000000000000000000000000') {
      return walletAddress; // Already exists
    }

    // Deploy new wallet
    final tx = Transaction.callContract(
      contract: factoryContract,
      function: createWalletFn,
      parameters: [
        userEOA,
        EthereumAddress.fromHex(config.usdtAddress),
        profitWallet,
        pin,
      ],
      maxGas: 500000,
    );

    final txHash = await client.sendTransaction(
      credentials,
      tx,
      chainId: config.chainId,
    );

    // Wait for receipt
    TransactionReceipt? receipt;
    while (receipt == null) {
      receipt = await client.getTransactionReceipt(txHash);
      await Future.delayed(const Duration(seconds: 2));
    }

    // Extract wallet address from WalletCreated event
    final event = factoryContract.event("WalletCreated");
    final logs = receipt.logs
        .map((log) => event.decodeResults(log.topics!, log.data!))
        .where((decoded) => decoded.isNotEmpty)
        .cast<List<dynamic>>()
        .firstOrNull;

    if (logs == null) throw Exception("WalletCreated event not found");

    return logs[1] as EthereumAddress;
  }

  /// Send ERC20 token gaslessly via SC wallet
  Future<String> sendTokenGasless({
    required EthereumAddress scWalletAddress,
    required EthereumAddress to,
    required BigInt amount,
    required String tokenWalletAbi,
    required String networkName,
    BigInt? gasFee,
  }) async {
    final config = _networks[networkName];
    if (config == null) throw Exception("Network not found");

    final client = Web3Client(config.rpcUrl, Client());

    final walletContract = DeployedContract(
      ContractAbi.fromJson(tokenWalletAbi, "USDTWalletGasless"),
      scWalletAddress,
    );

    final sendFn = walletContract.function("sendTokenWithFees");

    final tx = Transaction.callContract(
      contract: walletContract,
      function: sendFn,
      parameters: [
        to,
        amount,
        gasFee ?? BigInt.zero,
      ],
      maxGas: 300000,
    );

    final txHash = await client.sendTransaction(
      credentials,
      tx,
      chainId: config.chainId,
    );

    return txHash;
  }

  /// View token balance of a SC wallet
  Future<BigInt> getTokenBalance({
    required EthereumAddress scWalletAddress,
    required String tokenWalletAbi,
    required String networkName,
  }) async {
    final config = _networks[networkName];
    if (config == null) throw Exception("Network not found");

    final client = Web3Client(config.rpcUrl, Client());

    final walletContract = DeployedContract(
      ContractAbi.fromJson(tokenWalletAbi, "USDTWalletGasless"),
      scWalletAddress,
    );

    final balanceFn = walletContract.function("getTokenBalance");

    final balanceList = await client.call(
      contract: walletContract,
      function: balanceFn,
      params: [],
    );

    return balanceList.first as BigInt;
  }

  /// Get transaction history from SC wallet
  Future<List<WalletTransactionModel>> getTransactionHistory({
    required EthereumAddress scWalletAddress,
    required String tokenWalletAbi,
    required String networkName,
  }) async {
    final config = _networks[networkName];
    if (config == null) throw Exception("Network not found");

    final client = Web3Client(config.rpcUrl, Client());

    final walletContract = DeployedContract(
      ContractAbi.fromJson(tokenWalletAbi, "USDTWalletGasless"),
      scWalletAddress,
    );

    final countFn = walletContract.function("getTransactionCount");
    final txFn = walletContract.function("getTransaction");

    final countList = await client.call(
      contract: walletContract,
      function: countFn,
      params: [],
    );
    final txCount = (countList.first as BigInt).toInt();

    List<WalletTransactionModel> history = [];
    for (int i = 0; i < txCount; i++) {
      final txData = await client.call(
        contract: walletContract,
        function: txFn,
        params: [BigInt.from(i)],
      );

      history.add(
        WalletTransactionModel(
          sender: txData[0] as EthereumAddress,
          recipient: txData[1] as EthereumAddress,
          netAmount: txData[2] as BigInt,
          gasFee: txData[3] as BigInt,
          profitFee: txData[4] as BigInt,
          timestamp: txData[5] as BigInt,
        ),
      );
    }

    return history;
  }

  /// Get stored hashed PIN from SC wallet
  Future<String> getWalletPinHash({
    required EthereumAddress scWalletAddress,
    required String tokenWalletAbi,
    required String networkName,
  }) async {
    final config = _networks[networkName];
    if (config == null) throw Exception("Network not found");

    final client = Web3Client(config.rpcUrl, Client());

    final walletContract = DeployedContract(
      ContractAbi.fromJson(tokenWalletAbi, "USDTWalletGasless"),
      scWalletAddress,
    );

    final getPinHashFn = walletContract.function("getPinHash");

    final result = await client.call(
      contract: walletContract,
      function: getPinHashFn,
      params: [],
    );

    final bytes = result.first as Uint8List;

    return "0x${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}";
  }

  /// Verify a user-input PIN against the stored hash
  Future<bool> verifyPin({
    required EthereumAddress scWalletAddress,
    required String tokenWalletAbi,
    required String networkName,
    required String inputPin,
  }) async {
    final storedHashHex = await getWalletPinHash(
      scWalletAddress: scWalletAddress,
      tokenWalletAbi: tokenWalletAbi,
      networkName: networkName,
    );

    final inputBytes = utf8.encode(inputPin);
    final inputHash = sha3_256.convert(inputBytes).bytes;

    final inputHashHex =
    inputHash.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    return storedHashHex.replaceFirst('0x', '') == inputHashHex;
  }
}
