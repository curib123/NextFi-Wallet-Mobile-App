import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Components/CustomButton.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Components/SnackBar.dart';
import 'package:next_fi/Provider/TabProvider.dart';
import 'package:next_fi/Screen/auth_gate_screen.dart';
import 'package:next_fi/Services/seed_storage.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:bip39/src/wordlists/english.dart' as english;
import 'package:provider/provider.dart';

class ImportWalletScreen extends StatefulWidget {
  const ImportWalletScreen({super.key});

  @override
  State<ImportWalletScreen> createState() => _ImportWalletScreenState();
}

class _ImportWalletScreenState extends State<ImportWalletScreen> {
  final TextEditingController _mnemonicController = TextEditingController();
  List<String> _suggestions = [];
  bool _isImporting = false;

  @override
  void dispose() {
    _mnemonicController.dispose();
    super.dispose();
  }

  // ---------- Input helpers ----------
  String _sanitizedMnemonic(String text) =>
      text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  void _onTextChanged(String text) {
    final words = text.trim().split(RegExp(r'\s+'));
    final lastWord = words.isNotEmpty ? words.last : "";

    if (lastWord.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }

    final matches =
    english.WORDLIST.where((w) => w.startsWith(lastWord)).take(6).toList();

    setState(() => _suggestions = matches);
  }

  void _insertSuggestion(String word) {
    final text = _mnemonicController.text.trim();
    final words = text.isEmpty ? <String>[] : text.split(RegExp(r'\s+'));

    if (words.isEmpty) {
      words.add(word);
    } else {
      words[words.length - 1] = word;
    }

    _mnemonicController.text = "${words.join(" ")} ";
    _mnemonicController.selection = TextSelection.fromPosition(
      TextPosition(offset: _mnemonicController.text.length),
    );

    setState(() => _suggestions = []);
  }

  // ---------- Import flow ----------
  Future<void> _importWallet() async {
    final mnemonic = _sanitizedMnemonic(_mnemonicController.text);

    // 1) Validate mnemonic using bip39
    if (!bip39.validateMnemonic(mnemonic)) {
      showFloatingSnackBar(
        context,
        message: "Invalid seed phrase. Please check again.",
        type: SnackBarType.error,
      );
      return;
    }

    if (!mounted) return;

    // 2) Navigate to AuthGateScreen and run the save logic inside goNext
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AuthGateScreen(
          goNext: () async {
            if (_isImporting) return;
            setState(() => _isImporting = true);

            try {
              final ok = await SeedStorage.saveSeed(mnemonic);
              if (!ok) {
                showFloatingSnackBar(
                  context,
                  message: "Failed to save your wallet. Please try again.",
                  type: SnackBarType.error,
                );
                return;
              }

              // Success: set tab and restart
              if (!mounted) return;
              context.read<TabProvider>().setTab(1);
              Phoenix.rebirth(context);
            } catch (e) {
              showFloatingSnackBar(
                context,
                message: "⚠️ Failed to import wallet. Please try again.",
                type: SnackBarType.error,
              );
            } finally {
              if (mounted) setState(() => _isImporting = false);
            }
          },
        ),
      ),
    );
  }

  // ---------- Modal: Security checklist BEFORE importing ----------
  Future<void> _openImportChecklistModal() async {
    final colors = AppColor.of(context);
    final raw = _sanitizedMnemonic(_mnemonicController.text);
    if (raw.isEmpty) {
      showFloatingSnackBar(
        context,
        message: "Enter your recovery phrase first.",
        type: SnackBarType.warning,
      );
      return;
    }

    bool ackPrivate = false;
    bool ackCorrect = false;

    final wordsCount =
    raw.isEmpty ? 0 : raw.split(' ').where((w) => w.isNotEmpty).length;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: colors.surface,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final ready = ackPrivate && ackCorrect;

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 8,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.shieldCheck,
                          color: colors.textPrimary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "Security checklist",
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      _wordBadge(colors, wordsCount),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Tile 1
                  _confirmTile(
                    colors: colors,
                    value: ackPrivate,
                    onChanged: (v) => setModalState(() => ackPrivate = v),
                    leadingIcon: LucideIcons.eyeOff,
                    title: "I'm in a private place and trust this device.",
                    accent: colors.primary,
                  ),
                  const SizedBox(height: 10),

                  // Tile 2
                  _confirmTile(
                    colors: colors,
                    value: ackCorrect,
                    onChanged: (v) => setModalState(() => ackCorrect = v),
                    leadingIcon: LucideIcons.checkSquare,
                    title:
                    "The phrase is complete, in order, and typed correctly.",
                    accent: colors.success,
                  ),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.textSecondary,
                            side: BorderSide(
                                color: colors.border.withOpacity(.8)),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: ready ? () => Navigator.pop(ctx, true) : null,
                          style: ButtonStyle(
                            backgroundColor:
                            MaterialStateProperty.resolveWith((s) {
                              final disabled = s.contains(MaterialState.disabled);
                              return disabled
                                  ? colors.primary.withOpacity(.45)
                                  : colors.primary;
                            }),
                            foregroundColor:
                            const MaterialStatePropertyAll(Colors.white),
                          ),
                          child: const Text('Confirm & Import'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (ok == true) {
      await _importWallet();
    }
  }

  Widget _wordBadge(AppColor colors, int count) {
    String label = "$count words";
    Color tint = colors.background;
    Color text = colors.textSecondary;
    if (count == 12 || count == 24) {
      tint = colors.success.withOpacity(.12);
      text = colors.success;
    } else if (count > 0) {
      tint = colors.warning.withOpacity(.12);
      text = colors.warning;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: text.withOpacity(.35)),
      ),
      child: Text(
        label,
        style: TextStyle(color: text, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  // ---------- UI ----------
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
        actions: [
          IconButton(
            tooltip: 'Paste',
            onPressed: () async {
              final data = await Clipboard.getData(Clipboard.kTextPlain);
              final t = data?.text ?? "";
              if (t.trim().isNotEmpty) {
                _mnemonicController.text = _sanitizedMnemonic(t);
                _onTextChanged(_mnemonicController.text);
                HapticFeedback.selectionClick();
              }
            },
            icon: Icon(LucideIcons.clipboardPaste, color: colors.textPrimary),
          ),
        ],
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
                          suffixIcon: (_mnemonicController.text.isNotEmpty)
                              ? IconButton(
                            tooltip: 'Clear',
                            onPressed: () {
                              _mnemonicController.clear();
                              _onTextChanged('');
                              setState(() => _suggestions = []);
                            },
                            icon: Icon(LucideIcons.x, color: colors.textSecondary),
                          )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                            BorderSide(color: colors.border.withOpacity(0.2)),
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
                        final data = await Clipboard.getData(Clipboard.kTextPlain);
                        if (data?.text != null && data!.text!.isNotEmpty) {
                          _mnemonicController.text =
                              _sanitizedMnemonic(data.text!);
                          _onTextChanged(_mnemonicController.text);
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
                      text: _isImporting ? "Importing..." : "Import Wallet",
                      icon: LucideIcons.download,
                      type: ButtonType.filled,
                      onPressed: _isImporting ? () {} : _openImportChecklistModal,
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

  // ---------- Reusable UI pieces ----------
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

  Widget _confirmTile({
    required AppColor colors,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData leadingIcon,
    required String title,
    required Color accent,
  }) {
    final bgOn = accent.withOpacity(0.08);
    final borderOn = accent.withOpacity(0.9);

    return Semantics(
      button: true,
      toggled: value,
      label: title,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(!value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: value ? bgOn : colors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: value ? borderOn : colors.border.withOpacity(0.25),
            ),
          ),
          child: Row(
            children: [
              // Left accent bar
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: 4,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: value
                        ? [accent.withOpacity(.9), accent.withOpacity(.55)]
                        : [Colors.transparent, Colors.transparent],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Leading icon
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: value ? accent.withOpacity(.15) : colors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: value ? borderOn : colors.border.withOpacity(.25),
                  ),
                ),
                child: Icon(
                  leadingIcon,
                  size: 18,
                  color: value ? accent : colors.textSecondary,
                ),
              ),
              const SizedBox(width: 10),

              // Title
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Trailing animated check
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: value
                    ? Icon(LucideIcons.checkCircle,
                    key: const ValueKey('on'), color: accent, size: 22)
                    : Icon(LucideIcons.circle,
                    key: const ValueKey('off'),
                    color: colors.border,
                    size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
