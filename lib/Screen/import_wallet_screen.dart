import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animate_do/animate_do.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Components/CustomButton.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Components/SnackBar.dart';
import 'package:next_fi/Screen/auth_gate_screen.dart';
import 'package:next_fi/Services/seed_storage.dart';
import 'package:bip39/src/wordlists/english.dart' as english;
import 'package:next_fi/Services/tron_wallet_services.dart';

import 'wallet_home_screen.dart';

class ImportWalletScreen extends StatefulWidget {
  const ImportWalletScreen({super.key});

  @override
  State<ImportWalletScreen> createState() => _ImportWalletScreenState();
}

class _ImportWalletScreenState extends State<ImportWalletScreen> {
  final TextEditingController _mnemonicController = TextEditingController();

  List<String> _suggestions = [];

  @override
  void dispose() {
    _mnemonicController.dispose();
    super.dispose();
  }

  void _onTextChanged(String text) {
    final words = text.trim().split(RegExp(r'\s+'));
    final lastWord = words.isNotEmpty ? words.last : "";

    if (lastWord.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }

    final matches = english.WORDLIST
        .where((w) => w.startsWith(lastWord))
        .take(6)
        .toList();

    setState(() => _suggestions = matches);
  }

  void _insertSuggestion(String word) {
    final text = _mnemonicController.text.trim();
    final words = text.split(RegExp(r'\s+'));

    if (words.isNotEmpty) {
      words[words.length - 1] = word;
    } else {
      words.add(word);
    }

    _mnemonicController.text = "${words.join(" ")} ";
    _mnemonicController.selection = TextSelection.fromPosition(
      TextPosition(offset: _mnemonicController.text.length),
    );

    setState(() => _suggestions = []);
  }

  Future<void> _importWallet() async {
    final mnemonic = _mnemonicController.text.trim().toLowerCase();

    // Use TronWalletService for validation
    if (!TronWalletService.validateMnemonic(mnemonic)) {
      showFloatingSnackBar(
        context,
        message: "Invalid seed phrase. Please check again.",
        type: SnackBarType.error,
      );
      return;
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AuthGateScreen(
          goNext: () async {
            try {
              await SeedStorage.saveSeed(mnemonic);

              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const WalletHomeScreen()),
                );
              }
            } catch (e) {
              showFloatingSnackBar(
                context,
                message: "⚠️ Failed to import wallet. Please try again.",
                type: SnackBarType.error,
              );
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);

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
          'Import Wallet',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FadeInUp(
                      duration: const Duration(milliseconds: 600),
                      child: _warningBox(colors),
                    ),
                    const SizedBox(height: 10),
                    FadeInUp(
                      duration: const Duration(milliseconds: 700),
                      delay: const Duration(milliseconds: 200),
                      child: TextField(
                        controller: _mnemonicController,
                        onChanged: _onTextChanged,
                        maxLines: 3,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          hintText: "Enter your 12 or 24 word recovery phrase",
                          filled: true,
                          fillColor: colors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: colors.border.withOpacity(0.2),
                            ),
                          ),
                        ),
                      ),
                    ),

                    if (_suggestions.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _suggestions.map((s) {
                          return ActionChip(
                            label: Text(s),
                            backgroundColor: colors.background,
                            onPressed: () => _insertSuggestion(s),
                          );
                        }).toList(),
                      ),
                    ],

                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () async {
                        final data =
                        await Clipboard.getData(Clipboard.kTextPlain);
                        if (data?.text != null && data!.text!.isNotEmpty) {
                          _mnemonicController.text = data.text!.trim();
                        }
                      },
                      child: FadeInUp(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(LucideIcons.clipboardPaste,
                                size: 16, color: colors.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              'Paste from Clipboard',
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
                      text: "Import Wallet",
                      icon: LucideIcons.download,
                      type: ButtonType.filled,
                      onPressed: _importWallet,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SlideInUp(
                    delay: const Duration(milliseconds: 450),
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
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
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
          child: Text(
            "Enter your recovery phrase exactly as saved. "
                "Suggestions will help you auto-complete words.",
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ),
      ],
    ),
  );
}
