
class NetworkConfigModel {
  final String name;
  final String rpcUrl;
  final String usdtAddress;
  final String paymasterAddress;
  final int chainId;

  NetworkConfigModel({
    required this.name,
    required this.rpcUrl,
    required this.usdtAddress,
    required this.paymasterAddress,
    required this.chainId,
  });
}