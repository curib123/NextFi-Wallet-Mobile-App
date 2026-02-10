// lib/Screen/home.dart
import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/loader/page_loader.dart';
import 'package:next_fi/reusable_view_model/tab_vm.dart';
import 'package:next_fi/features/auth_gate/view/auth_gate_screen.dart';
import 'package:next_fi/features/wallet_creation/view/wallet_creation_screen.dart';
import 'package:next_fi/services/secure_storage/profit_address_vault_secure_storage.dart';
import 'package:next_fi/services/secure_storage/seed_storage.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/common/components/snackbar/SnackBar.dart';

import '../features/settings/view_model/settings_vm.dart' hide ThemeBridge;


class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  bool _showSplash = true;
  bool _isLoading = true;
  bool _hasMnemonic = false;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Apply system theme once at startup.
    _applySystemThemeToRoot();

    // Also react to platform brightness changes ASAP (in addition to didChangePlatformBrightness).
    WidgetsBinding.instance.platformDispatcher.onPlatformBrightnessChanged = () {
      _applySystemThemeToRoot();
    };

    _boot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Called by Flutter when platform brightness toggles (e.g., user changes system theme)
  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    _applySystemThemeToRoot();
  }

  void _applySystemThemeToRoot() {
    final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final mode = (brightness == Brightness.dark) ? ThemeMode.dark : ThemeMode.light;
    // Hand off to your app-level theme controller via ThemeBridge.
    ThemeBridge.apply?.call(mode);
  }

  Future<void> _boot() async {
    // initialize your signed fee config using the active wallet
    await TransactionFeeVaultSecureStorage().initSignedConfigFromActiveWallet();

    // Show splash for at least this long while we check storage.
    final minSplash = Future.delayed(const Duration(seconds: 5));
    final check = _checkMnemonic();
    await Future.wait([minSplash, check]);
    if (!mounted) return;
    setState(() => _showSplash = false);
  }

  Future<void> _checkMnemonic() async {
    final storedMnemonic = await SeedStorage.getSeed();

    if (!mounted) return;
    if (storedMnemonic != null && storedMnemonic.isNotEmpty) {
      setState(() {
        _hasMnemonic = true;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showFloatingSnackBar(
          context,
          message: "No wallet found. Please create one.",
          type: SnackBarType.error,
        );
      });
    }
  }

  void _onAuthSuccess() {
    if (!mounted) return;
    setState(() => _isAuthenticated = true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);

    // 1) Always show the splash first.
    if (_showSplash) {
      return const WalletCreationScreen(isSplash: true);
    }

    // 2) While still loading state (edge), show the 2×2 Rubik's outline loader.
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RubiksCubeLoader(
                size: 30,
                speed: const Duration(milliseconds: 1200),
                color: colors.textSecondary,
              ),
            ],
          ),
        ),
      );
    }

    // 3) If no wallet yet, go to your onboarding/creation screen.
    if (!_hasMnemonic) {
      return const WalletCreationScreen();
    }

    // 4) If wallet exists but not authenticated, gate with Auth.
    if (!_isAuthenticated) {
      return AuthGateScreen(goNext: _onAuthSuccess);
    }

    // 5) Authenticated main app with tabs.
    return ChangeNotifierProvider(
      create: (_) => TabVM(),
      child: Consumer<TabVM>(
        builder: (context, tabVM, _) {
          return Scaffold(
            body: tabVM.screens[tabVM.currentIndex],
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: tabVM.currentIndex,
              onTap: tabVM.setTab,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: colors.primary,
              unselectedItemColor: colors.textSecondary,
              showUnselectedLabels: true,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(LucideIcons.wallet),
                  label: 'Wallet',
                ),
                BottomNavigationBarItem(
                  icon: Icon(LucideIcons.shuffle),
                  label: 'Swap',
                ),
                BottomNavigationBarItem(
                  icon: Icon(LucideIcons.gift),
                  label: 'Claimable',
                ),
                BottomNavigationBarItem(
                  icon: Icon(LucideIcons.package),
                  label: 'Transaction',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}