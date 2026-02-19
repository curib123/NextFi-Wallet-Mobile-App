// lib/features/app_drawer/view/app_drawer.dart

import 'package:flutter/material.dart';
import 'package:next_fi/common/components/button/app_buttons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/profile_avatar/user_avatar.dart';
import 'package:next_fi/features/auth/view/login.dart';
import 'package:next_fi/features/verification_flow/view/verification_flow_screen.dart';
import 'package:next_fi/features/settings/view/settings_screen.dart';
import 'package:next_fi/features/wallet_settings/view/wallet_screen_settings.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:next_fi/services/oath2.0/auth_service.dart';
import 'package:next_fi/services/oath2.0/models/user_model.dart';
import 'package:next_fi/services/profile/models/profile_models.dart';
import 'package:next_fi/services/profile/profile_core_service.dart';
import 'package:next_fi/services/verification/models/verification_models.dart';
import 'package:next_fi/services/verification/verification_core_service.dart';

class AppDrawer extends StatefulWidget {
  final VoidCallback? onLogout;
  const AppDrawer({super.key, this.onLogout});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer>
    with SingleTickerProviderStateMixin {
  final _auth = AuthService();
  final _profile = ProfileCoreService.I;
  final _verification = VerificationCoreService.I;

  static User? _cachedUser;
  static PackageInfo? _cachedInfo;
  static ProfileModel? _cachedProfile;

  bool _loading = true;
  bool _loggingOut = false;
  TrustStatus _trustStatus = TrustStatus.unknown;

  late final AnimationController _entryCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(-0.04, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
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
      _fetchVerificationStatus(),
    ]);
  }

  Future<void> _fetchRealUser() async {
    try {
      if (!await _auth.isAuthenticated) return;
      final realUser = await _auth.currentUser;
      final same = _cachedUser != null && _isSameUser(_cachedUser!, realUser);
      _cachedUser = realUser;
      if (mounted) setState(() {});
      if (!same)
        await Future.wait([_fetchProfileData(), _fetchVerificationStatus()]);
    } catch (_) {}
  }

  bool _isSameUser(User a, User b) =>
      a.id == b.id &&
      a.name == b.name &&
      a.email == b.email &&
      a.avatarUrl == b.avatarUrl;

  Future<void> _fetchAppInfo() async {
    if (_cachedInfo != null) return;
    _cachedInfo = await PackageInfo.fromPlatform();
    if (mounted) setState(() {});
  }

  Future<void> _fetchVerificationStatus() async {
    try {
      if (!await _auth.isAuthenticated) {
        if (mounted) setState(() => _trustStatus = TrustStatus.unknown);
        return;
      }
      final data = await _verification.getMe();
      if (mounted) setState(() => _trustStatus = data.status);
    } catch (_) {
      if (mounted) setState(() => _trustStatus = TrustStatus.basic);
    }
  }

  Future<void> _fetchProfileData() async {
    try {
      if (!await _auth.isAuthenticated) {
        if (mounted) setState(() => _cachedProfile = null);
        return;
      }
      final p = await _profile.getMe();
      if (mounted) setState(() => _cachedProfile = p);
    } catch (_) {
      if (mounted) setState(() => _cachedProfile = null);
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
    _cachedProfile = null;
    _trustStatus = TrustStatus.unknown;
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

  // Fixed: redirects unauthenticated users to login
  void _handleVerificationTap() {
    if (_cachedUser == null) {
      _redirectToLogin();
      return;
    }
    _push(const VerificationFlowScreen());
  }

  void _push(Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final mq = MediaQuery.of(context);
    final user = _cachedUser;

    return Drawer(
      backgroundColor: c.background,
      elevation: 0,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Column(
            children: [
              if (_loading)
                _ProfileShimmer(topPadding: mq.padding.top, colors: c)
              else if (user != null)
                _ProfileHeader(
                  user: user,
                  profile: _cachedProfile,
                  colors: c,
                  trustStatus: _trustStatus,
                )
              else
                _LoginPrompt(
                  colors: c,
                  topPadding: mq.padding.top,
                  onTap: _redirectToLogin,
                ),

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
                      onTap: user == null ? _redirectToLogin : () {},
                      requiresAuth: user == null,
                    ),
                    _NavTile(
                      icon: LucideIcons.upload,
                      label: 'Sell XLM',
                      description: 'Convert lumens to cash',
                      colors: c,
                      onTap: user == null ? _redirectToLogin : () {},
                      requiresAuth: user == null,
                    ),
                    _NavTile(
                      icon: LucideIcons.checkCircle2,
                      label: 'Verification',
                      description: 'Complete identity steps',
                      colors: c,
                      trailing: user != null
                          ? _TrustStatusDot(status: _trustStatus, colors: c)
                          : null,
                      onTap: _handleVerificationTap,
                      requiresAuth: user == null,
                    ),
                    const SizedBox(height: 4),
                    const _SectionLabel(label: 'SETTINGS'),
                    _NavTile(
                      icon: LucideIcons.wallet,
                      label: 'Manage Wallet',
                      description: 'Keys & backup',
                      colors: c,
                      onTap: () => _push(const WalletScreenSettings()),
                    ),
                    _NavTile(
                      icon: LucideIcons.settings,
                      label: 'Preferences',
                      description: 'App settings',
                      colors: c,
                      onTap: () => _push(const SettingsScreen()),
                    ),
                    if (_cachedInfo != null) ...[
                      const SizedBox(height: 20),
                      _AppVersionInfo(info: _cachedInfo!, colors: c),
                    ],
                  ],
                ),
              ),

              if (user != null) ...[
                Divider(
                  color: c.border.withOpacity(0.18),
                  height: 1,
                  indent: 20,
                  endIndent: 20,
                ),
                _LogoutButton(
                  isLoading: _loggingOut,
                  colors: c,
                  onTap: _handleLogout,
                ),
              ],

              SizedBox(height: mq.padding.bottom + 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.user,
    required this.profile,
    required this.colors,
    required this.trustStatus,
  });
  final User user;
  final ProfileModel? profile;
  final AppColor colors;
  final TrustStatus trustStatus;

  String? get _identityLine {
    final p = profile;
    if (p == null) return null;
    final fullName = [
      p.firstName,
      p.middleName,
      p.lastName,
    ].where((e) => e != null && e.trim().isNotEmpty).join(' ').trim();
    if (fullName.isNotEmpty) return fullName;
    final display = p.displayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final username = p.username?.trim();
    if (username != null && username.isNotEmpty) return '@$username';
    return null;
  }

  String? get _locationLine {
    final p = profile;
    if (p == null) return null;
    final country = p.country?.trim();
    if (country != null && country.isNotEmpty) return country;
    final address = p.address?.trim();
    if (address != null && address.isNotEmpty) return address;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, top + 24, 20, 20),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(color: colors.border.withOpacity(0.18)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Avatar (top, left-anchored) ───────────────────────────
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.primary.withOpacity(0.2),
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: UserAvatar(user: user, radius: 30, colors: colors),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colors.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.surface, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: colors.success.withOpacity(0.4),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Name + verification badge ─────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  user.name,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: -0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _VerificationBadge(status: trustStatus, colors: colors),
            ],
          ),

          const SizedBox(height: 3),

          // ── Email ─────────────────────────────────────────────────
          Text(
            user.email,
            style: TextStyle(color: colors.textSecondary, fontSize: 12.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          // ── Identity sub-line ─────────────────────────────────────
          if (_identityLine != null) ...[
            const SizedBox(height: 6),
            _InfoRow(
              icon: Icons.person_outline_rounded,
              text: _identityLine!,
              colors: colors,
            ),
          ],

          // ── Location sub-line ─────────────────────────────────────
          if (_locationLine != null) ...[
            const SizedBox(height: 3),
            _InfoRow(
              icon: Icons.location_on_outlined,
              text: _locationLine!,
              colors: colors,
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
    required this.colors,
  });
  final IconData icon;
  final String text;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 11, color: colors.textSecondary.withOpacity(0.5)),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: colors.textSecondary.withOpacity(0.75),
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VERIFICATION BADGE
// ─────────────────────────────────────────────────────────────────────────────

class _VerificationBadge extends StatelessWidget {
  const _VerificationBadge({required this.status, required this.colors});
  final TrustStatus status;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      TrustStatus.ready => ('Verified', colors.success),
      TrustStatus.reviewing => ('Review', colors.warning),
      TrustStatus.suspended => ('Suspended', colors.error),
      TrustStatus.basic => ('Basic', colors.textSecondary),
      TrustStatus.unknown => ('Unverified', colors.textSecondary),
    };
    final isReady = status == TrustStatus.ready;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isReady) ...[
            Icon(Icons.verified_rounded, color: color, size: 10),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOGIN PROMPT
// ─────────────────────────────────────────────────────────────────────────────

class _LoginPrompt extends StatelessWidget {
  const _LoginPrompt({
    required this.colors,
    required this.topPadding,
    required this.onTap,
  });
  final AppColor colors;
  final double topPadding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topPadding + 24, 20, 22),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(color: colors.border.withOpacity(0.18)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: colors.border.withOpacity(0.07),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.border.withOpacity(0.18),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  LucideIcons.userCircle2,
                  color: colors.textSecondary.withOpacity(0.6),
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Guest Mode',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Sign in to unlock all features',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: AppElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.login_rounded, size: 16),
                  SizedBox(width: 7),
                  Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION LABEL
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: c.textSecondary.withOpacity(0.6),
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NAV TILE  — now with requiresAuth lock badge
// ─────────────────────────────────────────────────────────────────────────────

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.description,
    required this.colors,
    required this.onTap,
    this.trailing,
    this.requiresAuth = false,
  });
  final IconData icon;
  final String label;
  final String description;
  final AppColor colors;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool requiresAuth;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: colors.primary.withOpacity(0.06),
        highlightColor: colors.primary.withOpacity(0.03),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.border.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  color: colors.textPrimary.withOpacity(0.72),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 1),
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
              const SizedBox(width: 6),
              if (trailing != null)
                trailing!
              else if (requiresAuth)
                // Lock chip — subtle hint that sign-in is needed
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colors.border.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: colors.border.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 10,
                        color: colors.textSecondary.withOpacity(0.6),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Sign in',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Icon(
                  LucideIcons.chevronRight,
                  color: colors.textSecondary.withOpacity(0.3),
                  size: 16,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TRUST STATUS DOT
// ─────────────────────────────────────────────────────────────────────────────

class _TrustStatusDot extends StatelessWidget {
  const _TrustStatusDot({required this.status, required this.colors});
  final TrustStatus status;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      TrustStatus.ready => colors.success,
      TrustStatus.reviewing => colors.warning,
      TrustStatus.suspended => colors.error,
      _ => colors.textSecondary.withOpacity(0.35),
    };
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: status == TrustStatus.ready
            ? [
                BoxShadow(
                  color: colors.success.withOpacity(0.45),
                  blurRadius: 6,
                ),
              ]
            : null,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APP VERSION INFO
// ─────────────────────────────────────────────────────────────────────────────

class _AppVersionInfo extends StatelessWidget {
  const _AppVersionInfo({required this.info, required this.colors});
  final PackageInfo info;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          Icon(
            LucideIcons.info,
            size: 13,
            color: colors.textSecondary.withOpacity(0.45),
          ),
          const SizedBox(width: 6),
          Text(
            '${info.appName} v${info.version}',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: colors.textSecondary.withOpacity(0.55),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOGOUT BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({
    required this.isLoading,
    required this.colors,
    required this.onTap,
  });
  final bool isLoading;
  final AppColor colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        splashColor: colors.error.withOpacity(0.06),
        highlightColor: colors.error.withOpacity(0.03),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: isLoading
                    ? SizedBox(
                        key: const ValueKey('loader'),
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(colors.error),
                        ),
                      )
                    : Icon(
                        key: const ValueKey('icon'),
                        LucideIcons.logOut,
                        color: colors.error,
                        size: 18,
                      ),
              ),
              const SizedBox(width: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Text(
                  isLoading ? 'Signing out…' : 'Sign Out',
                  key: ValueKey(isLoading),
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: colors.error,
                    letterSpacing: -0.2,
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

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE SHIMMER
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileShimmer extends StatefulWidget {
  const _ProfileShimmer({required this.topPadding, required this.colors});
  final double topPadding;
  final AppColor colors;

  @override
  State<_ProfileShimmer> createState() => _ProfileShimmerState();
}

class _ProfileShimmerState extends State<_ProfileShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final s = c.border.withOpacity(0.07 + _anim.value * 0.07);
        return Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(20, widget.topPadding + 24, 20, 22),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(
              bottom: BorderSide(color: c.border.withOpacity(0.18)),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(color: s, shape: BoxShape.circle),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 130,
                      height: 15,
                      decoration: BoxDecoration(
                        color: s,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Container(
                      width: 175,
                      height: 11,
                      decoration: BoxDecoration(
                        color: s.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Container(
                      width: 110,
                      height: 10,
                      decoration: BoxDecoration(
                        color: s.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOGOUT CONFIRMATION MODAL
// ─────────────────────────────────────────────────────────────────────────────

class _LogoutConfirmationModal extends StatelessWidget {
  const _LogoutConfirmationModal();

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: c.border.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: c.error.withOpacity(0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: c.error.withOpacity(0.15),
                    width: 1.5,
                  ),
                ),
                child: Icon(LucideIcons.logOut, color: c.error, size: 26),
              ),

              const SizedBox(height: 16),

              Text(
                'Sign Out?',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "You'll need to sign in again\nto access your account.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: c.textSecondary,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: AppElevatedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.error,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Sign Out',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: AppTextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context, false);
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: c.border.withOpacity(0.08),
                    foregroundColor: c.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
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
