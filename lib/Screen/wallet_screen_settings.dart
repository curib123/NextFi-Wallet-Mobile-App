import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:next_fi/Components/CustomButton.dart';
import 'package:next_fi/Components/SnackBar.dart';
import 'package:next_fi/Components/wallet_switch_result.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Screen/auth_gate_screen.dart';
import 'package:next_fi/Screen/import_wallet_screen.dart';
import 'package:next_fi/Screen/wallet_creation_screen.dart';
import 'package:next_fi/Services/seed_storage.dart';

class WalletScreenSettings extends StatefulWidget {
  const WalletScreenSettings({super.key});

  @override
  State<WalletScreenSettings> createState() => _WalletScreenSettingsState();
}

class _WalletScreenSettingsState extends State<WalletScreenSettings>
    with WidgetsBindingObserver {
  // --- Design tokens ---
  static const double _pad = 16;
  static const double _radius = 14;

  // --- State ---
  String _mnemonic = "";
  List<String> _words = [];
  bool _isLoading = true;

  bool _obscured = true; // hidden until after auth
  bool _authorized = false; // becomes true after AuthGateScreen

  // Active wallet meta
  String? _activeWalletId;
  String _walletName = "My Wallet";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
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

  Future<void> _init() async {
    await SeedStorage.migrateLegacyIfNeeded();
    await _loadSecrets();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Auto re-hide if app backgrounded
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (!_obscured && mounted) setState(() => _obscured = true);
    }
  }

  Future<void> _loadSecrets() async {
    try {
      final meta = await SeedStorage.getActiveWalletMeta();
      final seed = await SeedStorage.getSeed(); // active wallet seed
      if (!mounted) return;

      if (seed == null || seed.trim().isEmpty) {
        setState(() {
          _activeWalletId = meta?.id;
          _walletName = meta?.name ?? "My Wallet";
          _mnemonic = "";
          _words = const [];
          _isLoading = false;
        });
        showFloatingSnackBar(
          context,
          message: 'No recovery phrase found. Import or create a wallet.',
          type: SnackBarType.warning,
        );
        return;
      }

      setState(() {
        _activeWalletId = meta?.id;
        _walletName = meta?.name ?? "My Wallet";
        _mnemonic = seed.trim();
        _words = _mnemonic.split(RegExp(r'\s+'));
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showFloatingSnackBar(
        context,
        message: 'Failed to load wallet: $e',
        type: SnackBarType.error,
      );
    }
  }

  Future<bool> _requireAuth() async {
    if (_authorized) return true;
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
    if (mounted && granted) {
      setState(() => _authorized = true);
      return true;
    }
    return false;
  }

  Future<void> _toggleObscure() async {
    if (_obscured) {
      final ok = await _requireAuth();
      if (!ok) return;
    }
    setState(() => _obscured = !_obscured);
    HapticFeedback.selectionClick();
  }

  Future<void> _copySeedPhrase() async {
    if (_mnemonic.isEmpty) return;
    final ok = await _requireAuth();
    if (!ok) return;

    if (_obscured) {
      showFloatingSnackBar(
        context,
        message: "Reveal the phrase first to copy.",
        type: SnackBarType.info,
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: _mnemonic));
    HapticFeedback.lightImpact();
    final colors = AppColor.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Copied recovery phrase (keep it safe!)',
            style: TextStyle(color: Colors.white)),
        backgroundColor: colors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ======= Navigation (Import / Rename / Switch) =======

  /// NEW: Instead of a modal, go to a simple screen with TODO.
  Future<void> _goToImport() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ImportWalletScreen()),
    );
  }

  Future<void> _openRenameSheet() async {
    if (_activeWalletId == null) {
      showFloatingSnackBar(context, message: "No active wallet.", type: SnackBarType.warning);
      return;
    }
    final colors = AppColor.of(context);
    final ctrl = TextEditingController(text: _walletName);
    final newName = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: _pad, right: _pad, top: 12,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + _pad,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SheetHandle(colors: colors),
              Text(
                'Rename Wallet',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLength: 32,
                decoration: InputDecoration(
                  counterText: "",
                  hintText: "Enter wallet name",
                  isDense: true,
                  filled: true,
                  fillColor: colors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(_radius),
                    borderSide: BorderSide(color: colors.border.withOpacity(.55)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(_radius),
                    borderSide: BorderSide(color: colors.primary, width: 1.2),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(LucideIcons.x, size: 16),
                      label: const Text('Cancel'),
                      onPressed: () { Navigator.pop(ctx); },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(LucideIcons.check, size: 16),
                      label: const Text('Save'),
                      onPressed: () {
                        final raw = ctrl.text.trim();
                        if (raw.isEmpty || raw.length > 32) {
                          showFloatingSnackBar(
                            context,
                            message: raw.isEmpty
                                ? "Wallet name cannot be empty."
                                : "Keep the name under 32 characters.",
                            type: SnackBarType.warning,
                          );
                          return;
                        }
                        Navigator.pop(ctx, raw);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (newName == null) return;
    final ok = await SeedStorage.renameWallet(_activeWalletId!, newName);
    if (!mounted) return;
    if (ok) {
      setState(() => _walletName = newName);
      showFloatingSnackBar(context, message: "Wallet name updated.", type: SnackBarType.success);
    } else {
      showFloatingSnackBar(context, message: "Failed to save wallet name.", type: SnackBarType.error);
    }
  }

  Future<void> _handleSwitch() async {
    final res = await showWalletSwitchSheet(
      context,
      currentActiveId: _activeWalletId,
      allowGenerate: true,
    );
    if (res == null) return;

    if (res.createNew) {
      // Go to your existing create flow
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const WalletCreationScreen()),
      );
      await _loadSecrets();
      if (!mounted) return;
      Phoenix.rebirth(context);
      return;
    }

    final chosenId = res.chosenWalletId;
    if (chosenId != null && chosenId != _activeWalletId) {
      final ok = await SeedStorage.setActiveWallet(chosenId);
      if (!mounted) return;
      if (ok) {
        await _loadSecrets();
        showFloatingSnackBar(context, message: "Switched active wallet.", type: SnackBarType.success);
        Phoenix.rebirth(context);
      } else {
        showFloatingSnackBar(context, message: "Failed to switch wallet.", type: SnackBarType.error);
      }
    }
  }

  // ======= UI =======

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final wordCount = _words.length;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colors.surface,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: colors.textPrimary),
          onPressed: () { Navigator.pop(context); },
          tooltip: 'Back',
          splashRadius: 22,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Wallet Settings',
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: .2,
              ),
            ),
            const SizedBox(height: 2),
            Text(_walletName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: colors.primary))
            : Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(_pad, 12, _pad, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FadeInDown(
                      duration: const Duration(milliseconds: 200),
                      child: _headerCard(colors),
                    ),
                    const SizedBox(height: 12),
                    FadeInDown(
                      duration: const Duration(milliseconds: 230),
                      child: _warningBox(colors),
                    ),
                    const SizedBox(height: 14),
                    FadeInUp(
                      duration: const Duration(milliseconds: 260),
                      child: _metaHeader(colors, wordCount),
                    ),
                    const SizedBox(height: 8),
                    FadeInUp(
                      duration: const Duration(milliseconds: 280),
                      child: _seedCard(colors),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "💡 Tip: Write it on paper and store offline. Never share or screenshot it.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
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
                      text: _obscured ? "Reveal Phrase" : "Hide Phrase",
                      icon: _obscured ? LucideIcons.eye : LucideIcons.eyeOff,
                      type: ButtonType.outlined,
                      onPressed: () { _toggleObscure(); },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: CustomButton(
                      text: "Copy",
                      icon: LucideIcons.copy,
                      type: ButtonType.outlined,
                      onPressed: () { if (_obscured) return; _copySeedPhrase(); },
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

  // ======= Widgets =======

  /// Top card with wallet avatar + quick actions
  Widget _headerCard(AppColor colors) {
    return Container(
      padding: const EdgeInsets.all(_pad),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: colors.border.withOpacity(0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.03),
            blurRadius: 10,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border.withOpacity(.25)),
                ),
                child: Icon(LucideIcons.wallet, color: colors.textPrimary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _walletName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: .2,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _StatusPill(
                icon: _obscured ? LucideIcons.lock : LucideIcons.unlock,
                label: _obscured ? 'Hidden' : 'Visible',
                color: _obscured ? colors.warning : colors.success,
                colors: colors,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  icon: LucideIcons.download,
                  label: 'Import',
                  onTap: () { _goToImport(); },
                  colors: colors,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickAction(
                  icon: LucideIcons.shuffle,
                  label: 'Switch',
                  onTap: () => _handleSwitch() ,
                  colors: colors,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickAction(
                  icon: LucideIcons.pencil,
                  label: 'Rename',
                  onTap: () { _openRenameSheet(); },
                  colors: colors,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaHeader(AppColor colors, int wordCount) {
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
        Text(
          "Recovery Phrase",
          style: TextStyle(
            color: colors.textSecondary,
            fontWeight: FontWeight.w700,
            letterSpacing: .2,
          ),
        ),
      ],
    );
  }

  Widget _seedCard(AppColor colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: colors.border.withOpacity(0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.03),
            blurRadius: 10,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _obscured
            ? _blurredPlaceholder(colors)
            : Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
          child: _seedGrid(colors),
        ),
      ),
    );
  }

  /// Safer: require long-press to reveal from the placeholder
  Widget _blurredPlaceholder(AppColor colors) {
    return InkWell(
      onLongPress: () { _toggleObscure(); }, // long-press instead of simple tap
      borderRadius: BorderRadius.circular(_radius),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 24, 14, 24),
        decoration: BoxDecoration(
          color: colors.background.withOpacity(.72),
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(color: colors.border.withOpacity(.25)),
        ),
        child: Column(
          children: [
            Icon(LucideIcons.eye, size: 24, color: colors.textSecondary),
            const SizedBox(height: 10),
            Text(
              "Press & hold to reveal your recovery phrase",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Authentication required",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSecondary.withOpacity(.85),
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _warningBox(AppColor colors) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: colors.warning.withOpacity(0.09),
      borderRadius: BorderRadius.circular(_radius),
      border: Border.all(color: colors.warning.withOpacity(0.30)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(LucideIcons.alertTriangle, color: colors.warning, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 13,
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
                  "It’s the only way to access your funds. Do not share it with anyone. NextFi never stores your keys—you are in full control.",
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

  Widget _seedGrid(AppColor colors) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // compact & readable
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.6,
      ),
      itemCount: _words.length,
      itemBuilder: (context, index) {
        final idx = index + 1;
        final word = _words[index];

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                alignment: Alignment.centerLeft,
                child: Text(
                  '$idx.',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  word,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    letterSpacing: .2,
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

// ======= Small helpers/components =======

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.colors,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: colors.border.withOpacity(.5)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        visualDensity: VisualDensity.compact,
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: colors.textPrimary),
      label: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: colors.textPrimary, fontSize: 12)),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.colors,
  });

  final IconData icon;
  final String label;
  final Color color;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.35)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: .2,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle({required this.colors});
  final AppColor colors;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.border,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
