import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/app/config/app_providers.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/core/widgets/profile_avatar/user_avatar.dart';
import 'package:next_fi/features/auth/presentation/screens/login_screen.dart';
import 'package:next_fi/features/merchant_flow/presentation/screens/merchant_onboarding_flow_screen.dart';
import 'package:next_fi/features/merchant_trades/presentation/screens/merchant_trades_screen.dart';
import 'package:next_fi/features/offers/presentation/screens/market_offers_screen.dart';
import 'package:next_fi/features/trades/presentation/screens/trade_history_screen.dart';
import 'package:next_fi/features/trades/presentation/viewmodels/trade_inbox_summary_provider.dart';
import 'package:next_fi/features/offers/presentation/screens/manage_offers_screen.dart';
import 'package:next_fi/features/verification_flow/presentation/screens/payment_method_setup_screen.dart';
import 'package:next_fi/features/verification_flow/presentation/screens/verification_flow_screen.dart';
import 'package:next_fi/features/settings/presentation/screens/settings_screen.dart';
import 'package:next_fi/features/wallet_settings/presentation/screens/wallet_settings_screen.dart';
import 'package:next_fi/core/utils/link_opener.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:next_fi/core/services/base_url/base_url.dart';
import 'package:next_fi/core/services/auth/auth_service.dart';
import 'package:next_fi/core/services/auth/models/user_model.dart';
import 'package:next_fi/core/services/merchant_profile/models/merchant_profile_models.dart';
import 'package:next_fi/core/services/merchant_profile/models/merchant_tier_progress_models.dart';
import 'package:next_fi/core/services/merchant_profile/merchant_profile_core_service.dart';
import 'package:next_fi/core/services/offers/models/offers_dtos.dart';
import 'package:next_fi/core/services/profile/models/profile_models.dart';
import 'package:next_fi/core/services/profile/profile_core_service.dart';
import 'package:next_fi/core/services/verification/models/verification_models.dart';
import 'package:next_fi/core/services/verification/verification_core_service.dart';

// -----------------------------------------------------------------------------
// TYPOGRAPHY TOKENS
// -----------------------------------------------------------------------------

abstract class _T {
  static const displayName = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    height: 1.1,
  );
  static const handle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.3,
  );
  static const email = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.3,
  );
  static const sectionLabel = TextStyle(
    fontSize: 9.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
    height: 1.0,
  );
  static const navTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.2,
  );
  static const navSub = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.3,
  );
  static const badge = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
    height: 1.0,
  );
  static const micro = TextStyle(
    fontSize: 9.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    height: 1.0,
  );
  static const logoutLabel = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.0,
  );
  static const version = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    height: 1.0,
  );
}

// -----------------------------------------------------------------------------
// TTL CACHE  (unchanged logic)
// -----------------------------------------------------------------------------

class _CacheEntry<T> {
  _CacheEntry(this.value) : _at = DateTime.now();
  final T value;
  final DateTime _at;
  bool isFresh(Duration ttl) => DateTime.now().difference(_at) < ttl;
}

class _DrawerCache {
  static const _userTtl = Duration(seconds: 30);
  static const _profileTtl = Duration(seconds: 5);
  static const _merchantTtl = Duration(seconds: 5);
  static const _verificationTtl = Duration(seconds: 5);
  static const _appInfoTtl = Duration(days: 1);
  static const _legalLinksTtl = Duration(hours: 6);

  static _CacheEntry<User>? user;
  static _CacheEntry<PackageInfo>? appInfo;
  static _CacheEntry<ProfileModel?>? profile;
  static _CacheEntry<MerchantProfileModel?>? merchantProfile;
  static _CacheEntry<MerchantTierProgressModel?>? tierProgress;
  static _CacheEntry<TrustStatus>? trustStatus;
  static _CacheEntry<String>? termsUrl;
  static _CacheEntry<String>? privacyUrl;

  static bool get hasUser => user != null && user!.isFresh(_userTtl);
  static bool get hasAppInfo =>
      appInfo != null && appInfo!.isFresh(_appInfoTtl);
  static bool get hasProfile =>
      profile != null && profile!.isFresh(_profileTtl);
  static bool get hasMerchantProfile =>
      merchantProfile != null && merchantProfile!.isFresh(_merchantTtl);
  static bool get hasTierProgress =>
      tierProgress != null && tierProgress!.isFresh(_merchantTtl);
  static bool get hasTrustStatus =>
      trustStatus != null && trustStatus!.isFresh(_verificationTtl);
  static bool get hasLegalLinks =>
      termsUrl != null &&
      termsUrl!.isFresh(_legalLinksTtl) &&
      privacyUrl != null &&
      privacyUrl!.isFresh(_legalLinksTtl);

  static void invalidateAll() {
    user = merchantProfile = profile = null;
    tierProgress = null;
    trustStatus = null;
    termsUrl = null;
    privacyUrl = null;
  }

  static void invalidateProfile() => profile = null;
}

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------

class AppDrawer extends StatefulWidget {
  final VoidCallback? onLogout;
  const AppDrawer({super.key, this.onLogout});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer>
    with SingleTickerProviderStateMixin {
  final _auth = AuthService();
  final _profileSvc = ProfileCoreService.I;
  final _verificationSvc = VerificationCoreService.I;
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
  MerchantProfileModel? get _merchantProfile =>
      _DrawerCache.merchantProfile?.value;
  MerchantTierProgressModel? get _tierProgress =>
      _DrawerCache.tierProgress?.value;
  TrustStatus get _trustStatus =>
      _DrawerCache.trustStatus?.value ?? TrustStatus.unknown;
  String get _termsUrl => _DrawerCache.termsUrl?.value ?? '';
  String get _privacyUrl => _DrawerCache.privacyUrl?.value ?? '';

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(-0.04, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _itemAnims = List.generate(22, (i) {
      final start = (i * 0.045).clamp(0.0, 0.75);
      final end = (start + 0.30).clamp(0.0, 1.0);
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
    await Future.wait([
      if (!_DrawerCache.hasAppInfo) _fetchAppInfo(),
      if (!_DrawerCache.hasLegalLinks) _fetchLegalLinks(),
      if (isAuth && !_DrawerCache.hasUser) _fetchUser(),
      if (isAuth && !_DrawerCache.hasProfile) _fetchProfile(),
      if (isAuth && !_DrawerCache.hasMerchantProfile)
        _fetchMerchantProfileData(),
      if (isAuth && !_DrawerCache.hasTierProgress) _fetchTierProgressData(),
      if (isAuth && !_DrawerCache.hasTrustStatus) _fetchVerification(),
    ]);
    if (mounted) setState(() {});
  }

  Future<void> _fetchUser() async {
    try {
      _DrawerCache.user = _CacheEntry(await _auth.currentUser);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _fetchAppInfo() async {
    try {
      _DrawerCache.appInfo = _CacheEntry(await PackageInfo.fromPlatform());
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _fetchProfile() async {
    try {
      _DrawerCache.profile = _CacheEntry(await _profileSvc.getMe());
    } catch (_) {
      _DrawerCache.profile = _CacheEntry(null);
    }
    if (mounted) setState(() {});
  }

  Future<void> _fetchVerification() async {
    try {
      final d = await _verificationSvc.getMe();
      _DrawerCache.trustStatus = _CacheEntry(d.status);
    } catch (_) {
      _DrawerCache.trustStatus = _CacheEntry(TrustStatus.basic);
    }
    if (mounted) setState(() {});
  }

  Future<void> _fetchLegalLinks() async {
    String base = centralizedBaseUrl.replaceFirst(RegExp(r'/api/v1/?$'), '');
    base = base.replaceFirst(RegExp(r'/$'), '');
    final fallback = '$base/download';
    try {
      final res = await http
          .get(Uri.parse('$base/download/meta'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final d = jsonDecode(res.body);
        if (d is Map<String, dynamic>) {
          final t = d['termsAndConditionsUrl']?.toString().trim() ?? '';
          final p = d['privacyPolicyUrl']?.toString().trim() ?? '';
          _DrawerCache.termsUrl = _CacheEntry(t.isNotEmpty ? t : fallback);
          _DrawerCache.privacyUrl = _CacheEntry(p.isNotEmpty ? p : fallback);
          if (mounted) setState(() {});
          return;
        }
      }
    } catch (_) {}
    _DrawerCache.termsUrl = _CacheEntry(fallback);
    _DrawerCache.privacyUrl = _CacheEntry(fallback);
    if (mounted) setState(() {});
  }

  Future<void> _fetchMerchantProfileData() async {
    try {
      _DrawerCache.merchantProfile = _CacheEntry(
        await _merchantProfileSvc.getMe(),
      );
    } catch (_) {
      _DrawerCache.merchantProfile = _CacheEntry(null);
    }
    if (mounted) setState(() {});
  }

  Future<void> _fetchTierProgressData() async {
    try {
      _DrawerCache.tierProgress = _CacheEntry(
        await _merchantProfileSvc.getTierProgress(),
      );
    } catch (_) {
      _DrawerCache.tierProgress = _CacheEntry(null);
    }
    if (mounted) setState(() {});
  }

  Future<void> _handleLogout() async {
    if (_loggingOut) return;
    HapticFeedback.mediumImpact();
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _LogoutModal(),
    );
    if (confirm != true || !mounted) return;
    setState(() => _loggingOut = true);
    await _auth.logout();
    _DrawerCache.invalidateAll();
    final container = ProviderScope.containerOf(context, listen: false);
    container.read(appShellProvider.notifier).setAuthenticated(false);
    container.read(tabControllerProvider.notifier).setTab(0);
    container.invalidate(tradeInboxSummaryProvider);
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

  void _redirectToPaymentAccount(bool isMerchant) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentAccountSetupScreen(isMerchant: isMerchant),
      ),
    );
  }

  void _handleVerificationTap() {
    if (_user == null) return _redirectToLogin();
    _push(const VerificationFlowScreen());
  }

  Future<void> _handleMerchantRequestTap() async {
    if (_user == null) return _redirectToLogin();
    Navigator.pop(context);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MerchantOnboardingFlowScreen()),
    );
    _DrawerCache.merchantProfile = null;
    _DrawerCache.tierProgress = null;
    if (mounted) await _fetchMerchantProfileData();
    if (mounted) await _fetchTierProgressData();
  }

  bool get _isVerified => _trustStatus == TrustStatus.ready;

  void _handleMerchantOffersTap() {
    if (_user == null) return _redirectToLogin();
    if (!_isVerified) return _push(const VerificationFlowScreen());
    _push(const ManageOffersScreen());
  }

  void _handleMerchantTradesTap() {
    if (_user == null) return _redirectToLogin();
    if (!_isVerified) return _push(const VerificationFlowScreen());
    _push(const MerchantTradesScreen());
  }

  void _handleP2PMarketplaceTap() {
    if (_user == null) return _redirectToLogin();
    if (!_isVerified) return _push(const VerificationFlowScreen());
    _push(const MarketOffersScreen(initialType: OfferType.sell));
  }

  void _handleTradeHistoryTap() {
    if (_user == null) return _redirectToLogin();
    if (!_isVerified) return _push(const VerificationFlowScreen());
    _push(const TradeHistoryScreen());
  }

  Future<void> _openLegal(String url, String label) async {
    await LinkOpener.open(context, url, fallbackLabel: label);
    if (mounted) Navigator.pop(context);
  }

  void _push(Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Widget _staggered(int i, Widget child) {
    if (i >= _itemAnims.length) return child;
    return AnimatedBuilder(
      animation: _itemAnims[i],
      builder: (_, __) => Opacity(
        opacity: _itemAnims[i].value,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - _itemAnims[i].value)),
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
    final canRequestMerchant =
        user != null && _trustStatus == TrustStatus.ready;
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
              // ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ Header ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬
              if (showShimmer)
                _ProfileShimmer(topPadding: mq.padding.top, c: c)
              else if (user != null)
                _ProfileHeader(
                  user: user,
                  profile: _cachedProfile,
                  tierProgress: _tierProgress,
                  trustStatus: _trustStatus,
                  c: c,
                )
              else
                _LoginPrompt(
                  c: c,
                  topPadding: mq.padding.top,
                  onTap: _redirectToLogin,
                ),

              // ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ Nav ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    const SizedBox(height: 8),

                    _staggered(0, _Section(label: 'MARKET', c: c)),
                    _staggered(
                      1,
                      _Tile(
                        icon: LucideIcons.arrowLeftRight,
                        label: 'P2P Marketplace',
                        sub: 'Browse buy & sell offers',
                        accent: c.success,
                        c: c,
                        locked: user == null,
                        onTap: _handleP2PMarketplaceTap,
                      ),
                    ),
                    _staggered(
                      2,
                      _Tile(
                        icon: LucideIcons.clipboardList,
                        label: 'My Trades',
                        sub: 'Trade history',
                        accent: c.primary,
                        c: c,
                        locked: user == null,
                        onTap: _handleTradeHistoryTap,
                      ),
                    ),

                    _staggered(3, _Section(label: 'ACCOUNT', c: c)),
                    _staggered(
                      4,
                      _Tile(
                        icon: LucideIcons.shieldCheck,
                        label: 'Verification',
                        sub: 'Identity & trust level',
                        accent: c.info,
                        c: c,
                        locked: user == null,
                        trailing: user != null
                            ? _StatusPill(status: _trustStatus, c: c)
                            : null,
                        onTap: _handleVerificationTap,
                      ),
                    ),
                    _staggered(
                      5,
                      _Tile(
                        icon: LucideIcons.landmark,
                        label: 'Payment Account',
                        sub: 'Manage payment methods',
                        accent: c.info,
                        c: c,
                        locked: user == null,
                        onTap: () => _redirectToPaymentAccount(false),
                      ),
                    ),

                    if (canRequestMerchant) ...[
                      _staggered(6, _Section(label: 'MERCHANT', c: c)),
                      _staggered(
                        7,
                        _Tile(
                          icon: LucideIcons.briefcase,
                          label: 'Merchant Request',
                          sub: 'Apply for merchant access',
                          accent: c.warning,
                          c: c,
                          trailing: merchantApproved
                              ? _StatusPill(status: TrustStatus.ready, c: c)
                              : null,
                          onTap: _handleMerchantRequestTap,
                        ),
                      ),
                    ],

                    if (isMerchant) ...[
                      if (!canRequestMerchant)
                        _staggered(8, _Section(label: 'MERCHANT', c: c)),
                      _staggered(
                        9,
                        _Tile(
                          icon: LucideIcons.tag,
                          label: 'Manage Offers',
                          sub: 'Create & edit offers',
                          accent: c.warning,
                          c: c,
                          onTap: _handleMerchantOffersTap,
                        ),
                      ),
                      _staggered(
                        11,
                        Consumer(
                          builder: (context, ref, _) {
                            final tradeSummary = ref.watch(
                              tradeInboxSummaryProvider,
                            );
                            final pendingMerchantActions = tradeSummary
                                .maybeWhen(
                                  data: (summary) =>
                                      summary.merchantActionCount,
                                  orElse: () => 0,
                                );

                            return _Tile(
                              icon: LucideIcons.repeat2,
                              label: 'Merchant Trades',
                              sub: 'Incoming trades & chat',
                              accent: c.accent,
                              c: c,
                              trailing: pendingMerchantActions > 0
                                  ? _CountBadge(
                                      count: pendingMerchantActions,
                                      c: c,
                                      color: c.error,
                                    )
                                  : null,
                              onTap: _handleMerchantTradesTap,
                            );
                          },
                        ),
                      ),
                    ],

                    _staggered(12, _Section(label: 'SETTINGS', c: c)),
                    _staggered(
                      13,
                      _Tile(
                        icon: LucideIcons.keyRound,
                        label: 'Manage Wallet',
                        sub: 'Keys & backup',
                        accent: c.success,
                        c: c,
                        onTap: () => _push(const WalletScreenSettings()),
                      ),
                    ),
                    _staggered(
                      14,
                      _Tile(
                        icon: LucideIcons.slidersHorizontal,
                        label: 'Preferences',
                        sub: 'App settings',
                        accent: c.textSecondary,
                        c: c,
                        onTap: () => _push(const SettingsScreen()),
                      ),
                    ),
                    _staggered(
                      15,
                      _Tile(
                        icon: LucideIcons.fileText,
                        label: 'Terms & Conditions',
                        sub: 'Legal terms',
                        accent: c.info,
                        c: c,
                        onTap: () => _openLegal(_termsUrl, 'Terms'),
                      ),
                    ),
                    _staggered(
                      16,
                      _Tile(
                        icon: LucideIcons.shield,
                        label: 'Privacy Policy',
                        sub: 'Privacy policy',
                        accent: c.accent,
                        c: c,
                        onTap: () => _openLegal(_privacyUrl, 'Privacy'),
                      ),
                    ),

                    const SizedBox(height: 20),
                    if (_appInfo != null)
                      _staggered(17, _VersionRow(info: _appInfo!, c: c)),
                    const SizedBox(height: 8),
                  ],
                ),
              ),

              // ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ Logout ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬
              if (user != null) ...[
                Container(height: 1, color: c.border.withValues(alpha: 0.5)),
                _LogoutTile(isLoading: _loggingOut, c: c, onTap: _handleLogout),
              ],
              SizedBox(height: mq.padding.bottom + 6),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// PROFILE HEADER
// -----------------------------------------------------------------------------

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.user,
    required this.profile,
    required this.tierProgress,
    required this.trustStatus,
    required this.c,
  });
  final User user;
  final ProfileModel? profile;
  final MerchantTierProgressModel? tierProgress;
  final TrustStatus trustStatus;
  final AppColor c;

  String? _s(String? v) {
    final t = v?.trim();
    return (t?.isEmpty ?? true) ? null : t;
  }

  String? get _displayName => _s(profile?.displayName);
  String? get _handle {
    final u = _s(profile?.username);
    return u != null ? '@$u' : null;
  }

  String? get _email => user.email.trim().isEmpty ? null : user.email.trim();
  String? get _country => _s(profile?.country);
  String get _name => _displayName ?? _email ?? 'Anonymous';

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      color: c.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thin primary accent line at very top
          Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [c.primary, c.primary.withValues(alpha: 0)],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(18, top + 18, 18, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar with tier ring
                _DrawerAvatar(user: user, c: c, tierProgress: tierProgress),
                const SizedBox(width: 13),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Name
                      Text(
                        _name,
                        style: _T.displayName.copyWith(color: c.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      // Handle / email sub-line
                      if (_handle != null)
                        Text(
                          _handle!,
                          style: _T.handle.copyWith(color: c.primary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      else if (_email != null)
                        Text(
                          _email!,
                          style: _T.email.copyWith(color: c.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (_handle != null &&
                          _email != null &&
                          _name != _email) ...[
                        const SizedBox(height: 1),
                        Text(
                          _email!,
                          style: _T.email.copyWith(color: c.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      // Meta chips row
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          _VerifiedBadge(status: trustStatus, c: c),
                          if (_country != null) ...[
                            const SizedBox(width: 6),
                            _CountryChip(country: _country!, c: c),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: c.border.withValues(alpha: 0.5)),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TIER META
// -----------------------------------------------------------------------------

class _TierMeta {
  static Color color(MerchantTier t) => switch (t) {
    MerchantTier.bronze => const Color(0xFFCD7F32),
    MerchantTier.silver => const Color(0xFF9CA3AF),
    MerchantTier.gold => const Color(0xFFF59E0B),
    MerchantTier.platinum => const Color(0xFF22D3EE),
    MerchantTier.diamond => const Color(0xFF818CF8),
  };

  static IconData icon(MerchantTier t) => switch (t) {
    MerchantTier.bronze => Icons.shield_outlined,
    MerchantTier.silver => Icons.workspace_premium_outlined,
    MerchantTier.gold => Icons.emoji_events_outlined,
    MerchantTier.platinum => Icons.military_tech_outlined,
    MerchantTier.diamond => Icons.diamond_outlined,
  };

  static String label(MerchantTier t) => switch (t) {
    MerchantTier.bronze => 'Bronze',
    MerchantTier.silver => 'Silver',
    MerchantTier.gold => 'Gold',
    MerchantTier.platinum => 'Platinum',
    MerchantTier.diamond => 'Diamond',
  };
}

// -----------------------------------------------------------------------------
// DRAWER AVATAR  (avatar + animated tier ring + badge below)
// -----------------------------------------------------------------------------

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });
  final double progress;
  final Color color;
  final Color trackColor;

  static const _stroke = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = cx - _stroke / 2 - 1;
    const startAngle = -1.5707963; // -ÃƒÂÃ¢â€šÂ¬/2 (top)
    const fullSweep = 6.2831853; // 2ÃƒÂÃ¢â€šÂ¬

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      startAngle,
      fullSweep,
      false,
      Paint()
        ..color = trackColor
        ..strokeWidth = _stroke
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    if (progress > 0.01) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        startAngle,
        fullSweep * progress,
        false,
        Paint()
          ..color = color
          ..strokeWidth = _stroke
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter o) =>
      o.progress != progress || o.color != color;
}

class _DrawerAvatar extends StatefulWidget {
  const _DrawerAvatar({required this.user, required this.c, this.tierProgress});
  final User user;
  final AppColor c;
  final MerchantTierProgressModel? tierProgress;

  @override
  State<_DrawerAvatar> createState() => _DrawerAvatarState();
}

class _DrawerAvatarState extends State<_DrawerAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ringCtrl;
  late final Animation<double> _ringAnim;

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _ringAnim = CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOutCubic);
    // Slight delay so it animates in after the drawer slides open
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _ringCtrl.forward();
    });
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tp = widget.tierProgress;
    final hasTier = tp != null;
    final tier = tp?.currentTier;
    final tierColor = tier != null ? _TierMeta.color(tier) : widget.c.primary;
    final tierLabel = tier != null ? _TierMeta.label(tier) : null;
    final tierIcon = tier != null ? _TierMeta.icon(tier) : null;
    final targetProgress = tp?.nextTier != null
        ? (tp!.nextTier!.progress.overallPercent.clamp(0.0, 100.0) / 100.0)
        : (hasTier ? 1.0 : 0.0);

    const outerSize = 64.0;
    const avatarSize = 52.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: outerSize,
          height: outerSize,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Animated tier progress ring
              if (hasTier)
                AnimatedBuilder(
                  animation: _ringAnim,
                  builder: (_, __) => CustomPaint(
                    size: const Size(outerSize, outerSize),
                    painter: _RingPainter(
                      progress: _ringAnim.value * targetProgress,
                      color: tierColor,
                      trackColor: tierColor.withValues(alpha: 0.15),
                    ),
                  ),
                ),
              // Avatar
              Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: hasTier
                        ? tierColor.withValues(alpha: 0.35)
                        : widget.c.border,
                    width: 1.5,
                  ),
                ),
                child: ClipOval(
                  child: UserAvatar(
                    user: widget.user,
                    radius: 24,
                    colors: widget.c,
                  ),
                ),
              ),
              // Online dot
              Positioned(
                bottom: 3,
                right: 3,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: widget.c.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: widget.c.surface, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Tier badge pill below avatar
        if (hasTier && tierLabel != null && tierIcon != null) ...[
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: tierColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: tierColor.withValues(alpha: 0.28)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(tierIcon, size: 8, color: tierColor),
                const SizedBox(width: 3),
                Text(
                  tierLabel,
                  style: _T.micro.copyWith(
                    color: tierColor,
                    fontSize: 8.5,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// VERIFIED BADGE
// -----------------------------------------------------------------------------

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge({required this.status, required this.c});
  final TrustStatus status;
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon, label) = switch (status) {
      TrustStatus.ready => (
        c.success.withValues(alpha: 0.12),
        c.success,
        LucideIcons.badgeCheck,
        'Verified',
      ),
      TrustStatus.reviewing => (
        c.warning.withValues(alpha: 0.12),
        c.warning,
        LucideIcons.clock,
        'In Review',
      ),
      TrustStatus.suspended => (
        c.error.withValues(alpha: 0.12),
        c.error,
        LucideIcons.shieldOff,
        'Suspended',
      ),
      TrustStatus.basic => (
        c.border,
        c.textSecondary,
        LucideIcons.shield,
        'Basic',
      ),
      _ => (c.border, c.textSecondary, LucideIcons.shield, 'Unverified'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 4),
          Text(label, style: _T.badge.copyWith(color: fg)),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// STATUS PILL  (nav tile trailing)
// -----------------------------------------------------------------------------

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.c});
  final TrustStatus status;
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    final (dot, label, bg, border) = switch (status) {
      TrustStatus.ready => (
        c.success,
        'Active',
        c.success.withValues(alpha: 0.10),
        c.success.withValues(alpha: 0.25),
      ),
      TrustStatus.reviewing => (
        c.warning,
        'Pending',
        c.warning.withValues(alpha: 0.10),
        c.warning.withValues(alpha: 0.25),
      ),
      TrustStatus.suspended => (
        c.error,
        'Suspended',
        c.error.withValues(alpha: 0.10),
        c.error.withValues(alpha: 0.25),
      ),
      _ => (c.textSecondary, 'Basic', c.border, c.border),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(label, style: _T.micro.copyWith(color: dot)),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// COUNTRY CHIP
// -----------------------------------------------------------------------------

class _CountryChip extends StatelessWidget {
  const _CountryChip({required this.country, required this.c});
  final String country;
  final AppColor c;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: c.background,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: c.border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(LucideIcons.mapPin, size: 9, color: c.textSecondary),
        const SizedBox(width: 3),
        Text(country, style: _T.micro.copyWith(color: c.textSecondary)),
      ],
    ),
  );
}

// -----------------------------------------------------------------------------
// LOGIN PROMPT
// -----------------------------------------------------------------------------

class _LoginPrompt extends StatelessWidget {
  const _LoginPrompt({
    required this.c,
    required this.topPadding,
    required this.onTap,
  });
  final AppColor c;
  final double topPadding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: c.surface,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [c.primary, c.primary.withValues(alpha: 0)],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(18, topPadding + 18, 18, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.border.withValues(alpha: 0.5),
                  border: Border.all(color: c.border),
                ),
                child: Icon(
                  LucideIcons.userCircle2,
                  color: c.textSecondary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Welcome back',
                      style: _T.displayName.copyWith(color: c.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Sign in to trade',
                      style: _T.navSub.copyWith(color: c.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: onTap,
                      child: Container(
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: c.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.login_rounded,
                              size: 13,
                              color: c.onPrimary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Sign In',
                              style: _T.badge.copyWith(
                                color: c.onPrimary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
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
        Container(height: 1, color: c.border.withValues(alpha: 0.5)),
      ],
    ),
  );
}

// -----------------------------------------------------------------------------
// SECTION LABEL
// -----------------------------------------------------------------------------

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.c});
  final String label;
  final AppColor c;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 20, 18, 4),
    child: Text(
      label,
      style: _T.sectionLabel.copyWith(
        color: c.textSecondary.withValues(alpha: 0.6),
      ),
    ),
  );
}

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------

class _Tile extends StatefulWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.sub,
    required this.accent,
    required this.c,
    required this.onTap,
    this.trailing,
    this.locked = false,
  });
  final IconData icon;
  final String label;
  final String sub;
  final Color accent;
  final AppColor c;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool locked;

  @override
  State<_Tile> createState() => _TileState();
}

class _TileState extends State<_Tile> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
    reverseDuration: const Duration(milliseconds: 180),
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 1.0,
    end: 0.975,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

  bool _pressed = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final accent = widget.accent;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onTapDown: (_) {
        setState(() => _pressed = true);
        _ctrl.forward();
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        _ctrl.reverse();
      },
      onTapCancel: () {
        setState(() => _pressed = false);
        _ctrl.reverse();
      },
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          constraints: const BoxConstraints(minHeight: 52),
          decoration: BoxDecoration(
            color: _pressed
                ? accent.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Accent icon container ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â 40ÃƒÆ’Ã¢â‚¬â€40
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(widget.icon, color: accent, size: 18),
              ),
              const SizedBox(width: 12),
              // Label + sub
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label,
                      style: _T.navTitle.copyWith(color: c.textPrimary),
                    ),
                    Text(
                      widget.sub,
                      style: _T.navSub.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Trailing
              if (widget.trailing != null)
                widget.trailing!
              else if (widget.locked)
                _LockPill(c: c)
              else
                Icon(
                  LucideIcons.chevronRight,
                  color: c.textSecondary.withValues(alpha: 0.4),
                  size: 14,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// LOCK PILL
// -----------------------------------------------------------------------------

class _LockPill extends StatelessWidget {
  const _LockPill({required this.c});
  final AppColor c;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: c.border.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lock_outline_rounded, size: 9, color: c.textSecondary),
        const SizedBox(width: 3),
        Text('Sign in', style: _T.micro.copyWith(color: c.textSecondary)),
      ],
    ),
  );
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({
    required this.count,
    required this.c,
    required this.color,
  });

  final int count;
  final AppColor c;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.28),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: _T.badge.copyWith(
          color: c.onPrimary,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// VERSION ROW
// -----------------------------------------------------------------------------

class _VersionRow extends StatelessWidget {
  const _VersionRow({required this.info, required this.c});
  final PackageInfo info;
  final AppColor c;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          LucideIcons.package,
          size: 9,
          color: c.textSecondary.withValues(alpha: 0.4),
        ),
        const SizedBox(width: 5),
        Text(
          '${info.appName}  v${info.version}',
          style: _T.version.copyWith(
            color: c.textSecondary.withValues(alpha: 0.4),
          ),
        ),
      ],
    ),
  );
}

// -----------------------------------------------------------------------------
// LOGOUT TILE
// -----------------------------------------------------------------------------

class _LogoutTile extends StatefulWidget {
  const _LogoutTile({
    required this.isLoading,
    required this.c,
    required this.onTap,
  });
  final bool isLoading;
  final AppColor c;
  final VoidCallback onTap;

  @override
  State<_LogoutTile> createState() => _LogoutTileState();
}

class _LogoutTileState extends State<_LogoutTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.isLoading ? null : widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.fromLTRB(10, 4, 10, 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        constraints: const BoxConstraints(minHeight: 52),
        decoration: BoxDecoration(
          color: _pressed
              ? c.error.withValues(alpha: 0.07)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.error.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(11),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: widget.isLoading
                    ? SizedBox(
                        key: const ValueKey('l'),
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(c.error),
                        ),
                      )
                    : Icon(
                        key: const ValueKey('i'),
                        LucideIcons.logOut,
                        color: c.error,
                        size: 17,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.isLoading ? 'Signing out...' : 'Sign Out',
                style: _T.logoutLabel.copyWith(color: c.error),
              ),
            ),
            if (!widget.isLoading)
              Icon(
                LucideIcons.chevronRight,
                color: c.error.withValues(alpha: 0.45),
                size: 13,
              ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// PROFILE SHIMMER
// -----------------------------------------------------------------------------

class _ProfileShimmer extends StatefulWidget {
  const _ProfileShimmer({required this.topPadding, required this.c});
  final double topPadding;
  final AppColor c;

  @override
  State<_ProfileShimmer> createState() => _ProfileShimmerState();
}

class _ProfileShimmerState extends State<_ProfileShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark
        ? c.border.withValues(alpha: 0.7)
        : c.textPrimary.withValues(alpha: 0.07);
    final shine = isDark
        ? c.surface.withValues(alpha: 0.9)
        : Colors.white.withValues(alpha: 0.9);

    Widget box(double w, double h, {double r = 6}) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(r),
      ),
    );

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => LayoutBuilder(
        builder: (_, constraints) {
          final tw = constraints.maxWidth;
          final band = tw * 0.26;
          final dx = -band + (_ctrl.value * (tw + band * 2));

          return Container(
            color: c.surface,
            child: Stack(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [c.primary, c.primary.withValues(alpha: 0)],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        18,
                        widget.topPadding + 18,
                        18,
                        16,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          box(64, 64, r: 32),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                box(110, 17, r: 6),
                                const SizedBox(height: 7),
                                box(75, 11, r: 4),
                                const SizedBox(height: 5),
                                box(130, 10, r: 4),
                                const SizedBox(height: 9),
                                Row(
                                  children: [
                                    box(62, 22, r: 6),
                                    const SizedBox(width: 7),
                                    box(52, 22, r: 6),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 1,
                      color: c.border.withValues(alpha: 0.5),
                    ),
                  ],
                ),
                // Shimmer sweep
                Positioned.fill(
                  child: IgnorePointer(
                    child: Transform.translate(
                      offset: Offset(dx, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: band,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                shine.withValues(alpha: 0),
                                shine.withValues(alpha: isDark ? 0.18 : 0.40),
                                shine.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// LOGOUT MODAL
// -----------------------------------------------------------------------------

class _LogoutModal extends StatelessWidget {
  const _LogoutModal();

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: c.textPrimary.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.error.withValues(alpha: 0.08),
                  border: Border.all(
                    color: c.error.withValues(alpha: 0.18),
                    width: 1.5,
                  ),
                ),
                child: Icon(LucideIcons.logOut, color: c.error, size: 22),
              ),
              const SizedBox(height: 14),
              Text(
                'Sign Out?',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                "You'll need to sign in again\nto access your account.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: c.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              // Confirm button
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context, true);
                },
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: c.error,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Yes, Sign Out',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: c.onPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Cancel button
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context, false);
                },
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: c.border.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 14.5,
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
