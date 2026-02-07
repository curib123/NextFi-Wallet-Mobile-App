// lib/features/import_wallet/view/import_wallet_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/reusable_view_model/tab_vm.dart';
import 'package:next_fi/features/auth_gate/view/auth_gate_screen.dart';
import 'package:next_fi/features/import_wallet/model/import_wallet_state.dart';
import 'package:next_fi/features/import_wallet/view/widgets/warning_box.dart';
import 'package:next_fi/features/import_wallet/view/widgets/word_badge.dart';
import 'package:next_fi/features/import_wallet/view_model/import_wallet_vm.dart';
import 'package:next_fi/features/seed_phrases/view/widgets/confirm_tile.dart';
import 'package:provider/provider.dart';
import 'package:next_fi/common/components/button/CustomButton.dart';
import 'package:next_fi/common/components/snackbar/SnackBar.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class ImportWalletScreen extends StatefulWidget {
  const ImportWalletScreen({super.key});

  @override
  State<ImportWalletScreen> createState() => _ImportWalletScreenState();
}

class _ImportWalletScreenState extends State<ImportWalletScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // UI helpers
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _pasteFromClipboard(BuildContext context, ImportWalletVM vm) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final t = data?.text ?? '';
    if (t.trim().isNotEmpty) {
      _controller.text = t.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
      vm.updateText(_controller.text);
      HapticFeedback.selectionClick();
    }
  }

  void _onSuggestionTap(ImportWalletVM vm, String word) {
    final newText = vm.replaceLastWord(_controller.text, word);
    _controller.text = newText;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: newText.length),
    );
    vm.updateText(newText);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Security checklist → import flow
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _openImportChecklistModal(
      BuildContext context,
      ImportWalletVM vm,
      ImportWalletState s,
      ) async {
    if (s.rawText.trim().isEmpty) {
      showFloatingSnackBar(
        context,
        message: "Enter your recovery phrase first.",
        type: SnackBarType.warning,
      );
      return;
    }

    final colors = AppColor.of(context);
    bool ackPrivate = false;
    bool ackCorrect = false;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: colors.surface,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
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
                _sheetHeader(colors, s),
                const SizedBox(height: 12),
                ConfirmTile(
                  title: "I'm in a private place and trust this device.",
                  icon: LucideIcons.eyeOff,
                  value: ackPrivate,
                  onChanged: (v) => setS(() => ackPrivate = v),
                  accent: colors.primary,
                ),
                const SizedBox(height: 10),
                ConfirmTile(
                  title: "The phrase is complete, in order, and typed correctly.",
                  icon: LucideIcons.checkSquare,
                  value: ackCorrect,
                  onChanged: (v) => setS(() => ackCorrect = v),
                  accent: colors.success,
                ),
                const SizedBox(height: 16),
                _sheetActions(
                  colors: colors,
                  confirmLabel: 'Confirm & Import',
                  confirmEnabled: ready,
                  onCancel: () => Navigator.pop(ctx, false),
                  onConfirm: () => Navigator.pop(ctx, true),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (ok == true && mounted) {
      await _startImportFlow(context, vm);
    }
  }

  Future<void> _startImportFlow(BuildContext context, ImportWalletVM vm) async {
    // Validate before opening AuthGate (async in SDK v3).
    final valid = await vm.validatePhrase();
    if (!valid) {
      if (!context.mounted) return;
      showFloatingSnackBar(
        context,
        message: "Invalid seed phrase. Please check again.",
        type: SnackBarType.error,
      );
      return;
    }

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AuthGateScreen(
          goNext: () async {
            if (!mounted) return;
            bool restarted = false;
            try {
              final ok = await vm.saveImported();
              if (!ok) {
                final err = vm.state.error;
                if (err != null && err.isNotEmpty && mounted) {
                  showFloatingSnackBar(
                    context,
                    message: err,
                    type: SnackBarType.error,
                  );
                }
                return;
              }

              if (!mounted) return;

              // Move to Wallet tab before clean restart.
              context.read<TabVM>().setTab(1);

              // Close auth screen before hard restart.
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }

              Phoenix.rebirth(context);
              restarted = true;
            } catch (e) {
              if (mounted) {
                showFloatingSnackBar(
                  context,
                  message: "Failed to import wallet. Please try again.",
                  type: SnackBarType.error,
                );
              }
            }
          },
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return Consumer<ImportWalletVM>(
      builder: (_, vm, __) {
        final s = vm.state;

        return Scaffold(
          backgroundColor: colors.surface,
          appBar: _buildAppBar(colors, vm),
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
                          child: const WarningBox(),
                        ),
                        const SizedBox(height: 10),
                        FadeInUp(
                          duration: const Duration(milliseconds: 700),
                          delay: const Duration(milliseconds: 200),
                          child: _buildTextField(colors, vm),
                        ),
                        if (s.suggestions.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: s.suggestions.map((w) {
                              return ActionChip(
                                label: Text(w),
                                backgroundColor: colors.background,
                                onPressed: () => _onSuggestionTap(vm, w),
                              );
                            }).toList(),
                          ),
                        ],
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => _pasteFromClipboard(context, vm),
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
                        if (s.error != null && s.error!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(s.error!,
                              style: const TextStyle(color: Colors.red)),
                        ],
                      ],
                    ),
                  ),
                ),
                Divider(
                    color: colors.border.withValues(alpha: 0.2), height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  child: Column(
                    children: [
                      SlideInUp(
                        delay: const Duration(milliseconds: 300),
                        child: CustomButton(
                          text: s.importing ? "Importing..." : "Import Wallet",
                          icon: LucideIcons.download,
                          type: ButtonType.filled,
                          onPressed: s.importing
                              ? () {}
                              : () => _openImportChecklistModal(context, vm, s),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SlideInUp(
                        delay: const Duration(milliseconds: 450),
                        child: Text(
                          "💡 Tip: Keep this phrase safe! Store it offline "
                              "or in a secure place. Never share it.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.textSecondary,
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
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // UI components
  // ──────────────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(AppColor colors, ImportWalletVM vm) {
    return AppBar(
      elevation: 0,
      backgroundColor: colors.surface,
      leading: IconButton(
        icon: Icon(LucideIcons.arrowLeft, color: colors.textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Import Wallet',
        style: TextStyle(
            color: colors.textPrimary, fontWeight: FontWeight.w600),
      ),
      actions: [
        IconButton(
          tooltip: 'Paste',
          onPressed: () => _pasteFromClipboard(context, vm),
          icon:
          Icon(LucideIcons.clipboardPaste, color: colors.textPrimary),
        ),
      ],
    );
  }

  Widget _buildTextField(AppColor colors, ImportWalletVM vm) {
    return TextField(
      controller: _controller,
      onChanged: vm.updateText,
      maxLines: 3,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        hintText: "Enter your 12 or 24 word recovery phrase",
        filled: true,
        fillColor: colors.background,
        suffixIcon: (_controller.text.isNotEmpty)
            ? IconButton(
          tooltip: 'Clear',
          onPressed: () {
            _controller.clear();
            vm.updateText('');
          },
          icon: Icon(LucideIcons.x, color: colors.textSecondary),
        )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border.withValues(alpha: 0.2)),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Bottom-sheet helpers
  // ──────────────────────────────────────────────────────────────────────────

  Widget _sheetHeader(AppColor colors, ImportWalletState s) {
    return Row(children: [
      Icon(LucideIcons.shieldCheck, color: colors.textPrimary, size: 20),
      const SizedBox(width: 8),
      Text(
        "Security checklist",
        style: TextStyle(
            color: colors.textPrimary, fontWeight: FontWeight.w700),
      ),
      const Spacer(),
      WordBadge(count: s.wordCount),
    ]);
  }

  Widget _sheetActions({
    required AppColor colors,
    required String confirmLabel,
    required VoidCallback onCancel,
    required VoidCallback onConfirm,
    bool confirmEnabled = true,
  }) {
    return Row(children: [
      Expanded(
        child: OutlinedButton(
          onPressed: onCancel,
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.textSecondary,
            side: BorderSide(color: colors.border.withValues(alpha: 0.8)),
          ),
          child: const Text('Cancel'),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: FilledButton(
          onPressed: confirmEnabled ? onConfirm : null,
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.disabled)
                  ? colors.primary.withValues(alpha: 0.45)
                  : colors.primary,
            ),
            foregroundColor: const WidgetStatePropertyAll(Colors.white),
          ),
          child: Text(confirmLabel),
        ),
      ),
    ]);
  }
}