import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:next_fi/app/config/app_providers.dart';
import 'package:next_fi/app/navigation/app_navigation_bridge.dart';
import 'package:next_fi/core/widgets/loader/page_loader.dart';
import 'package:next_fi/core/widgets/snackbar/snack_bar.dart';
import 'package:next_fi/features/claimable/presentation/screens/claimable_list_screen.dart';
import 'package:next_fi/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:next_fi/features/receive/presentation/screens/receive_screen.dart';
import 'package:next_fi/features/send/presentation/screens/send_screen.dart';
import 'package:next_fi/features/settings/presentation/screens/settings_screen.dart';
import 'package:next_fi/features/swap/presentation/screens/swap_screen.dart';
import 'package:next_fi/features/transactions/presentation/screens/transaction_screen.dart';
import 'package:next_fi/features/wallet_creation/presentation/screens/wallet_creation_screen.dart';
import 'package:next_fi/features/wallet_home/presentation/screens/wallet_home_screen.dart';

import 'widgets/app_bottom_navigation.dart';

const List<Widget> _shellScreens = [
  WalletHomeScreen(),
  TransactionScreen(),
  SwapScreen(),
  ClaimableListScreen(),
  SettingsScreen(),
];

class Home extends ConsumerStatefulWidget {
  const Home({super.key});

  @override
  ConsumerState<Home> createState() => _HomeState();
}

class _HomeState extends ConsumerState<Home> {
  bool _shownMissingWalletSnack = false;

  @override
  void initState() {
    super.initState();
    AppNavigationBridge.register(_handleAppNavigation);
  }

  @override
  void dispose() {
    AppNavigationBridge.unregister(_handleAppNavigation);
    super.dispose();
  }

  Future<bool> _handleAppNavigation(
    String route,
    Map<String, dynamic> payload,
  ) async {
    if (!mounted) return false;

    final normalizedRoute = route.trim().toLowerCase();
    final shell = ref.read(appShellProvider);
    if (shell.showSplash || shell.loading || !shell.hasMnemonic) {
      return false;
    }

    final tabs = ref.read(tabControllerProvider.notifier);
    final vm = ref.read(walletHomeVmProvider);
    final wallet = vm.state;
    final address = (wallet.address ?? '').trim();

    switch (normalizedRoute) {
      case 'wallet':
      case '/wallet':
      case 'home':
      case '/home':
        tabs.setTab(0);
        return true;
      case 'transactions':
      case '/transactions':
      case 'activity':
      case '/activity':
        tabs.setTab(1);
        return true;
      case 'swap':
      case '/swap':
        tabs.setTab(2);
        return true;
      case 'claimable':
      case '/claimable':
      case 'claims':
      case '/claims':
        tabs.setTab(3);
        return true;
      case 'settings':
      case '/settings':
        tabs.setTab(4);
        return true;
      case 'receive':
      case '/receive':
        if (address.isEmpty) return false;
        tabs.setTab(0);
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ReceiveScreen(
              address: address,
              initialAssetId:
                  (payload['assetId'] ?? payload['asset'] ?? 'stellar')
                      .toString(),
            ),
          ),
        );
        return true;
      case 'send':
      case '/send':
        if (address.isEmpty) return false;
        tabs.setTab(0);
        final assetId = (payload['assetId'] ?? payload['asset'] ?? 'stellar')
            .toString();
        final balance =
            wallet.balancesByAssetId[assetId] ??
            (assetId == 'stellar' ? wallet.xlm : 0.0);
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SendScreen(
              address: address,
              assetId: assetId,
              balance: balance,
              autoOpenScanner:
                  payload['scan']?.toString().toLowerCase() == 'true',
              prefillAddress: payload['address']?.toString(),
              prefillName: payload['name']?.toString(),
              onTransactionCompleted: () => vm.refresh(force: true),
            ),
          ),
        );
        return true;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppShellState>(appShellProvider, (prev, next) {
      final shouldShowMissingWallet =
          !next.showSplash &&
          !next.loading &&
          !next.hasMnemonic &&
          !next.showOnboarding;
      if (!_shownMissingWalletSnack && shouldShowMissingWallet && mounted) {
        _shownMissingWalletSnack = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          showFloatingSnackBar(
            context,
            message: 'No wallet found. Please create one.',
            type: SnackBarType.error,
          );
        });
      }
    });

    final shell = ref.watch(appShellProvider);
    final tab = ref.watch(tabControllerProvider);

    if (shell.showSplash) {
      return const WalletCreationScreen(isSplash: true);
    }

    if (shell.loading) {
      return const Scaffold(body: PageLoader(label: 'Loading wallet...'));
    }

    if (shell.showOnboarding) {
      return OnboardingScreen(
        onFinish: () =>
            ref.read(appShellProvider.notifier).completeOnboarding(),
      );
    }

    if (!shell.hasMnemonic) {
      return const WalletCreationScreen();
    }

    return Scaffold(
      body: _shellScreens[tab.currentIndex],
      bottomNavigationBar: const AppBottomNavigationPremium(),
    );
  }
}
