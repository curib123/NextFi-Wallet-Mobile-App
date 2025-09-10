// lib/Screen/home.dart
import 'package:flutter/material.dart';
import 'package:next_fi/Services/profit_address_vault_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Components/SnackBar.dart';
import 'package:next_fi/Screen/wallet_creation_screen.dart';
import 'package:next_fi/Screen/auth_gate_screen.dart';
import 'package:next_fi/Services/seed_storage.dart';
import 'package:next_fi/Provider/TabProvider.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool _showSplash = true;
  bool _isLoading = true;
  bool _hasMnemonic = false;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {

    await ProfitConfigVaultSecureStorage().initSignedConfigFromActiveWallet();

    // Show splash for at least this long while we check storage.
    final minSplash = Future.delayed(const Duration(seconds: 5 ));
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
      return const WalletCreationScreen(isSplash: true,);
    }

    // 2) While still loading state (edge), show a simple loader.
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 3) If no wallet yet, go to your onboarding/creation screen.
    //    Replace WalletCreationScreen with your preferred onboarding if needed.
    if (!_hasMnemonic) {
      return const WalletCreationScreen();
    }

    // 4) If wallet exists but not authenticated, gate with Auth.
    if (!_isAuthenticated) {
      return AuthGateScreen(goNext: _onAuthSuccess);
    }

    // 5) Authenticated main app with tabs.
    return ChangeNotifierProvider(
      create: (_) => TabProvider(),
      child: Consumer<TabProvider>(
        builder: (context, tabProvider, _) {
          return Scaffold(
            body: tabProvider.screens[tabProvider.currentIndex],
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: tabProvider.currentIndex,
              onTap: tabProvider.setTab,
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
                  icon: Icon(LucideIcons.package),
                  label: 'Transaction',
                ),
                BottomNavigationBarItem(
                  icon: Icon(LucideIcons.shuffle),
                  label: 'Swap',
                ),
                BottomNavigationBarItem(
                  icon: Icon(LucideIcons.settings),
                  label: 'Settings',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
