import 'package:flutter_test/flutter_test.dart';
import 'package:next_fi/core/services/portfolio/models/portfolio_models.dart';
import 'package:next_fi/features/portfolio/presentation/viewmodels/portfolio_state.dart';

void main() {
  test('portfolio state reports empty when there is no wallet data or error', () {
    const state = PortfolioState(
      activeWalletId: 'wallet-a',
      activeWalletAddress: 'GA123',
    );

    expect(state.hasWallet, isTrue);
    expect(state.isEmpty, isTrue);
    expect(state.hasInsufficientData, isTrue);
  });

  test('portfolio state detects insufficient chart history and zero balance', () {
    final state = PortfolioState(
      activeWalletId: 'wallet-a',
      activeWalletAddress: 'GA123',
      data: WalletPortfolioData(
        walletId: 'wallet-a',
        walletAddress: 'GA123',
        walletLabel: 'A',
        range: PortfolioRange.h24,
        summary: PortfolioSummary(
          totalValue: 0,
          fiatCurrency: 'USD',
          absoluteChange: 0,
          percentChange: 0,
          lastUpdated: DateTime(2026, 3, 21),
        ),
        chart: const [],
        allocation: const [],
        activity: const [],
      ),
    );

    expect(state.isZeroBalance, isTrue);
    expect(state.hasInsufficientData, isTrue);
  });
}
