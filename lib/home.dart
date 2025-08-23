import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Components/SnackBar.dart';
import 'package:next_fi/Screen/wallet_creation_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _checkMnemonic();
  }

  Future<void> _checkMnemonic() async {
    final storedMnemonic = await SeedStorage.getSeed();

    if (storedMnemonic != null && storedMnemonic.isNotEmpty) {
      if (mounted) {
        setState(() {
          _hasMnemonic = true;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            showFloatingSnackBar(
              context,
              message: "No wallet found. Please create one.",
              type: SnackBarType.error,
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => TabProvider(),
      child: Consumer<TabProvider>(
        builder: (context, tabProvider, _) {
          if (_hasMnemonic) {
            return Scaffold(
              body: tabProvider.screens[tabProvider.currentIndex],
              bottomNavigationBar: BottomNavigationBar(
                currentIndex: tabProvider.currentIndex,
                onTap: tabProvider.setTab,
                type: BottomNavigationBarType.fixed,
                selectedItemColor: Colors.teal,
                unselectedItemColor: Colors.grey,
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
          } else {
            return const WalletCreationScreen();
          }
        },
      ),
    );
  }
}
