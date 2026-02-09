// lib/Screen/home.dart
import 'package:flutter/material.dart';
import 'package:next_fi/features/settings/view_model/settings_vm.dart' hide ThemeBridge;
import 'package:next_fi/services/secure_storage/profit_address_vault_secure_storage.dart';
import 'package:next_fi/common/components/loader/page_loader.dart';
import 'package:next_fi/reusable_view_model/tab_vm.dart';
import 'package:next_fi/features/auth_gate/view/auth_gate_screen.dart';
import 'package:next_fi/features/wallet_creation/view/wallet_creation_screen.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/snackbar/SnackBar.dart';
import 'package:next_fi/services/secure_storage/seed_storage.dart';

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
    WidgetsBinding.instance.platformDispatcher.onPlatformBrightnessChanged =
        () => _applySystemThemeToRoot();
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
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final mode =
    (brightness == Brightness.dark) ? ThemeMode.dark : ThemeMode.light;
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
        if (!mounted) return;
        showFloatingSnackBar(
          context,
          message: 'No wallet found. Please create one.',
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
    final c = AppColor.of(context);

    // 1) Splash
    if (_showSplash) {
      return const WalletCreationScreen(isSplash: true);
    }

    // 2) Loading
    if (_isLoading) {
      return Scaffold(
        backgroundColor: c.background,
        body: Center(
          child: RubiksCubeLoader(
            size: 30,
            speed: const Duration(milliseconds: 1200),
            color: c.textSecondary,
          ),
        ),
      );
    }

    // 3) No wallet → onboarding
    if (!_hasMnemonic) {
      return const WalletCreationScreen();
    }

    // 4) Auth gate
    if (!_isAuthenticated) {
      return AuthGateScreen(goNext: _onAuthSuccess);
    }

    // 5) Main app
    return ChangeNotifierProvider(
      create: (_) => TabVM(),
      child: Consumer<TabVM>(
        builder: (context, tabVM, _) {
          return Scaffold(
            backgroundColor: c.background,
            body: tabVM.screens[tabVM.currentIndex],
            bottomNavigationBar: _buildBottomNav(c, tabVM),
          );
        },
      ),
    );
  }

  Widget _buildBottomNav(AppColor c, TabVM tabVM) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(
          top: BorderSide(color: c.border.withValues(alpha: 0.12)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              _navItem(c, tabVM, 0, LucideIcons.wallet, 'Wallet'),
              _navItem(c, tabVM, 1, LucideIcons.arrowLeftRight, 'Swap'),
              _navItem(c, tabVM, 2, LucideIcons.gift, 'Claimable'),
              _navItem(c, tabVM, 3, LucideIcons.history, 'Activity'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(
      AppColor c,
      TabVM tabVM,
      int index,
      IconData icon,
      String label,
      ) {
    final active = tabVM.currentIndex == index;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => tabVM.setTab(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: active
                      ? c.primary.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: active
                      ? c.primary
                      : c.textSecondary.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active
                      ? c.primary
                      : c.textSecondary.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}