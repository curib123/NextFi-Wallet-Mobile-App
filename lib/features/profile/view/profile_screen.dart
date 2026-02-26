import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/loader/page_loader.dart';
import 'package:next_fi/common/components/modal/chat_consent_modal.dart';
import 'package:next_fi/common/components/modal/profile_setup_modal.dart';
import 'package:next_fi/common/components/profile_avatar/user_avatar.dart';
import 'package:next_fi/features/chat/view/chat_hub_screen.dart';
import 'package:next_fi/features/chat/view/chat_thread_screen.dart';
import 'package:next_fi/features/verification_flow/view/verification_flow_screen.dart';
import 'package:next_fi/services/chat/chat_core_service.dart';
import 'package:next_fi/services/chat/models/chat_dtos.dart';
import 'package:next_fi/services/chat/models/chat_models.dart';
import 'package:next_fi/services/merchant_profile/merchant_profile_core_service.dart';
import 'package:next_fi/services/merchant_profile/models/merchant_profile_models.dart';
import 'package:next_fi/services/merchant_profile/models/merchant_tier_progress_models.dart';
import 'package:next_fi/services/oath2.0/auth_service.dart';
import 'package:next_fi/services/oath2.0/models/user_model.dart';
import 'package:next_fi/services/profile/models/profile_models.dart';
import 'package:next_fi/services/profile/profile_core_service.dart';
import 'package:next_fi/services/secure_storage/security_storage.dart';
import 'package:next_fi/services/verification/models/verification_models.dart';
import 'package:next_fi/services/verification/verification_core_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  static const String _kChatConsentKey = 'chat.user_consent.v1';
  static const String _kChatConsentAtKey = 'chat.user_consent_at.v1';

  final _auth = AuthService();
  final _profile = ProfileCoreService.I;
  final _verification = VerificationCoreService.I;
  final _merchantProfile = MerchantProfileCoreService.I;
  final _chat = ChatCoreService.I;
  final _date = DateFormat('MMM d, yyyy · HH:mm');

  late final AnimationController _fadeCtrl;
  late final AnimationController _slideCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  StreamSubscription<void>? _profileChangesSub;

  bool _loading = true;
  bool _busyChat = false;
  String? _error;

  User? _user;
  ProfileModel? _profileData;
  VerificationModel? _verificationData;
  MerchantProfileModel? _merchantProfileData;
  MerchantTierProgressModel? _tierProgress;
  List<ChatFriendModel> _friends = const [];

  List<ChatFriendModel> _sortFriends(List<ChatFriendModel> friends) {
    final sorted = [...friends];
    sorted.sort((a, b) {
      final online = (_isFriendOnline(b) ? 1 : 0) - (_isFriendOnline(a) ? 1 : 0);
      if (online != 0) return online;

      final unread = b.newUnreadMessageCount.compareTo(a.newUnreadMessageCount);
      if (unread != 0) return unread;

      final an = _friendName(a.friend, 'Friend').toLowerCase();
      final bn = _friendName(b.friend, 'Friend').toLowerCase();
      return an.compareTo(bn);
    });
    return sorted;
  }

  bool _looksLikeId(String value) {
    final v = value.trim();
    if (v.isEmpty) return false;
    if (v.length >= 24) return true;
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(v);
  }

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));

    _profileChangesSub = ProfileCoreService.changes.listen((_) {
      if (mounted) _load();
    });

    _load();
  }

  @override
  void dispose() {
    _profileChangesSub?.cancel();
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  Future<T?> _safe<T>(Future<T> Function() task) async {
    try {
      return await task();
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final authenticated = await _auth.isAuthenticated;
      if (!authenticated) {
        if (!mounted) return;
        setState(() {
          _user = null;
          _profileData = null;
          _verificationData = null;
          _merchantProfileData = null;
          _tierProgress = null;
          _friends = const [];
          _loading = false;
        });
        _fadeCtrl.forward(from: 0);
        _slideCtrl.forward(from: 0);
        return;
      }

      final results = await Future.wait([
        _safe<User>(() => _auth.currentUser),
        _safe<ProfileModel?>(() => _profile.getMe()),
        _safe<VerificationModel>(() => _verification.getMe()),
        _safe<MerchantProfileModel?>(() => _merchantProfile.getMe()),
        _safe<ChatPaged<ChatFriendModel>>(
          () => _chat.listFriends(const ChatListQuery(page: 1, limit: 50)),
        ),
      ]);

      final merchant = results[3] as MerchantProfileModel?;
      final tierProgress = merchant?.isApproved == true
          ? await _safe<MerchantTierProgressModel?>(
              () => _merchantProfile.getTierProgress(),
            )
          : null;

      if (!mounted) return;
      setState(() {
        _user = results[0] as User?;
        _profileData = results[1] as ProfileModel?;
        _verificationData = results[2] as VerificationModel?;
        _merchantProfileData = merchant;
        _tierProgress = tierProgress;
        _friends = _sortFriends(
          (results[4] as ChatPaged<ChatFriendModel>?)?.items ?? const [],
        );
        _loading = false;
      });
      _fadeCtrl.forward(from: 0);
      _slideCtrl.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openVerification() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const VerificationFlowScreen()));
    if (mounted) await _load();
  }

  Future<void> _editProfile() async {
    final changed = await showProfileSetupModal(context, initial: _profileData);
    if (changed == true && mounted) {
      _fadeCtrl.forward(from: 0);
    }
  }

  Future<void> _openMessenger() async {
    final consented = await _ensureChatConsent();
    if (!consented || !mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ChatHubScreen()));
    if (mounted) await _load();
  }

  Future<void> _openFriendChat(ChatFriendModel friend) async {
    if (_busyChat) return;
    final consented = await _ensureChatConsent();
    if (!consented || !mounted) return;
    setState(() => _busyChat = true);
    try {
      final thread = await _chat.openThreadWithFriend(friend.friendUserId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatThreadScreen(
            thread: thread,
            username: friend.friend.username,
            avatarUrl: friend.friend.avatarUrl,
          ),
        ),
      );
      if (mounted) await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busyChat = false);
    }
  }

  Future<bool> _ensureChatConsent() async {
    try {
      final stored = await SecurityStorage.read(_kChatConsentKey);
      if (stored == 'accepted') return true;
    } catch (_) {}
    if (!mounted) return false;
    final accepted = await showChatConsentModal(context);
    if (!accepted) return false;
    try {
      await SecurityStorage.save(_kChatConsentKey, 'accepted');
      await SecurityStorage.save(
        _kChatConsentAtKey,
        DateTime.now().toUtc().toIso8601String(),
      );
    } catch (_) {}
    return true;
  }

  String _displayName() {
    final profile = _profileData;
    final user = _user;
    if (profile?.displayName != null &&
        profile!.displayName!.trim().isNotEmpty) {
      return profile.displayName!.trim();
    }
    if (user != null && user.name.trim().isNotEmpty) return user.name.trim();
    if (user != null && user.email.trim().isNotEmpty) return user.email.trim();
    return 'Profile';
  }

  String _friendName(ChatUserLite? user, String fallback) {
    if (user == null) return _looksLikeId(fallback) ? 'Friend' : fallback;
    final display = user.displayName?.trim() ?? '';
    if (display.isNotEmpty) return display;
    final name = user.name.trim();
    if (name.isNotEmpty) return name;
    final username = user.username?.trim() ?? '';
    if (username.isNotEmpty) return '@$username';
    final email = user.email.trim();
    if (email.isNotEmpty) return email;
    return _looksLikeId(fallback) ? 'Friend' : fallback;
  }

  String _friendSubtitle(ChatUserLite? user, String fallback) {
    if (user == null) return fallback;
    final username = user.username?.trim() ?? '';
    final email = user.email.trim();
    if (username.isNotEmpty && email.isNotEmpty) return '@$username · $email';
    if (username.isNotEmpty) return '@$username';
    if (email.isNotEmpty) return email;
    return fallback;
  }

  bool _isFriendOnline(ChatFriendModel friend) {
    if (!friend.friendIsOnline) return false;
    final lastSeen = friend.friendLastSeenAt;
    if (lastSeen == null) return true;
    final diff = DateTime.now().difference(lastSeen.toLocal());
    return diff.inMinutes <= 2;
  }

  String _value(String? raw) {
    final text = raw?.trim() ?? '';
    return text.isEmpty ? '—' : text;
  }

  String _valueDate(DateTime? raw) =>
      raw == null ? '—' : _date.format(raw.toLocal());

  bool get _isMerchant => _merchantProfileData?.isApproved == true;

  ({String label, Color color, IconData icon}) _trustUi(AppColor c) {
    final status =
        _verificationData?.status ??
        ((_profileData?.isVerificationIdentityComplete ?? false)
            ? TrustStatus.ready
            : TrustStatus.basic);
    switch (status) {
      case TrustStatus.ready:
        return (
          label: 'Verified',
          color: c.success,
          icon: Icons.verified_rounded,
        );
      case TrustStatus.reviewing:
        return (
          label: 'In Review',
          color: c.warning,
          icon: Icons.hourglass_top_rounded,
        );
      case TrustStatus.suspended:
        return (label: 'Suspended', color: c.error, icon: Icons.block_rounded);
      case TrustStatus.basic:
        return (
          label: 'Basic',
          color: c.textSecondary,
          icon: Icons.shield_outlined,
        );
      case TrustStatus.unknown:
        return (
          label: 'Unknown',
          color: c.textSecondary,
          icon: Icons.help_outline_rounded,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);

    return Scaffold(
      backgroundColor: c.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        centerTitle: false,
        titleSpacing: 24,
        title: Text(
          'Profile',
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: c.surface,
                shape: BoxShape.circle,
                border: Border.all(color: c.border),
              ),
              child: Icon(
                Icons.refresh_rounded,
                color: c.textPrimary,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _loading
          ? const PageLoader(label: 'Loading profile...')
          : _error != null
          ? _ErrorState(message: _error!, onRetry: _load)
          : _user == null
          ? _LoggedOutState(onRetry: _load)
          : FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: RefreshIndicator(
                  onRefresh: _load,
                  color: c.primary,
                  backgroundColor: c.surface,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // Top safe area padding
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height:
                              MediaQuery.of(context).padding.top +
                              kToolbarHeight +
                              8,
                        ),
                      ),
                      // Hero section
                      SliverToBoxAdapter(
                        child: _HeroSection(
                          user: _user!,
                          profile: _profileData,
                          displayName: _displayName(),
                          tierProgress: _tierProgress,
                          trustUi: _trustUi(c),
                          onEditProfile: _editProfile,
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      // Stats row
                      if (_isMerchant && _tierProgress != null)
                        SliverToBoxAdapter(
                          child: _StatsRow(data: _tierProgress!),
                        ),
                      if (_isMerchant && _tierProgress != null)
                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      // Section header: Account
                      SliverToBoxAdapter(
                        child: _SectionHeader(label: 'Account'),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 10)),
                      // Account info items
                      SliverToBoxAdapter(
                        child: _AccountInfoCard(
                          profile: _profileData,
                          connectedEmail: _user!.email,
                          value: _value,
                          valueDate: _valueDate,
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      // Section header: Verification
                      SliverToBoxAdapter(
                        child: _SectionHeader(label: 'Verification'),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 10)),
                      SliverToBoxAdapter(
                        child: _VerificationCard(
                          ui: _trustUi(c),
                          verification: _verificationData,
                          onOpenVerification: _openVerification,
                        ),
                      ),
                      if (_isMerchant && _tierProgress != null) ...[
                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                        SliverToBoxAdapter(
                          child: _SectionHeader(label: 'Merchant Tier'),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 10)),
                        SliverToBoxAdapter(
                          child: _MerchantTierCard(data: _tierProgress!),
                        ),
                      ],
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      SliverToBoxAdapter(
                        child: _SectionHeader(
                          label: 'Friends',
                          trailing: GestureDetector(
                            onTap: _openMessenger,
                            child: Text(
                              'Messenger',
                              style: TextStyle(
                                color: c.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 10)),
                      SliverToBoxAdapter(
                        child: _FriendsSection(
                          friends: _friends,
                          busy: _busyChat,
                          friendName: _friendName,
                          friendSubtitle: _friendSubtitle,
                          onChatTap: _openFriendChat,
                          onOpenMessenger: _openMessenger,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: MediaQuery.of(context).padding.bottom + 32,
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

// ─────────────────────────────────────────────────────────────────────────────
// HERO SECTION — full-width cover with avatar, name, handle, edit button
// ─────────────────────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.user,
    required this.profile,
    required this.displayName,
    required this.tierProgress,
    required this.trustUi,
    required this.onEditProfile,
  });

  final User user;
  final ProfileModel? profile;
  final String displayName;
  final MerchantTierProgressModel? tierProgress;
  final ({String label, Color color, IconData icon}) trustUi;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final username = profile?.username?.trim();
    final handle = (username != null && username.isNotEmpty)
        ? '@$username'
        : null;
    final email = user.email.trim();
    final tier = tierProgress?.currentTier;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Avatar + cover gradient card
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [c.background, c.surface, c.surface],
                stops: const [0.0, 0.45, 1.0],
              ),
              border: Border.all(color: c.border),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Avatar with tier ring
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: tier != null
                                  ? _tierColor(tier)
                                  : c.primary,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                              child: UserAvatarLarge(user: user, colors: c),
                            ),
                          ),
                          // Online dot
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: c.success,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                height: 1.1,
                              ),
                            ),
                            if (handle != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                handle,
                                style: TextStyle(
                                  color: c.primary,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              email.isEmpty ? 'No email connected' : email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: c.textSecondary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                // Trust badge
                                _TrustBadge(ui: trustUi),
                                const SizedBox(width: 8),
                                // Tier badge
                                if (tier != null) _TierBadge(tier: tier),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Edit profile button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onEditProfile,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit Profile'),
              style: OutlinedButton.styleFrom(
                foregroundColor: c.textPrimary,
                side: BorderSide(color: c.border),
                backgroundColor: c.surface,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
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

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({required this.ui});
  final ({String label, Color color, IconData icon}) ui;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: ui.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ui.color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ui.icon, size: 12, color: c.onPrimary),
          const SizedBox(width: 5),
          Text(
            ui.label,
            style: TextStyle(
              color: c.onPrimary,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _TierBadge extends StatelessWidget {
  const _TierBadge({required this.tier});
  final MerchantTier tier;

  @override
  Widget build(BuildContext context) {
    final color = _tierColor(tier);
    final c = AppColor.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: _solidTint(color),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_tierIcon(tier), size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            _tierLabel(tier),
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATS ROW — compact metric cards
// ─────────────────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.data});
  final MerchantTierProgressModel data;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final nextPercent = data.nextTier?.progress.overallPercent ?? 100.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              icon: Icons.trending_up_rounded,
              iconColor: c.success,
              value: '${data.metrics.avgOfferSuccessRate.toStringAsFixed(1)}%',
              label: 'Success Rate',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              icon: Icons.star_rounded,
              iconColor: c.warning,
              value: data.metrics.avgReviewRating.toStringAsFixed(1),
              label: 'Avg Rating',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              icon: Icons.arrow_upward_rounded,
              iconColor: c.primary,
              value: '${nextPercent.toStringAsFixed(0)}%',
              label: data.nextTier == null
                  ? 'Top Tier'
                  : 'To ${_tierLabel(data.nextTier!.tier)}',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 14, 13, 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _solidTint(iconColor),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, this.trailing});
  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          if (trailing != null) ...[const Spacer(), trailing!],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACCOUNT INFO CARD — clean list rows
// ─────────────────────────────────────────────────────────────────────────────

class _AccountInfoCard extends StatelessWidget {
  const _AccountInfoCard({
    required this.profile,
    required this.connectedEmail,
    required this.value,
    required this.valueDate,
  });

  final ProfileModel? profile;
  final String connectedEmail;
  final String Function(String?) value;
  final String Function(DateTime?) valueDate;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final p = profile;

    final rows = [
      _RowData(
        icon: LucideIcons.mail,
        label: 'Email',
        value: connectedEmail.trim().isEmpty ? '—' : connectedEmail.trim(),
      ),
      _RowData(
        icon: LucideIcons.user,
        label: 'Username',
        value: value(p?.username),
      ),
      _RowData(
        icon: LucideIcons.badge,
        label: 'Display Name',
        value: value(p?.displayName),
      ),
      _RowData(
        icon: LucideIcons.globe2,
        label: 'Country',
        value: value(p?.country),
      ),
      _RowData(
        icon: LucideIcons.calendarDays,
        label: 'Member Since',
        value: valueDate(p?.createdAt),
      ),
      _RowData(
        icon: LucideIcons.refreshCw,
        label: 'Last Updated',
        value: valueDate(p?.updatedAt),
        isLast: true,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.border),
        ),
        child: Column(
          children: rows.map((row) => _InfoRow(data: row)).toList(),
        ),
      ),
    );
  }
}

class _RowData {
  const _RowData({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isLast;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.data});
  final _RowData data;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: c.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(data.icon, size: 16, color: c.textSecondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.label,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      data.value,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!data.isLast)
          Divider(height: 1, indent: 62, endIndent: 16, color: c.border),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VERIFICATION CARD
// ─────────────────────────────────────────────────────────────────────────────

class _VerificationCard extends StatelessWidget {
  const _VerificationCard({
    required this.ui,
    required this.verification,
    required this.onOpenVerification,
  });

  final ({String label, Color color, IconData icon}) ui;
  final VerificationModel? verification;
  final VoidCallback onOpenVerification;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.border),
        ),
        child: Column(
          children: [
            // Status banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: _solidTint(ui.color),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(17),
                ),
                border: Border(bottom: BorderSide(color: c.border)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _solidTint(ui.color),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(ui.icon, size: 16, color: ui.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account Status',
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ui.label,
                          style: TextStyle(
                            color: ui.color,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Details
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                children: [
                  _InfoRow(
                    data: _RowData(
                      icon: LucideIcons.phone,
                      label: 'Phone Number',
                      value:
                          verification?.phoneNumber?.trim().isNotEmpty == true
                          ? verification!.phoneNumber!
                          : 'Not submitted',
                    ),
                  ),
                  Divider(height: 1, color: c.border),
                  _InfoRow(
                    data: _RowData(
                      icon: LucideIcons.calendar,
                      label: 'Submitted At',
                      value: verification?.submittedAt == null
                          ? 'Not submitted'
                          : DateFormat(
                              'MMM d, yyyy · HH:mm',
                            ).format(verification!.submittedAt!.toLocal()),
                      isLast: true,
                    ),
                  ),
                ],
              ),
            ),
            // CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onOpenVerification,
                  icon: const Icon(Icons.verified_user_outlined, size: 16),
                  label: const Text('Open Verification'),
                  style: FilledButton.styleFrom(
                    backgroundColor: c.primary,
                    foregroundColor: c.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MERCHANT TIER CARD
// ─────────────────────────────────────────────────────────────────────────────

class _MerchantTierCard extends StatelessWidget {
  const _MerchantTierCard({required this.data});
  final MerchantTierProgressModel data;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!data.minimumData.met) ...[
              Container(
                margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: c.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.warning),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 15,
                      color: c.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'At least 1 offer and 1 review are required to rank above BRONZE.',
                        style: TextStyle(
                          color: c.warning,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: _TierSummaryCard(
                      title: 'Current Tier',
                      tier: data.currentTier,
                      subtitle: 'Active rank',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: data.nextTier == null
                        ? _TopTierCard()
                        : _TierSummaryCard(
                            title: 'Next Tier',
                            tier: data.nextTier!.tier,
                            subtitle:
                                '${data.nextTier!.progress.overallPercent.toStringAsFixed(0)}% progress',
                          ),
                  ),
                ],
              ),
            ),
            if (data.nextTier != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
                  decoration: BoxDecoration(
                    color: c.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.border),
                  ),
                  child: Text(
                    'Need +${data.nextTier!.progress.remainingSuccessRate.toStringAsFixed(1)}% success and +${data.nextTier!.progress.remainingAvgRating.toStringAsFixed(2)} rating',
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TierSummaryCard extends StatelessWidget {
  const _TierSummaryCard({
    required this.title,
    required this.tier,
    required this.subtitle,
  });

  final String title;
  final MerchantTier tier;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final color = _tierColor(tier);
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_tierIcon(tier), size: 14, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _tierLabel(tier),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 13.2,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 11.2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopTierCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final diamond = _tierColor(MerchantTier.diamond);
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Next Tier',
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.verified_rounded, size: 16, color: diamond),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Top Tier',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 13.2,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'DIAMOND achieved',
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 11.2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// FRIENDS SECTION
// ─────────────────────────────────────────────────────────────────────────────

class _FriendsSection extends StatelessWidget {
  const _FriendsSection({
    required this.friends,
    required this.busy,
    required this.friendName,
    required this.friendSubtitle,
    required this.onChatTap,
    required this.onOpenMessenger,
  });

  final List<ChatFriendModel> friends;
  final bool busy;
  final String Function(ChatUserLite? user, String fallback) friendName;
  final String Function(ChatUserLite? user, String fallback) friendSubtitle;
  final Future<void> Function(ChatFriendModel friend) onChatTap;
  final VoidCallback onOpenMessenger;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);

    if (friends.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.border),
          ),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _solidTint(c.primary),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.people_outline_rounded,
                  size: 24,
                  color: c.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'No friends yet',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Open Messenger to send friend requests.',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onOpenMessenger,
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                  label: const Text('Find Friends'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.primary,
                    side: BorderSide(color: c.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.border),
        ),
        child: Column(
          children: [
            for (var i = 0; i < friends.length; i++) ...[
              _FriendRow(
                friend: friends[i],
                busy: busy,
                friendName: friendName,
                friendSubtitle: friendSubtitle,
                onChatTap: onChatTap,
                isLast: i == friends.length - 1,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({
    required this.friend,
    required this.busy,
    required this.friendName,
    required this.friendSubtitle,
    required this.onChatTap,
    required this.isLast,
  });

  final ChatFriendModel friend;
  final bool busy;
  final String Function(ChatUserLite? user, String fallback) friendName;
  final String Function(ChatUserLite? user, String fallback) friendSubtitle;
  final Future<void> Function(ChatFriendModel friend) onChatTap;
  final bool isLast;

  String _presenceLabel(ChatFriendModel friend) {
    if (_isFriendOnline(friend)) return 'Online';
    final lastSeen = friend.friendLastSeenAt;
    if (lastSeen != null) {
      final now = DateTime.now();
      final local = lastSeen.toLocal();
      final diff = now.difference(local);
      if (diff.inMinutes < 1) return 'Last seen now';
      if (diff.inMinutes < 60) return 'Last seen ${diff.inMinutes}m';
      if (diff.inHours < 24) return 'Last seen ${diff.inHours}h';
      if (diff.inDays < 7) return 'Last seen ${diff.inDays}d';
      return 'Last seen ${DateFormat('MMM d').format(local)}';
    }
    final status = friend.friendStatus.trim();
    if (status.isNotEmpty) {
      return status[0].toUpperCase() + status.substring(1).toLowerCase();
    }
    return '';
  }

  bool _isFriendOnline(ChatFriendModel friend) {
    if (!friend.friendIsOnline) return false;
    final lastSeen = friend.friendLastSeenAt;
    if (lastSeen == null) return true;
    final diff = DateTime.now().difference(lastSeen.toLocal());
    return diff.inMinutes <= 2;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final user = friend.friend;
    final title = friendName(user, 'Friend');
    final baseSubtitle = friendSubtitle(user, '');
    final presence = _presenceLabel(friend);
    final subtitle = [
      baseSubtitle,
      presence,
    ].where((s) => s.trim().isNotEmpty).join(' · ');
    final unread = friend.newUnreadMessageCount;
    return Material(
      color: Colors.transparent,
      child: Column(
        children: [
          InkWell(
            onTap: busy ? null : () => onChatTap(friend),
            borderRadius: isLast
                ? const BorderRadius.vertical(bottom: Radius.circular(17))
                : BorderRadius.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Avatar
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ChatUserAvatar(
                        name: title,
                        avatarUrl: user.avatarUrl,
                        size: 42,
                      ),
                      if (_isFriendOnline(friend))
                        Positioned(
                          right: 1,
                          bottom: 1,
                          child: Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                              color: c.success,
                              shape: BoxShape.circle,
                              border: Border.all(color: c.surface, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (unread > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: c.primary,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        unread > 99 ? '99+' : '$unread',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _solidTint(c.primary),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Message',
                      style: TextStyle(
                        color: c.primary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isLast)
            Divider(height: 1, indent: 70, endIndent: 16, color: c.border),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TIER HELPERS
// ─────────────────────────────────────────────────────────────────────────────

/// Returns a solid light-tint version of [color] suitable for chip/badge backgrounds.
/// Blends the color toward white at ~10% strength — no opacity involved.
Color _solidTint(Color color) {
  return Color.lerp(color, Colors.white, 0.88) ?? color;
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
  MerchantTier.bronze => 'Bronze',
  MerchantTier.silver => 'Silver',
  MerchantTier.gold => 'Gold',
  MerchantTier.platinum => 'Platinum',
  MerchantTier.diamond => 'Diamond',
};

// ─────────────────────────────────────────────────────────────────────────────
// ERROR STATE
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _solidTint(c.error),
              ),
              child: Icon(Icons.cloud_off_rounded, size: 26, color: c.error),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Try Again'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOGGED OUT STATE
// ─────────────────────────────────────────────────────────────────────────────

class _LoggedOutState extends StatelessWidget {
  const _LoggedOutState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _solidTint(c.primary),
              ),
              child: Icon(
                Icons.lock_outline_rounded,
                size: 26,
                color: c.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Sign in required',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please sign in to view your profile, verification status, and friends.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Refresh Session'),
              style: OutlinedButton.styleFrom(
                foregroundColor: c.primary,
                side: BorderSide(color: c.primary),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
