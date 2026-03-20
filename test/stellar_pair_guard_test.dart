import 'package:flutter_test/flutter_test.dart';
import 'package:next_fi/core/services/stellar/stellar_pair_guard.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

void main() {
  const issuer = 'GUSDCISSUER';

  test('allows XLM to USDC and USDC to XLM only', () {
    final xlm = Asset.NATIVE;
    final usdc = AssetTypeCreditAlphaNum4('USDC', issuer);
    final eurc = AssetTypeCreditAlphaNum4('EURC', issuer);

    expect(
      isSupportedXlmUsdcPair(first: xlm, second: usdc, usdcIssuer: issuer),
      isTrue,
    );
    expect(
      isSupportedXlmUsdcPair(first: usdc, second: xlm, usdcIssuer: issuer),
      isTrue,
    );
    expect(
      isSupportedXlmUsdcPair(first: xlm, second: eurc, usdcIssuer: issuer),
      isFalse,
    );
    expect(
      isSupportedXlmUsdcPair(first: usdc, second: eurc, usdcIssuer: issuer),
      isFalse,
    );
  });
}
