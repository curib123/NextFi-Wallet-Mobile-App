// lib/features/app_drawer/view/app_drawer.dart

import 'dart:async';
import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/profile_avatar/user_avatar.dart';
import 'package:next_fi/features/auth/view/login.dart';
import 'package:next_fi/features/chat/view/chat_hub_screen.dart';
import 'package:next_fi/features/merchant_flow/view/merchant_onboarding_flow_screen.dart';
import 'package:next_fi/features/merchant_trades/view/merchant_trades_screen.dart';
import 'package:next_fi/features/offers/view/market_offers_screen.dart';
import 'package:next_fi/features/offers/view/manage_offers_screen.dart';
import 'package:next_fi/features/verification_flow/view/payment_method_setup_screen.dart';
import 'package:next_fi/features/verification_flow/view/verification_flow_screen.dart';
import 'package:next_fi/features/settings/view/settings_screen.dart';
import 'package:next_fi/features/wallet_settings/view/wallet_screen_settings.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:next_fi/services/oath2.0/auth_service.dart';
import 'package:next_fi/services/oath2.0/models/user_model.dart';
import 'package:next_fi/services/chat/chat_core_service.dart';
import 'package:next_fi/services/chat/models/chat_dtos.dart';
import 'package:next_fi/services/merchant_profile/models/merchant_profile_models.dart';
import 'package:next_fi/services/merchant_profile/merchant_profile_core_service.dart';
import 'package:next_fi/services/offers/models/offers_dtos.dart';
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
  final _chat = ChatCoreService.I;
  final _profile = ProfileCoreService.I;
  final _verification = VerificationCoreService.I;
  final _merchantProfile = MerchantProfileCoreService.I;

  static User? _cachedUser;
  static PackageInfo? _cachedInfo;
  static ProfileModel? _cachedProfile;
  static MerchantProfileModel? _cachedMerchantProfile;

  bool _loading = true;
  bool _loggingOut = false;
  TrustStatus _trustStatus = TrustStatus.unknown;
  int _unreadChatCount = 0;
  StreamSubscription<void>? _profileChangesSub;

  late final AnimationController _entryCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final List<Animation<double>> _itemAnims;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(-0.06, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    _itemAnims = List.generate(16, (i) {
      final start = 0.1 + i * 0.06;
      final end = (start + 0.35).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _entryCtrl,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      );
    });

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
      _fetchMerchantProfile(),
      _fetchAppInfo(),
      _fetchVerificationStatus(),
      _fetchUnreadChatCount(),
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

  Future<void> _fetchUnreadChatCount() async {
    try {
      if (!await _auth.isAuthenticated) {
        if (mounted) setState(() => _unreadChatCount = 0);
        return;
      }
      final threads = await _chat.listThreads(
        const ChatListQuery(page: 1, limit: 50),
      );
      final unread = threads.items.fold<int>(
        0,
            (sum, thread) => sum + thread.unreadCount,
      );
      if (mounted) setState(() => _unreadChatCount = unread);
    } catch (_) {
      if (mounted) setState(() => _unreadChatCount = 0);
    }
  }

  Future<void> _fetchMerchantProfile() async {
    try {
      if (!await _auth.isAuthenticated) {
        if (mounted) setState(() => _cachedMerchantProfile = null);
        return;
      }
      final merchant = await _merchantProfile.getMe();
      if (mounted) setState(() => _cachedMerchantProfile = merchant);
    } catch (_) {
      if (mounted) setState(() => _cachedMerchantProfile = null);
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
    _cachedMerchantProfile = null;
    _trustStatus = TrustStatus.unknown;
    if (!mounted) return;
    Navigator.pop(context);
    widget.onLogout?.call();
    Phoenix.rebirth(context);
  }

  void _redirectToLogin() {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  void _redirectToPaymentAccount(bool isMerchant) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) =>PaymentAccountSetupScreen(isMerchant:isMerchant)));
  }

  void _handleVerificationTap() {
    if (_cachedUser == null) { _redirectToLogin(); return; }
    _push(const VerificationFlowScreen());
  }

  Future<void> _handleMerchantRequestTap() async {
    if (_cachedUser == null) { _redirectToLogin(); return; }
    Navigator.pop(context);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MerchantOnboardingFlowScreen()),
    );
    if (mounted) await _fetchMerchantProfile();
  }

  void _handleMerchantOffersTap() {
    if (_cachedUser == null) { _redirectToLogin(); return; }
    if (!_isVerifiedForTradeAccess) { _push(const VerificationFlowScreen()); return; }
    _push(const ManageOffersScreen());
  }

  void _handleMerchantTradesTap() {
    if (_cachedUser == null) { _redirectToLogin(); return; }
    if (!_isVerifiedForTradeAccess) { _push(const VerificationFlowScreen()); return; }
    _push(const MerchantTradesScreen());
  }

  void _handleP2PMarketplaceTap() {
    if (_cachedUser == null) { _redirectToLogin(); return; }
    _push(const MarketOffersScreen(initialType: OfferType.sell));
  }

  bool get _isVerifiedForTradeAccess =>
      _trustStatus == TrustStatus.ready ||
          (_cachedProfile?.isVerificationIdentityComplete ?? false);

  void _handleMessengerTap() {
    if (_cachedUser == null) { _redirectToLogin(); return; }
    _push(const ChatHubScreen());
  }

  void _push(Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Widget _staggered(int index, Widget child) {
    if (index >= _itemAnims.length) return child;
    return AnimatedBuilder(
      animation: _itemAnims[index],
      builder: (_, __) => Opacity(
        opacity: _itemAnims[index].value,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - _itemAnims[index].value)),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final mq = MediaQuery.of(context);
    final user = _cachedUser;

    final merchantApproved = _cachedMerchantProfile?.isApproved ?? false;
    final isMerchant = user != null && merchantApproved;
    final canRequestMerchant = user != null && _trustStatus == TrustStatus.ready;

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
                    const SizedBox(height: 10),
                    _staggered(0, _SectionLabel(label: 'P2P MARKET', colors: c)),
                    _staggered(1, _NavTile(
                      icon: LucideIcons.store, label: 'P2P Marketplace',
                      description: 'Browse buy and sell offers', colors: c,
                      accentColor: const Color(0xFF10B981), onTap: _handleP2PMarketplaceTap,
                      requiresAuth: user == null,
                    )),
                    _staggered(2, _NavTile(
                      icon: LucideIcons.messageSquare, label: 'Messenger',
                      description: 'Friends, threads & secure chat', colors: c,
                      accentColor: const Color(0xFF6366F1),
                      trailing: user != null && _unreadChatCount > 0
                          ? _UnreadBadge(count: _unreadChatCount, colors: c)
                          : null,
                      onTap: _handleMessengerTap, requiresAuth: user == null,
                    )),

                    const SizedBox(height: 2),
                    _staggered(3, _SectionLabel(label: 'ACCOUNT', colors: c)),
                    _staggered(4, _NavTile(
                      icon: LucideIcons.checkCircle2, label: 'Verification',
                      description: 'Complete identity steps', colors: c,
                      accentColor: const Color(0xFF0EA5E9),
                      trailing: user != null
                          ? _TrustStatusChip(status: _trustStatus, colors: c)
                          : null,
                      onTap: _handleVerificationTap, requiresAuth: user == null,
                    )),

                    _staggered(5, _NavTile(
                      icon: LucideIcons.checkCircle2, label: 'Payment Account',
                      description: 'User Payment Account', colors: c,
                      accentColor: const Color(0xFF0EA5E9),
                      trailing: user != null
                          ? _TrustStatusChip(status: _trustStatus, colors: c)
                          : null,
                      onTap: () => _redirectToPaymentAccount(false),
                      requiresAuth: user == null,
                    )),

                    if (canRequestMerchant)
                      _staggered(6, _SectionLabel(label: 'MERCHANT', colors: c)),

                    if (canRequestMerchant)
                      _staggered(7, _NavTile(
                        icon: LucideIcons.store, label: 'Merchant Request',
                        description: 'Request merchant account access', colors: c,
                        accentColor: const Color(0xFFF97316),
                        trailing: merchantApproved
                            ? _TrustStatusChip(status: TrustStatus.ready, colors: c)
                            : null,
                        onTap: _handleMerchantRequestTap,
                      )),

                    if (isMerchant) ...[
                      if (!canRequestMerchant) ...[
                        const SizedBox(height: 2),
                        _staggered(8, _SectionLabel(label: 'MERCHANT', colors: c)),
                      ],
                      _staggered(9, _NavTile(
                        icon: LucideIcons.badgeDollarSign,
                        label: 'Merchant Payment',
                        description: 'Merchant Payment Account',
                        colors: c,
                        accentColor: const Color(0xFFF97316),
                        trailing: _TrustStatusChip(status: TrustStatus.ready, colors: c),
                        onTap: () => _redirectToPaymentAccount(isMerchant),
                      )),
                      _staggered(10, _NavTile(
                        icon: LucideIcons.badgeDollarSign, label: 'Manage Offers',
                        description: 'Create and edit merchant offers', colors: c,
                        accentColor: const Color(0xFFF97316), onTap: _handleMerchantOffersTap,
                      )),
                      _staggered(11, _NavTile(
                        icon: LucideIcons.messageSquare, label: 'Merchant Trades',
                        description: 'Incoming trades and chat inbox', colors: c,
                        accentColor: const Color(0xFF8B5CF6), onTap: _handleMerchantTradesTap,
                      )),
                    ],

                    const SizedBox(height: 4),
                    _staggered(12, _SectionLabel(label: 'SETTINGS', colors: c)),
                    _staggered(13, _NavTile(
                      icon: LucideIcons.wallet, label: 'Manage Wallet',
                      description: 'Keys & backup', colors: c,
                      accentColor: const Color(0xFF14B8A6),
                      onTap: () => _push(const WalletScreenSettings()),
                    )),
                    _staggered(14, _NavTile(
                      icon: LucideIcons.settings, label: 'Preferences',
                      description: 'App settings', colors: c,
                      onTap: () => _push(const SettingsScreen()),
                    )),

                    if (_cachedInfo != null) ...[
                      const SizedBox(height: 24),
                      _AppVersionInfo(info: _cachedInfo!, colors: c),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),

              if (user != null) ...[
                _DrawerDivider(colors: c),
                _LogoutButton(isLoading: _loggingOut, colors: c, onTap: _handleLogout),
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
// PROFILE HEADER — solid surface, no glass
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

  String? _s(String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  String? get _displayName => _s(profile?.displayName);
  String? get _handle {
    final u = _s(profile?.username);
    return u != null ? '@$u' : null;
  }
  String? get _email => user.email.trim().isEmpty ? null : user.email.trim();
  String? get _country => _s(profile?.country);
  String get _line1 => _displayName ?? _email ?? 'Anonymous';
  String? get _line2 => _handle;
  String? get _line3 {
    final e = _email;
    if (e == null) return null;
    if (_line1 == e) return null;
    return e;
  }

  ({Color bg, Color glow, IconData icon, String label}) get _trust =>
      switch (trustStatus) {
        TrustStatus.ready => (
        bg: const Color(0xFF10B981), glow: const Color(0xFF10B981),
        icon: LucideIcons.badgeCheck, label: 'Verified',
        ),
        TrustStatus.reviewing => (
        bg: const Color(0xFFF59E0B), glow: const Color(0xFFF59E0B),
        icon: LucideIcons.clock, label: 'In Review',
        ),
        TrustStatus.suspended => (
        bg: const Color(0xFFEF4444), glow: const Color(0xFFEF4444),
        icon: LucideIcons.shieldOff, label: 'Suspended',
        ),
        TrustStatus.basic => (
        bg: colors.border, glow: Colors.transparent,
        icon: LucideIcons.shield, label: 'Basic',
        ),
        _ => (
        bg: colors.border, glow: Colors.transparent,
        icon: LucideIcons.shield, label: 'Unverified',
        ),
      };

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final tc = _trust;
    final ctry = _country;

    return Container(
      width: double.infinity,
      color: colors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thin primary accent bar at top
          Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colors.primary,
                  colors.primary.withOpacity(0.4),
                  colors.primary.withOpacity(0.0),
                ],
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(20, top + 22, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DrawerAvatar(user: user, colors: colors),
                    const Spacer(),
                    _TrustPill(icon: tc.icon, label: tc.label, bg: tc.bg, glow: tc.glow),
                  ],
                ),

                const SizedBox(height: 14),

                Text(
                  _line1,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                if (_line2 != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    _line2!,
                    style: TextStyle(
                      color: colors.primary.withOpacity(0.8),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                if (_line3 != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _line3!,
                    style: TextStyle(
                      color: colors.textSecondary.withOpacity(0.55),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                if (ctry != null) ...[
                  const SizedBox(height: 10),
                  _CountryChip(country: ctry, colors: colors),
                ],
              ],
            ),
          ),

          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colors.border.withOpacity(0.0),
                  colors.border.withOpacity(0.25),
                  colors.primary.withOpacity(0.35),
                  colors.border.withOpacity(0.25),
                  colors.border.withOpacity(0.0),
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
// TRUST PILL
// ─────────────────────────────────────────────────────────────────────────────

class _TrustPill extends StatelessWidget {
  const _TrustPill({
    required this.icon,
    required this.label,
    required this.bg,
    required this.glow,
  });

  final IconData icon;
  final String label;
  final Color bg;
  final Color glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: bg.withOpacity(0.30), width: 1),
        boxShadow: glow != Colors.transparent
            ? [BoxShadow(color: glow.withOpacity(0.18), blurRadius: 10)]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: bg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: bg, letterSpacing: 0.1),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COUNTRY CHIP
// ─────────────────────────────────────────────────────────────────────────────

class _CountryChip extends StatelessWidget {
  const _CountryChip({required this.country, required this.colors});
  final String country;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: colors.border.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.mapPin, size: 10, color: colors.textSecondary.withOpacity(0.6)),
          const SizedBox(width: 4),
          Text(
            country,
            style: TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w500,
              color: colors.textSecondary.withOpacity(0.7), letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DRAWER AVATAR
// ─────────────────────────────────────────────────────────────────────────────

class _DrawerAvatar extends StatefulWidget {
  const _DrawerAvatar({required this.user, required this.colors});
  final User user;
  final AppColor colors;

  @override
  State<_DrawerAvatar> createState() => _DrawerAvatarState();
}

class _DrawerAvatarState extends State<_DrawerAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulse, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, child) => Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: c.primary.withOpacity(0.08 + _pulseAnim.value * 0.12),
                  blurRadius: 16 + _pulseAnim.value * 8,
                ),
              ],
            ),
            child: child,
          ),
          child: Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [c.primary.withOpacity(0.6), c.primary.withOpacity(0.2)],
              ),
            ),
            padding: const EdgeInsets.all(2.5),
            child: ClipOval(child: UserAvatar(user: widget.user, radius: 27, colors: c)),
          ),
        ),

        Positioned(
          bottom: 2, right: 2,
          child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 18, height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.success.withOpacity(0.2 * _pulseAnim.value),
                  ),
                ),
                Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    color: c.success, shape: BoxShape.circle,
                    border: Border.all(color: c.surface, width: 2),
                    boxShadow: [BoxShadow(color: c.success.withOpacity(0.5), blurRadius: 6)],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOGIN PROMPT — solid surface, no glass
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
          // Accent bar
          Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colors.primary,
                  colors.primary.withOpacity(0.4),
                  colors.primary.withOpacity(0.0),
                ],
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(20, topPadding + 22, 20, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.border.withOpacity(0.06),
                    border: Border.all(color: colors.border.withOpacity(0.18), width: 1.5),
                  ),
                  child: Icon(
                    LucideIcons.userCircle2,
                    color: colors.textSecondary.withOpacity(0.35),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome',
                        style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800,
                          color: colors.textPrimary, letterSpacing: -0.8, height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Sign in to unlock all features',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.textSecondary),
                      ),
                      const SizedBox(height: 14),
                      _GradientButton(label: 'Sign In', icon: Icons.login_rounded, primaryColor: colors.primary, onTap: onTap),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colors.border.withOpacity(0.0),
                  colors.border.withOpacity(0.25),
                  colors.primary.withOpacity(0.35),
                  colors.border.withOpacity(0.25),
                  colors.border.withOpacity(0.0),
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
// GRADIENT BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label, required this.icon,
    required this.primaryColor, required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color primaryColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [primaryColor, Color.lerp(primaryColor, Colors.purple, 0.3)!],
          ),
          borderRadius: BorderRadius.circular(11),
          boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 7),
            Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.1)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION LABEL
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.colors});
  final String label;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Row(
        children: [
          Container(
            width: 3, height: 10,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [colors.primary, colors.primary.withOpacity(0.3)],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w800,
              color: colors.textSecondary.withOpacity(0.5), letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NAV TILE
// ─────────────────────────────────────────────────────────────────────────────

class _NavTile extends StatefulWidget {
  const _NavTile({
    required this.icon, required this.label, required this.description,
    required this.colors, required this.onTap,
    this.accentColor, this.trailing, this.requiresAuth = false,
  });

  final IconData icon;
  final String label;
  final String description;
  final AppColor colors;
  final VoidCallback onTap;
  final Color? accentColor;
  final Widget? trailing;
  final bool requiresAuth;

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _scaleAnim;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _pressCtrl.dispose(); super.dispose(); }

  void _onTapDown(_) { setState(() => _isPressed = true); _pressCtrl.forward(); }
  void _onTapUp(_) { setState(() => _isPressed = false); _pressCtrl.reverse(); }
  void _onTapCancel() { setState(() => _isPressed = false); _pressCtrl.reverse(); }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final accent = widget.accentColor ?? c.primary;

    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); widget.onTap(); },
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: _isPressed ? accent.withOpacity(0.05) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isPressed ? accent.withOpacity(0.12) : Colors.transparent, width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [accent.withOpacity(0.18), accent.withOpacity(0.08)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withOpacity(0.18), width: 1),
                ),
                child: Icon(widget.icon, color: accent, size: 18),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w600,
                        color: c.textPrimary, letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      widget.description,
                      style: TextStyle(fontSize: 11.5, color: c.textSecondary.withOpacity(0.7), height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (widget.trailing != null)
                widget.trailing!
              else if (widget.requiresAuth)
                _AuthBadge(colors: c)
              else
                Icon(LucideIcons.chevronRight, color: c.textSecondary.withOpacity(0.22), size: 15),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AUTH BADGE
// ─────────────────────────────────────────────────────────────────────────────

class _AuthBadge extends StatelessWidget {
  const _AuthBadge({required this.colors});
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.border.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline_rounded, size: 10, color: colors.textSecondary.withOpacity(0.5)),
          const SizedBox(width: 4),
          Text('Sign in', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: colors.textSecondary.withOpacity(0.5))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TRUST STATUS CHIP
// ─────────────────────────────────────────────────────────────────────────────

class _TrustStatusChip extends StatelessWidget {
  const _TrustStatusChip({required this.status, required this.colors});
  final TrustStatus status;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      TrustStatus.ready => (const Color(0xFF10B981), 'Verified'),
      TrustStatus.reviewing => (const Color(0xFFF59E0B), 'Pending'),
      TrustStatus.suspended => (const Color(0xFFEF4444), 'Suspended'),
      _ => (colors.textSecondary.withOpacity(0.4), 'Basic'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              color: color, shape: BoxShape.circle,
              boxShadow: status == TrustStatus.ready
                  ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 5)]
                  : null,
            ),
          ),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.1)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UNREAD BADGE
// ─────────────────────────────────────────────────────────────────────────────

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count, required this.colors});
  final int count;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, Color.lerp(colors.primary, Colors.purple, 0.3)!],
        ),
        borderRadius: BorderRadius.circular(99),
        boxShadow: [BoxShadow(color: colors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DRAWER DIVIDER
// ─────────────────────────────────────────────────────────────────────────────

class _DrawerDivider extends StatelessWidget {
  const _DrawerDivider({required this.colors});
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.border.withOpacity(0.0), colors.border.withOpacity(0.3), colors.border.withOpacity(0.0)],
        ),
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
      padding: const EdgeInsets.fromLTRB(22, 0, 20, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: colors.border.withOpacity(0.06),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: colors.border.withOpacity(0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.package, size: 10, color: colors.textSecondary.withOpacity(0.4)),
            const SizedBox(width: 5),
            Text(
              '${info.appName}  v${info.version}',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: colors.textSecondary.withOpacity(0.45), letterSpacing: 0.1),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOGOUT BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _LogoutButton extends StatefulWidget {
  const _LogoutButton({required this.isLoading, required this.colors, required this.onTap});
  final bool isLoading;
  final AppColor colors;
  final VoidCallback onTap;

  @override
  State<_LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<_LogoutButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return GestureDetector(
      onTap: widget.isLoading ? null : widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: _pressed ? c.error.withOpacity(0.07) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _pressed ? c.error.withOpacity(0.15) : Colors.transparent),
        ),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: widget.isLoading
                  ? SizedBox(key: const ValueKey('l'), width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(c.error)))
                  : Icon(key: const ValueKey('i'), LucideIcons.logOut, color: c.error, size: 18),
            ),
            const SizedBox(width: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: Text(
                widget.isLoading ? 'Signing out…' : 'Sign Out',
                key: ValueKey(widget.isLoading),
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: c.error, letterSpacing: -0.2),
              ),
            ),
            const Spacer(),
            if (!widget.isLoading)
              Icon(LucideIcons.chevronRight, color: c.error.withOpacity(0.3), size: 14),
          ],
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
  late final Animation<double> _sweep;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
    _sweep = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return AnimatedBuilder(
      animation: _sweep,
      builder: (_, __) {
        Widget shimBox(double w, double h, {double r = 6}) => Container(
          width: w, height: h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(r),
            gradient: LinearGradient(
              begin: Alignment(-1 + _sweep.value * 2.5, 0),
              end: Alignment(-0.5 + _sweep.value * 2.5, 0),
              colors: [c.border.withOpacity(0.08), c.border.withOpacity(0.17), c.border.withOpacity(0.08)],
            ),
          ),
        );

        return Container(
          color: c.surface,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [c.primary.withOpacity(0.4), c.primary.withOpacity(0.1), Colors.transparent],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, widget.topPadding + 22, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [shimBox(60, 60, r: 30), const Spacer(), shimBox(72, 26, r: 13)]),
                    const SizedBox(height: 14),
                    shimBox(130, 20, r: 8),
                    const SizedBox(height: 8),
                    shimBox(90, 14, r: 6),
                    const SizedBox(height: 6),
                    shimBox(160, 12, r: 5),
                    const SizedBox(height: 12),
                    shimBox(70, 24, r: 8),
                  ],
                ),
              ),
              Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [c.border.withOpacity(0.0), c.border.withOpacity(0.2), c.border.withOpacity(0.0)],
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 40, offset: const Offset(0, -10))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 28),
                decoration: BoxDecoration(color: c.border.withOpacity(0.25), borderRadius: BorderRadius.circular(2)),
              ),
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.error.withOpacity(0.08),
                  border: Border.all(color: c.error.withOpacity(0.18), width: 1.5),
                ),
                child: Icon(LucideIcons.logOut, color: c.error, size: 28),
              ),
              const SizedBox(height: 18),
              Text('Sign Out?',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.textPrimary, letterSpacing: -0.6)),
              const SizedBox(height: 8),
              Text(
                "You'll need to sign in again\nto access your account.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: c.textSecondary, height: 1.55),
              ),
              const SizedBox(height: 28),
              GestureDetector(
                onTap: () { HapticFeedback.lightImpact(); Navigator.pop(context, true); },
                child: Container(
                  width: double.infinity, height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [c.error, Color.lerp(c.error, Colors.red.shade900, 0.4)!]),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [BoxShadow(color: c.error.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
                  ),
                  alignment: Alignment.center,
                  child: const Text('Yes, Sign Out',
                      style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.2)),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () { HapticFeedback.lightImpact(); Navigator.pop(context, false); },
                child: Container(
                  width: double.infinity, height: 52,
                  decoration: BoxDecoration(
                    color: c.border.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: c.border.withOpacity(0.12)),
                  ),
                  alignment: Alignment.center,
                  child: Text('Cancel',
                      style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: c.textPrimary, letterSpacing: -0.2)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}