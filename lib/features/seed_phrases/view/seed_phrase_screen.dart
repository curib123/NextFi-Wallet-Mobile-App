// lib/features/seed_phrases/view/seed_phrase_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/features/seed_phrases/view/widgets/word_picker.dart';
import 'package:provider/provider.dart';

import 'package:next_fi/reusable_view_model/tab_vm.dart';
import 'package:next_fi/features/auth_gate/view/auth_gate_screen.dart';
import 'package:next_fi/features/seed_phrases/view/widgets/confirm_tile.dart';
import 'package:next_fi/features/seed_phrases/view/widgets/meta_header.dart';
import 'package:next_fi/features/seed_phrases/view/widgets/phrase_card.dart';
import 'package:next_fi/features/seed_phrases/view_model/seed_phrase_vm.dart';

import 'package:next_fi/common/components/button/CustomButton.dart';
import 'package:next_fi/common/components/snackbar/SnackBar.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

import '../model/seed_phrase_state.dart';

class SeedPhraseScreen extends StatefulWidget {
  const SeedPhraseScreen({super.key});

  @override
  State<SeedPhraseScreen> createState() => _SeedPhraseScreenState();
}

class _SeedPhraseScreenState extends State<SeedPhraseScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final colors = AppColor.of(context);
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: colors.surface,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      );
      await context.read<SeedPhraseVM>().init();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (mounted) context.read<SeedPhraseVM>().forceHide();
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _copyAll(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    if (!context.mounted) return;
    final colors = AppColor.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(LucideIcons.checkCircle2, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Copied seed phrase (keep it safe!)',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: colors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _showCopyGuide(BuildContext context, SeedPhraseState s) async {
    if (s.obscured) {
      showFloatingSnackBar(
        context,
        message: "Reveal the phrase first to copy.",
        type: SnackBarType.info,
      );
      return;
    }
    final colors = AppColor.of(context);
    final ok = await _showActionSheet<bool>(
      context: context,
      icon: LucideIcons.copy,
      title: 'Copy recovery phrase?',
      confirmLabel: 'Copy anyway',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _guideRow(colors, LucideIcons.shieldAlert, "Never share your phrase",
              "Anyone with this phrase can control your funds."),
          const SizedBox(height: 14),
          _guideRow(colors, LucideIcons.phoneOff, "Avoid screenshots",
              "Screenshots may be backed up to cloud services."),
          const SizedBox(height: 14),
          _guideRow(colors, LucideIcons.eye, "Ensure privacy",
              "Make sure no one is looking at your screen."),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await _copyAll(context, s.mnemonic);
    }
  }

  Future<void> _confirmRegenerate(
      BuildContext context, {
        int? wordCount,
      }) async {
    final colors = AppColor.of(context);
    final ok = await _showActionSheet<bool>(
      context: context,
      icon: LucideIcons.refreshCw,
      title: 'Generate a new phrase',
      confirmLabel: 'Generate',
      body: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'This will replace the current recovery phrase with a new one. '
              'Make sure you have securely stored the current phrase if you '
              'still need it.',
          style: TextStyle(
            color: colors.textSecondary,
            height: 1.5,
            fontSize: 14,
          ),
        ),
      ),
    );
    if (ok == true && context.mounted) {
      await context
          .read<SeedPhraseVM>()
          .regenerate(wordCountOverride: wordCount);
      if (!context.mounted) return;
      final chosen = wordCount ?? context.read<SeedPhraseVM>().wordCount;
      showFloatingSnackBar(
        context,
        message: 'Generated a new $chosen-word recovery phrase.',
        type: SnackBarType.success,
      );
    }
  }

  Future<void> _openChecklist(
      BuildContext context,
      SeedPhraseVM vm,
      SeedPhraseState s,
      ) async {
    if (s.obscured) {
      showFloatingSnackBar(
        context,
        message: "Reveal your recovery phrase first.",
        type: SnackBarType.warning,
      );
      return;
    }
    if (s.loading) return;

    final colors = AppColor.of(context);
    bool a1 = s.ack1, a2 = s.ack2;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final ready = a1 && a2;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors.surface,
                  colors.surface.withOpacity(0.98),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: colors.border.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _sheetHeader(
                      colors, LucideIcons.shieldCheck, "Security checklist"),
                  const SizedBox(height: 20),
                  ConfirmTile(
                    title:
                    "I wrote my recovery phrase on paper (or stored it offline).",
                    icon: LucideIcons.pencil,
                    value: a1,
                    onChanged: (v) => setS(() => a1 = v),
                    accent: colors.primary,
                  ),
                  const SizedBox(height: 12),
                  ConfirmTile(
                    title:
                    "I understand NextFi cannot help recover this phrase.",
                    icon: LucideIcons.shield,
                    value: a2,
                    onChanged: (v) => setS(() => a2 = v),
                    accent: colors.success,
                  ),
                  const SizedBox(height: 20),
                  _sheetActions(
                    colors: colors,
                    confirmLabel: 'Confirm & Secure',
                    confirmEnabled: ready,
                    onCancel: () => Navigator.pop(ctx, false),
                    onConfirm: () => Navigator.pop(ctx, true),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (ok == true && mounted) {
      vm.setAck1(a1);
      vm.setAck2(a2);
      await _startAuthFlow(context, vm);
    }
  }

  Future<void> _startAuthFlow(BuildContext context, SeedPhraseVM vm) async {
    final confirmed = await vm.saveSecurely();
    if (!mounted) return;
    if (confirmed) {
      showFloatingSnackBar(
        context,
        message: 'Wallet secured successfully!',
        type: SnackBarType.success,
      );
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthGateScreen()),
      );
      if (mounted) {
        final tabVM = context.read<TabVM>();
        tabVM.setTab(0);
        Phoenix.rebirth(context);
      }
    } else {
      showFloatingSnackBar(
        context,
        message: 'Failed to secure wallet. Please try again.',
        type: SnackBarType.error,
      );
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);

    return Consumer<SeedPhraseVM>(
      builder: (context, vm, child) {
        final s = vm.state;
        final readyVisual = s.ack1 && s.ack2;

        return Scaffold(
          backgroundColor: colors.surface,
          extendBodyBehindAppBar: true,
          appBar: _buildAppBar(colors, vm, s),
          body: Stack(
            children: [
              // Gradient background
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        colors.surface,
                        colors.background.withOpacity(0.5),
                        colors.surface,
                      ],
                    ),
                  ),
                ),
              ),
              // Content
              Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + 60,
                        left: 20,
                        right: 20,
                        bottom: 20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FadeInDown(
                            duration: const Duration(milliseconds: 500),
                            child: WordCountPicker(
                              current: vm.wordCount,
                              loading: s.loading,
                              onPick: (wc) => _confirmRegenerate(
                                context,
                                wordCount: wc,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          FadeInUp(
                            duration: const Duration(milliseconds: 600),
                            delay: const Duration(milliseconds: 150),
                            child: MetaHeader(
                              wordCount: s.words.length,
                              obscured: s.obscured,
                              onCopy: () => _showCopyGuide(context, s),
                            ),
                          ),
                          const SizedBox(height: 16),
                          FadeInUp(
                            duration: const Duration(milliseconds: 700),
                            delay: const Duration(milliseconds: 200),
                            child: PhraseCard(
                              words: s.obscured
                                  ? List.filled(s.words.length, "••••••")
                                  : s.words,
                              obscured: s.obscured,
                              isTwentyFour: vm.wordCount == 24,
                              onTapObscured: vm.toggleObscure,
                            ),
                          ),
                          const SizedBox(height: 20),
                          FadeIn(
                            duration: const Duration(milliseconds: 600),
                            delay: const Duration(milliseconds: 250),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    colors.primary.withOpacity(0.05),
                                    colors.primary.withOpacity(0.02),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: colors.border.withOpacity(0.15),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    LucideIcons.lightbulb,
                                    size: 20,
                                    color: colors.primary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      "Write it down on paper and store offline. "
                                          "Never share it. Screenshots can be risky.",
                                      style: TextStyle(
                                        color: colors.textSecondary,
                                        fontSize: 13.5,
                                        height: 1.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (s.error != null && s.error!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: colors.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: colors.error.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    LucideIcons.alertCircle,
                                    color: colors.error,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      s.error!,
                                      style: TextStyle(
                                        color: colors.error,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // Bottom action bar
                  Container(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      border: Border(
                        top: BorderSide(
                          color: colors.border.withOpacity(0.15),
                          width: 1.5,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 16,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CustomButton(
                              text: s.loading ? "Securing..." : "Secure & Continue",
                              icon: LucideIcons.arrowRight,
                              type: readyVisual
                                  ? ButtonType.filled
                                  : ButtonType.outlined,
                              onPressed: () => _openChecklist(context, vm, s),
                            ),
                            const SizedBox(height: 12),
                            CustomButton(
                              text: s.obscured ? "Tap to Reveal" : "Hide Phrase",
                              icon: s.obscured ? LucideIcons.eye : LucideIcons.eyeOff,
                              type: ButtonType.outlined,
                              onPressed: vm.toggleObscure,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // UI components
  // ──────────────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(
      AppColor colors, SeedPhraseVM vm, SeedPhraseState s) {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colors.surface.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colors.border.withOpacity(0.15),
            width: 1.5,
          ),
        ),
        child: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
          padding: EdgeInsets.zero,
        ),
      ),
      title: Text(
        'Your Recovery Phrase',
        style: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 18,
          letterSpacing: -0.3,
        ),
      ),
      centerTitle: false,
      actions: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: colors.surface.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colors.border.withOpacity(0.15),
              width: 1.5,
            ),
          ),
          child: IconButton(
            tooltip: 'Copy all',
            onPressed: s.obscured ? null : () => _showCopyGuide(context, s),
            icon: Icon(
              LucideIcons.copy,
              color: s.obscured
                  ? colors.textSecondary.withOpacity(0.45)
                  : colors.primary,
              size: 20,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: colors.surface.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colors.border.withOpacity(0.15),
              width: 1.5,
            ),
          ),
          child: IconButton(
            tooltip: s.obscured ? 'Reveal phrase' : 'Hide phrase',
            onPressed: vm.toggleObscure,
            icon: Icon(
              s.obscured ? LucideIcons.eye : LucideIcons.eyeOff,
              color: colors.textPrimary,
              size: 20,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: colors.surface.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colors.border.withOpacity(0.15),
              width: 1.5,
            ),
          ),
          child: IconButton(
            tooltip: 'Generate new phrase',
            onPressed: () => _confirmRegenerate(context),
            icon: Icon(
              LucideIcons.refreshCw,
              color: colors.textPrimary,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _guideRow(
      AppColor colors, IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.background.withOpacity(0.6),
            colors.background.withOpacity(0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colors.border.withOpacity(0.15),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colors.primary.withOpacity(0.12),
                  colors.primary.withOpacity(0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: colors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: colors.textSecondary,
                    height: 1.5,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Shared bottom-sheet helpers
  // ──────────────────────────────────────────────────────────────────────────

  Future<T?> _showActionSheet<T>({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String confirmLabel,
    required Widget body,
  }) {
    final colors = AppColor.of(context);
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.surface,
              colors.surface.withOpacity(0.98),
            ],
          ),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(32),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: colors.border.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 24),
              _sheetHeader(colors, icon, title),
              const SizedBox(height: 20),
              body,
              const SizedBox(height: 24),
              _sheetActions(
                colors: colors,
                confirmLabel: confirmLabel,
                onCancel: () => Navigator.pop(ctx, false as T),
                onConfirm: () => Navigator.pop(ctx, true as T),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetHeader(AppColor colors, IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colors.primary.withOpacity(0.15),
                colors.primary.withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: colors.primary, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _sheetActions({
    required AppColor colors,
    required String confirmLabel,
    required VoidCallback onCancel,
    required VoidCallback onConfirm,
    bool confirmEnabled = true,
  }) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colors.background,
                  colors.background.withOpacity(0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colors.border.withOpacity(0.25),
                width: 1.5,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onCancel,
                borderRadius: BorderRadius.circular(16),
                child: Center(
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              gradient: confirmEnabled
                  ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.primary,
                  colors.primary.withOpacity(0.85),
                ],
              )
                  : null,
              color: confirmEnabled ? null : colors.border.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              boxShadow: confirmEnabled
                  ? [
                BoxShadow(
                  color: colors.primary.withOpacity(0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: confirmEnabled ? onConfirm : null,
                borderRadius: BorderRadius.circular(16),
                child: Center(
                  child: Text(
                    confirmLabel,
                    style: TextStyle(
                      color: confirmEnabled
                          ? Colors.white
                          : colors.textSecondary.withOpacity(0.5),
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}