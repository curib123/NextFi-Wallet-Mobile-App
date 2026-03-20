import 'package:flutter_test/flutter_test.dart';
import 'package:next_fi/features/wallet_home/presentation/widgets/live_counting_balance.dart';

void main() {
  test('large balances animate faster than small balances', () {
    expect(
      BalanceCountAnimationProfile.tickForMagnitude(12),
      const Duration(milliseconds: 96),
    );
    expect(
      BalanceCountAnimationProfile.tickForMagnitude(250000),
      const Duration(milliseconds: 24),
    );
    expect(
      BalanceCountAnimationProfile.stepFractionForMagnitude(12),
      lessThan(BalanceCountAnimationProfile.stepFractionForMagnitude(250000)),
    );
  });
}
