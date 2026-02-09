// lib/features/wallet_home/view/widgets/top_bar.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/features/settings/view/settings_screen.dart';
import 'package:next_fi/features/wallet_settings/view/wallet_screen_settings.dart';
import 'package:next_fi/reusable_view_model/tab_vm.dart';
import 'package:next_fi/features/import_wallet/view/import_wallet_screen.dart';
import 'package:next_fi/features/seed_phrases/view/seed_phrase_screen.dart';
import 'package:next_fi/features/wallet_home/view_model/wallet_home_vm.dart';
import 'package:provider/provider.dart';
import 'package:next_fi/common/components/snackbar/SnackBar.dart';
import 'package:next_fi/common/components/modal/wallet_switch_result.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/services/secure_storage/seed_storage.dart';

class TopBar extends StatelessWidget {
  const TopBar({super.key});

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'WW';
    final parts = trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      final first = parts.first[0];
      final last = parts.last[0];
      return (first + last).toUpperCase();
    } else {
      final w = parts.first;
      return (w.length >= 2 ? w.substring(0, 2) : (w + 'W')).toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final vm = context.watch<WalletHomeVM>();
    final walletName = vm.state.walletName ?? 'Default Wallet';
    final initials = _initials(walletName);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ProfileButton(
            initials: initials,
            colors: colors,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WalletScreenSettings()),
              );
            },
          ),
          _WalletSwitcher(
            walletName: walletName,
            colors: colors,
            onTap: () => _handleWalletSwitch(context),
          ),
          _SettingsButton(
            colors: colors,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleWalletSwitch(BuildContext context) async {
    final activeId = await SeedStorage.getActiveWalletId();
    final res = await showWalletSwitchSheet(
      context,
      currentActiveId: activeId,
      allowGenerate: true,
    );
    if (res == null) return;

    if (res.importRequested) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ImportWalletScreen()),
      );
      if (!context.mounted) return;
      await context.read<WalletHomeVM>().boot();
      showFloatingSnackBar(
        context,
        message: 'Wallets updated.',
        type: SnackBarType.success,
      );
      return;
    }

    if (res.createNew) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SeedPhraseScreen()),
      );
      if (!context.mounted) return;
      await context.read<WalletHomeVM>().boot();
      return;
    }

    final chosenId = res.chosenWalletId;
    if (chosenId != null && chosenId != activeId) {
      final ok = await context.read<WalletHomeVM>().switchTo(chosenId);
      if (!context.mounted) return;
      showFloatingSnackBar(
        context,
        message: ok ? 'Switched active wallet.' : 'Failed to switch wallet.',
        type: ok ? SnackBarType.success : SnackBarType.error,
      );
    }
  }
}

class _ProfileButton extends StatefulWidget {
  final String initials;
  final AppColor colors;
  final VoidCallback onTap;

  const _ProfileButton({
    required this.initials,
    required this.colors,
    required this.onTap,
  });

  @override
  State<_ProfileButton> createState() => _ProfileButtonState();
}

class _ProfileButtonState extends State<_ProfileButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _controller.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Tooltip(
          message: 'Activity',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _isPressed
                    ? [
                  widget.colors.primary.withOpacity(0.2),
                  widget.colors.primary.withOpacity(0.15),
                ]
                    : [
                  widget.colors.primary.withOpacity(0.12),
                  widget.colors.primary.withOpacity(0.08),
                ],
              ),
              border: Border.all(
                color: _isPressed
                    ? widget.colors.primary.withOpacity(0.4)
                    : widget.colors.primary.withOpacity(0.25),
                width: 1.5,
              ),
              boxShadow: _isPressed
                  ? [
                BoxShadow(
                  color: widget.colors.primary.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
                  : [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.15 : 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              widget.initials,
              style: TextStyle(
                color: widget.colors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WalletSwitcher extends StatefulWidget {
  final String walletName;
  final AppColor colors;
  final VoidCallback onTap;

  const _WalletSwitcher({
    required this.walletName,
    required this.colors,
    required this.onTap,
  });

  @override
  State<_WalletSwitcher> createState() => _WalletSwitcherState();
}

class _WalletSwitcherState extends State<_WalletSwitcher> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _controller.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _isPressed
                ? widget.colors.primary.withOpacity(isDark ? 0.15 : 0.08)
                : widget.colors.border.withOpacity(isDark ? 0.08 : 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isPressed
                  ? widget.colors.primary.withOpacity(0.3)
                  : widget.colors.border.withOpacity(isDark ? 0.12 : 0.08),
              width: 1,
            ),
            boxShadow: _isPressed
                ? [
              BoxShadow(
                color: widget.colors.primary.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  widget.walletName,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: -0.3,
                    color: widget.colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              RotationTransition(
                turns: _rotationAnimation,
                child: Icon(
                  LucideIcons.chevronDown,
                  size: 18,
                  color: widget.colors.textPrimary.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsButton extends StatefulWidget {
  final AppColor colors;
  final VoidCallback onTap;

  const _SettingsButton({
    required this.colors,
    required this.onTap,
  });

  @override
  State<_SettingsButton> createState() => _SettingsButtonState();
}

class _SettingsButtonState extends State<_SettingsButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.125).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _controller.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Tooltip(
          message: 'Settings',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isPressed
                  ? widget.colors.border.withOpacity(isDark ? 0.15 : 0.12)
                  : widget.colors.border.withOpacity(isDark ? 0.08 : 0.05),
              border: Border.all(
                color: _isPressed
                    ? widget.colors.border.withOpacity(0.25)
                    : widget.colors.border.withOpacity(isDark ? 0.12 : 0.08),
                width: 1,
              ),
              boxShadow: _isPressed
                  ? [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
                  : [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.1 : 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: RotationTransition(
              turns: _rotationAnimation,
              child: Icon(
                LucideIcons.settings,
                color: widget.colors.textPrimary.withOpacity(0.8),
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}