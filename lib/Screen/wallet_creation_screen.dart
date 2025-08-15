import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Components/CustomButton.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Screen/import_wallet_screen.dart';
import 'package:next_fi/Screen/seed_phrase_screen.dart';

class WalletCreationScreen extends StatefulWidget {
  const WalletCreationScreen({super.key});

  @override
  State<WalletCreationScreen> createState() => _WalletCreationScreenState();
}

class _WalletCreationScreenState extends State<WalletCreationScreen> {
  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);

    return SafeArea(
      child: Container(
        color: colors.surface,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // ─── Top Section ───
              Expanded(
                child: Align(
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon from top
                      FadeInDown(
                        duration: const Duration(milliseconds: 900),
                        child: Icon(
                          LucideIcons.shield,
                          size: 110,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Title from left
                      FadeInLeft(
                        duration: const Duration(milliseconds: 800),
                        delay: const Duration(milliseconds: 200),
                        child: Text(
                          "NextFI Wallet",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: colors.textPrimary,
                            height: 1.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Tagline from right
                      FadeInRight(
                        duration: const Duration(milliseconds: 800),
                        delay: const Duration(milliseconds: 400),
                        child: Text(
                          "Your super-easy, lightning-fast wallet for all your money — send funds to anyone, receive payments instantly, and manage your balance safely and securely, anywhere in the world, without borders or complicated steps.",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: colors.textSecondary,
                            height: 1.6,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Buttons from bottom ───
              FadeInUp(
                duration: const Duration(milliseconds: 800),
                delay: const Duration(milliseconds: 600),
                child: CustomButton(
                  text: "Create New Wallet",
                  icon: LucideIcons.plusCircle,
                  type: ButtonType.filled,
                  onPressed: () {
                    // TODO: Create wallet logic
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SeedPhraseScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              FadeInUp(
                duration: const Duration(milliseconds: 800),
                delay: const Duration(milliseconds: 800),
                child: CustomButton(
                  text: "Import Wallet",
                  icon: LucideIcons.download,
                  type: ButtonType.outlined,
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ImportWalletScreen(),
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
