// lib/features/seed_phrase/view/seed_phrase_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/reusable_view_model/tab_vm.dart';
import 'package:next_fi/features/auth_gate/view/auth_gate_screen.dart';
import 'package:next_fi/features/seed_phrases/view/widgets/confirm_tile.dart';
import 'package:next_fi/features/seed_phrases/view/widgets/meta_header.dart';
import 'package:next_fi/features/seed_phrases/view/widgets/phrase_card.dart';
import 'package:next_fi/features/seed_phrases/view/widgets/warning_box.dart' show WarningBox;
import 'package:next_fi/features/seed_phrases/view_model/seed_phrase_vm.dart';
import 'package:provider/provider.dart';
import 'package:next_fi/common/components/button/CustomButton.dart';
import 'package:next_fi/common/components/snackbar/SnackBar.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

import '../model/seed_phrase_state.dart';

class SeedPhraseScreen extends StatefulWidget {
  const SeedPhraseScreen({super.key});
  @override
  State<SeedPhraseScreen> createState() => _SeedPhraseScreenState();
}

class _SeedPhraseScreenState extends State<SeedPhraseScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final colors = AppColor.of(context);
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(statusBarColor: colors.surface, statusBarIconBrightness: Brightness.dark),
      );
      await context.read<SeedPhraseVM>().init();
    });
  }

  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (mounted) context.read<SeedPhraseVM>().forceHide();
    }
  }

  // —— helpers ——
  Future<void> _copyAll(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    final colors = AppColor.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: const Text('Copied seed phrase (keep it safe!)', style: TextStyle(color: Colors.white)),
          backgroundColor: colors.primary, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _showCopyGuide(BuildContext context, SeedPhraseState s) async {
    if (s.obscured) {
      showFloatingSnackBar(context, message: "Reveal the phrase first to copy.", type: SnackBarType.info);
      return;
    }
    final colors = AppColor.of(context);
    final ok = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, backgroundColor: colors.surface, showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 8, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Icon(LucideIcons.copy, color: colors.textPrimary, size: 20),
            const SizedBox(width: 8),
            Text('Copy recovery phrase?', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 12),
          _guideRow(colors, LucideIcons.shieldAlert, "Never share your phrase",
              "Anyone with this phrase can control your funds."),
          const SizedBox(height: 10),
          _guideRow(colors, LucideIcons.phoneOff, "Avoid screenshots",
              "Screenshots may be backed up to cloud services."),
          const SizedBox(height: 10),
          _guideRow(colors, LucideIcons.eye, "Ensure privacy",
              "Make sure no one is looking at your screen."),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.textSecondary,
                side: BorderSide(color: colors.border.withOpacity(.8)),
              ),
              child: const Text('Cancel'),
            )),
            const SizedBox(width: 10),
            Expanded(child: FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ButtonStyle(
                backgroundColor: MaterialStatePropertyAll(colors.primary),
                foregroundColor: const MaterialStatePropertyAll(Colors.white),
              ),
              child: const Text('Copy anyway'),
            )),
          ]),
        ]),
      ),
    );
    if (ok == true) await _copyAll(context, s.mnemonic);
  }

  Future<void> _confirmRegenerate(BuildContext context) async {
    final colors = AppColor.of(context);
    final ok = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, backgroundColor: colors.surface, showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 8, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Icon(LucideIcons.refreshCw, color: colors.textPrimary, size: 20),
            const SizedBox(width: 8),
            Text('Generate a new phrase', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'This will replace the current recovery phrase with a new one. '
                  'Make sure you have securely stored the current phrase if you still need it.',
              style: TextStyle(color: colors.textSecondary, height: 1.45),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.textSecondary,
                side: BorderSide(color: colors.border.withOpacity(.8)),
              ),
              child: const Text('Cancel'),
            )),
            const SizedBox(width: 10),
            Expanded(child: FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ButtonStyle(
                backgroundColor: MaterialStatePropertyAll(colors.primary),
                foregroundColor: const MaterialStatePropertyAll(Colors.white),
              ),
              child: const Text('Generate'),
            )),
          ]),
        ]),
      ),
    );
    if (ok == true) {
      await context.read<SeedPhraseVM>().regenerate();
      showFloatingSnackBar(context, message: 'Generated a new recovery phrase.', type: SnackBarType.success);
    }
  }

  Future<void> _openChecklist(BuildContext context, SeedPhraseVM vm, SeedPhraseState s) async {
    if (s.obscured) {
      showFloatingSnackBar(context, message: "Reveal your recovery phrase first.", type: SnackBarType.warning);
      return;
    }
    if (s.loading) return;

    final colors = AppColor.of(context);
    bool a1 = s.ack1, a2 = s.ack2;
    final ok = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, backgroundColor: colors.surface, showDragHandle: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        final ready = a1 && a2;
        return Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 8, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Icon(LucideIcons.shieldCheck, color: colors.textPrimary, size: 20),
              const SizedBox(width: 8),
              Text("Security checklist", style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 10),
            ConfirmTile(
              title: "I wrote my recovery phrase on paper (or stored it offline).",
              icon: LucideIcons.pencil,
              value: a1,
              onChanged: (v) => setS(() => a1 = v),
              accent: colors.primary,
            ),
            const SizedBox(height: 10),
            ConfirmTile(
              title: "I understand NextFi cannot help recover this phrase.",
              icon: LucideIcons.shield,
              value: a2,
              onChanged: (v) => setS(() => a2 = v),
              accent: colors.success,
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.textSecondary,
                  side: BorderSide(color: colors.border.withOpacity(.8)),
                ),
                child: const Text('Cancel'),
              )),
              const SizedBox(width: 10),
              Expanded(child: FilledButton(
                onPressed: ready ? () => Navigator.pop(ctx, true) : null,
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.resolveWith(
                        (st) => st.contains(MaterialState.disabled) ? colors.primary.withOpacity(.45) : colors.primary,
                  ),
                  foregroundColor: const MaterialStatePropertyAll(Colors.white),
                ),
                child: const Text('Confirm & Secure'),
              )),
            ]),
          ]),
        );
      }),
    );
    if (ok == true) {
      vm.setAck1(a1); vm.setAck2(a2);
      await _startAuthFlow(context, vm);
    }
  }

  Future<void> _startAuthFlow(BuildContext context, SeedPhraseVM vm) async {
    final s = vm.state;
    if (!vm.readyToSecure) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AuthGateScreen(
          goNext: () async {
            if (!mounted) return;
            bool restarted = false;
            try {
              final ok = await vm.saveSecurely();
              if (!ok) {
                final err = vm.state.error;
                if (err != null && err.isNotEmpty) {
                  showFloatingSnackBar(context, message: err, type: SnackBarType.error);
                }
                return;
              }
              context.read<TabVM>().setTab(1);
              if (Navigator.of(context).canPop()) Navigator.of(context).pop();
              Phoenix.rebirth(context);
              restarted = true;
            } catch (e) {
              showFloatingSnackBar(context, message: "Unexpected error: $e", type: SnackBarType.error);
            } finally {
              if (!restarted && mounted) {
                // VM already handles loading flags
              }
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return Consumer<SeedPhraseVM>(
      builder: (_, vm, __) {
        final s = vm.state;
        final wordCount = s.words.length;
        final readyVisual = !s.obscured && !s.loading;

        return Scaffold(
          backgroundColor: colors.surface,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: colors.surface,
            leading: IconButton(
              icon: Icon(LucideIcons.arrowLeft, color: colors.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text('Your Recovery Phrase',
                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700)),
            centerTitle: false,
            actions: [
              IconButton(
                tooltip: 'Copy all',
                onPressed: s.obscured ? null : () => _showCopyGuide(context, s),
                icon: Icon(LucideIcons.copy,
                    color: s.obscured ? colors.textSecondary.withOpacity(.45) : colors.textPrimary),
              ),
              IconButton(
                tooltip: s.obscured ? 'Reveal phrase' : 'Hide phrase',
                onPressed: vm.toggleObscure,
                icon: Icon(s.obscured ? LucideIcons.eye : LucideIcons.eyeOff, color: colors.textPrimary),
              ),
              IconButton(
                tooltip: 'Generate new phrase',
                onPressed: () => _confirmRegenerate(context),
                icon: Icon(LucideIcons.refreshCw, color: colors.textPrimary),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FadeInDown(duration: const Duration(milliseconds: 450), child: const WarningBox()),
                        const SizedBox(height: 18),
                        FadeInUp(
                          duration: const Duration(milliseconds: 550),
                          child: MetaHeader(
                            wordCount: wordCount,
                            obscured: s.obscured,
                            onCopy: s.obscured ? null : () => _showCopyGuide(context, s),
                          ),
                        ),
                        const SizedBox(height: 10),
                        FadeInUp(
                          duration: const Duration(milliseconds: 650),
                          child: PhraseCard(
                            words: s.obscured ? List.filled(s.words.length, "••••••") : s.words,
                            obscured: s.obscured,
                            isTwentyFour: s.isTwentyFour,
                            onTapObscured: vm.toggleObscure,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FadeIn(
                          duration: const Duration(milliseconds: 500),
                          child: Text(
                            "💡 Tip: Write it down on paper and store offline. Never share it. Screenshots can be risky.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.5),
                          ),
                        ),
                        if (s.error != null && s.error!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(s.error!, style: const TextStyle(color: Colors.red)),
                        ],
                      ],
                    ),
                  ),
                ),
                Divider(color: colors.border.withOpacity(0.2), height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    children: [
                      CustomButton(
                        text: s.loading ? "Securing..." : "Secure & Continue",
                        icon: LucideIcons.arrowRight,
                        type: readyVisual ? ButtonType.filled : ButtonType.outlined,
                        onPressed: () => _openChecklist(context, vm, s),
                      ),
                      const SizedBox(height: 10),
                      CustomButton(
                        text: s.obscured ? "Tap to Reveal" : "Hide Phrase",
                        icon: s.obscured ? LucideIcons.eye : LucideIcons.eyeOff,
                        type: ButtonType.outlined,
                        onPressed: vm.toggleObscure,
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

  Widget _guideRow(AppColor colors, IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: colors.textPrimary, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(TextSpan(children: [
            TextSpan(text: "$title\n", style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700)),
            TextSpan(text: subtitle, style: TextStyle(color: colors.textSecondary, height: 1.45)),
          ])),
        ),
      ],
    );
  }
}
