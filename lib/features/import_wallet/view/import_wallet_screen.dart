// lib/features/import_wallet/view/import_wallet_screen.dart
import 'package:flutter/material.dart';
import 'package:next_fi/common/components/button/app_buttons.dart';
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
import 'package:next_fi/common/components/snackbar/SnackBar.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class ImportWalletScreen extends StatefulWidget {
  const ImportWalletScreen({super.key});

  @override
  State<ImportWalletScreen> createState() => _ImportWalletScreenState();
}

class _ImportWalletScreenState extends State<ImportWalletScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _keyboardVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final bottomInset = View.of(context).viewInsets.bottom;
    final isKeyboardVisible = bottomInset > 0;

    if (_keyboardVisible != isKeyboardVisible) {
      setState(() {
        _keyboardVisible = isKeyboardVisible;
      });

      // Scroll to show suggestions when keyboard appears
      if (isKeyboardVisible) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_scrollController.hasClients && mounted) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // UI helpers
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _pasteFromClipboard(
    BuildContext context,
    ImportWalletVM vm,
  ) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final t = data?.text ?? '';
    if (t.trim().isNotEmpty) {
      _controller.text = t.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
      vm.updateText(_controller.text);
      HapticFeedback.mediumImpact();

      if (!mounted) return;
      showFloatingSnackBar(
        context,
        message: "Recovery phrase pasted",
        type: SnackBarType.success,
      );
    }
  }

  void _onSuggestionTap(ImportWalletVM vm, String word) {
    final newText = vm.replaceLastWord(_controller.text, word);
    _controller.text = newText;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: newText.length),
    );
    vm.updateText(newText);
    HapticFeedback.selectionClick();
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
      backgroundColor: colors.surface,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final ready = ackPrivate && ackCorrect;
          return _SecurityChecklistSheet(
            colors: colors,
            state: s,
            ackPrivate: ackPrivate,
            ackCorrect: ackCorrect,
            confirmEnabled: ready,
            onPrivateToggle: (v) => setS(() => ackPrivate = v),
            onCorrectToggle: (v) => setS(() => ackCorrect = v),
            onCancel: () => Navigator.pop(ctx, false),
            onConfirm: () => Navigator.pop(ctx, true),
          );
        },
      ),
    );

    if (ok == true && mounted) {
      await _startImportFlow(context, vm);
    }
  }

  Future<void> _startImportFlow(BuildContext context, ImportWalletVM vm) async {
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
              context.read<TabVM>().setTab(1);

              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }

              Phoenix.rebirth(context);
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
          backgroundColor: colors.background,
          extendBodyBehindAppBar: true,
          resizeToAvoidBottomInset: true,
          appBar: _buildAppBar(colors, vm),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    20,
                    MediaQuery.of(context).padding.top + 80,
                    20,
                    _keyboardVisible ? 120 : 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FadeInDown(
                        duration: const Duration(milliseconds: 300),
                        child: const WarningBox(),
                      ),
                      const SizedBox(height: 20),
                      FadeInDown(
                        duration: const Duration(milliseconds: 350),
                        child: _buildTextField(colors, vm, s),
                      ),
                      if (s.suggestions.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        FadeInUp(
                          duration: const Duration(milliseconds: 300),
                          child: _buildSuggestionChips(colors, vm, s),
                        ),
                        if (_keyboardVisible) const SizedBox(height: 20),
                      ],
                      const SizedBox(height: 16),
                      FadeInUp(
                        duration: const Duration(milliseconds: 400),
                        child: _buildPasteButton(context, colors, vm),
                      ),
                      if (s.error != null && s.error!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildErrorMessage(s.error!, colors),
                      ],
                    ],
                  ),
                ),
              ),
              // Fixed bottom import section
              _buildBottomActions(context, vm, s, colors),
            ],
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
      surfaceTintColor: colors.surface,
      leading: Container(
        margin: const EdgeInsets.only(left: 8),
        child: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colors.border.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
            child: Icon(
              LucideIcons.arrowLeft,
              color: colors.textPrimary,
              size: 20,
            ),
          ),
          onPressed: () => Navigator.pop(context),
          splashRadius: 24,
        ),
      ),
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colors.border.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.download, size: 18, color: colors.primary),
            const SizedBox(width: 10),
            Text(
              'Import Wallet',
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
      centerTitle: false,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          child: IconButton(
            tooltip: 'Paste',
            onPressed: () => _pasteFromClipboard(context, vm),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.primary.withValues(alpha: 0.12),
                    colors.primary.withValues(alpha: 0.06),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: Icon(
                LucideIcons.clipboardPaste,
                color: colors.primary,
                size: 18,
              ),
            ),
            splashRadius: 24,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    AppColor colors,
    ImportWalletVM vm,
    ImportWalletState s,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.surface, colors.surface.withValues(alpha: 0.95)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withValues(alpha: 0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Icon(
                  LucideIcons.keyRound,
                  size: 16,
                  color: colors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Recovery Phrase',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.1,
                  ),
                ),
                const Spacer(),
                WordBadge(count: s.wordCount),
              ],
            ),
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colors.border.withValues(alpha: 0),
                  colors.border.withValues(alpha: 0.2),
                  colors.border.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          TextField(
            controller: _controller,
            onChanged: vm.updateText,
            maxLines: 4,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w500,
              fontSize: 14,
              height: 1.6,
            ),
            decoration: InputDecoration(
              hintText: "Enter your 12 or 24 word recovery phrase...",
              hintStyle: TextStyle(
                color: colors.textSecondary.withValues(alpha: 0.5),
                fontWeight: FontWeight.w500,
              ),
              filled: false,
              contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              suffixIcon: (_controller.text.isNotEmpty)
                  ? IconButton(
                      tooltip: 'Clear',
                      onPressed: () {
                        _controller.clear();
                        vm.updateText('');
                        HapticFeedback.lightImpact();
                      },
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: colors.background.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          LucideIcons.x,
                          color: colors.textSecondary,
                          size: 14,
                        ),
                      ),
                    )
                  : null,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChips(
    AppColor colors,
    ImportWalletVM vm,
    ImportWalletState s,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.sparkles, size: 14, color: colors.primary),
            const SizedBox(width: 6),
            Text(
              'Suggestions',
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: s.suggestions.map((word) {
            return _SuggestionChip(
              word: word,
              colors: colors,
              onTap: () => _onSuggestionTap(vm, word),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPasteButton(
    BuildContext context,
    AppColor colors,
    ImportWalletVM vm,
  ) {
    return GestureDetector(
      onTap: () => _pasteFromClipboard(context, vm),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.primary.withValues(alpha: 0.08),
              colors.primary.withValues(alpha: 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colors.primary.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.clipboardPaste, size: 18, color: colors.primary),
            const SizedBox(width: 10),
            Text(
              'Paste from Clipboard',
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMessage(String error, AppColor colors) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.error.withValues(alpha: 0.12),
            colors.error.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.error.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.alertCircle, color: colors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error,
              style: TextStyle(
                color: colors.error,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(
    BuildContext context,
    ImportWalletVM vm,
    ImportWalletState s,
    AppColor colors,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.surface.withValues(alpha: 0.95), colors.surface],
        ),
        border: Border(
          top: BorderSide(color: colors.border.withValues(alpha: 0.1), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModernImportButton(
            text: s.importing ? "Importing..." : "Import Wallet",
            colors: colors,
            enabled: !s.importing,
            onPressed: s.importing
                ? () {}
                : () => _openImportChecklistModal(context, vm, s),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                LucideIcons.lightbulb,
                size: 16,
                color: colors.textSecondary.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Store offline & never share your recovery phrase",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Helper Widgets ──────────────────────────────────────────────────────────

class _SuggestionChip extends StatefulWidget {
  const _SuggestionChip({
    required this.word,
    required this.colors,
    required this.onTap,
  });

  final String word;
  final AppColor colors;
  final VoidCallback onTap;

  @override
  State<_SuggestionChip> createState() => _SuggestionChipState();
}

class _SuggestionChipState extends State<_SuggestionChip> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _isPressed
              ? widget.colors.primary.withValues(alpha: 0.15)
              : widget.colors.background.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isPressed
                ? widget.colors.primary.withValues(alpha: 0.3)
                : widget.colors.border.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: _isPressed
              ? []
              : [
                  BoxShadow(
                    color: widget.colors.textPrimary.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Text(
          widget.word,
          style: TextStyle(
            color: widget.colors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}

class _ModernImportButton extends StatefulWidget {
  const _ModernImportButton({
    required this.text,
    required this.colors,
    required this.enabled,
    required this.onPressed,
  });

  final String text;
  final AppColor colors;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  State<_ModernImportButton> createState() => _ModernImportButtonState();
}

class _ModernImportButtonState extends State<_ModernImportButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled
          ? (_) => setState(() => _isPressed = true)
          : null,
      onTapUp: widget.enabled
          ? (_) {
              setState(() => _isPressed = false);
              widget.onPressed();
            }
          : null,
      onTapCancel: widget.enabled
          ? () => setState(() => _isPressed = false)
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: widget.enabled
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _isPressed
                      ? [
                          widget.colors.primary.withValues(alpha: 0.9),
                          widget.colors.primary.withValues(alpha: 0.8),
                        ]
                      : [
                          widget.colors.primary,
                          widget.colors.primary.withValues(alpha: 0.9),
                        ],
                )
              : LinearGradient(
                  colors: [
                    widget.colors.primary.withValues(alpha: 0.5),
                    widget.colors.primary.withValues(alpha: 0.45),
                  ],
                ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: _isPressed || !widget.enabled
              ? []
              : [
                  BoxShadow(
                    color: widget.colors.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.download, size: 18, color: widget.colors.onPrimary),
            const SizedBox(width: 10),
            Text(
              widget.text,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: widget.colors.onPrimary,
                fontSize: 15,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Security Checklist Sheet ────────────────────────────────────────────────

class _SecurityChecklistSheet extends StatelessWidget {
  const _SecurityChecklistSheet({
    required this.colors,
    required this.state,
    required this.ackPrivate,
    required this.ackCorrect,
    required this.confirmEnabled,
    required this.onPrivateToggle,
    required this.onCorrectToggle,
    required this.onCancel,
    required this.onConfirm,
  });

  final AppColor colors;
  final ImportWalletState state;
  final bool ackPrivate;
  final bool ackCorrect;
  final bool confirmEnabled;
  final ValueChanged<bool> onPrivateToggle;
  final ValueChanged<bool> onCorrectToggle;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.surface, colors.surface.withValues(alpha: 0.98)],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: colors.border.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colors.border.withValues(alpha: 0.5),
                      colors.border.withValues(alpha: 0.3),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colors.warning.withValues(alpha: 0.15),
                          colors.warning.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colors.warning.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      LucideIcons.shieldCheck,
                      color: colors.warning,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Security Checklist",
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  WordBadge(count: state.wordCount),
                ],
              ),
              const SizedBox(height: 20),
              // Checklist items
              ConfirmTile(
                title: "I'm in a private place and trust this device.",
                icon: LucideIcons.eyeOff,
                value: ackPrivate,
                onChanged: onPrivateToggle,
                accent: colors.primary,
              ),
              const SizedBox(height: 12),
              ConfirmTile(
                title: "The phrase is complete, in order, and typed correctly.",
                icon: LucideIcons.checkSquare,
                value: ackCorrect,
                onChanged: onCorrectToggle,
                accent: colors.success,
              ),
              const SizedBox(height: 20),
              // Actions
              Row(
                children: [
                  Expanded(
                    child: _SheetButton(
                      icon: LucideIcons.x,
                      label: 'Cancel',
                      onPressed: onCancel,
                      colors: colors,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SheetButton(
                      icon: LucideIcons.check,
                      label: 'Confirm & Import',
                      onPressed: confirmEnabled ? onConfirm : () {},
                      colors: colors,
                      isPrimary: true,
                      enabled: confirmEnabled,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.colors,
    this.isPrimary = false,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final AppColor colors;
  final bool isPrimary;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AppElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary
            ? (enabled ? colors.primary : colors.primary.withValues(alpha: 0.5))
            : colors.background.withValues(alpha: 0.6),
        foregroundColor: isPrimary ? colors.onPrimary : colors.textPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: isPrimary
              ? BorderSide.none
              : BorderSide(color: colors.border.withValues(alpha: 0.25), width: 1.5),
        ),
      ),
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
