import 'package:flutter/material.dart';
import 'package:next_fi/Components/SnackBar.dart';
import 'package:next_fi/Screen/wallet_creation_screen.dart';
import 'package:next_fi/Screen/wallet_home_screen.dart';
import 'package:next_fi/Services/seed_storage.dart';
import 'package:next_fi/Screen/auth_gate_screen.dart'; // 👈 import your auth gate

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkMnemonic();
  }

  Future<void> _checkMnemonic() async {
    String? storedMnemonic = await SeedStorage.getSeed();

    if (storedMnemonic != null && storedMnemonic.isNotEmpty) {
      if (mounted) {
        // 👇 Wrap WalletHomeScreen with AuthGateScreen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AuthGateScreen(
              goNext: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const WalletHomeScreen()),
                );
              },
            ),
          ),
        );
      }
    } else {
      if (mounted) {
        showFloatingSnackBar(
          context,
          message: "Failed to save your wallet. Please try again.",
          type: SnackBarType.error,
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return const Scaffold(
      body: WalletCreationScreen(),
    );
  }
}
