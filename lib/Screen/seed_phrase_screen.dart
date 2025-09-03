import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:next_fi/Components/CustomButton.dart';
import 'package:next_fi/Components/SnackBar.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Provider/TabProvider.dart';
import 'package:next_fi/Screen/auth_gate_screen.dart';
import 'package:next_fi/Services/seed_storage.dart';
import 'package:next_fi/Services/tron_wallet_service.dart';

class SeedPhraseScreen extends StatefulWidget {
  const SeedPhraseScreen({super.key});

  @override
  State<SeedPhraseScreen> createState() => _SeedPhraseScreenState();
}

class _SeedPhraseScreenState extends State<SeedPhraseScreen>
    with WidgetsBindingObserver {
  String _mnemonic = "";
  List<String> _words = [];
  bool _isLoading = false;

  // UI / UX state
  bool _obscured = true; // hidden until user taps reveal
  bool _ack1 = false; // "I wrote it down"
  bool _ack2 = false; // "I understand NextFi can't recover it"

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Auto re-hide if app backgrounded for safety
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (!_obscured && mounted) {
        setState(() => _obscured = true);
      }
    }
  }

  Future<void> _generateMnemonic() async {
    _mnemonic = TronWalletService.generateMnemonic(); // ✅ Tron service
    _words = _mnemonic.split(' ');
    if (mounted) setState(() {});
  }

  // === Regenerate: modal bottom sheet ===
  Future<void> _confirmRegenerate() async {
    final colors = AppColor.of(context);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      showDragHandle: true,
      builder: (ctx) {
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
                  Icon(LucideIcons.refreshCw, color: colors.textPrimary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Generate a new phrase',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
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
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.textSecondary,
                        side: BorderSide(color: colors.border.withOpacity(.8)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ButtonStyle(
                        backgroundColor: WidgetStatePropertyAll(colors.primary),
                        foregroundColor: const WidgetStatePropertyAll(Colors.white),
                      ),
                      child: const Text('Generate'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    if (ok == true) {
      setState(() {
        _ack1 = _ack2 = false;
        _obscured = true;
      });
      await _generateMnemonic();
      showFloatingSnackBar(
        context,
        message: 'Generated a new recovery phrase.',
        type: SnackBarType.success,
      );
    }
  }

  void _toggleObscure() {
    setState(() {
      _obscured = !_obscured;
    });
    HapticFeedback.selectionClick();
  }

  // Copy all — real copier
  Future<void> _copySeedPhrase() async {
    await Clipboard.setData(ClipboardData(text: _mnemonic));
    HapticFeedback.lightImpact();
    final colors = AppColor.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Copied seed phrase (keep it safe!)',
            style: TextStyle(color: Colors.white)),
        backgroundColor: colors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // === Copy guide: modal bottom sheet ===
  Future<void> _showCopyGuide() async {
    if (_obscured) {
      showFloatingSnackBar(
        context,
        message: "Reveal the phrase first to copy.",
        type: SnackBarType.info,
      );
      return;
    }
    final colors = AppColor.of(context);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      showDragHandle: true,
      builder: (ctx) {
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
                  Icon(LucideIcons.copy, color: colors.textPrimary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Copy recovery phrase?',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _guideRow(
                colors,
                LucideIcons.shieldAlert,
                "Never share your phrase",
                "Anyone with this phrase can control your funds.",
              ),
              const SizedBox(height: 10),
              _guideRow(
                colors,
                LucideIcons.phoneOff,
                "Avoid screenshots",
                "Screenshots may be backed up to cloud services.",
              ),
              const SizedBox(height: 10),
              _guideRow(
                colors,
                LucideIcons.eye,
                "Ensure privacy",
                "Make sure no one is looking at your screen.",
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.textSecondary,
                        side: BorderSide(color: colors.border.withOpacity(.8)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ButtonStyle(
                        backgroundColor: WidgetStatePropertyAll(colors.primary),
                        foregroundColor: const WidgetStatePropertyAll(Colors.white),
                      ),
                      child: const Text('Copy anyway'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    if (ok == true) {
      await _copySeedPhrase();
    }
  }

  Widget _guideRow(
      AppColor colors,
      IconData icon,
      String title,
      String subtitle,
      ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: colors.textPrimary, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: "$title\n",
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text: subtitle,
                  style: TextStyle(
                    color: colors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // === NEW: Open Security Checklist in a MODAL when pressing "Secure & Continue" ===
  Future<void> _openSecurityChecklistModal() async {
    if (_obscured) {
      showFloatingSnackBar(
        context,
        message: "Reveal your recovery phrase first.",
        type: SnackBarType.warning,
      );
      return;
    }
    if (_isLoading) return;

    final colors = AppColor.of(context);
    bool tempAck1 = _ack1;
    bool tempAck2 = _ack2;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final ready = tempAck1 && tempAck2;
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
                      Icon(LucideIcons.shieldCheck, color: colors.textPrimary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "Security checklist",
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  _confirmTile(
                    colors: colors,
                    value: tempAck1,
                    onChanged: (v) => setModalState(() => tempAck1 = v),
                    leadingIcon: LucideIcons.pencil,
                    title: "I wrote my recovery phrase on paper (or stored it offline).",
                    accent: colors.primary,
                  ),
                  const SizedBox(height: 10),
                  _confirmTile(
                    colors: colors,
                    value: tempAck2,
                    onChanged: (v) => setModalState(() => tempAck2 = v),
                    leadingIcon: LucideIcons.shield,
                    title: "I understand NextFi cannot help recover this phrase.",
                    accent: colors.success,
                  ),

                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.textSecondary,
                            side: BorderSide(color: colors.border.withOpacity(.8)),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: ready ? () => Navigator.pop(ctx, true) : null,
                          style: ButtonStyle(
                            backgroundColor: MaterialStateProperty.resolveWith(
                                  (s) => s.contains(MaterialState.disabled)
                                  ? colors.primary.withOpacity(.45)
                                  : colors.primary,
                            ),
                            foregroundColor: const MaterialStatePropertyAll(Colors.white),
                          ),
                          child: const Text('Confirm & Secure'),
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
      setState(() {
        _ack1 = tempAck1;
        _ack2 = tempAck2;
      });
      await _secureAndContinue();
    }
  }

  Future<void> _secureAndContinue() async {
    // Guard: must be revealed and acknowledged via modal
    if (_obscured || !_ack1 || !_ack2) return;

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
                  final tabProvider = context.read<TabProvider>();
                  tabProvider.setTab(1);
                  Phoenix.rebirth(context);
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

    final wordCount = _words.length;
    final isTwentyFour = wordCount == 24;

    // Button visual cue: filled when visible, outlined when hidden; acks are handled in modal
    final readyVisual = !_obscured && !_isLoading;

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
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
        actions: [
          // Copy comes BEFORE the hide/show toggle
          IconButton(
            tooltip: 'Copy all',
            onPressed: _obscured ? null : _showCopyGuide,
            icon: Icon(
              LucideIcons.copy,
              color: _obscured
                  ? colors.textSecondary.withOpacity(.45)
                  : colors.textPrimary,
            ),
          ),
          IconButton(
            tooltip: _obscured ? 'Reveal phrase' : 'Hide phrase',
            onPressed: _toggleObscure,
            icon: Icon(
              _obscured ? LucideIcons.eye : LucideIcons.eyeOff,
              color: colors.textPrimary,
            ),
          ),
          IconButton(
            tooltip: 'Generate new phrase',
            onPressed: _confirmRegenerate,
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
                    FadeInDown(
                      duration: const Duration(milliseconds: 450),
                      child: _warningBox(colors),
                    ),
                    const SizedBox(height: 18),
                    FadeInUp(
                      duration: const Duration(milliseconds: 550),
                      child: _metaHeader(colors, wordCount),
                    ),
                    const SizedBox(height: 10),
                    // Seed card with overlay reveal
                    FadeInUp(
                      duration: const Duration(milliseconds: 650),
                      child: _seedCard(colors, isTwentyFour),
                    ),
                    const SizedBox(height: 16),
                    // NOTE: Security checklist is NO LONGER SHOWN inline — it appears only in the modal
                    FadeIn(
                      duration: const Duration(milliseconds: 500),
                      child: Text(
                        "💡 Tip: Write it down on paper and store offline. Never share it. Screenshots can be risky.",
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
            ),

            // Footer
            Divider(color: colors.border.withOpacity(0.2), height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                children: [
                  CustomButton(
                    text: _isLoading ? "Securing..." : "Secure & Continue",
                    icon: LucideIcons.arrowRight,
                    type: readyVisual ? ButtonType.filled : ButtonType.outlined,
                    onPressed: _openSecurityChecklistModal,
                  ),
                  const SizedBox(height: 10),
                  // Secondary action: reveal/hide quick toggle (mobile ergonomics)
                  CustomButton(
                    text: _obscured ? "Tap to Reveal" : "Hide Phrase",
                    icon: _obscured ? LucideIcons.eye : LucideIcons.eyeOff,
                    type: ButtonType.outlined,
                    onPressed: _toggleObscure,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaHeader(AppColor colors, int wordCount) {
    final bool canCopy = !_obscured;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colors.background,
            border: Border.all(color: colors.border.withOpacity(.25)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.keyRound, size: 16, color: colors.textSecondary),
              const SizedBox(width: 6),
              Text(
                '$wordCount-word phrase',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        // Inline "Copy" button before Hidden/Visible
        OutlinedButton.icon(
          onPressed: canCopy ? _showCopyGuide : null,
          icon: const Icon(LucideIcons.copy, size: 14),
          label: const Text('Copy', style: TextStyle(fontSize: 12.5)),
          style: OutlinedButton.styleFrom(
            foregroundColor: canCopy ? colors.primary : colors.textSecondary,
            side: BorderSide(
              color: canCopy ? colors.primary : colors.border.withOpacity(.7),
              width: 1,
            ),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 8),
        Row(
          children: [
            Icon(
              _obscured ? LucideIcons.lock : LucideIcons.unlock,
              size: 16,
              color: _obscured ? colors.warning : colors.success,
            ),
            const SizedBox(width: 6),
            Text(
              _obscured ? 'Hidden' : 'Visible',
              style: TextStyle(
                color: _obscured ? colors.warning : colors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _seedCard(AppColor colors, bool isTwentyFour) {
    final grid = _seedGrid(colors, isTwentyFour);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Stack(
        children: [
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _obscured ? _blurredPlaceholder(colors) : grid,
            ),
          ),

          // “Do not share” watermark when visible
          if (!_obscured)
            IgnorePointer(
              child: Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 10, bottom: 8),
                  child: Opacity(
                    opacity: 0.14,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.shieldAlert,
                            size: 16, color: colors.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          "Do not share",
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _blurredPlaceholder(AppColor colors) {
    return GestureDetector(
      onTap: _toggleObscure,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 24, 14, 24),
        decoration: BoxDecoration(
          color: colors.background.withOpacity(.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border.withOpacity(.25)),
        ),
        child: Column(
          children: [
            Icon(LucideIcons.eye, size: 26, color: colors.textSecondary),
            const SizedBox(height: 12),
            Text(
              "Tap to reveal your recovery phrase",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Make sure no one is looking at your screen.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSecondary.withOpacity(.8),
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // ===== Reusable slim confirmation tile (used in modal only) =====
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

              // Texts
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

  Widget _warningBox(AppColor colors) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: colors.warning.withOpacity(0.10),
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
                fontSize: 13.2,
                height: 1.45,
              ),
              children: [
                TextSpan(
                  text: "Keep your recovery phrase safe.\n",
                  style: TextStyle(
                    color: colors.warning,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(
                  text:
                  "It’s the only way to access your funds. Do not share it with anyone. "
                      "NextFi never stores your keys—you are in full control.",
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w400,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _seedGrid(AppColor colors, bool isTwentyFour) {
    // 3 columns works well for 12 and 24; increase row spacing for readability
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: isTwentyFour ? 10 : 12,
        crossAxisSpacing: 8,
        childAspectRatio: 2.45,
      ),
      itemCount: _words.length,
      itemBuilder: (context, index) {
        final idx = index + 1;
        final word = _words[index];
        final visibleWord = _obscured ? "••••••" : word;

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
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    letterSpacing: .2,
                  ),
                  child: Text(
                    visibleWord,
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
