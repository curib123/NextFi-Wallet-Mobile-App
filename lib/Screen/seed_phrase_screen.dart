import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animate_do/animate_do.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Components/CustomButton.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Components/SnackBar.dart';
import 'package:next_fi/Screen/auth_gate_screen.dart';
import 'package:next_fi/Services/seed_storage.dart';
import 'package:next_fi/Services/stellar_wallet_services.dart';
import 'wallet_home_screen.dart';

class SeedPhraseScreen extends StatefulWidget {
  const SeedPhraseScreen({super.key});

  @override
  State<SeedPhraseScreen> createState() => _SeedPhraseScreenState();
}

class _SeedPhraseScreenState extends State<SeedPhraseScreen> {
  String _mnemonic = "";
  List<String> _words = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _generateMnemonic();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final colors = AppColor.of(context);
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarColor: colors.surface,
          statusBarIconBrightness: Brightness.dark,
        ),
      );
    });
  }

  Future<void> _generateMnemonic() async {
    _mnemonic = await StellarWalletService.generateMnemonic(); // async
    _words = _mnemonic.split(' ');
    if (mounted) setState(() {});
  }

  void _copySeedPhrase() {
    Clipboard.setData(ClipboardData(text: _mnemonic));
    final colors = AppColor.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Copied seed phrase (keep it safe!)',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: colors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _secureAndContinue() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AuthGateScreen(
          goNext: () async {
            try {
              setState(() => _isLoading = true);

              await SeedStorage.saveSeed(_mnemonic);

              final storedMnemonic = await SeedStorage.getSeed();
              if (storedMnemonic != null && storedMnemonic.isNotEmpty) {
                if (mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const WalletHomeScreen()),
                  );
                }
              } else {
                showFloatingSnackBar(
                  context,
                  message: "Failed to save your wallet. Please try again.",
                  type: SnackBarType.error,
                );
              }
            } catch (e) {
              showFloatingSnackBar(
                context,
                message: "Unexpected error: $e",
                type: SnackBarType.error,
              );
            } finally {
              if (mounted) setState(() => _isLoading = false);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colors.surface,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Your Recovery Phrase',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    FadeInUp(
                      duration: const Duration(milliseconds: 650),
                      child: _warningBox(colors),
                    ),
                    const SizedBox(height: 24),
                    FadeInUp(
                      duration: const Duration(milliseconds: 700),
                      delay: const Duration(milliseconds: 200),
                      child: _seedGrid(colors),
                    ),
                    const SizedBox(height: 20),
                    FadeInUp(
                      delay: const Duration(milliseconds: 300),
                      child: GestureDetector(
                        onTap: _copySeedPhrase,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.copy, size: 16, color: colors.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              'Copy to Clipboard',
                              style: TextStyle(
                                color: colors.textSecondary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Divider(color: colors.border.withOpacity(0.2), height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                children: [
                  SlideInUp(
                    delay: const Duration(milliseconds: 300),
                    child: CustomButton(
                      text: "Secure & Continue",
                      icon: LucideIcons.arrowRight,
                      type: ButtonType.filled,
                      onPressed: _secureAndContinue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SlideInUp(
                    delay: const Duration(milliseconds: 450),
                    child: CustomButton(
                      text: "Get a New Phrase",
                      icon: LucideIcons.refreshCw,
                      type: ButtonType.outlined,
                      onPressed: _generateMnemonic,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FadeInUp(
                    delay: const Duration(milliseconds: 300),
                    child: Text(
                      "💡 Tip: Keep this phrase safe! Store it offline or in a secure place. Never share it.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColor.of(context).textSecondary,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _warningBox(AppColor colors) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: colors.warning.withOpacity(0.12),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: colors.warning.withOpacity(0.35)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(LucideIcons.alertTriangle, color: colors.warning, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 13,
                height: 1.45,
              ),
              children: [
                TextSpan(
                  text: "Keep your recovery phrase safe.\n",
                  style: TextStyle(
                    color: colors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text:
                  "Keep it private and secure — NextFI never stores your keys, so you are always in control of your funds.",
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _seedGrid(AppColor colors) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 5),
    decoration: BoxDecoration(
      color: colors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: colors.border.withOpacity(0.25)),
    ),
    child: GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 5,
        childAspectRatio: 2.3,
      ),
      itemCount: _words.length,
      itemBuilder: (context, index) {
        final idx = index + 1;
        final word = _words[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border.withOpacity(0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '$idx.',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  word,
                  softWrap: true,
                  overflow: TextOverflow.visible,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
