// lib/app/home.dart
import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/loader/page_loader.dart';
import 'package:next_fi/reusable_view_model/tab_vm.dart';
import 'package:next_fi/features/auth_gate/view/auth_gate_screen.dart';
import 'package:next_fi/features/wallet_creation/view/wallet_creation_screen.dart';
import 'package:next_fi/services/secure_storage/profit_address_vault_secure_storage.dart';
import 'package:next_fi/services/secure_storage/seed_storage.dart';
import 'package:provider/provider.dart';
import 'package:next_fi/common/components/snackbar/SnackBar.dart';
import 'package:next_fi/features/settings/view_model/settings_vm.dart' hide ThemeBridge;

import 'widgets/app_bottom_navigation.dart';

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
    _applySystemThemeToRoot();

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

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    _applySystemThemeToRoot();
  }

  void _applySystemThemeToRoot() {
    final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final mode = (brightness == Brightness.dark) ? ThemeMode.dark : ThemeMode.light;
    ThemeBridge.apply?.call(mode);
  }

  Future<void> _boot() async {
    await TransactionFeeVaultSecureStorage().initSignedConfigFromActiveWallet();
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

    if (_showSplash) {
      return const WalletCreationScreen(isSplash: true);
    }

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

    if (!_hasMnemonic) {
      return const WalletCreationScreen();
    }

    if (!_isAuthenticated) {
      return AuthGateScreen(goNext: _onAuthSuccess);
    }

    return ChangeNotifierProvider(
      create: (_) => TabVM(),
      child: Consumer<TabVM>(
        builder: (context, tabVM, _) {
          return Scaffold(
            body: tabVM.screens[tabVM.currentIndex],
            bottomNavigationBar: const AppBottomNavigationPremium(),
          );
        },
      ),
    );
  }
}