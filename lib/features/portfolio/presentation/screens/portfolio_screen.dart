import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:next_fi/app/config/app_providers.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/app/viewmodels/currency_vm.dart';
import 'package:next_fi/core/models/asset_model.dart';
import 'package:next_fi/core/services/portfolio/models/portfolio_models.dart';
import 'package:next_fi/core/widgets/modal/send_flow_modal.dart';
import 'package:next_fi/core/widgets/modal/token_chooser.dart';
import 'package:next_fi/features/receive/presentation/screens/receive_screen.dart';
import 'package:next_fi/features/swap/presentation/screens/swap_screen.dart';
import 'package:next_fi/features/wallet_home/presentation/widgets/portfolio_overview_section.dart';

class PortfolioScreen extends ConsumerStatefulWidget {
  const PortfolioScreen({super.key});

  @override
  ConsumerState<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends ConsumerState<PortfolioScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_bindPortfolio());
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final walletVm = ref.watch(walletHomeVmProvider);
    final portfolioVm = ref.watch(portfolioVmProvider);
    final currency = ref.watch(currencyVmProvider);
    final assetsVm = ref.watch(assetVmProvider);
    final state = walletVm.state;
    final totalFiat = _portfolioFiatTotal(
      currency: currency,
      assets: assetsVm.assets,
      balancesByAssetId: state.balancesByAssetId,
    );

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Portfolio'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _handleRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: _handleRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          child: PortfolioOverviewSection(
            colors: colors,
            state: portfolioVm.state,
            currency: currency,
            liveTotalFiat: totalFiat,
            reserveXlm: state.xlmTotalReserve,
            showHero: false,
            showReserveHelper: false,
            showActions: false,
            onSend: _openSend,
            onReceive: _openReceive,
            onScan: _openScanSend,
            onSwap: _openSwap,
            onRetry: () => portfolioVm.load(),
            onRangeChanged: portfolioVm.setRange,
          ),
        ),
      ),
    );
  }

  Future<void> _bindPortfolio() async {
    final walletVm = ref.read(walletHomeVmProvider);
    await ref
        .read(portfolioVmProvider)
        .bindActiveWallet(
          localWalletId: ref.read(seedKeypairProvider).activeWalletId,
          address: walletVm.state.address,
          label: walletVm.state.walletName,
        );
  }

  Future<void> _handleRefresh() async {
    final walletVm = ref.read(walletHomeVmProvider);
    final portfolioVm = ref.read(portfolioVmProvider);
    await walletVm.refresh(force: true);
    await portfolioVm.refreshForWallet(
      walletState: walletVm.state,
      trigger: WalletSnapshotTrigger.manualRefresh,
    );
  }

  Future<void> _openSend() async {
    final walletVm = ref.read(walletHomeVmProvider);
    final portfolioVm = ref.read(portfolioVmProvider);
    final address = walletVm.state.address;
    if (address == null || address.trim().isEmpty) return;

    await showTokenSelector(
      context,
      address,
      balanceResolver: (asset) =>
          walletVm.state.balancesByAssetId[asset.id] ?? 0.0,
      title: 'Select Asset',
      onSelect: (selectedAddress, token, balance) => showSendModal(
        context,
        address: selectedAddress,
        assetId: token,
        balance: balance,
        onTransactionCompleted: () async {
          await walletVm.refresh(force: true);
          await portfolioVm.refreshForWallet(
            walletState: walletVm.state,
            trigger: WalletSnapshotTrigger.send,
          );
        },
      ),
    );

    if (!mounted) return;
    await walletVm.refresh(force: true);
  }

  Future<void> _openReceive() async {
    final walletState = ref.read(walletHomeVmProvider).state;
    final address = walletState.address;
    if (address == null || address.trim().isEmpty) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ReceiveScreen(address: address, initialAssetId: 'stellar'),
      ),
    );
  }

  Future<void> _openScanSend() async {
    final walletVm = ref.read(walletHomeVmProvider);
    final portfolioVm = ref.read(portfolioVmProvider);
    final address = walletVm.state.address;
    if (address == null || address.trim().isEmpty) return;

    await showTokenSelector(
      context,
      address,
      balanceResolver: (asset) =>
          walletVm.state.balancesByAssetId[asset.id] ?? 0.0,
      title: 'Select Asset',
      onSelect: (selectedAddress, token, balance) => showSendModal(
        context,
        address: selectedAddress,
        assetId: token,
        balance: balance,
        autoOpenScanner: true,
        onTransactionCompleted: () async {
          await walletVm.refresh(force: true);
          await portfolioVm.refreshForWallet(
            walletState: walletVm.state,
            trigger: WalletSnapshotTrigger.send,
          );
        },
      ),
    );

    if (!mounted) return;
    await walletVm.refresh(force: true);
  }

  Future<void> _openSwap() async {
    final walletVm = ref.read(walletHomeVmProvider);
    final portfolioVm = ref.read(portfolioVmProvider);
    final swapVm = ref.read(swapVmProvider);
    final beforeTx = swapVm.lastSuccessfulSwapTxId;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SwapScreen()),
    );

    if (!mounted) return;
    await walletVm.refresh(force: true);
    if (swapVm.lastSuccessfulSwapTxId != null &&
        swapVm.lastSuccessfulSwapTxId != beforeTx) {
      await portfolioVm.refreshForWallet(
        walletState: walletVm.state,
        trigger: WalletSnapshotTrigger.swap,
      );
    }
  }

  double _portfolioFiatTotal({
    required CurrencyVM currency,
    required List<AssetModel> assets,
    required Map<String, double> balancesByAssetId,
  }) {
    var total = 0.0;
    for (final asset in assets) {
      final balance = balancesByAssetId[asset.id] ?? 0.0;
      if (balance <= 0) continue;
      total += currency.assetAmountToFiat(asset, balance);
    }
    return total.isFinite ? total : 0.0;
  }
}
