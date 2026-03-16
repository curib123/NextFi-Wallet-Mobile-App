// lib/features/seed_phrases/view/seed_phrase_screen.dart
import 'package:flutter/material.dart';
import 'package:next_fi/core/widgets/button/app_buttons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:next_fi/app/config/app_providers.dart';
import 'package:next_fi/features/auth_gate/presentation/screens/auth_gate_screen.dart';
import 'package:next_fi/features/seed_phrases/presentation/widgets/phrase_card.dart';
import 'package:next_fi/features/seed_phrases/presentation/viewmodels/seed_phrase_vm.dart';

import 'package:next_fi/core/widgets/snackbar/snack_bar.dart';
import 'package:next_fi/app/theme/app_color.dart';

import 'package:next_fi/features/seed_phrases/presentation/viewmodels/seed_phrase_state.dart';

class SeedPhraseScreen extends ConsumerStatefulWidget {
  const SeedPhraseScreen({super.key});

  @override
  ConsumerState<SeedPhraseScreen> createState() => _SeedPhraseScreenState();
}

class _SeedPhraseScreenState extends ConsumerState<SeedPhraseScreen>
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
          statusBarColor: colors.surface,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: colors.surface,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      );
      await ref.read(seedPhraseVmProvider).init();
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
      if (mounted) ref.read(seedPhraseVmProvider).forceHide();
    }
  }

  Future<void> _copyAll(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    if (!context.mounted) return;
    final colors = AppColor.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(LucideIcons.checkCircle2, color: colors.onPrimary, size: 18),
            const SizedBox(width: 10),
            Text(
              'Recovery phrase copied',
              style: TextStyle(
                color: colors.onPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
        backgroundColor: colors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final vm = ref.watch(seedPhraseVmProvider);
    final s = vm.state;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context, colors, vm),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildHeader(colors, vm),
                        const SizedBox(height: 24),
                        _buildWordCountSelector(colors, vm, s),
                        const SizedBox(height: 24),
                        _buildPhraseSection(colors, vm, s),
                        const SizedBox(height: 24),
                        _buildSecurityInfo(colors),
                        const SizedBox(height: 32),
                        _buildActionButtons(context, colors, vm, s),
                        const SizedBox(height: 20),
                      ]),
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

  Widget _buildAppBar(BuildContext context, AppColor colors, SeedPhraseVM vm) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(
          bottom: BorderSide(
            color: colors.border.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(LucideIcons.arrowLeft, color: colors.textPrimary),
            iconSize: 24,
          ),
          Expanded(
            child: Text(
              'Recovery Phrase',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _showInfoSheet(context, colors),
            icon: Icon(LucideIcons.info, color: colors.textSecondary),
            iconSize: 22,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppColor colors, SeedPhraseVM vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your secret recovery phrase',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Write down or copy these words in the right order and save them somewhere safe.',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 15,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildWordCountSelector(
    AppColor colors,
    SeedPhraseVM vm,
    SeedPhraseState s,
  ) {
    return Row(
      children: [
        _buildWordCountChip(colors, vm, s, 12),
        const SizedBox(width: 8),
        _buildWordCountChip(colors, vm, s, 18),
        const SizedBox(width: 8),
        _buildWordCountChip(colors, vm, s, 24),
      ],
    );
  }

  Widget _buildWordCountChip(
    AppColor colors,
    SeedPhraseVM vm,
    SeedPhraseState s,
    int count,
  ) {
    final isSelected = vm.wordCount == count;
    final isEnabled = !s.loading;

    return Expanded(
      child: GestureDetector(
        onTap: isEnabled
            ? () async {
                HapticFeedback.selectionClick();
                if (vm.wordCount != count) {
                  await _confirmWordCountChange(context, vm, count);
                }
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? colors.primary : colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? colors.primary
                  : colors.border.withValues(alpha: 0.15),
              width: 1.5,
            ),
          ),
          child: Text(
            '$count words',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? colors.onPrimary : colors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhraseSection(
    AppColor colors,
    SeedPhraseVM vm,
    SeedPhraseState s,
  ) {
    return Column(
      children: [
        // Action bar (only show when revealed)
        if (!s.obscured) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  '${s.words.length} words',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              _buildActionButton(
                colors,
                LucideIcons.copy,
                'Copy',
                () => _showCopyConfirmation(context, colors, s),
              ),
              const SizedBox(width: 8),
              _buildActionButton(colors, LucideIcons.eyeOff, 'Hide', () {
                HapticFeedback.lightImpact();
                vm.toggleObscure();
              }),
            ],
          ),
          const SizedBox(height: 16),
        ],
        // Phrase card with grid
        PhraseCard(
          words: s.words,
          obscured: s.obscured,
          isTwentyFour: vm.isTwentyFour,
          onTapObscured: () {
            HapticFeedback.mediumImpact();
            vm.toggleObscure();
          },
        ),
      ],
    );
  }

  Widget _buildActionButton(
    AppColor colors,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: colors.border.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colors.textPrimary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityInfo(AppColor colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.warning.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.alertTriangle, color: colors.warning, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Never share your recovery phrase with anyone or risk losing your funds',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    AppColor colors,
    SeedPhraseVM vm,
    SeedPhraseState s,
  ) {
    final canProceed = !s.obscured && !s.loading;

    return Column(
      children: [
        // Primary action
        SizedBox(
          width: double.infinity,
          height: 54,
          child: AppElevatedButton(
            onPressed: canProceed
                ? () => _handleSecureAndContinue(context, vm, s)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              disabledBackgroundColor: colors.border.withValues(alpha: 0.2),
              disabledForegroundColor: colors.textSecondary.withValues(
                alpha: 0.5,
              ),
              elevation: 0,
              shadowColor: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: s.loading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colors.onPrimary,
                      ),
                    ),
                  )
                : const Text(
                    " 'I've saved it",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        // Secondary action
        SizedBox(
          width: double.infinity,
          height: 54,
          child: AppTextButton(
            onPressed: s.loading ? null : () => _handleRegenerate(context, vm),
            style: TextButton.styleFrom(
              foregroundColor: colors.textPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.refreshCw, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Generate new phrase',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleSecureAndContinue(
    BuildContext context,
    SeedPhraseVM vm,
    SeedPhraseState s,
  ) async {
    HapticFeedback.mediumImpact();

    final confirmed = await _showConfirmationSheet(context, s);
    if (confirmed != true || !context.mounted) return;

    await _startAuthFlow(context, vm);
  }

  Future<void> _startAuthFlow(BuildContext context, SeedPhraseVM vm) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AuthGateScreen(
          goNext: () async {
            if (!context.mounted) return;
            try {
              final ok = await vm.saveSecurely();
              if (!ok) {
                final err = vm.state.error;
                if (err!.isNotEmpty && context.mounted) {
                  showFloatingSnackBar(
                    context,
                    message: err,
                    type: SnackBarType.error,
                  );
                }
                return;
              }

              if (!context.mounted) return;
              ref.read(tabControllerProvider.notifier).setTab(0);
              ref.read(appShellProvider.notifier).completeWalletSetup();

              if (!context.mounted) return;
              Navigator.of(
                context,
                rootNavigator: true,
              ).popUntil((route) => route.isFirst);
            } catch (e) {
              if (context.mounted) {
                showFloatingSnackBar(
                  context,
                  message: "Failed to save phrase: $e",
                  type: SnackBarType.error,
                );
              }
            }
          },
        ),
      ),
    );
  }

  Future<void> _handleRegenerate(BuildContext context, SeedPhraseVM vm) async {
    final confirmed = await _showRegenerateSheet(context);
    if (confirmed == true && context.mounted) {
      HapticFeedback.mediumImpact();
      await vm.regenerate();
      if (context.mounted) {
        showFloatingSnackBar(
          context,
          message: 'New recovery phrase generated',
          type: SnackBarType.success,
        );
      }
    }
  }

  Future<void> _showCopyConfirmation(
    BuildContext context,
    AppColor colors,
    SeedPhraseState s,
  ) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColor.of(context).surface,
      builder: (context) => _buildBottomSheet(
        context,
        colors,
        icon: LucideIcons.copy,
        title: 'Copy recovery phrase?',
        description:
            'Make sure no one can see your screen. Never share this phrase with anyone.',
        confirmText: 'Copy phrase',
        confirmColor: colors.primary,
      ),
    );

    if (confirmed == true && context.mounted) {
      await _copyAll(context, s.mnemonic);
    }
  }

  Future<bool?> _showConfirmationSheet(
    BuildContext context,
    SeedPhraseState s,
  ) {
    final colors = AppColor.of(context);
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: colors.surface,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    LucideIcons.shieldCheck,
                    color: colors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Confirm backup',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildCheckItem(
              colors,
              'I wrote down my recovery phrase',
              'I understand that anyone who has this phrase can access my wallet',
            ),
            const SizedBox(height: 12),
            _buildCheckItem(
              colors,
              'I stored it in a safe place',
              'I know NextFI cannot recover this phrase for me',
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: AppOutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: colors.border.withValues(alpha: 0.2),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: AppElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckItem(AppColor colors, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.border.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.checkCircle2, color: colors.success, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showRegenerateSheet(BuildContext context) {
    final colors = AppColor.of(context);
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: colors.surface,
      builder: (context) => _buildBottomSheet(
        context,
        colors,
        icon: LucideIcons.refreshCw,
        title: 'Generate new phrase?',
        description:
            'This will create a completely new recovery phrase. Your current phrase will be replaced.',
        confirmText: 'Generate new',
        confirmColor: colors.warning,
      ),
    );
  }

  void _showInfoSheet(BuildContext context, AppColor colors) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    LucideIcons.shieldAlert,
                    color: colors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'About recovery phrases',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInfoItem(
              colors,
              'What is it?',
              'A recovery phrase is a list of words that stores all the information needed to recover your wallet.',
            ),
            const SizedBox(height: 16),
            _buildInfoItem(
              colors,
              'Why is it important?',
              'If you lose access to your device, this phrase is the only way to recover your wallet and funds.',
            ),
            const SizedBox(height: 16),
            _buildInfoItem(
              colors,
              'Keep it safe',
              'Write it down on paper and store it somewhere secure. Never share it with anyone or store it digitally.',
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: AppElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Got it',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(AppColor colors, String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomSheet(
    BuildContext context,
    AppColor colors, {
    required IconData icon,
    required String title,
    required String description,
    required String confirmText,
    required Color confirmColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.border.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: confirmColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: confirmColor, size: 28),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: AppOutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: colors.border.withValues(alpha: 0.2),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: AppElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmColor,
                      foregroundColor: colors.onPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      confirmText,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmWordCountChange(
    BuildContext context,
    SeedPhraseVM vm,
    int newCount,
  ) async {
    final colors = AppColor.of(context);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: colors.surface,
      builder: (context) => _buildBottomSheet(
        context,
        colors,
        icon: LucideIcons.refreshCw,
        title: 'Change word count?',
        description: 'This will generate a new $newCount-word recovery phrase.',
        confirmText: 'Change to $newCount words',
        confirmColor: colors.primary,
      ),
    );

    if (confirmed == true && context.mounted) {
      HapticFeedback.mediumImpact();
      await vm.setWordCount(newCount, regenerateNow: true);
    }
  }
}
