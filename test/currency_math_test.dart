import 'package:flutter_test/flutter_test.dart';
import 'package:next_fi/app/viewmodels/currency_math.dart';

void main() {
  test('assetAmountToFiat sanitizes invalid values and converts safely', () {
    expect(
      CurrencyMath.assetAmountToFiat(amount: 12.5, unitPrice: 0.25),
      3.125,
    );
    expect(
      CurrencyMath.assetAmountToFiat(amount: double.nan, unitPrice: 1),
      0.0,
    );
    expect(
      CurrencyMath.assetAmountToFiat(amount: 10, unitPrice: double.infinity),
      0.0,
    );
    expect(CurrencyMath.sanitize(double.negativeInfinity), 0.0);
  });
}
