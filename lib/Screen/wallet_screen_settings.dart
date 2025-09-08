import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animate_do/animate_do.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:next_fi/Components/CustomButton.dart';
import 'package:next_fi/Components/SnackBar.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Screen/auth_gate_screen.dart';
import 'package:next_fi/Services/seed_storage.dart';
import 'package:next_fi/Services/wallet_secure_storage.dart';

class WalletScreenSettings extends StatefulWidget {
  const WalletScreenSettings({super.key});

  @override
  State<WalletScreenSettings> createState() => _WalletScreenSettingsState();
}

class _WalletScreenSettingsState extends State<WalletScreenSettings>
    with WidgetsBindingObserver {
  String _mnemonic = "";
  List<String> _words = [];
  bool _isLoading = true;

  bool _obscured = true;    // hidden until after auth
  bool _authorized = false; // becomes true after AuthGateScreen

  // Wallet name
  String _walletName = "My Wallet";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSecrets();
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

  // Auto re-hide if app backgrounded
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (!_obscured && mounted) setState(() => _obscured = true);
    }
  }

  Future<void> _loadSecrets() async {
    try {
      final seed = await SeedStorage.getSeed();
      final name = await WalletSecureStorage.readWalletName();
      if (!mounted) return;

      if (seed == null || seed.trim().isEmpty) {
        setState(() => _isLoading = false);
        showFloatingSnackBar(
          context,
          message: 'No recovery phrase found. Create or import a wallet first.',
          type: SnackBarType.warning,
        );
        return;
      }

      setState(() {
        _mnemonic = seed.trim();
        _words = _mnemonic.split(RegExp(r'\s+'));
        _walletName = (name?.trim().isNotEmpty == true) ? name!.trim() : "My Wallet";
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showFloatingSnackBar(
        context,
        message: 'Failed to load wallet secrets: $e',
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

  Future<void> _openRenameSheet() async {
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
            left: 16, right: 16, top: 12,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: colors.border, borderRadius: BorderRadius.circular(2),
                ),
              ),
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
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.border.withOpacity(.55)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
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
                      onPressed: () { Navigator.pop(ctx); }, // VOID CALLBACK ✔
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(LucideIcons.check, size: 16),
                      label: const Text('Save'),
                      onPressed: () {                          // VOID CALLBACK ✔
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
    final ok = await WalletSecureStorage.saveWalletName(newName);
    if (!mounted) return;
    if (ok) {
      setState(() => _walletName = newName);
      showFloatingSnackBar(context, message: "Wallet name updated.", type: SnackBarType.success);
    } else {
      showFloatingSnackBar(context, message: "Failed to save wallet name.", type: SnackBarType.error);
    }
  }

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
          onPressed: () { Navigator.pop(context); }, // VOID CALLBACK ✔
          tooltip: 'Back',
        ),
        title: Text(
          'Wallet Settings',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: .2,
          ),
        ),
        // Removed AppBar action buttons to avoid redundancy with footer actions
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: colors.primary))
            : Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FadeInDown(
                      duration: const Duration(milliseconds: 280),
                      child: _walletNameCard(colors),
                    ),
                    const SizedBox(height: 12),
                    FadeInDown(
                      duration: const Duration(milliseconds: 320),
                      child: _warningBox(colors),
                    ),
                    const SizedBox(height: 16),
                    FadeInUp(
                      duration: const Duration(milliseconds: 340),
                      child: _metaHeader(colors, wordCount),
                    ),
                    const SizedBox(height: 10),
                    FadeInUp(
                      duration: const Duration(milliseconds: 360),
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              child: Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: _obscured ? "Reveal Phrase" : "Hide Phrase",
                      icon: _obscured ? LucideIcons.eye : LucideIcons.eyeOff,
                      type: ButtonType.outlined,
                      onPressed: () { _toggleObscure(); }, // VOID CALLBACK ✔
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: CustomButton(
                      text: "Copy",
                      icon: LucideIcons.copy,
                      type: ButtonType.outlined,
                      onPressed: () {                     // ← always a non-null VoidCallback
                        if (_obscured) return;            // guard instead of passing null
                        _copySeedPhrase();
                      },
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

  // --- Widgets ---
  Widget _walletNameCard(AppColor colors) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.035),
            blurRadius: 16,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.border.withOpacity(.25)),
            ),
            child: Icon(LucideIcons.wallet, color: colors.textPrimary, size: 20),
          ),
          const SizedBox(width: 10),
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
          IconButton(
            tooltip: 'Rename wallet',
            onPressed: () { _openRenameSheet(); }, // VOID CALLBACK ✔
            icon: Icon(LucideIcons.pencil, color: colors.textSecondary),
            splashRadius: 20,
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
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _seedCard(AppColor colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.035),
            blurRadius: 16,
            offset: const Offset(0, 10),
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

  Widget _blurredPlaceholder(AppColor colors) {
    return InkWell(
      onTap: () { _toggleObscure(); }, // VOID CALLBACK ✔
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 24, 14, 24),
        decoration: BoxDecoration(
          color: colors.background.withOpacity(.7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border.withOpacity(.25)),
        ),
        child: Column(
          children: [
            Icon(LucideIcons.eye, size: 24, color: colors.textSecondary),
            const SizedBox(height: 10),
            Text(
              "Tap to reveal your recovery phrase",
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
      color: colors.warning.withOpacity(0.10),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: colors.warning.withOpacity(0.35)),
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

  Widget _seedGrid(AppColor colors) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
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
