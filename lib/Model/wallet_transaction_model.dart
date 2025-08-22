import 'package:web3dart/web3dart.dart';

/// Transaction model in Dart
class WalletTransactionModel {
  final EthereumAddress sender;
  final EthereumAddress recipient;
  final BigInt netAmount;
  final BigInt gasFee;
  final BigInt profitFee;
  final BigInt timestamp;

  WalletTransactionModel({
    required this.sender,
    required this.recipient,
    required this.netAmount,
    required this.gasFee,
    required this.profitFee,
    required this.timestamp,
  });
}