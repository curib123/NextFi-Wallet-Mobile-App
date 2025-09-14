// lib/features/wallet_settings/view/wallet_screen_settings.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/features/auth_gate/view/auth_gate_screen.dart';
import 'package:next_fi/features/seed_phrases/view/seed_phrase_screen.dart';
import 'package:next_fi/features/wallet_creation/view/wallet_creation_screen.dart';
import 'package:next_fi/features/wallet_settings/view_model/wallet_settings_vm.dart';
import 'package:provider/provider.dart';
import 'package:next_fi/common/components/CustomButton.dart';
import 'package:next_fi/common/components/SnackBar.dart';
import 'package:next_fi/common/components/wallet_switch_result.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/features/import_wallet/view/import_wallet_screen.dart';
import 'widgets/header_card.dart';
import 'widgets/warning_box_settings.dart';
import 'widgets/meta_header_settings.dart';
import 'widgets/phrase_card_hold_reveal.dart';

class WalletScreenSettings extends StatefulWidget {
  const WalletScreenSettings({super.key});
  @override
  State<WalletScreenSettings> createState() => _WalletScreenSettingsState();
}

class _WalletScreenSettingsState extends State<WalletScreenSettings> with WidgetsBindingObserver {
  static const double _pad = 16;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final colors = AppColor.of(context);
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(statusBarColor: colors.surface, statusBarIconBrightness: Brightness.dark),
      );
      await context.read<WalletSettingsVM>().init();
    });
  }

  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (mounted) context.read<WalletSettingsVM>().forceHide();
    }
  }

  // ── Auth gate helper ────────────────────────────────────────────────────────
  Future<bool> _requireAuth(BuildContext context, WalletSettingsVM vm) async {
    final s = vm.state;
    if (s.authorized) return true;
    bool granted = false;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AuthGateScreen(
          goNext: () {
            granted = true;
            Navigator.pop(context);
          },
        ),
      ),
    );
    if (granted) vm.setAuthorized(true);
    return granted;
  }

  // ── Actions ─────────────────────────────────────────────────────────────────
  Future<void> _toggleObscure(BuildContext context, WalletSettingsVM vm) async {
    if (vm.state.obscured) {
      final ok = await _requireAuth(context, vm);
      if (!ok) return;
    }
    vm.toggleObscure();
    HapticFeedback.selectionClick();
  }

  Future<void> _copySeedPhrase(BuildContext context, WalletSettingsVM vm) async {
    if (!vm.state.hasSeed) return;
    final ok = await _requireAuth(context, vm);
    if (!ok) return;

    if (vm.state.obscured) {
      showFloatingSnackBar(context, message: "Reveal the phrase first to copy.", type: SnackBarType.info);
      return;
    }
    await Clipboard.setData(ClipboardData(text: vm.state.mnemonic));
    HapticFeedback.lightImpact();
    final colors = AppColor.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Copied recovery phrase (keep it safe!)', style: TextStyle(color: Colors.white)),
        backgroundColor: colors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _goToImport(BuildContext context, WalletSettingsVM vm) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ImportWalletScreen()));
    await vm.refresh(); // in case of return without restart
  }

  Future<void> _openRenameSheet(BuildContext context, WalletSettingsVM vm) async {
    final colors = AppColor.of(context);
    final ctrl = TextEditingController(text: vm.state.walletName);
    final newName = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: _pad, right: _pad, top: 12, bottom: MediaQuery.of(ctx).viewInsets.bottom + _pad),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _SheetHandle(colors: colors),
          Text('Rename Wallet', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          TextField(
            controller: ctrl, autofocus: true, maxLength: 32,
            decoration: InputDecoration(
              counterText: "",
              hintText: "Enter wallet name",
              isDense: true, filled: true, fillColor: colors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: colors.border.withOpacity(.55)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: colors.primary, width: 1.2),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              icon: const Icon(LucideIcons.x, size: 16), label: const Text('Cancel'),
              onPressed: () => Navigator.pop(ctx),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton.icon(
              icon: const Icon(LucideIcons.check, size: 16), label: const Text('Save'),
              onPressed: () {
                final raw = ctrl.text.trim();
                if (raw.isEmpty || raw.length > 32) {
                  showFloatingSnackBar(context,
                    message: raw.isEmpty ? "Wallet name cannot be empty." : "Keep the name under 32 characters.",
                    type: SnackBarType.warning,
                  );
                  return;
                }
                Navigator.pop(ctx, raw);
              },
            )),
          ]),
        ]),
      ),
    );

    if (newName == null) return;
    final ok = await vm.renameActive(newName);
    if (ok) {
      showFloatingSnackBar(context, message: "Wallet name updated.", type: SnackBarType.success);
    } else {
      showFloatingSnackBar(context, message: "Failed to save wallet name.", type: SnackBarType.error);
    }
  }

  Future<void> _handleSwitch(BuildContext context, WalletSettingsVM vm) async {
    final res = await showWalletSwitchSheet(
      context,
      currentActiveId: vm.state.activeWalletId,
      allowGenerate: true,
    );
    if (res == null) return;

    // NEW: Import flow
    if (res.importRequested) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ImportWalletScreen()),
      );
      await vm.refresh();
      if (!mounted) return;
      Phoenix.rebirth(context);
      return;
    }

    // Existing: Create New flow
    if (res.createNew) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SeedPhraseScreen()),
      );
      await vm.refresh();
      if (!mounted) return;
      Phoenix.rebirth(context);
      return;
    }

    // Existing: Switch to an existing wallet
    final chosenId = res.chosenWalletId;
    if (chosenId != null && chosenId != vm.state.activeWalletId) {
      final ok = await vm.switchActive(chosenId);
      if (!mounted) return;
      if (ok) {
        showFloatingSnackBar(
          context,
          message: "Switched active wallet.",
          type: SnackBarType.success,
        );
        Phoenix.rebirth(context);
      } else {
        showFloatingSnackBar(
          context,
          message: "Failed to switch wallet.",
          type: SnackBarType.error,
        );
      }
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return Consumer<WalletSettingsVM>(
      builder: (_, vm, __) {
        final s = vm.state;

        return Scaffold(
          backgroundColor: colors.surface,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: colors.surface,
            leading: IconButton(
              icon: Icon(LucideIcons.arrowLeft, color: colors.textPrimary),
              onPressed: () => Navigator.pop(context),
              tooltip: 'Back',
              splashRadius: 22,
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Wallet Settings',
                    style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: .2)),
                const SizedBox(height: 2),
                Text(s.walletName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ],
            ),
            centerTitle: false,
          ),
          body: SafeArea(
            child: s.loading
                ? Center(child: CircularProgressIndicator(color: colors.primary))
                : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(_pad, 12, _pad, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FadeInDown(duration: const Duration(milliseconds: 200),
                          child: HeaderCard(
                            walletName: s.walletName,
                            obscured: s.obscured,
                            onImport: () => _goToImport(context, vm),
                            onSwitch: () => _handleSwitch(context, vm),
                            onRename: () => _openRenameSheet(context, vm),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FadeInDown(duration: const Duration(milliseconds: 230), child: const WarningBoxSettings()),
                        const SizedBox(height: 14),
                        FadeInUp(duration: const Duration(milliseconds: 260),
                          child: MetaHeaderSettings(wordCount: s.wordCount),
                        ),
                        const SizedBox(height: 8),
                        FadeInUp(duration: const Duration(milliseconds: 280),
                          child: PhraseCardHoldReveal(
                            words: s.words,
                            obscured: s.obscured,
                            onRevealHold: () => _toggleObscure(context, vm),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "💡 Tip: Write it on paper and store offline. Never share or screenshot it.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.textSecondary, fontSize: 12.5, height: 1.45),
                        ),
                        if (s.error != null && s.error!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(s.error!, style: const TextStyle(color: Colors.red)),
                        ],
                      ],
                    ),
                  ),
                ),
                Divider(color: colors.border.withOpacity(0.18), height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(_pad, 12, _pad, 18),
                  child: Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          text: s.obscured ? "Reveal Phrase" : "Hide Phrase",
                          icon: s.obscured ? LucideIcons.eye : LucideIcons.eyeOff,
                          type: ButtonType.outlined,
                          onPressed: () => _toggleObscure(context, vm),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CustomButton(
                          text: "Copy",
                          icon: LucideIcons.copy,
                          type: ButtonType.outlined,
                          onPressed: () => _copySeedPhrase(context, vm),
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
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle({required this.colors});
  final AppColor colors;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36, height: 4, margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2)),
    );
  }
}
