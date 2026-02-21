import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/button/app_buttons.dart';
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
import 'package:next_fi/services/oath2.0/auth_service.dart';
import 'package:next_fi/services/oath2.0/models/user_model.dart';
import 'package:next_fi/services/profile/models/profile_models.dart';
import 'package:next_fi/services/profile/profile_core_service.dart';
import 'package:next_fi/services/secure_storage/security_storage.dart';
import 'package:next_fi/services/verification/models/verification_models.dart';
import 'package:next_fi/services/verification/verification_core_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  static const String _kChatConsentKey = 'chat.user_consent.v1';
  static const String _kChatConsentAtKey = 'chat.user_consent_at.v1';

  final _auth = AuthService();
  final _profile = ProfileCoreService.I;
  final _verification = VerificationCoreService.I;
  final _chat = ChatCoreService.I;
  final _date = DateFormat('MMM d, y - HH:mm');

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;

  StreamSubscription<void>? _profileChangesSub;

  bool _loading = true;
  bool _busyChat = false;
  String? _error;

  User? _user;
  ProfileModel? _profileData;
  VerificationModel? _verificationData;
  List<ChatFriendModel> _friends = const [];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _profileChangesSub = ProfileCoreService.changes.listen((_) {
      if (mounted) _load();
    });

    _load();
  }

  @override
  void dispose() {
    _profileChangesSub?.cancel();
    _fadeCtrl.dispose();
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
          _friends = const [];
          _loading = false;
        });
        _fadeCtrl.forward(from: 0);
        return;
      }

      final results = await Future.wait([
        _safe<User>(() => _auth.currentUser),
        _safe<ProfileModel?>(() => _profile.getMe()),
        _safe<VerificationModel>(() => _verification.getMe()),
        _safe<ChatPaged<ChatFriendModel>>(
              () => _chat.listFriends(const ChatListQuery(page: 1, limit: 50)),
        ),
      ]);

      if (!mounted) return;
      setState(() {
        _user = results[0] as User?;
        _profileData = results[1] as ProfileModel?;
        _verificationData = results[2] as VerificationModel?;
        _friends =
            (results[3] as ChatPaged<ChatFriendModel>?)?.items ?? const [];
        _loading = false;
      });
      _fadeCtrl.forward(from: 0);
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
      // _load() already triggered by the changes stream.
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
        MaterialPageRoute(builder: (_) => ChatThreadScreen(thread: thread)),
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
    if (user == null) return fallback;
    final display = user.displayName?.trim() ?? '';
    if (display.isNotEmpty) return display;
    final name = user.name.trim();
    if (name.isNotEmpty) return name;
    final username = user.username?.trim() ?? '';
    if (username.isNotEmpty) return '@$username';
    final email = user.email.trim();
    return email.isEmpty ? fallback : email;
  }

  String _friendSubtitle(ChatUserLite? user, String fallback) {
    if (user == null) return fallback;
    final username = user.username?.trim() ?? '';
    final email = user.email.trim();
    if (username.isNotEmpty && email.isNotEmpty) return '@$username | $email';
    if (username.isNotEmpty) return '@$username';
    if (email.isNotEmpty) return email;
    return fallback;
  }

  String _value(String? raw) {
    final text = raw?.trim() ?? '';
    return text.isEmpty ? 'Not set' : text;
  }

  String _valueDate(DateTime? raw) =>
      raw == null ? 'Not set' : _date.format(raw.toLocal());

  ({String label, Color color, IconData icon}) _trustUi(AppColor c) {
    // Use isVerificationIdentityComplete (username set) as local fallback
    // when no verification record is available yet.
    final status =
        _verificationData?.status ??
            ((_profileData?.isVerificationIdentityComplete ?? false)
                ? TrustStatus.ready
                : TrustStatus.basic);
    switch (status) {
      case TrustStatus.ready:
        return (label: 'READY', color: c.success, icon: Icons.verified_rounded);
      case TrustStatus.reviewing:
        return (
        label: 'REVIEWING',
        color: c.warning,
        icon: Icons.hourglass_top_rounded,
        );
      case TrustStatus.suspended:
        return (label: 'SUSPENDED', color: c.error, icon: Icons.block_rounded);
      case TrustStatus.basic:
        return (
        label: 'BASIC',
        color: c.textSecondary,
        icon: Icons.shield_outlined,
        );
      case TrustStatus.unknown:
        return (
        label: 'UNKNOWN',
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
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        title: Text(
          'Profile',
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: Icon(Icons.refresh_rounded, color: c.textPrimary),
          ),
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
        child: RefreshIndicator(
          onRefresh: _load,
          color: c.primary,
          backgroundColor: c.surface,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              _HeroCard(
                user: _user!,
                profile: _profileData,
                displayName: _displayName(),
              ),
              const SizedBox(height: 14),
              _VerificationCard(
                ui: _trustUi(c),
                verification: _verificationData,
                onOpenVerification: _openVerification,
              ),
              const SizedBox(height: 14),
              _ProfileDataCard(
                profile: _profileData,
                connectedEmail: _user!.email,
                onEditProfile: _editProfile,
                value: _value,
                valueDate: _valueDate,
              ),
              const SizedBox(height: 14),
              _FriendsCard(
                friends: _friends,
                busy: _busyChat,
                friendName: _friendName,
                friendSubtitle: _friendSubtitle,
                onChatTap: _openFriendChat,
                onOpenMessenger: _openMessenger,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO CARD
// ─────────────────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.user,
    required this.profile,
    required this.displayName,
  });

  final User user;
  final ProfileModel? profile;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final username = profile?.username?.trim();
    final handle = (username != null && username.isNotEmpty)
        ? '@$username'
        : null;
    final email = user.email.trim();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border.withOpacity(0.26)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.primary.withOpacity(0.11), c.surface.withOpacity(0.78)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: c.primary.withOpacity(0.22), width: 2),
            ),
            child: UserAvatarLarge(user: user, colors: c),
          ),
          const SizedBox(width: 14),
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
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.35,
                  ),
                ),
                if (handle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    handle,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  email.isEmpty ? 'No connected email' : email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.textSecondary, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
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
    return _SectionCard(
      title: 'Verification',
      subtitle: 'Trust status and verification progress',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: ui.color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: ui.color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ui.icon, size: 14, color: ui.color),
            const SizedBox(width: 6),
            Text(
              ui.label,
              style: TextStyle(
                color: ui.color,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
      child: Column(
        children: [
          _DataLine(
            icon: LucideIcons.phone,
            label: 'Phone Number',
            value: verification?.phoneNumber?.trim().isNotEmpty == true
                ? verification!.phoneNumber!
                : 'Not submitted',
          ),
          const SizedBox(height: 10),
          _DataLine(
            icon: LucideIcons.calendar,
            label: 'Submitted At',
            value: verification?.submittedAt == null
                ? 'Not submitted'
                : DateFormat(
              'MMM d, y - HH:mm',
            ).format(verification!.submittedAt!.toLocal()),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: AppFilledButton.icon(
              onPressed: onOpenVerification,
              icon: const Icon(Icons.verified_user_rounded, size: 16),
              label: const Text('Open Verification'),
              style: FilledButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE DATA CARD
// Fields reflect ProfileModel: username, displayName, country, createdAt, updatedAt
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileDataCard extends StatelessWidget {
  const _ProfileDataCard({
    required this.profile,
    required this.connectedEmail,
    required this.onEditProfile,
    required this.value,
    required this.valueDate,
  });

  final ProfileModel? profile;
  final String connectedEmail;
  final VoidCallback onEditProfile;
  final String Function(String?) value;
  final String Function(DateTime?) valueDate;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final p = profile;

    return _SectionCard(
      title: 'Profile Data',
      subtitle: 'Current account profile information',
      trailing: AppTextButton.icon(
        onPressed: onEditProfile,
        icon: const Icon(Icons.edit_rounded, size: 15),
        label: const Text('Edit'),
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
      ),
      child: Column(
        children: [
          _DataLine(
            icon: LucideIcons.mail,
            label: 'Connected Email',
            value: connectedEmail.trim().isEmpty
                ? 'Not set'
                : connectedEmail.trim(),
          ),
          const SizedBox(height: 10),
          _DataLine(
            icon: LucideIcons.user,
            label: 'Username',
            value: value(p?.username),
          ),
          const SizedBox(height: 10),
          _DataLine(
            icon: LucideIcons.badge,
            label: 'Display Name',
            value: value(p?.displayName),
          ),
          const SizedBox(height: 10),
          _DataLine(
            icon: LucideIcons.globe2,
            label: 'Country',
            value: value(p?.country),
          ),
          const SizedBox(height: 10),
          _DataLine(
            icon: LucideIcons.calendarDays,
            label: 'Member Since',
            value: valueDate(p?.createdAt),
          ),
          const SizedBox(height: 10),
          _DataLine(
            icon: LucideIcons.refreshCw,
            label: 'Last Updated',
            value: valueDate(p?.updatedAt),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FRIENDS CARD
// ─────────────────────────────────────────────────────────────────────────────

class _FriendsCard extends StatelessWidget {
  const _FriendsCard({
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

    return _SectionCard(
      title: 'Friend List',
      subtitle: 'Tap a friend to open chat',
      trailing: AppTextButton.icon(
        onPressed: onOpenMessenger,
        icon: const Icon(Icons.forum_rounded, size: 15),
        label: const Text('Messenger'),
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
      ),
      child: friends.isEmpty
          ? Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No friends yet. Open Messenger to send requests.',
            style: TextStyle(color: c.textSecondary, fontSize: 12.6),
          ),
          const SizedBox(height: 10),
          AppOutlinedButton.icon(
            onPressed: onOpenMessenger,
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
            label: const Text('Open Friend Requests'),
            style: OutlinedButton.styleFrom(
              foregroundColor: c.primary,
              side: BorderSide(color: c.primary.withOpacity(0.34)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      )
          : Column(
        children: [
          for (var i = 0; i < friends.length; i++) ...[
            _FriendTile(
              friend: friends[i],
              busy: busy,
              friendName: friendName,
              friendSubtitle: friendSubtitle,
              onChatTap: onChatTap,
            ),
            if (i != friends.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({
    required this.friend,
    required this.busy,
    required this.friendName,
    required this.friendSubtitle,
    required this.onChatTap,
  });

  final ChatFriendModel friend;
  final bool busy;
  final String Function(ChatUserLite? user, String fallback) friendName;
  final String Function(ChatUserLite? user, String fallback) friendSubtitle;
  final Future<void> Function(ChatFriendModel friend) onChatTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final user = friend.friend;
    final title = friendName(user, friend.friendUserId);
    final subtitle = friendSubtitle(user, friend.friendUserId);

    return InkWell(
      onTap: busy ? null : () => onChatTap(friend),
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: c.background.withOpacity(0.35),
          border: Border.all(color: c.border.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: c.primary.withOpacity(0.12),
              child: Text(
                (title.isNotEmpty ? title[0] : '?').toUpperCase(),
                style: TextStyle(
                  color: c.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ),
            const SizedBox(width: 10),
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
                      fontSize: 13.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.textSecondary, fontSize: 11.8),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AppTextButton(
              onPressed: busy ? null : () => onChatTap(friend),
              style: TextButton.styleFrom(
                foregroundColor: c.primary,
                backgroundColor: c.primary.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
              ),
              child: const Text('Chat'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION CARD
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border.withOpacity(0.26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: c.textSecondary, fontSize: 12.4),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA LINE
// ─────────────────────────────────────────────────────────────────────────────

class _DataLine extends StatelessWidget {
  const _DataLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 15, color: c.textSecondary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 11.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
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
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.error.withOpacity(0.08),
              ),
              child: Icon(Icons.wifi_off_rounded, size: 24, color: c.error),
            ),
            const SizedBox(height: 12),
            Text(
              'Unable to load profile',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 12.6,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            AppFilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline_rounded, color: c.textSecondary, size: 32),
            const SizedBox(height: 10),
            Text(
              'No active login session.',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Please sign in to view profile, verification, and friend list.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 12.5),
            ),
            const SizedBox(height: 14),
            AppOutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Refresh Session'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}