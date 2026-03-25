import 'package:flutter/material.dart';
import 'package:next_fi/core/widgets/button/app_buttons.dart';
import 'package:flutter/services.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/app/config/app_providers.dart';
import 'package:next_fi/features/auth_gate/presentation/screens/auth_gate_screen.dart';
import 'package:next_fi/features/seed_phrases/presentation/screens/seed_phrase_screen.dart';
import 'package:next_fi/features/wallet_settings/presentation/viewmodels/wallet_settings_vm.dart';
import 'package:next_fi/core/widgets/loader/page_loader.dart';
import 'package:next_fi/core/widgets/modal/base/app_modal_base.dart';
import 'package:next_fi/core/widgets/snackbar/snack_bar.dart';
import 'package:next_fi/core/widgets/modal/wallet_switch_result.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/features/import_wallet/presentation/screens/import_wallet_screen.dart';

import 'package:next_fi/features/wallet_settings/presentation/widgets/header_card.dart';
import 'package:next_fi/features/wallet_settings/presentation/widgets/meta_header_settings.dart';
import 'package:next_fi/features/wallet_settings/presentation/widgets/phrase_card_hold_reveal.dart';

class WalletScreenSettings extends ConsumerStatefulWidget {
  const WalletScreenSettings({super.key});

  @override
  ConsumerState<WalletScreenSettings> createState() =>
      _WalletScreenSettingsState();
}

class _WalletScreenSettingsState extends ConsumerState<WalletScreenSettings>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const double _pad = 20;
  late AnimationController _fabController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final colors = AppColor.of(context);
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarColor: AppColor.of(context).surface,
          statusBarIconBrightness:
              Theme.of(context).brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
          systemNavigationBarColor: colors.background,
        ),
      );
      await ref.read(walletSettingsVmProvider).init();
      _fabController.forward();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (mounted) ref.read(walletSettingsVmProvider).forceHide();
    }
  }

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
    if (!context.mounted) return false;

    if (granted) vm.setAuthorized(true);
    return granted;
  }

  Future<void> _toggleObscure(BuildContext context, WalletSettingsVM vm) async {
    if (vm.state.obscured) {
      final ok = await _requireAuth(context, vm);
      if (!ok) return;
    }
    vm.toggleObscure();
    HapticFeedback.mediumImpact();
  }

  Future<void> _copySeedPhrase(
    BuildContext context,
    WalletSettingsVM vm,
  ) async {
    if (!vm.state.hasSeed) return;

    final ok = await _requireAuth(context, vm);
    if (!ok) return;
    if (!context.mounted) return;

    if (vm.state.obscured) {
      showFloatingSnackBar(
        context,
        message: "Reveal the phrase first to copy.",
        type: SnackBarType.info,
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: vm.state.mnemonic));
    HapticFeedback.lightImpact();

    if (!context.mounted) return;
    showFloatingSnackBar(
      context,
      message: "Recovery phrase copied securely",
      type: SnackBarType.success,
    );
  }

  Future<void> _goToImport(BuildContext context, WalletSettingsVM vm) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ImportWalletScreen()));
    if (!context.mounted) return;
    await ref.read(seedKeypairProvider).refresh();
    await ref.read(walletHomeVmProvider).boot();
    await vm.refresh();
  }

  Future<void> _openRenameSheet(
    BuildContext context,
    WalletSettingsVM vm,
  ) async {
    final colors = AppColor.of(context);
    final ctrl = TextEditingController(text: vm.state.walletName);

    final newName = await showAppModalBottomSheet<String>(
      context,
      builder: (ctx) => _RenameBottomSheet(controller: ctrl, colors: colors),
    );

    if (newName == null) return;

    final ok = await vm.renameActive(newName);
    if (!context.mounted) return;

    if (ok) {
      showFloatingSnackBar(
        context,
        message: "Wallet name updated successfully",
        type: SnackBarType.success,
      );
    } else {
      showFloatingSnackBar(
        context,
        message: "Failed to save wallet name",
        type: SnackBarType.error,
      );
    }
  }

  Future<void> _handleSwitch(BuildContext context, WalletSettingsVM vm) async {
    final res = await showWalletSwitchSheet(
      context,
      currentActiveId: vm.state.activeWalletId,
      allowGenerate: true,
    );

    if (res == null) return;
    if (!context.mounted) return;

    if (res.importRequested) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ImportWalletScreen()),
      );
      if (!context.mounted) return;
      await ref.read(seedKeypairProvider).refresh();
      await ref.read(walletHomeVmProvider).boot();
      await vm.refresh();
      return;
    }

    if (res.createNew) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SeedPhraseScreen()),
      );
      if (!context.mounted) return;
      await ref.read(seedKeypairProvider).refresh();
      await ref.read(walletHomeVmProvider).boot();
      await vm.refresh();
      return;
    }

    if (res.switchedInSheet) {
      await ref.read(seedKeypairProvider).refresh();
      await ref.read(walletHomeVmProvider).boot();
      await vm.refresh();
      if (!context.mounted) return;
      showFloatingSnackBar(
        context,
        message: "Switched active wallet",
        type: SnackBarType.success,
      );
      return;
    }

    final chosenId = res.chosenWalletId;
    if (chosenId != null && chosenId != vm.state.activeWalletId) {
      final ok = await ref.read(walletHomeVmProvider).switchTo(chosenId);
      if (!context.mounted) return;

      if (ok) {
        await vm.refresh();
        if (!context.mounted) return;
        showFloatingSnackBar(
          context,
          message: "Switched active wallet",
          type: SnackBarType.success,
        );
      } else {
        showFloatingSnackBar(
          context,
          message: "Failed to switch wallet",
          type: SnackBarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final vm = ref.watch(walletSettingsVmProvider);
    final s = vm.state;

    return Scaffold(
      backgroundColor: colors.background,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(colors, s),
      body: s.loading
          ? _buildLoading()
          : Column(
              children: [
                Expanded(
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: MediaQuery.of(context).padding.top + 60,
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(_pad, 12, _pad, 12),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            FadeInDown(
                              duration: const Duration(milliseconds: 300),
                              child: HeaderCard(
                                walletName: s.walletName,
                                obscured: s.obscured,
                                onImport: () => _goToImport(context, vm),
                                onSwitch: () => _handleSwitch(context, vm),
                                onRename: () => _openRenameSheet(context, vm),
                              ),
                            ),
                            const SizedBox(height: 24),
                            FadeInUp(
                              duration: const Duration(milliseconds: 400),
                              child: MetaHeaderSettings(wordCount: s.wordCount),
                            ),
                            const SizedBox(height: 12),
                            FadeInUp(
                              duration: const Duration(milliseconds: 450),
                              child: PhraseCardHoldReveal(
                                words: s.words,
                                obscured: s.obscured,
                                onRevealHold: () => _toggleObscure(context, vm),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildTipSection(colors),
                            if (s.error != null && s.error!.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _buildErrorMessage(s.error!, colors),
                            ],
                            const SizedBox(height: 16),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: _buildFloatingActions(context, vm, s, colors),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  PreferredSizeWidget _buildAppBar(AppColor colors, state) {
    return AppBar(
      elevation: 0,
      backgroundColor: AppColor.of(context).surface,
      surfaceTintColor: AppColor.of(context).surface,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Wallet Settings',
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              state.walletName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textSecondary.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
      centerTitle: false,
    );
  }

  Widget _buildLoading() {
    return const PageLoader(label: 'Loading wallet settings...');
  }

  Widget _buildTipSection(AppColor colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary.withValues(alpha: 0.06),
            colors.primary.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.12),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.lightbulb, size: 20, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Write it on paper and store offline. Never share or screenshot it.",
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                height: 1.5,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(String error, AppColor colors) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.error.withValues(alpha: 0.3),
          width: 1.5,
        ),
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

  Widget _buildFloatingActions(
    BuildContext context,
    WalletSettingsVM vm,
    state,
    AppColor colors,
  ) {
    return ScaleTransition(
      scale: CurvedAnimation(parent: _fabController, curve: Curves.easeOut),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: _pad),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.surface, colors.surface.withValues(alpha: 0.95)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colors.border.withValues(alpha: 0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColor.of(context).textPrimary.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
              spreadRadius: -4,
            ),
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: _ModernActionButton(
                icon: state.obscured ? LucideIcons.eye : LucideIcons.eyeOff,
                label: state.obscured ? "Reveal" : "Hide",
                onPressed: () => _toggleObscure(context, vm),
                colors: colors,
                isPrimary: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ModernActionButton(
                icon: LucideIcons.copy,
                label: "Copy",
                onPressed: () => _copySeedPhrase(context, vm),
                colors: colors,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModernActionButton extends StatefulWidget {
  const _ModernActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.colors,
    this.isPrimary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final AppColor colors;
  final bool isPrimary;

  @override
  State<_ModernActionButton> createState() => _ModernActionButtonState();
}

class _ModernActionButtonState extends State<_ModernActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          gradient: widget.isPrimary
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
              : null,
          color: !widget.isPrimary
              ? (_isPressed
                    ? widget.colors.background.withValues(alpha: 0.8)
                    : widget.colors.background.withValues(alpha: 0.5))
              : null,
          borderRadius: BorderRadius.circular(14),
          border: !widget.isPrimary
              ? Border.all(
                  color: widget.colors.border.withValues(alpha: 0.25),
                  width: 1.5,
                )
              : null,
          boxShadow: _isPressed
              ? []
              : [
                  if (widget.isPrimary)
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
            Icon(
              widget.icon,
              size: 18,
              color: widget.isPrimary
                  ? AppColor.of(context).onPrimary
                  : widget.colors.textPrimary,
            ),
            const SizedBox(width: 10),
            Text(
              widget.label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: widget.isPrimary
                    ? AppColor.of(context).onPrimary
                    : widget.colors.textPrimary,
                fontSize: 14,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RenameBottomSheet extends StatelessWidget {
  const _RenameBottomSheet({required this.controller, required this.colors});

  final TextEditingController controller;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    return AppModalBase(
      backgroundColor: colors.surface,
      maxHeightFactor: 0.45,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Rename Wallet',
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 20,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            maxLength: 32,
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            decoration: InputDecoration(
              counterText: "",
              hintText: "Enter wallet name",
              hintStyle: TextStyle(
                color: colors.textSecondary.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: colors.background.withValues(alpha: 0.6),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: colors.border.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: colors.border.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: colors.primary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SheetButton(
                  icon: LucideIcons.x,
                  label: 'Cancel',
                  onPressed: () => Navigator.pop(context),
                  colors: colors,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SheetButton(
                  icon: LucideIcons.check,
                  label: 'Save',
                  onPressed: () {
                    final raw = controller.text.trim();
                    if (raw.isEmpty || raw.length > 32) {
                      return;
                    }
                    Navigator.pop(context, raw);
                  },
                  colors: colors,
                  isPrimary: true,
                ),
              ),
            ],
          ),
        ],
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
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final AppColor colors;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return AppElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary
            ? colors.primary
            : colors.background.withValues(alpha: 0.6),
        foregroundColor: isPrimary
            ? AppColor.of(context).onPrimary
            : colors.textPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: isPrimary
              ? BorderSide.none
              : BorderSide(
                  color: colors.border.withValues(alpha: 0.25),
                  width: 1.5,
                ),
        ),
      ),
      onPressed: onPressed,
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
