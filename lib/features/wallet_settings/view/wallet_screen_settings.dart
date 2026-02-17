// lib/features/wallet_settings/view/wallet_screen_settings_refined.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/features/auth_gate/view/auth_gate_screen.dart';
import 'package:next_fi/features/seed_phrases/view/seed_phrase_screen.dart';
import 'package:next_fi/features/wallet_settings/view_model/wallet_settings_vm.dart';
import 'package:provider/provider.dart';
import 'package:next_fi/common/components/loader/page_loader.dart';
import 'package:next_fi/common/components/snackbar/SnackBar.dart';
import 'package:next_fi/common/components/modal/wallet_switch_result.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/features/import_wallet/view/import_wallet_screen.dart';

// Import widgets
import 'widgets/header_card.dart';
import 'widgets/meta_header_settings.dart';
import 'widgets/phrase_card_hold_reveal.dart';

class WalletScreenSettings extends StatefulWidget {
  const WalletScreenSettings({super.key});

  @override
  State<WalletScreenSettings> createState() => _WalletScreenSettingsState();
}

class _WalletScreenSettingsState extends State<WalletScreenSettings>
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
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: colors == AppColor.dark
              ? Brightness.light
              : Brightness.dark,
          systemNavigationBarColor: colors.background,
        ),
      );
      await context.read<WalletSettingsVM>().init();
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
    HapticFeedback.mediumImpact();
  }

  Future<void> _copySeedPhrase(BuildContext context, WalletSettingsVM vm) async {
    if (!vm.state.hasSeed) return;

    final ok = await _requireAuth(context, vm);
    if (!ok) return;

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

    if (!mounted) return;
    showFloatingSnackBar(
      context,
      message: "Recovery phrase copied securely",
      type: SnackBarType.success,
    );
  }

  Future<void> _goToImport(BuildContext context, WalletSettingsVM vm) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ImportWalletScreen()),
    );
    await vm.refresh();
  }

  Future<void> _openRenameSheet(BuildContext context, WalletSettingsVM vm) async {
    final colors = AppColor.of(context);
    final ctrl = TextEditingController(text: vm.state.walletName);

    final newName = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RenameBottomSheet(
        controller: ctrl,
        colors: colors,
      ),
    );

    if (newName == null) return;

    final ok = await vm.renameActive(newName);
    if (!mounted) return;

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

    final chosenId = res.chosenWalletId;
    if (chosenId != null && chosenId != vm.state.activeWalletId) {
      final ok = await vm.switchActive(chosenId);
      if (!mounted) return;

      if (ok) {
        showFloatingSnackBar(
          context,
          message: "Switched active wallet",
          type: SnackBarType.success,
        );
        Phoenix.rebirth(context);
      } else {
        showFloatingSnackBar(
          context,
          message: "Failed to switch wallet",
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
      },
    );
  }

  PreferredSizeWidget _buildAppBar(AppColor colors, state) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      leading: Container(
        margin: const EdgeInsets.only(left: 8),
        child: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.surface.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colors.border.withOpacity(0.15),
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
          color: colors.surface.withOpacity(0.9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colors.border.withOpacity(0.15),
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
                color: colors.textSecondary.withOpacity(0.7),
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
            colors.primary.withOpacity(0.06),
            colors.primary.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colors.primary.withOpacity(0.12),
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
        color: colors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
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
            size: 18,
          ),
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
      scale: CurvedAnimation(
        parent: _fabController,
        curve: Curves.easeOut,
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: _pad),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.surface,
              colors.surface.withOpacity(0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colors.border.withOpacity(0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
              spreadRadius: -4,
            ),
            BoxShadow(
              color: colors.primary.withOpacity(0.04),
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

// ── Helper Widgets ──────────────────────────────────────────────────────────

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
              widget.colors.primary.withOpacity(0.9),
              widget.colors.primary.withOpacity(0.8),
            ]
                : [
              widget.colors.primary,
              widget.colors.primary.withOpacity(0.9),
            ],
          )
              : null,
          color: !widget.isPrimary
              ? (_isPressed
              ? widget.colors.background.withOpacity(0.8)
              : widget.colors.background.withOpacity(0.5))
              : null,
          borderRadius: BorderRadius.circular(14),
          border: !widget.isPrimary
              ? Border.all(
            color: widget.colors.border.withOpacity(0.25),
            width: 1.5,
          )
              : null,
          boxShadow: _isPressed
              ? []
              : [
            if (widget.isPrimary)
              BoxShadow(
                color: widget.colors.primary.withOpacity(0.3),
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
                  ? Colors.white
                  : widget.colors.textPrimary,
            ),
            const SizedBox(width: 10),
            Text(
              widget.label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: widget.isPrimary
                    ? Colors.white
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
  const _RenameBottomSheet({
    required this.controller,
    required this.colors,
  });

  final TextEditingController controller;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: colors.border.withOpacity(0.15),
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
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
                  color: colors.textSecondary.withOpacity(0.5),
                ),
                filled: true,
                fillColor: colors.background.withOpacity(0.6),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: colors.border.withOpacity(0.25),
                    width: 1.5,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: colors.border.withOpacity(0.25),
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: colors.primary,
                    width: 2,
                  ),
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
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary
            ? colors.primary
            : colors.background.withOpacity(0.6),
        foregroundColor: isPrimary ? Colors.white : colors.textPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: isPrimary
              ? BorderSide.none
              : BorderSide(
            color: colors.border.withOpacity(0.25),
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
