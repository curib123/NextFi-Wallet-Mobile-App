import 'dart:async';

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
import 'package:next_fi/features/trades/view/trade_history_screen.dart';
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
import 'package:next_fi/services/merchant_profile/models/merchant_tier_progress_models.dart';
import 'package:next_fi/services/merchant_profile/merchant_profile_core_service.dart';
import 'package:next_fi/services/offers/models/offers_dtos.dart';
import 'package:next_fi/services/profile/models/profile_models.dart';
import 'package:next_fi/services/profile/profile_core_service.dart';
import 'package:next_fi/services/verification/models/verification_models.dart';
import 'package:next_fi/services/verification/verification_core_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TTL CACHE ENTRY
// ─────────────────────────────────────────────────────────────────────────────

class _CacheEntry<T> {
  _CacheEntry(this.value) : _at = DateTime.now();
  final T value;
  final DateTime _at;
  bool isFresh(Duration ttl) => DateTime.now().difference(_at) < ttl;
}

// ─────────────────────────────────────────────────────────────────────────────
// DRAWER CACHE
// ─────────────────────────────────────────────────────────────────────────────

class _DrawerCache {
  static const _userTtl = Duration(seconds: 30);
  static const _profileTtl = Duration(seconds: 5);
  static const _merchantTtl = Duration(seconds: 5);
  static const _verificationTtl = Duration(seconds: 5);
  static const _chatTtl = Duration(seconds: 1);
  static const _appInfoTtl = Duration(days: 1);

  static _CacheEntry<User>? user;
  static _CacheEntry<PackageInfo>? appInfo;
  static _CacheEntry<ProfileModel?>? profile;
  static _CacheEntry<MerchantProfileModel?>? merchantProfile;
  static _CacheEntry<MerchantTierProgressModel?>? tierProgress;
  static _CacheEntry<TrustStatus>? trustStatus;
  static _CacheEntry<int>? unreadCount;

  static bool get hasUser => user != null && user!.isFresh(_userTtl);
  static bool get hasAppInfo => appInfo != null && appInfo!.isFresh(_appInfoTtl);
  static bool get hasProfile => profile != null && profile!.isFresh(_profileTtl);
  static bool get hasMerchantProfile => merchantProfile != null && merchantProfile!.isFresh(_merchantTtl);
  static bool get hasTierProgress => tierProgress != null && tierProgress!.isFresh(_merchantTtl);
  static bool get hasTrustStatus => trustStatus != null && trustStatus!.isFresh(_verificationTtl);
  static bool get hasUnreadCount => unreadCount != null && unreadCount!.isFresh(_chatTtl);

  static void invalidateAll() {
    user = merchantProfile = profile = null;
    tierProgress = null;
    trustStatus = unreadCount = null;
  }

  static void invalidateProfile() {
    profile = null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class AppDrawer extends StatefulWidget {
  final VoidCallback? onLogout;
  const AppDrawer({super.key, this.onLogout});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> with SingleTickerProviderStateMixin {
  final _auth = AuthService();
  final _chat = ChatCoreService.I;
  final _profile = ProfileCoreService.I;
  final _verification = VerificationCoreService.I;
  final _merchantProfileSvc = MerchantProfileCoreService.I;

  bool _loggingOut = false;
  StreamSubscription<void>? _profileChangeSub;

  late final AnimationController _entryCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final List<Animation<double>> _itemAnims;

  User? get _user => _DrawerCache.user?.value;
  PackageInfo? get _appInfo => _DrawerCache.appInfo?.value;
  ProfileModel? get _cachedProfile => _DrawerCache.profile?.value;
  MerchantProfileModel? get _merchantProfile => _DrawerCache.merchantProfile?.value;
  MerchantTierProgressModel? get _tierProgress => _DrawerCache.tierProgress?.value;
  TrustStatus get _trustStatus => _DrawerCache.trustStatus?.value ?? TrustStatus.unknown;
  int get _unreadChatCount => _DrawerCache.unreadCount?.value ?? 0;

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

    _profileChangeSub = ProfileCoreService.changes.listen((_) {
      if (!mounted) return;
      _DrawerCache.invalidateProfile();
      _fetchProfile();
    });

    _bootstrap();
  }

  @override
  void dispose() {
    _profileChangeSub?.cancel();
    _entryCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    _entryCtrl.forward();
    final isAuth = await _auth.isAuthenticated;

    final futures = <Future<void>>[
      if (!_DrawerCache.hasAppInfo) _fetchAppInfo(),
      if (isAuth && !_DrawerCache.hasUser) _fetchUser(),
      if (isAuth && !_DrawerCache.hasProfile) _fetchProfile(),
      if (isAuth && !_DrawerCache.hasMerchantProfile) _fetchMerchantProfileData(),
      if (isAuth && !_DrawerCache.hasTierProgress) _fetchTierProgressData(),
      if (isAuth && !_DrawerCache.hasTrustStatus) _fetchVerification(),
      if (isAuth && !_DrawerCache.hasUnreadCount) _fetchUnreadCount(),
    ];

    if (futures.isNotEmpty) await Future.wait(futures);
    if (mounted) setState(() {});
  }

  Future<void> _fetchUser() async {
    try {
      final u = await _auth.currentUser;
      _DrawerCache.user = _CacheEntry(u);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _fetchAppInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _DrawerCache.appInfo = _CacheEntry(info);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _fetchProfile() async {
    try {
      final p = await _profile.getMe();
      _DrawerCache.profile = _CacheEntry(p);
      if (mounted) setState(() {});
    } catch (_) {
      _DrawerCache.profile = _CacheEntry(null);
    }
  }

  Future<void> _fetchVerification() async {
    try {
      final data = await _verification.getMe();
      _DrawerCache.trustStatus = _CacheEntry(data.status);
      if (mounted) setState(() {});
    } catch (_) {
      _DrawerCache.trustStatus = _CacheEntry(TrustStatus.basic);
    }
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final threads = await _chat.listThreads(const ChatListQuery(page: 1, limit: 50));
      final count = threads.items.fold<int>(0, (sum, t) => sum + t.unreadCount);
      _DrawerCache.unreadCount = _CacheEntry(count);
      if (mounted) setState(() {});
    } catch (_) {
      _DrawerCache.unreadCount = _CacheEntry(0);
    }
  }

  Future<void> _fetchMerchantProfileData() async {
    try {
      final m = await _merchantProfileSvc.getMe();
      _DrawerCache.merchantProfile = _CacheEntry(m);
      if (mounted) setState(() {});
    } catch (_) {
      _DrawerCache.merchantProfile = _CacheEntry(null);
    }
  }

  Future<void> _fetchTierProgressData() async {
    try {
      final t = await _merchantProfileSvc.getTierProgress();
      _DrawerCache.tierProgress = _CacheEntry(t);
      if (mounted) setState(() {});
    } catch (_) {
      _DrawerCache.tierProgress = _CacheEntry(null);
    }
  }

  Future<void> _handleLogout() async {
    if (_loggingOut) return;
    HapticFeedback.mediumImpact();
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _LogoutConfirmationModal(),
    );
    if (confirm != true || !mounted) return;

    setState(() => _loggingOut = true);
    await _auth.logout();
    _DrawerCache.invalidateAll();

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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PaymentAccountSetupScreen(isMerchant: isMerchant)),
    );
  }

  void _handleVerificationTap() {
    if (_user == null) { _redirectToLogin(); return; }
    _push(const VerificationFlowScreen());
  }

  Future<void> _handleMerchantRequestTap() async {
    if (_user == null) { _redirectToLogin(); return; }
    Navigator.pop(context);
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const MerchantOnboardingFlowScreen()));
    _DrawerCache.merchantProfile = null;
    _DrawerCache.tierProgress = null;
    if (mounted) await _fetchMerchantProfileData();
    if (mounted) await _fetchTierProgressData();
  }

  void _handleMerchantOffersTap() {
    if (_user == null) { _redirectToLogin(); return; }
    if (!_isVerifiedForTradeAccess) { _push(const VerificationFlowScreen()); return; }
    _push(const ManageOffersScreen());
  }

  void _handleMerchantTradesTap() {
    if (_user == null) { _redirectToLogin(); return; }
    if (!_isVerifiedForTradeAccess) { _push(const VerificationFlowScreen()); return; }
    _push(const MerchantTradesScreen());
  }

  void _handleP2PMarketplaceTap() {
    if (_user == null) { _redirectToLogin(); return; }
    if (!_isVerifiedForTradeAccess) { _push(const VerificationFlowScreen()); return; }
    _push(const MarketOffersScreen(initialType: OfferType.sell));
  }

  void _handleMessengerTap() {
    if (_user == null) { _redirectToLogin(); return; }
    if (!_isVerifiedForTradeAccess) { _push(const VerificationFlowScreen()); return; }
    _push(const ChatHubScreen());
  }

  void _handleTradeHistoryTap() {
    if (_user == null) { _redirectToLogin(); return; }
    if (!_isVerifiedForTradeAccess) { _push(const VerificationFlowScreen()); return; }
    _push(const TradeHistoryScreen());
  }

  bool get _isVerifiedForTradeAccess =>
      _trustStatus == TrustStatus.ready ||
          (_cachedProfile?.isVerificationIdentityComplete ?? false);

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
    final user = _user;

    final merchantApproved = _merchantProfile?.isApproved ?? false;
    final isMerchant = user != null && merchantApproved;
    final canRequestMerchant = user != null && _trustStatus == TrustStatus.ready;
    final showShimmer = user == null && !_DrawerCache.hasProfile;

    return Drawer(
      backgroundColor: c.background,
      elevation: 0,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────────────────
              if (showShimmer)
                _ProfileShimmer(topPadding: mq.padding.top, colors: c)
              else if (user != null)
                _ProfileHeader(
                  user: user,
                  profile: _cachedProfile,
                  tierProgress: _tierProgress,
                  trustStatus: _trustStatus,
                  colors: c,
                )
              else
                _LoginPrompt(
                  colors: c,
                  topPadding: mq.padding.top,
                  onTap: _redirectToLogin,
                ),

              // ── Nav list ────────────────────────────────────────────────
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    const SizedBox(height: 12),
                    _staggered(0, _SectionLabel(label: 'P2P MARKET', colors: c)),
                    _staggered(1, _NavTile(
                      icon: LucideIcons.arrowLeftRight,
                      label: 'P2P Marketplace',
                      description: 'Browse buy and sell offers',
                      colors: c,
                      accentColor: const Color(0xFF10B981), // emerald
                      onTap: _handleP2PMarketplaceTap,
                      requiresAuth: user == null,
                    )),
                    _staggered(2, _NavTile(
                      icon: LucideIcons.messagesSquare,
                      label: 'Messenger',
                      description: 'Friends, threads & secure chat',
                      colors: c,
                      accentColor: const Color(0xFF6366F1), // indigo
                      trailing: user != null && _unreadChatCount > 0
                          ? _UnreadBadge(count: _unreadChatCount, colors: c)
                          : null,
                      onTap: _handleMessengerTap,
                      requiresAuth: user == null,
                    )),
                    _staggered(2, _NavTile(
                      icon: LucideIcons.clipboardList,
                      label: 'My Trades',
                      description: 'Your trade history',
                      colors: c,
                      accentColor: const Color(0xFF8B5CF6), // violet
                      onTap: _handleTradeHistoryTap,
                      requiresAuth: user == null,
                    )),

                    const SizedBox(height: 4),
                    _staggered(3, _SectionLabel(label: 'ACCOUNT', colors: c)),
                    _staggered(4, _NavTile(
                      icon: LucideIcons.shieldCheck,
                      label: 'Verification',
                      description: 'Complete identity steps',
                      colors: c,
                      accentColor: const Color(0xFF0EA5E9), // sky blue
                      trailing: user != null
                          ? _TrustStatusBadge(status: _trustStatus, colors: c)
                          : null,
                      onTap: _handleVerificationTap,
                      requiresAuth: user == null,
                    )),
                    _staggered(5, _NavTile(
                      icon: LucideIcons.landmark,
                      label: 'Payment Account',
                      description: 'Manage payment methods',
                      colors: c,
                      accentColor: const Color(0xFF06B6D4), // cyan
                      onTap: () => _redirectToPaymentAccount(false),
                      requiresAuth: user == null,
                    )),

                    if (canRequestMerchant) ...[
                      _staggered(6, _SectionLabel(label: 'MERCHANT', colors: c)),
                      _staggered(7, _NavTile(
                        icon: LucideIcons.briefcase,
                        label: 'Merchant Request',
                        description: 'Request merchant account access',
                        colors: c,
                        accentColor: const Color(0xFFF97316), // orange
                        trailing: merchantApproved
                            ? _TrustStatusBadge(status: TrustStatus.ready, colors: c)
                            : null,
                        onTap: _handleMerchantRequestTap,
                      )),
                    ],

                    if (isMerchant) ...[
                      if (!canRequestMerchant) ...[
                        const SizedBox(height: 4),
                        _staggered(8, _SectionLabel(label: 'MERCHANT', colors: c)),
                      ],
                      _staggered(9, _NavTile(
                        icon: LucideIcons.creditCard,
                        label: 'Merchant Payment',
                        description: 'Merchant payment account',
                        colors: c,
                        accentColor: const Color(0xFFEA580C), // deep orange
                        trailing: _TrustStatusBadge(status: TrustStatus.ready, colors: c),
                        onTap: () => _redirectToPaymentAccount(isMerchant),
                      )),
                      _staggered(10, _NavTile(
                        icon: LucideIcons.tag,
                        label: 'Manage Offers',
                        description: 'Create and edit merchant offers',
                        colors: c,
                        accentColor: const Color(0xFFD97706), // amber
                        onTap: _handleMerchantOffersTap,
                      )),
                      _staggered(11, _NavTile(
                        icon: LucideIcons.repeat2,
                        label: 'Merchant Trades',
                        description: 'Incoming trades and chat inbox',
                        colors: c,
                        accentColor: const Color(0xFFA855F7), // purple
                        onTap: _handleMerchantTradesTap,
                      )),
                    ],

                    const SizedBox(height: 4),
                    _staggered(12, _SectionLabel(label: 'SETTINGS', colors: c)),
                    _staggered(13, _NavTile(
                      icon: LucideIcons.keyRound,
                      label: 'Manage Wallet',
                      description: 'Keys & backup',
                      colors: c,
                      accentColor: const Color(0xFF14B8A6), // teal
                      onTap: () => _push(const WalletScreenSettings()),
                    )),
                    _staggered(14, _NavTile(
                      icon: LucideIcons.slidersHorizontal,
                      label: 'Preferences',
                      description: 'App settings',
                      colors: c,
                      accentColor: const Color(0xFF64748B), // slate
                      onTap: () => _push(const SettingsScreen()),
                    )),

                    if (_appInfo != null) ...[
                      const SizedBox(height: 24),
                      _AppVersionInfo(info: _appInfo!, colors: c),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),

              // ── Logout ──────────────────────────────────────────────────
              if (user != null) ...[
                _DrawerDivider(colors: c),
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
// ═════════════════════════════════════════════════════════════════════════════

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.user,
    required this.profile,
    required this.tierProgress,
    required this.trustStatus,
    required this.colors,
  });

  final User user;
  final ProfileModel? profile;
  final MerchantTierProgressModel? tierProgress;
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
    if (e == null || _line1 == e) return null;
    return e;
  }

  Color _tierColor(MerchantTier tier) => switch (tier) {
    MerchantTier.bronze => const Color(0xFFB87333),
    MerchantTier.silver => const Color(0xFF94A3B8),
    MerchantTier.gold => const Color(0xFFF59E0B),
    MerchantTier.platinum => const Color(0xFF64748B),
    MerchantTier.diamond => const Color(0xFF06B6D4),
  };

  IconData _tierIcon(MerchantTier tier) => switch (tier) {
    MerchantTier.bronze => Icons.shield_outlined,
    MerchantTier.silver => Icons.workspace_premium_outlined,
    MerchantTier.gold => Icons.emoji_events_outlined,
    MerchantTier.platinum => Icons.military_tech_outlined,
    MerchantTier.diamond => Icons.diamond_outlined,
  };

  String _tierLabel(MerchantTier tier) => switch (tier) {
    MerchantTier.bronze => 'BRONZE',
    MerchantTier.silver => 'SILVER',
    MerchantTier.gold => 'GOLD',
    MerchantTier.platinum => 'PLATINUM',
    MerchantTier.diamond => 'DIAMOND',
  };

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final ctry = _country;
    final c = colors;

    return Container(
      width: double.infinity,
      color: c.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top accent line
          Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [c.primary, c.primary, c.surface],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, top + 24, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DrawerAvatar(user: user, colors: c),
                    const Spacer(),
                    // ── REDESIGNED VERIFICATION BADGE ──────────────────
                    _VerifiedBadge(status: trustStatus, colors: c),
                  ],
                ),
                const SizedBox(height: 16),

                // Display name
                Text(
                  _line1,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                // Username handle — use primary color
                if (_line2 != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _line2!,
                        style: TextStyle(
                          color: c.primary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],

                // Email
                if (_line3 != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    _line3!,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // Country chip
                if (ctry != null) ...[
                  const SizedBox(height: 10),
                  _CountryChip(country: ctry, colors: c),
                ],

                // Merchant tier card
                if (tierProgress != null) ...[
                  const SizedBox(height: 14),
                  _MerchantTierCard(
                    tierProgress: tierProgress!,
                    tierColor: _tierColor,
                    tierIcon: _tierIcon,
                    tierLabel: _tierLabel,
                    colors: c,
                  ),
                ],
              ],
            ),
          ),
          Container(height: 1, color: c.border),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ✦ REDESIGNED VERIFIED BADGE
// Clean pill with icon + text on primary color background.
// Text uses white (on primary) for maximum contrast & legibility.
// ─────────────────────────────────────────────────────────────────────────────

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge({required this.status, required this.colors});

  final TrustStatus status;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    final (bgColor, icon, label, isGlowing) = switch (status) {
      TrustStatus.ready => (
      colors.primary,         // use theme primary — text on primary
      LucideIcons.badgeCheck,
      'Verified',
      true,
      ),
      TrustStatus.reviewing => (
      const Color(0xFFF59E0B),
      LucideIcons.clock,
      'In Review',
      false,
      ),
      TrustStatus.suspended => (
      const Color(0xFFEF4444),
      LucideIcons.shieldOff,
      'Suspended',
      false,
      ),
      TrustStatus.basic => (
      colors.border,
      LucideIcons.shield,
      'Basic',
      false,
      ),
      _ => (
      colors.border,
      LucideIcons.shield,
      'Unverified',
      false,
      ),
    };

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: isGlowing
            ? [
          BoxShadow(
            color: bgColor,
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ]
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.1,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TRUST STATUS BADGE (used in nav tile trailing)
// Minimalist dot + text, no fill box — cleaner in list context
// ─────────────────────────────────────────────────────────────────────────────

class _TrustStatusBadge extends StatelessWidget {
  const _TrustStatusBadge({required this.status, required this.colors});
  final TrustStatus status;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    final (dotColor, label, textColor, bgColor, borderColor, icon) =
    switch (status) {
      TrustStatus.ready => (
      const Color(0xFF059669), // dot
      'Verified',
      const Color(0xFF065F46), // text
      const Color(0xFFD1FAE5), // bg
      const Color(0xFF6EE7B7), // border
      Icons.verified_rounded,
      ),
      TrustStatus.reviewing => (
      const Color(0xFFD97706), // dot
      'Pending',
      const Color(0xFF78350F), // text
      const Color(0xFFFEF3C7), // bg
      const Color(0xFFFCD34D), // border
      Icons.hourglass_top_rounded,
      ),
      TrustStatus.suspended => (
      const Color(0xFFDC2626), // dot
      'Suspended',
      const Color(0xFF7F1D1D), // text
      const Color(0xFFFEE2E2), // bg
      const Color(0xFFFCA5A5), // border
      Icons.block_rounded,
      ),
      _ => (
      const Color(0xFF475569), // dot
      'Basic',
      const Color(0xFF334155), // text
      const Color(0xFFF1F5F9), // bg
      const Color(0xFFCBD5E1), // border
      Icons.person_rounded,
      ),
    };

    assert(
    bgColor.alpha == 0xFF &&
        borderColor.alpha == 0xFF &&
        textColor.alpha == 0xFF &&
        dotColor.alpha == 0xFF,
    'TrustStatusBadge: all colors must be fully opaque (no opacity)',
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 11, color: dotColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: 0.3,
              height: 1,
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.mapPin, size: 10, color: colors.textSecondary),
          const SizedBox(width: 5),
          Text(
            country,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: colors.textSecondary,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MERCHANT TIER CARD
// ─────────────────────────────────────────────────────────────────────────────

class _MerchantTierCard extends StatelessWidget {
  const _MerchantTierCard({
    required this.tierProgress,
    required this.tierColor,
    required this.tierIcon,
    required this.tierLabel,
    required this.colors,
  });

  final MerchantTierProgressModel tierProgress;
  final Color Function(MerchantTier) tierColor;
  final IconData Function(MerchantTier) tierIcon;
  final String Function(MerchantTier) tierLabel;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    final tc = tierColor(tierProgress.currentTier);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(tierIcon(tierProgress.currentTier), size: 14, color: tc),
              const SizedBox(width: 7),
              Text(
                'Merchant Tier',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: tc,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  tierLabel(tierProgress.currentTier),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TierSummaryItem(
                  label: 'Current Tier',
                  caption: 'Active rank',
                  tierLabel: tierLabel(tierProgress.currentTier),
                  tierColor: tierColor(tierProgress.currentTier),
                  tierIcon: tierIcon(tierProgress.currentTier),
                  colors: colors,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TierSummaryItem(
                  label: 'Next Tier',
                  caption: tierProgress.nextTier == null
                      ? 'Top tier reached'
                      : '${tierProgress.nextTier!.progress.overallPercent.toStringAsFixed(0)}% progress',
                  tierLabel: tierProgress.nextTier == null
                      ? 'TOP TIER'
                      : tierLabel(tierProgress.nextTier!.tier),
                  tierColor: tierProgress.nextTier == null
                      ? tierColor(MerchantTier.diamond)
                      : tierColor(tierProgress.nextTier!.tier),
                  tierIcon: tierProgress.nextTier == null
                      ? tierIcon(MerchantTier.diamond)
                      : tierIcon(tierProgress.nextTier!.tier),
                  colors: colors,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TierSummaryItem extends StatelessWidget {
  const _TierSummaryItem({
    required this.label,
    required this.caption,
    required this.tierLabel,
    required this.tierColor,
    required this.tierIcon,
    required this.colors,
  });

  final String label;
  final String caption;
  final String tierLabel;
  final Color tierColor;
  final IconData tierIcon;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: tierColor,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(tierIcon, size: 13, color: Colors.white),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  tierLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            caption,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w500,
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
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulse, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, child) => Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: c.primary,
                  blurRadius: 16 + _pulseAnim.value * 8,
                ),
              ],
            ),
            child: child,
          ),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.primary,
            ),
            padding: const EdgeInsets.all(2.5),
            child: ClipOval(
              child: UserAvatar(user: widget.user, radius: 27, colors: c),
            ),
          ),
        ),
        Positioned(
          bottom: 2,
          right: 2,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 18, height: 18,
                decoration: BoxDecoration(shape: BoxShape.circle, color: c.success),
              ),
              Container(
                width: 12, height: 12,
                decoration: BoxDecoration(
                  color: c.success,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.surface, width: 2),
                  boxShadow: [BoxShadow(color: c.success, blurRadius: 6)],
                ),
              ),
            ],
          ),
        ),
      ],
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
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors.primary, colors.primary, colors.primary],
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
                    color: colors.border,
                  ),
                  child: Icon(LucideIcons.userCircle2, color: colors.textSecondary, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                          letterSpacing: -0.8,
                          height: 1.1,
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
                      const SizedBox(height: 14),
                      _GradientButton(
                        label: 'Sign In',
                        icon: Icons.login_rounded,
                        primaryColor: colors.primary,
                        onTap: onTap,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: colors.border),
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
    required this.label,
    required this.icon,
    required this.primaryColor,
    required this.onTap,
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
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [primaryColor, const Color(0xFF7C3AED)],
          ),
          borderRadius: BorderRadius.circular(11),
          boxShadow: [
            BoxShadow(color: primaryColor, blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.1,
              ),
            ),
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
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Row(
        children: [
          Container(
            width: 3, height: 11,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: colors.textSecondary,
              letterSpacing: 1.5,
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
    required this.icon,
    required this.label,
    required this.description,
    required this.colors,
    required this.onTap,
    this.accentColor,
    this.trailing,
    this.requiresAuth = false,
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
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(_) { setState(() => _isPressed = true); _pressCtrl.forward(); }
  void _onTapUp(_) { setState(() => _isPressed = false); _pressCtrl.reverse(); }
  void _onTapCancel() { setState(() => _isPressed = false); _pressCtrl.reverse(); }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final accent =  c.primary;

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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _isPressed ? accent : widget.colors.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isPressed ? accent : widget.colors.background,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent, width: 1),
                ),
                child: Icon(widget.icon, color: c.onPrimary, size: 18),
              ),
              const SizedBox(width: 13),
              // Labels
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      widget.description,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: c.textSecondary,
                        height: 1.3,
                      ),
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
                Icon(LucideIcons.chevronRight, color: c.textSecondary, size: 15),
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
        color: colors.border,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline_rounded, size: 10, color: colors.textSecondary),
          const SizedBox(width: 4),
          Text(
            'Sign in',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
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
          colors: [colors.primary, const Color(0xFF7C3AED)],
        ),
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(color: colors.primary, blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800),
      ),
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
    return Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 20), color: colors.border);
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
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: colors.border,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.package, size: 10, color: colors.textSecondary),
            const SizedBox(width: 5),
            Text(
              '${info.appName}  v${info.version}',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
                letterSpacing: 0.1,
              ),
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
          color: _pressed ? const Color(0xFFFFF0F0) : widget.colors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _pressed ? const Color(0xFFFFCDD2) : widget.colors.background),
        ),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: widget.isLoading
                  ? SizedBox(
                key: const ValueKey('l'),
                width: 18, height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(c.error),
                ),
              )
                  : Icon(key: const ValueKey('i'), LucideIcons.logOut, color: c.error, size: 18),
            ),
            const SizedBox(width: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: Text(
                widget.isLoading ? 'Signing out…' : 'Sign Out',
                key: ValueKey(widget.isLoading),
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: c.error,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const Spacer(),
            if (!widget.isLoading)
              Icon(LucideIcons.chevronRight, color: c.error, size: 14),
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

class _ProfileShimmerState extends State<_ProfileShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _sweep;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
    _sweep = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
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
      animation: _sweep,
      builder: (_, __) {
        final shimBase = c.border;
        final shimHighlight = const Color(0xFFE2E8F0); // solid light grey highlight
        Widget shimBox(double w, double h, {double r = 6}) => Container(
          width: w, height: h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(r),
            gradient: LinearGradient(
              begin: Alignment(-1 + _sweep.value * 2.5, 0),
              end: Alignment(-0.5 + _sweep.value * 2.5, 0),
              colors: [shimBase, shimHighlight, shimBase],
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
                  gradient: LinearGradient(colors: [c.primary, c.primary, c.surface]),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, widget.topPadding + 22, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        shimBox(60, 60, r: 30),
                        const Spacer(),
                        shimBox(80, 32, r: 10),
                      ],
                    ),
                    const SizedBox(height: 16),
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
              Container(height: 1, color: c.border),
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
        boxShadow: [
          BoxShadow(color: const Color(0x4D000000), blurRadius: 40, offset: const Offset(0, -10)),
        ],
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
                decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
              ),
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFF0F0),
                  border: Border.all(color: const Color(0xFFFFCDD2), width: 1.5),
                ),
                child: Icon(LucideIcons.logOut, color: c.error, size: 28),
              ),
              const SizedBox(height: 18),
              Text(
                'Sign Out?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary,
                  letterSpacing: -0.6,
                ),
              ),
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
                    gradient: LinearGradient(
                      colors: [c.error, const Color(0xFFB71C1C)],
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(color: c.error, blurRadius: 16, offset: const Offset(0, 6)),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Yes, Sign Out',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () { HapticFeedback.lightImpact(); Navigator.pop(context, false); },
                child: Container(
                  width: double.infinity, height: 52,
                  decoration: BoxDecoration(
                    color: c.border,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
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
