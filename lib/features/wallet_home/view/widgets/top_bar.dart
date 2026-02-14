// lib/features/wallet_home/view/widgets/top_bar.dart

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/features/settings/view/settings_screen.dart';
import 'package:next_fi/features/import_wallet/view/import_wallet_screen.dart';
import 'package:next_fi/features/seed_phrases/view/seed_phrase_screen.dart';
import 'package:next_fi/features/wallet_home/view_model/wallet_home_vm.dart';
import 'package:next_fi/services/oath2.0/auth_http_client.dart';
import 'package:next_fi/services/oath2.0/endpoints.dart';
import 'package:next_fi/services/oath2.0/models/user_model.dart';
import 'package:next_fi/services/oath2.0/token_storage.dart';
import 'package:provider/provider.dart';
import 'package:next_fi/common/components/snackbar/SnackBar.dart';
import 'package:next_fi/common/components/modal/wallet_switch_result.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/services/secure_storage/seed_storage.dart';

class TopBar extends StatefulWidget {
  final GlobalKey<ScaffoldState>? scaffoldKey;

  const TopBar({super.key, this.scaffoldKey});

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar>
    with WidgetsBindingObserver {
  final _tokenStorage = TokenStorage();

  bool _isLoggedIn = false;
  bool _loading = true;
  User? _user;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshProfile();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(
      AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshProfile();
    }
  }

  Future<void> _refreshProfile() async {
    setState(() => _loading = true);

    final hasTokens =
    await _tokenStorage.hasTokens;

    if (!hasTokens) {
      if (!mounted) return;
      setState(() {
        _isLoggedIn = false;
        _user = null;
        _loading = false;
      });
      return;
    }

    try {
      final client =
      AuthHttpClient(tokenStorage: _tokenStorage);

      final json =
      await client.get(AuthEndpoints.me);

      final user = User.fromJson(json);

      if (!mounted) return;

      setState(() {
        _isLoggedIn = true;
        _user = user;
        _loading = false;
      });

      client.dispose();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoggedIn = false;
        _user = null;
        _loading = false;
      });
    }
  }

  void _openDrawer(BuildContext context) {
    if (widget.scaffoldKey != null) {
      widget.scaffoldKey!
          .currentState
          ?.openDrawer();
    } else {
      Scaffold.of(context).openDrawer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final vm = context.watch<WalletHomeVM>();
    final walletName =
        vm.state.walletName ?? 'Default Wallet';

    return Padding(
      padding:
      const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Builder(
            builder: (ctx) => _MenuButton(
              colors: colors,
              onTap: () => _openDrawer(ctx),
            ),
          ),

          const Spacer(),

          _WalletSwitcher(
            walletName: walletName,
            colors: colors,
            onTap: () =>
                _handleWalletSwitch(context),
          ),

          const Spacer(),

          _SettingsButton(
            colors: colors,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                  const SettingsScreen(),
                ),
              );

              if (context.mounted) {
                _refreshProfile();
              }
            },
          ),

          if (!_loading &&
              _isLoggedIn &&
              _user != null) ...[
            const SizedBox(width: 8),
            _ProfileAvatar(
              user: _user!,
              colors: colors,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleWalletSwitch(
      BuildContext context) async {
    final activeId =
    await SeedStorage.getActiveWalletId();

    final res =
    await showWalletSwitchSheet(
      context,
      currentActiveId: activeId,
      allowGenerate: true,
    );

    if (res == null) return;

    if (res.importRequested) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
          const ImportWalletScreen(),
        ),
      );

      if (!context.mounted) return;

      await context
          .read<WalletHomeVM>()
          .boot();

      await _refreshProfile();

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
        MaterialPageRoute(
          builder: (_) =>
          const SeedPhraseScreen(),
        ),
      );

      if (!context.mounted) return;

      await context
          .read<WalletHomeVM>()
          .boot();

      await _refreshProfile();
      return;
    }

    final chosenId =
        res.chosenWalletId;

    if (chosenId != null &&
        chosenId != activeId) {
      final ok = await context
          .read<WalletHomeVM>()
          .switchTo(chosenId);

      if (!context.mounted) return;

      await _refreshProfile();

      showFloatingSnackBar(
        context,
        message: ok
            ? 'Switched active wallet.'
            : 'Failed to switch wallet.',
        type: ok
            ? SnackBarType.success
            : SnackBarType.error,
      );
    }
  }
}

class _MenuButton extends StatefulWidget {
  final AppColor colors;
  final VoidCallback onTap;

  const _MenuButton({
    required this.colors,
    required this.onTap,
  });

  @override
  State<_MenuButton> createState() =>
      _MenuButtonState();
}

class _MenuButtonState
    extends State<_MenuButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController
  _controller;
  late final Animation<double>
  _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();

    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(
              milliseconds: 150),
        );

    _scaleAnimation =
        Tween<double>(
          begin: 1.0,
          end: 0.92,
        ).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Curves.easeInOut,
          ),
        );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness ==
            Brightness.dark;

    return GestureDetector(
      onTapDown: (_) {
        setState(
                () => _isPressed = true);
        _controller.forward();
      },
      onTapUp: (_) {
        setState(
                () => _isPressed = false);
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () {
        setState(
                () => _isPressed = false);
        _controller.reverse();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(
              milliseconds: 200),
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isPressed
                ? widget.colors.border
                .withOpacity(
                isDark
                    ? 0.15
                    : 0.12)
                : widget.colors.border
                .withOpacity(
                isDark
                    ? 0.08
                    : 0.05),
          ),
          child: Icon(
            LucideIcons.menu,
            size: 20,
            color:
            widget.colors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _WalletSwitcher
    extends StatelessWidget {
  final String walletName;
  final AppColor colors;
  final VoidCallback onTap;

  const _WalletSwitcher({
    required this.walletName,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
        const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10),
        decoration: BoxDecoration(
          borderRadius:
          BorderRadius.circular(16),
          color: colors.border
              .withOpacity(0.08),
        ),
        child: Row(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            Text(
              walletName,
              style: TextStyle(
                fontWeight:
                FontWeight.w700,
                color: colors
                    .textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              LucideIcons
                  .chevronDown,
              size: 18,
              color: colors
                  .textPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsButton
    extends StatelessWidget {
  final AppColor colors;
  final VoidCallback onTap;

  const _SettingsButton({
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        LucideIcons.settings,
        color:
        colors.textPrimary,
      ),
      onPressed: onTap,
    );
  }
}

class _ProfileAvatar
    extends StatelessWidget {
  final User user;
  final AppColor colors;

  const _ProfileAvatar({
    required this.user,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final initial =
    user.name.isNotEmpty
        ? user.name[0]
        .toUpperCase()
        : '?';

    return CircleAvatar(
      radius: 18,
      backgroundColor:
      colors.primary,
      child: Text(
        initial,
        style:
        const TextStyle(
          color: Colors.white,
          fontWeight:
          FontWeight.bold,
        ),
      ),
    );
  }
}
