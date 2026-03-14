import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/app/config/app_providers.dart';
import 'package:next_fi/core/widgets/loader/page_loader.dart';
import 'package:next_fi/core/widgets/snackbar/snack_bar.dart';
import 'package:next_fi/features/auth_gate/presentation/screens/auth_gate_screen.dart';
import 'package:next_fi/features/claimable/presentation/screens/claimable_list_screen.dart';
import 'package:next_fi/features/onboarding/presentation/screens/onboarding_screen.dart';
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

class _HomeState extends ConsumerState<Home> with WidgetsBindingObserver {
  bool _shownMissingWalletSnack = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _applySystemThemeToRoot();

    WidgetsBinding.instance.platformDispatcher.onPlatformBrightnessChanged = () {
      _applySystemThemeToRoot();
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    _applySystemThemeToRoot();
  }

  void _applySystemThemeToRoot() {
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final mode = brightness == Brightness.dark
        ? ThemeMode.dark
        : ThemeMode.light;
    ThemeBridge.apply?.call(mode);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppShellState>(appShellProvider, (prev, next) {
      final shouldShowMissingWallet = !next.showSplash &&
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
        onFinish: () => ref.read(appShellProvider.notifier).completeOnboarding(),
      );
    }

    if (!shell.hasMnemonic) {
      return const WalletCreationScreen();
    }

    if (!shell.isAuthenticated) {
      return AuthGateScreen(
        goNext: () => ref.read(appShellProvider.notifier).setAuthenticated(true),
      );
    }

    return Scaffold(
      body: _shellScreens[tab.currentIndex],
      bottomNavigationBar: const AppBottomNavigationPremium(),
    );
  }
}

