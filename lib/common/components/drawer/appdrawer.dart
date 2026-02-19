// lib/features/app_drawer/view/app_drawer.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:next_fi/common/components/button/app_buttons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/profile_avatar/user_avatar.dart';
import 'package:next_fi/features/auth/view/login.dart';
import 'package:next_fi/features/merchant_offers/view/merchant_offers_screen.dart';
import 'package:next_fi/features/merchant_request/view/merchant_request_screen.dart';
import 'package:next_fi/features/merchant_trades/view/merchant_trades_screen.dart';
import 'package:next_fi/features/trades/view/trade_template_screen.dart';
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
  StreamSubscription<void>? _profileChangesSub;

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

    _profileChangesSub = ProfileCoreService.changes.listen((_) {
      if (!mounted) return;
      _fetchProfileData();
    });
    _bootstrap();
  }

  @override
  void dispose() {
    _profileChangesSub?.cancel();
    _profileChangesSub = null;
    _entryCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = false);
    _entryCtrl.forward();
    await Future.wait([
      _fetchRealUser(),
      _fetchProfileData(),
      _fetchAppInfo(),
      _fetchVerificationStatus(),
    ]);
  }

  Future<void> _fetchRealUser() async {
    try {
      if (!await _auth.isAuthenticated) return;
      _cachedUser = await _auth.currentUser;
      if (mounted) setState(() {});
    } catch (_) {}
  }

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

  void _handleVerificationTap() {
    if (_cachedUser == null) {
      _redirectToLogin();
      return;
    }
    _push(const VerificationFlowScreen());
  }

  void _handleMerchantRequestTap() {
    if (_cachedUser == null) {
      _redirectToLogin();
      return;
    }
    _push(const MerchantRequestScreen());
  }

  void _handleMerchantOffersTap() {
    if (_cachedUser == null) {
      _redirectToLogin();
      return;
    }
    if (!_isVerifiedForTradeAccess) {
      _push(const VerificationFlowScreen());
      return;
    }
    if (_cachedProfile?.isMerchant != true) {
      _push(const MerchantRequestScreen());
      return;
    }
    _push(const MerchantOffersScreen());
  }

  void _handleMerchantTradesTap() {
    if (_cachedUser == null) {
      _redirectToLogin();
      return;
    }
    if (!_isVerifiedForTradeAccess) {
      _push(const VerificationFlowScreen());
      return;
    }
    if (_cachedProfile?.isMerchant != true) {
      _push(const MerchantRequestScreen());
      return;
    }
    _push(const MerchantTradesScreen());
  }

  bool get _isVerifiedForTradeAccess =>
      _trustStatus == TrustStatus.ready ||
      (_cachedProfile?.isVerified ?? false);

  void _openTradeTemplate(TradeTemplateMode mode) {
    if (_cachedUser == null) {
      _redirectToLogin();
      return;
    }
    if (!_isVerifiedForTradeAccess) {
      _push(const VerificationFlowScreen());
      return;
    }
    _push(TradeTemplateScreen(mode: mode));
  }

  void _handleBuyTradesTap() => _openTradeTemplate(TradeTemplateMode.buy);
  void _handleSellTradesTap() => _openTradeTemplate(TradeTemplateMode.sell);

  void _push(Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final mq = MediaQuery.of(context);
    final user = _cachedUser;
    final canRequestMerchant =
        user != null &&
        _isVerifiedForTradeAccess &&
        _cachedProfile?.isMerchant != true;
    final isMerchant = user != null && _cachedProfile?.isMerchant == true;

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
                  trustStatus: _trustStatus,
                  colors: c,
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
                      label: 'Buy Trades',
                      description: 'Open buy trades template',
                      colors: c,
                      onTap: _handleBuyTradesTap,
                      requiresAuth: user == null,
                    ),
                    _NavTile(
                      icon: LucideIcons.upload,
                      label: 'Sell Trades',
                      description: 'Open sell trades template',
                      colors: c,
                      onTap: _handleSellTradesTap,
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
                    if (canRequestMerchant)
                      _NavTile(
                        icon: LucideIcons.store,
                        label: 'Merchant Request',
                        description: 'Request merchant account access',
                        colors: c,
                        onTap: _handleMerchantRequestTap,
                      ),
                    if (isMerchant) ...[
                      const SizedBox(height: 4),
                      const _SectionLabel(label: 'MERCHANT'),
                      _NavTile(
                        icon: LucideIcons.badgeDollarSign,
                        label: 'Manage Offers',
                        description: 'Create and edit merchant offers',
                        colors: c,
                        onTap: _handleMerchantOffersTap,
                      ),
                      _NavTile(
                        icon: LucideIcons.messageSquare,
                        label: 'Merchant Trades',
                        description: 'Incoming trades and chat inbox',
                        colors: c,
                        onTap: _handleMerchantTradesTap,
                      ),
                    ],
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

// ═════════════════════════════════════════════════════════════════════════════
// PROFILE HEADER
//
// Data resolved once, zero duplication across the three visual zones:
//
//   ZONE A — Avatar (left)
//     • 56px avatar with brand ring + online dot + merchant crown
//
//   ZONE B — Identity text (right of avatar)
//     Line 1  displayName        e.g. "NextFI"           [17px w700]
//     Line 2  @username          e.g. "@nextfi_user"      [13px w500, muted]
//     Line 3  email (auth email) e.g. "me@nextfi.io"      [12px w400, dimmer]
//
//   ZONE C — Meta row (below text, inline)
//     • Verification status pill  (Verified / In Review / …)
//     • Country chip              (only country — not repeated elsewhere)
//     • Merchant tag              (only when isMerchant == true)
//
// Fallback chain (no duplication):
//   • If displayName is absent  → full name ("Juan D. Cruz") used in Line 1
//   • If full name is absent    → email used in Line 1, Line 2 hidden
//   • Line 2 (@username) hidden when username is absent
//   • Line 3 (email) hidden when it would duplicate Line 1
// ═════════════════════════════════════════════════════════════════════════════

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.user,
    required this.profile,
    required this.trustStatus,
    required this.colors,
  });

  final User user;
  final ProfileModel? profile;
  final TrustStatus trustStatus;
  final AppColor colors;

  // ── helpers ───────────────────────────────────────────────────────────────

  String? _s(String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  // "NextFI" — displayName wins
  String? get _displayName => _s(profile?.displayName);

  // "Juan D. Cruz" — assembled from parts, never shown if displayName exists
  String? get _fullName {
    final parts = [
      profile?.firstName,
      profile?.middleName,
      profile?.lastName,
    ].map(_s).whereType<String>().join(' ').trim();
    return parts.isEmpty ? null : parts;
  }

  // "@nextfi_user"
  String? get _handle {
    final u = _s(profile?.username);
    return u != null ? '@$u' : null;
  }

  // Raw email from auth
  String? get _email => user.email.trim().isEmpty ? null : user.email.trim();

  // Country code / name
  String? get _country => _s(profile?.country);

  bool get _isMerchant => profile?.isMerchant ?? false;
  bool get _isPending => profile?.merchantRequestPending ?? false;

  // ── Resolve the three text lines with zero duplication ───────────────────
  //
  // line1  : always shown — the primary identity label
  // line2  : @handle — only shown when a handle exists (never repeats line1)
  // line3  : email   — only shown when it wouldn't repeat line1

  String get _line1 => _displayName ?? _fullName ?? _email ?? 'Anonymous';

  String? get _line2 => _handle; // null if no username

  // Email is shown as line3 ONLY when line1 is not the email already
  String? get _line3 {
    final e = _email;
    if (e == null) return null;
    if (_line1 == e) return null; // would duplicate
    return e;
  }

  // ── Trust pill config ─────────────────────────────────────────────────────

  ({Color color, IconData icon, String label}) get _trust =>
      switch (trustStatus) {
        TrustStatus.ready => (
          color: colors.success,
          icon: LucideIcons.badgeCheck,
          label: 'Verified',
        ),
        TrustStatus.reviewing => (
          color: colors.warning,
          icon: LucideIcons.clock,
          label: 'In Review',
        ),
        TrustStatus.suspended => (
          color: colors.error,
          icon: LucideIcons.shieldOff,
          label: 'Suspended',
        ),
        TrustStatus.basic => (
          color: colors.textSecondary,
          icon: LucideIcons.shield,
          label: 'Basic',
        ),
        _ => (
          color: colors.textSecondary,
          icon: LucideIcons.shield,
          label: 'Unverified',
        ),
      };

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final l1 = _line1;
    final l2 = _line2;
    final l3 = _line3;
    final tc = _trust;
    final ctry = _country;

    return Container(
      width: double.infinity,
      color: colors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Content block ────────────────────────────────────────────────
          Container(
            width: double.infinity,
            color: colors.primary.withOpacity(0.04),
            padding: EdgeInsets.fromLTRB(20, top + 24, 20, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ZONE A — Avatar
                _DrawerAvatar(
                  user: user,
                  isMerchant: _isMerchant,
                  colors: colors,
                ),

                const SizedBox(width: 14),

                // ZONE B + C — Text + meta
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Line 1 — display name / full name / email
                      Text(
                        l1,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Line 2 — @username handle
                      if (l2 != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          l2,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      // Line 3 — email (only when not already on line 1)
                      if (l3 != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          l3,
                          style: TextStyle(
                            color: colors.textSecondary.withOpacity(0.6),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            letterSpacing: -0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      const SizedBox(height: 10),

                      // ZONE C — Meta pills
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          // Verification status — always shown
                          _MetaPill(
                            icon: tc.icon,
                            label: tc.label,
                            color: tc.color,
                            colors: colors,
                          ),

                          // Country — shown once, here only
                          if (ctry != null)
                            _MetaPill(
                              icon: LucideIcons.mapPin,
                              label: ctry,
                              color: colors.textSecondary,
                              colors: colors,
                              subtle: true,
                            ),

                          // Merchant / Pending — mutually exclusive
                          if (_isMerchant)
                            _MetaPill(
                              icon: LucideIcons.store,
                              label: 'Merchant',
                              color: colors.primary,
                              colors: colors,
                            )
                          else if (_isPending)
                            _MetaPill(
                              icon: LucideIcons.hourglass,
                              label: 'Pending',
                              color: colors.warning,
                              colors: colors,
                              subtle: true,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Hard rule — clean separation from nav list
          Divider(
            height: 1,
            thickness: 1,
            color: colors.border.withOpacity(0.13),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DRAWER AVATAR
// ─────────────────────────────────────────────────────────────────────────────

class _DrawerAvatar extends StatelessWidget {
  const _DrawerAvatar({
    required this.user,
    required this.isMerchant,
    required this.colors,
  });

  final User user;
  final bool isMerchant;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Avatar + brand ring
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: colors.primary.withOpacity(0.25),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withOpacity(0.10),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: UserAvatar(user: user, radius: 26, colors: colors),
        ),

        // Online dot — bottom-right
        Positioned(
          bottom: 1,
          right: 1,
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

        // Merchant crown — top-right
        if (isMerchant)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: colors.surface, width: 1.5),
              ),
              child: const Icon(LucideIcons.star, size: 9, color: Colors.white),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// META PILL  — small status tag used in profile header ZONE C only
// ─────────────────────────────────────────────────────────────────────────────

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.colors,
    this.subtle = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final AppColor colors;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    final fg = subtle ? colors.textSecondary : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: subtle
            ? colors.border.withOpacity(0.08)
            : color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: subtle
              ? colors.border.withOpacity(0.20)
              : color.withOpacity(0.22),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: fg,
              letterSpacing: -0.1,
              height: 1.0,
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
      color: colors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            color: colors.primary.withOpacity(0.04),
            padding: EdgeInsets.fromLTRB(20, topPadding + 24, 20, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.border.withOpacity(0.07),
                    border: Border.all(
                      color: colors.border.withOpacity(0.20),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    LucideIcons.userCircle2,
                    color: colors.textSecondary.withOpacity(0.45),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Guest',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                          letterSpacing: -0.5,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Sign in to unlock all features',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 36,
                        child: AppElevatedButton(
                          onPressed: onTap,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.login_rounded, size: 14),
                              SizedBox(width: 6),
                              Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: colors.border.withOpacity(0.13),
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
          color: c.textSecondary.withOpacity(0.55),
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NAV TILE
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
// TRUST STATUS DOT  (nav tile trailing)
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
                        key: const ValueKey('l'),
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(colors.error),
                        ),
                      )
                    : Icon(
                        key: const ValueKey('i'),
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
// PROFILE SHIMMER  — mirrors real header layout exactly
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
          color: c.surface,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                color: c.primary.withOpacity(0.04),
                padding: EdgeInsets.fromLTRB(
                  20,
                  widget.topPadding + 24,
                  20,
                  20,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: s,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Line 1 — name
                          Container(
                            width: 120,
                            height: 16,
                            decoration: BoxDecoration(
                              color: s,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 7),
                          // Line 2 — handle
                          Container(
                            width: 88,
                            height: 12,
                            decoration: BoxDecoration(
                              color: s.withOpacity(0.65),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          const SizedBox(height: 5),
                          // Line 3 — email
                          Container(
                            width: 140,
                            height: 11,
                            decoration: BoxDecoration(
                              color: s.withOpacity(0.45),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Pills row
                          Row(
                            children: [
                              Container(
                                width: 68,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: s.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 40,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: s.withOpacity(0.35),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: c.border.withOpacity(0.13),
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
