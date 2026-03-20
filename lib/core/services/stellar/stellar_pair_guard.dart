import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

bool isSupportedXlmUsdcPair({
  required Asset first,
  required Asset second,
  required String usdcIssuer,
}) {
  final issuer = usdcIssuer.trim();
  if (issuer.isEmpty) return false;

  bool isXlm(Asset asset) => asset is AssetTypeNative;

  bool isUsdc(Asset asset) =>
      asset is AssetTypeCreditAlphaNum &&
      asset.code.trim().toUpperCase() == 'USDC' &&
      asset.issuerId.trim() == issuer;

  return (isXlm(first) && isUsdc(second)) || (isUsdc(first) && isXlm(second));
}
