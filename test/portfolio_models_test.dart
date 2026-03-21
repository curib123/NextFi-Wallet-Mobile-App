import 'package:flutter_test/flutter_test.dart';
import 'package:next_fi/core/services/portfolio/models/portfolio_models.dart';

void main() {
  test('portfolio range api mapping stays stable', () {
    expect(portfolioRangeToApi(PortfolioRange.h24), '24H');
    expect(portfolioRangeToApi(PortfolioRange.d7), '7D');
    expect(portfolioRangeToApi(PortfolioRange.d30), '30D');
    expect(portfolioRangeToApi(PortfolioRange.all), 'ALL');
  });

  test('snapshot trigger api mapping stays wallet-scoped and deterministic', () {
    expect(walletSnapshotTriggerToApi(WalletSnapshotTrigger.appOpen), 'APP_OPEN');
    expect(walletSnapshotTriggerToApi(WalletSnapshotTrigger.receiveDetected), 'RECEIVE_DETECTED');
    expect(walletSnapshotTriggerFromApi('wallet_switch'), WalletSnapshotTrigger.walletSwitch);
    expect(walletSnapshotTriggerFromApi('swap'), WalletSnapshotTrigger.swap);
  });
}
