import 'package:flutter/material.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
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
  bool _isLoading = true;
  bool _hasMnemonic = false;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkMnemonic();
  }

  Future<void> _checkMnemonic() async {
    final storedMnemonic = await SeedStorage.getSeed();

    if (mounted) {
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
  }

  void _onAuthSuccess() {
    if (mounted) {
      setState(() => _isAuthenticated = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // If no wallet, show WalletCreationScreen
    if (!_hasMnemonic) {
      return const WalletCreationScreen();
    }

    // If wallet exists but not authenticated, show AuthGate
    if (!_isAuthenticated) {
      return AuthGateScreen(
        goNext: _onAuthSuccess,
      );
    }

    // If authenticated and wallet exists, show main home with tabs
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
                  icon: Icon(LucideIcons.zap),
                  label: 'Stake',
                ),
                BottomNavigationBarItem(
                  icon: Icon(LucideIcons.shuffle),
                  label: 'Swap',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
