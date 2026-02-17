// lib/features/app_drawer/view/app_drawer.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/profile_avatar/user_avatar.dart';
import 'package:next_fi/features/auth/view/login.dart';
import 'package:next_fi/features/settings/view/settings_screen.dart';
import 'package:next_fi/features/wallet_settings/view/wallet_screen_settings.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:next_fi/services/oath2.0/auth_service.dart';
import 'package:next_fi/services/oath2.0/models/user_model.dart';

class AppDrawer extends StatefulWidget {
  final VoidCallback? onLogout;

  const AppDrawer({super.key, this.onLogout});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer>
    with SingleTickerProviderStateMixin {
  final _auth = AuthService();

  static User? _cachedUser;
  static PackageInfo? _cachedInfo;

  bool _loading = true;
  bool _loggingOut = false;

  late final AnimationController _entryCtrl;

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _bootstrap();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = false);
    _entryCtrl.forward();

    await Future.wait([
      _fetchRealUser(),
      _fetchAppInfo(),
    ]);
  }

  Future<void> _fetchRealUser() async {
    try {
      if (!await _auth.isAuthenticated) return;

      final realUser = await _auth.currentUser;

      if (_cachedUser == null) {
        _cachedUser = realUser;
        if (mounted) setState(() {});
        return;
      }

      if (!_isSameUser(_cachedUser!, realUser)) {
        _cachedUser = realUser;
        if (mounted) setState(() {});
      }
    } catch (_) {}
  }

  bool _isSameUser(User a, User b) {
    return a.id == b.id &&
        a.name == b.name &&
        a.email == b.email &&
        a.avatarUrl == b.avatarUrl;
  }

  Future<void> _fetchAppInfo() async {
    if (_cachedInfo != null) return;

    final info = await PackageInfo.fromPlatform();

    if (_cachedInfo == null) {
      _cachedInfo = info;
      if (mounted) setState(() {});
    }
  }

  Future<void> _handleLogout() async {
    if (_loggingOut) return;

    HapticFeedback.mediumImpact();

    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _LogoutConfirmationModal(),
    );

    if (confirm != true || !mounted) return;

    setState(() => _loggingOut = true);

    await _auth.logout();

    _cachedUser = null;

    if (!mounted) return;

    Navigator.pop(context);
    widget.onLogout?.call();

    Phoenix.rebirth(context);
  }

  void _redirectToLogin() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final mq = MediaQuery.of(context);
    final user = _cachedUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      backgroundColor: c.background,
      elevation: 0,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(-0.02, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _entryCtrl,
          curve: Curves.easeOutCubic,
        )),
        child: Column(
          children: [
            // Header Section
            if (_loading)
              _ProfileShimmer(topPadding: mq.padding.top, colors: c)
            else if (user != null)
              _ProfileHeader(
                user: user,
                appInfo: _cachedInfo,
                colors: c,
                isDark: isDark,
              )
            else
              _LoginPrompt(
                colors: c,
                topPadding: mq.padding.top,
                onTap: _redirectToLogin,
              ),

            // Navigation Section
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const SizedBox(height: 8),

                  const _SectionLabel(label: 'QUICK ACTIONS'),

                  _NavTile(
                    icon: LucideIcons.download,
                    label: 'Buy XLM',
                    description: 'Purchase Stellar lumens',
                    colors: c,
                    onTap: () {
                      if (user == null) {
                        _redirectToLogin();
                      } else {
                        // Handle buy action
                      }
                    },
                  ),

                  _NavTile(
                    icon: LucideIcons.upload,
                    label: 'Sell XLM',
                    description: 'Convert lumens to cash',
                    colors: c,
                    onTap: () {
                      if (user == null) {
                        _redirectToLogin();
                      } else {
                        // Handle sell action
                      }
                    },
                  ),

                  const SizedBox(height: 16),
                  const _SectionLabel(label: 'SETTINGS'),

                  _NavTile(
                    icon: LucideIcons.wallet,
                    label: 'Manage Wallet',
                    description: 'Keys & backup',
                    colors: c,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WalletScreenSettings(),
                        ),
                      );
                    },
                  ),

                  _NavTile(
                    icon: LucideIcons.settings,
                    label: 'Preferences',
                    description: 'App settings',
                    colors: c,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),

                  if (_cachedInfo != null) ...[
                    const SizedBox(height: 24),
                    _AppVersionInfo(info: _cachedInfo!, colors: c),
                  ],
                ],
              ),
            ),

            // Logout Button
            if (user != null) ...[
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: c.border.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: _LogoutButton(
                  isLoading: _loggingOut,
                  colors: c,
                  onTap: _handleLogout,
                ),
              ),
            ],

            SizedBox(height: mq.padding.bottom + 8),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PROFILE HEADER
// ═══════════════════════════════════════════════════════════════════

class _ProfileHeader extends StatelessWidget {
  final User user;
  final PackageInfo? appInfo;
  final AppColor colors;
  final bool isDark;

  const _ProfileHeader({
    required this.user,
    required this.appInfo,
    required this.colors,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, top + 20, 20, 24),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(
            color: colors.border.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar with subtle border
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.primary.withOpacity(0.15),
                    width: 2,
                  ),
                ),
                child: UserAvatar(
                  user: user,
                  radius: 32,
                  colors: colors,
                ),
              ),

              const SizedBox(width: 16),

              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Verified badge
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  LucideIcons.checkCircle2,
                  color: Colors.green,
                  size: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// LOGIN PROMPT
// ═══════════════════════════════════════════════════════════════════

class _LoginPrompt extends StatelessWidget {
  final AppColor colors;
  final double topPadding;
  final VoidCallback onTap;

  const _LoginPrompt({
    required this.colors,
    required this.topPadding,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topPadding + 20, 20, 24),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(
            color: colors.border.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Guest Icon
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: colors.border.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.border.withOpacity(0.2),
                    width: 2,
                  ),
                ),
                child: Icon(
                  LucideIcons.userCircle2,
                  color: colors.textSecondary,
                  size: 32,
                ),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Guest Mode',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sign in to unlock all features',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Sign In Button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Sign In',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// NAVIGATION TILE
// ═══════════════════════════════════════════════════════════════════

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final AppColor colors;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.description,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              // Icon Container
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.border.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: colors.textPrimary,
                  size: 20,
                ),
              ),

              const SizedBox(width: 14),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow
              Icon(
                LucideIcons.chevronRight,
                color: colors.textSecondary.withOpacity(0.4),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SECTION LABEL
// ═══════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: colors.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// APP VERSION INFO
// ═══════════════════════════════════════════════════════════════════

class _AppVersionInfo extends StatelessWidget {
  final PackageInfo info;
  final AppColor colors;

  const _AppVersionInfo({
    required this.info,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(
            color: colors.border.withOpacity(0.2),
            height: 1,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                LucideIcons.info,
                size: 14,
                color: colors.textSecondary.withOpacity(0.6),
              ),
              const SizedBox(width: 8),
              Text(
                '${info.appName} v${info.version}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colors.textSecondary.withOpacity(0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// LOGOUT BUTTON
// ═══════════════════════════════════════════════════════════════════

class _LogoutButton extends StatelessWidget {
  final bool isLoading;
  final AppColor colors;
  final VoidCallback onTap;

  const _LogoutButton({
    required this.isLoading,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              if (isLoading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(colors.error),
                  ),
                )
              else
                Icon(
                  LucideIcons.logOut,
                  color: colors.error,
                  size: 20,
                ),

              const SizedBox(width: 14),

              Text(
                isLoading ? 'Signing out...' : 'Sign Out',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.error,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PROFILE SHIMMER
// ═══════════════════════════════════════════════════════════════════

class _ProfileShimmer extends StatelessWidget {
  final double topPadding;
  final AppColor colors;

  const _ProfileShimmer({
    required this.topPadding,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topPadding + 20, 20, 24),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(
            color: colors.border.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: colors.border.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 140,
                  height: 18,
                  decoration: BoxDecoration(
                    color: colors.border.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 180,
                  height: 14,
                  decoration: BoxDecoration(
                    color: colors.border.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// LOGOUT CONFIRMATION MODAL
// ═══════════════════════════════════════════════════════════════════

class _LogoutConfirmationModal extends StatelessWidget {
  const _LogoutConfirmationModal();

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? colors.surface : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colors.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.logOut,
                  color: colors.error,
                  size: 28,
                ),
              ),

              const SizedBox(height: 20),

              // Title
              Text(
                'Sign Out?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 8),

              // Description
              Text(
                'You will need to sign in again to access your account',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: colors.textSecondary,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 24),

              // Sign Out Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.error,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Sign Out',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Cancel Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context, false);
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: colors.border.withOpacity(0.1),
                    foregroundColor: colors.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}