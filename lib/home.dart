import 'package:flutter/material.dart';
import 'package:next_fi/Components/SnackBar.dart';
import 'package:next_fi/Screen/wallet_creation_screen.dart';
import 'package:next_fi/Screen/auth_gate_screen.dart';
import 'package:next_fi/Services/seed_storage.dart';
import 'package:next_fi/Screen/wallet_home_screen.dart';

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

        // Delay snackbar until after build
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

    return Scaffold(
      body: _hasMnemonic
          ? AuthGateScreen(
        goNext: () async {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const WalletHomeScreen()),
            );
          }
        },
      )
          : const WalletCreationScreen(),
    );

  }
}
