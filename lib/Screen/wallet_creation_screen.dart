import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Components/CustomButton.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Screen/import_wallet_screen.dart';
import 'package:next_fi/Screen/seed_phrase_screen.dart';
import 'package:next_fi/Screen/auth_gate_screen.dart';

class WalletCreationScreen extends StatefulWidget {
  const WalletCreationScreen({super.key});

  @override
  State<WalletCreationScreen> createState() => _WalletCreationScreenState();
}

class _WalletCreationScreenState extends State<WalletCreationScreen> {
  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // ─── Top Section ───
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Moving Icon
                      Bounce(
                        infinite: true, // keeps bouncing forever
                        duration: const Duration(seconds: 3),
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.primary.withOpacity(0.08),
                          ),
                          child: Icon(
                            LucideIcons.wallet2,
                            size: 80,
                            color: colors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Title
                      FadeInUp(
                        duration: const Duration(milliseconds: 800),
                        delay: const Duration(milliseconds: 200),
                        child: Text(
                          "NextFI Wallet",
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Tagline
                      FadeInUp(
                        duration: const Duration(milliseconds: 800),
                        delay: const Duration(milliseconds: 300),
                        child: Text(
                          "Your key to Easy, Fast, User-controlled and Highly Secure Digital Payments",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: colors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Buttons ───
              FadeInUp(
                duration: const Duration(milliseconds: 800),
                delay: const Duration(milliseconds: 500),
                child: CustomButton(
                  text: "Create New Wallet",
                  icon: LucideIcons.plusCircle,
                  type: ButtonType.filled,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AuthGateScreen(
                          goNext: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SeedPhraseScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              FadeInUp(
                duration: const Duration(milliseconds: 800),
                delay: const Duration(milliseconds: 700),
                child: CustomButton(
                  text: "Import Wallet",
                  icon: LucideIcons.download,
                  type: ButtonType.outlined,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AuthGateScreen(
                          goNext: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ImportWalletScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
