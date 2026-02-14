// lib/features/app_drawer/view/app_drawer.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
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

  User? _user;
  bool _loading = true;
  bool _loggingOut = false;

  // Cached app info (STATIC → loads once per app lifecycle)
  static PackageInfo? _cachedInfo;

  late final AnimationController _entryCtrl;

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260), // faster
    );

    _bootstrap();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  // ── FAST PARALLEL BOOTSTRAP ─────────────────────────────

  Future<void> _bootstrap() async {
    Future.wait([
      _loadUser(),
      _loadAppInfo(),
    ]).then((_) {
      if (mounted) {
        setState(() => _loading = false);
        _entryCtrl.forward();
      }
    });
  }

  Future<void> _loadUser() async {
    try {
      if (await _auth.isAuthenticated) {
        final user = await _auth.currentUser;
        if (mounted) _user = user;
      }
    } catch (_) {}
  }

  Future<void> _loadAppInfo() async {
    if (_cachedInfo != null) return;
    _cachedInfo = await PackageInfo.fromPlatform();
  }

  // ── LOGOUT ─────────────────────────────────────────────

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

    if (!mounted) return;

    // Pop the drawer
    Navigator.pop(context);

    // Call the logout callback
    widget.onLogout?.call();
  }

  void _redirectToLogin() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  // ── UI ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final mq = MediaQuery.of(context);

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(-0.04, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _entryCtrl,
          curve: Curves.easeOutCubic,
        )),
        child: Container(
          color: c.background,
          child: Column(
            children: [
              // ── PROFILE ─────────────────────

              if (_loading)
                _ProfileShimmer(topPadding: mq.padding.top)
              else if (_user != null)
                _ProfileHeader(user: _user!, appInfo: _cachedInfo)
              else
                _LoginPrompt(appInfo: _cachedInfo),

              // ── NAV ─────────────────────────

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    const _SectionLabel(label: 'Quick Actions'),

                    _NavTile(
                      icon: Icons.arrow_downward_rounded,
                      label: 'Buy XLM',
                      description: 'Purchase Stellar lumens',
                      onTap: () {
                        if (_user == null) {
                          _redirectToLogin();
                        }
                      },
                    ),

                    _NavTile(
                      icon: Icons.arrow_upward_rounded,
                      label: 'Sell XLM',
                      description: 'Convert lumens to cash',
                      onTap: () {
                        if (_user == null) {
                          _redirectToLogin();
                        }
                      },
                    ),

                    _NavTile(
                      icon: Icons.account_balance_rounded,
                      label: 'Manage Wallet',
                      description: 'Keys & backup',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                            const WalletScreenSettings(),
                          ),
                        );
                      },
                    ),

                    _NavTile(
                      icon: Icons.tune_rounded,
                      label: 'Settings',
                      description: 'Preferences',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                            const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              if (_user != null) ...[
                const Divider(height: 0.5),
                _LogoutButton(
                  isLoading: _loggingOut,
                  onTap: _handleLogout,
                ),
              ],

              SizedBox(height: mq.padding.bottom + 12),
            ],
          ),
        ),
      ),
    );
  }
}

//
// ─────────────────────────────────────────────────────────────
// PROFILE HEADER (WITH APP INFO)
// ─────────────────────────────────────────────────────────────
//

class _ProfileHeader extends StatelessWidget {
  final User user;
  final PackageInfo? appInfo;

  const _ProfileHeader({
    required this.user,
    required this.appInfo,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final top = MediaQuery.of(context).padding.top;

    final initial = user.name.isNotEmpty ? user.name[0] : '?';

    return Container(
      width: double.infinity,
      color: c.surface,
      padding: EdgeInsets.fromLTRB(20, top + 24, 20, 20),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: c.primary,
                child: Text(
                  initial.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      user.email,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // App info in profile section
          if (appInfo != null) ...[
            const SizedBox(height: 16),
            Divider(color: c.border.withOpacity(0.5), height: 1),
            const SizedBox(height: 12),
            Text(
              '${appInfo!.appName} v${appInfo!.version}',
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

//
// ─────────────────────────────────────────────────────────────
// LOGIN PROMPT (WITH APP INFO)
// ─────────────────────────────────────────────────────────────
//

class _LoginPrompt extends StatelessWidget {
  final PackageInfo? appInfo;

  const _LoginPrompt({required this.appInfo});

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final top = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      color: c.surface,
      padding: EdgeInsets.fromLTRB(20, top + 24, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 28,
            child: Icon(Icons.person_outline),
          ),
          const SizedBox(height: 12),
          Text(
            'Guest Mode',
            style: TextStyle(
              color: c.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'Sign in to unlock features',
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12,
            ),
          ),

          // App info in login prompt
          if (appInfo != null) ...[
            const SizedBox(height: 16),
            Divider(color: c.border.withOpacity(0.5), height: 1),
            const SizedBox(height: 12),
            Text(
              '${appInfo!.appName} v${appInfo!.version}',
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

//
// ─────────────────────────────────────────────────────────────
// NAV TILE (FAST — NO HEAVY ANIM)
// ─────────────────────────────────────────────────────────────
//

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);

    return ListTile(
      leading: Icon(icon, color: c.textSecondary),
      title: Text(label),
      subtitle: Text(description),
      onTap: onTap,
    );
  }
}

//
// ─────────────────────────────────────────────────────────────
// LOGOUT BUTTON (MODERN SOFT DESIGN)
// ─────────────────────────────────────────────────────────────
//

class _LogoutButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const _LogoutButton({
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Material(
        color: c.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                if (isLoading)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: c.error,
                    ),
                  )
                else
                  Icon(
                    Icons.logout_rounded,
                    color: c.error,
                    size: 20,
                  ),
                const SizedBox(width: 14),
                Text(
                  isLoading ? 'Signing out…' : 'Sign Out',
                  style: TextStyle(
                    color: c.error,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

//
// ─────────────────────────────────────────────────────────────
// LOGOUT CONFIRMATION MODAL (MODERN BOTTOM SHEET)
// ─────────────────────────────────────────────────────────────
//

class _LogoutConfirmationModal extends StatelessWidget {
  const _LogoutConfirmationModal();

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final mq = MediaQuery.of(context);

    return Container(
      margin: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: c.border.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 24),

            // Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: c.error.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.logout_rounded,
                color: c.error,
                size: 32,
              ),
            ),

            const SizedBox(height: 20),

            // Title
            Text(
              'Sign Out?',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 8),

            // Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'You will need to sign in again to access your account',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Sign out button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context, true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.error,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Sign Out',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Cancel button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: TextButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context, false);
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: c.border.withOpacity(0.1),
                        foregroundColor: c.textPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

//
// ─────────────────────────────────────────────────────────────
// SHIMMER (LIGHT)
// ─────────────────────────────────────────────────────────────
//

class _ProfileShimmer extends StatelessWidget {
  final double topPadding;

  const _ProfileShimmer({
    required this.topPadding,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);

    return Container(
      width: double.infinity,
      color: c.surface,
      padding: EdgeInsets.fromLTRB(20, topPadding + 24, 20, 20),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: c.border,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 120,
            height: 14,
            color: c.border,
          ),
        ],
      ),
    );
  }
}

//
// ─────────────────────────────────────────────────────────────
// SECTION LABEL
// ─────────────────────────────────────────────────────────────
//

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: c.textSecondary,
          fontSize: 10,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}