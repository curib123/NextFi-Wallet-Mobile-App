import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/common/components/modal/wallet_switch_result.dart';
import 'package:next_fi/common/components/profile_avatar/user_avatar.dart';
import 'package:next_fi/common/components/snackbar/SnackBar.dart';
import 'package:next_fi/features/auth/view/login.dart';
import 'package:next_fi/features/import_wallet/view/import_wallet_screen.dart';
import 'package:next_fi/features/profile/view/profile_screen.dart';
import 'package:next_fi/features/seed_phrases/view/seed_phrase_screen.dart';
import 'package:next_fi/features/wallet_home/view_model/wallet_home_vm.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/services/oath2.0/api/auth_http_client.dart';
import 'package:next_fi/services/oath2.0/api/endpoints.dart';
import 'package:next_fi/services/oath2.0/models/user_model.dart';
import 'package:next_fi/services/secure_storage/seed_storage.dart';
import 'package:next_fi/services/secure_storage/token_storage.dart';
import 'package:provider/provider.dart';

class TopBar extends StatefulWidget {
  final GlobalKey<ScaffoldState>? scaffoldKey;

  const TopBar({super.key, this.scaffoldKey});

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> with WidgetsBindingObserver {
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshProfile();
    }
  }

  Future<void> _refreshProfile() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final hasTokens = await _tokenStorage.hasTokens;
    if (!hasTokens) {
      if (!mounted) return;
      setState(() {
        _isLoggedIn = false;
        _user = null;
        _loading = false;
      });
      return;
    }

    final client = AuthHttpClient(tokenStorage: _tokenStorage);
    try {
      final json = await client.get(AuthEndpoints.me);
      final user = User.fromJson(json);
      if (!mounted) return;
      setState(() {
        _isLoggedIn = true;
        _user = user;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoggedIn = false;
        _user = null;
        _loading = false;
      });
    } finally {
      client.dispose();
    }
  }

  void _openDrawer(BuildContext context) {
    if (widget.scaffoldKey != null) {
      widget.scaffoldKey!.currentState?.openDrawer();
    } else {
      Scaffold.of(context).openDrawer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final vm = context.watch<WalletHomeVM>();
    final walletName = vm.state.walletName ?? 'Default Wallet';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Builder(
            builder: (ctx) =>
                _MenuButton(colors: colors, onTap: () => _openDrawer(ctx)),
          ),
          const Spacer(),
          _WalletSwitcher(
            walletName: walletName,
            colors: colors,
            onTap: () => _handleWalletSwitch(context),
          ),
          const Spacer(),
          _ProfileActionButton(
            colors: colors,
            isLoading: _loading,
            isLoggedIn: _isLoggedIn,
            user: _user,
            onTap: () async {
              if (!_isLoggedIn || _user == null) {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              } else {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              }
              await _refreshProfile();
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
        MaterialPageRoute(builder: (_) => const SeedPhraseScreen()),
      );
      if (!context.mounted) return;
      await context.read<WalletHomeVM>().boot();
      await _refreshProfile();
      return;
    }

    final chosenId = res.chosenWalletId;
    if (chosenId != null && chosenId != activeId) {
      final ok = await context.read<WalletHomeVM>().switchTo(chosenId);
      if (!context.mounted) return;
      await _refreshProfile();
      showFloatingSnackBar(
        context,
        message: ok ? 'Switched active wallet.' : 'Failed to switch wallet.',
        type: ok ? SnackBarType.success : SnackBarType.error,
      );
    }
  }
}

class _MenuButton extends StatefulWidget {
  final AppColor colors;
  final VoidCallback onTap;

  const _MenuButton({required this.colors, required this.onTap});

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.92,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isPressed
                ? widget.colors.border.withOpacity(isDark ? 0.15 : 0.12)
                : widget.colors.border.withOpacity(isDark ? 0.08 : 0.05),
          ),
          child: Icon(
            LucideIcons.menu,
            size: 20,
            color: widget.colors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _WalletSwitcher extends StatelessWidget {
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
    final title = walletName.trim().isEmpty ? 'My Wallet' : walletName.trim();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.border.withOpacity(0.35)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.primary.withOpacity(0.12),
                  colors.surface.withOpacity(0.55),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    LucideIcons.wallet2,
                    size: 14,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 12.9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  LucideIcons.chevronDown,
                  size: 17,
                  color: colors.textPrimary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileActionButton extends StatelessWidget {
  final AppColor colors;
  final VoidCallback onTap;
  final bool isLoading;
  final bool isLoggedIn;
  final User? user;

  const _ProfileActionButton({
    required this.colors,
    required this.onTap,
    required this.isLoading,
    required this.isLoggedIn,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.border.withOpacity(0.08),
        ),
        child: isLoading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.primary,
                ),
              )
            : (isLoggedIn && user != null)
            ? UserAvatarMedium(user: user!, colors: colors)
            : Icon(
                LucideIcons.userCircle2,
                color: colors.textPrimary,
                size: 22,
              ),
      ),
    );
  }
}
