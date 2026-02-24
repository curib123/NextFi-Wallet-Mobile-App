import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/button/app_buttons.dart';
import 'package:next_fi/common/components/loader/page_loader.dart';
import 'package:next_fi/common/components/modal/chat_consent_modal.dart';
import 'package:next_fi/common/components/profile_avatar/user_avatar.dart';
import 'package:next_fi/features/chat/view/chat_thread_screen.dart';
import 'package:next_fi/services/chat/chat_core_service.dart';
import 'package:next_fi/services/chat/crypto/chat_envelope_codec.dart';
import 'package:next_fi/services/chat/models/chat_dtos.dart';
import 'package:next_fi/services/chat/models/chat_models.dart';
import 'package:next_fi/services/secure_storage/security_storage.dart';

class ChatHubScreen extends StatefulWidget {
  const ChatHubScreen({super.key});

  @override
  State<ChatHubScreen> createState() => _ChatHubScreenState();
}

class _ChatHubScreenState extends State<ChatHubScreen>
    with TickerProviderStateMixin {
  static const String _kChatConsentKey = 'chat.user_consent.v1';
  static const String _kChatConsentAtKey = 'chat.user_consent_at.v1';

  final _chat = ChatCoreService.I;
  final _searchCtrl = TextEditingController();

  late final TabController _tabCtrl;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;

  bool _loading = true;
  bool _busy = false;
  String? _error;

  List<ChatDirectThreadModel> _threads = const [];
  List<ChatFriendModel> _friends = const [];
  List<ChatFriendRequestModel> _incoming = const [];
  List<ChatFriendRequestModel> _outgoing = const [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bootstrap();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _fadeCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── service ───────────────────────────────────────────────────────────────

  Future<void> _load({required bool showLoader}) async {
    if (showLoader) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final q = _searchCtrl.text.trim();
      final query = ChatListQuery(page: 1, limit: 50, q: q.isEmpty ? null : q);
      final data = await Future.wait([
        _chat.listThreads(query),
        _chat.listFriends(query),
        _chat.listFriendRequests(
          ChatListQuery(
            page: 1,
            limit: 50,
            q: q.isEmpty ? null : q,
            status: ChatFriendRequestStatus.pending,
          ),
        ),
        _chat.listSentFriendRequests(
          ChatListQuery(
            page: 1,
            limit: 50,
            q: q.isEmpty ? null : q,
            status: ChatFriendRequestStatus.pending,
          ),
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _threads = (data[0] as ChatPaged<ChatDirectThreadModel>).items;
        _friends = (data[1] as ChatPaged<ChatFriendModel>).items;
        _incoming = (data[2] as ChatPaged<ChatFriendRequestModel>).items;
        _outgoing = (data[3] as ChatPaged<ChatFriendRequestModel>).items;
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

  Future<void> _bootstrap() async {
    final consented = await _ensureChatConsent();
    if (!mounted) return;
    if (!consented) {
      Navigator.of(context).maybePop();
      return;
    }
    await _load(showLoader: true);
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

  Future<void> _sendFriendRequest() async {
    final payload = await showModalBottomSheet<(String, String?)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddFriendSheet(),
    );

    if (payload == null) return;

    setState(() => _busy = true);
    try {
      await _chat.sendFriendRequest(
        SendChatFriendRequestRequest(
          receiverUsername: payload.$1,
          note: payload.$2,
        ),
      );
      await _load(showLoader: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request sent.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openThreadWithFriend(ChatFriendModel friend) async {
    setState(() => _busy = true);
    try {
      final thread = await _chat.openThreadWithFriend(friend.friendUserId);
      if (!mounted) return;
      setState(() => _busy = false);
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatThreadScreen(thread: thread)),
      );
      if (mounted) await _load(showLoader: false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _applyRequest(
    ChatFriendRequestModel req,
    Future<void> Function() action,
  ) async {
    setState(() => _busy = true);
    try {
      await action();
      await _load(showLoader: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmRemoveFriend(ChatFriendModel friend) async {
    final c = AppColor.of(context);
    final name = _friendName(friend.friend, friend.friendUserId);

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(28),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: c.border.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: c.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_remove_rounded,
                  color: c.error,
                  size: 26,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Remove Friend',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Remove $name from your friends?\nYou can add them again later.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: AppOutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        foregroundColor: c.textPrimary,
                        side: BorderSide(color: c.border.withOpacity(0.35)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: c.error,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Remove'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await _chat.removeFriendship(friend.friendshipId);
      await _load(showLoader: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── helpers ───────────────────────────────────────────────────────────────

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
    if (username.isNotEmpty) return '@$username';
    if (email.isNotEmpty) return email;
    return fallback;
  }

  String _relativeTime(DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    final diff = now.difference(local);
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7 && local.year == now.year) {
      return DateFormat('EEE').format(local);
    }
    return DateFormat('MMM d').format(local);
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final pendingCount = _incoming
        .where((r) => r.status == ChatFriendRequestStatus.pending)
        .length;
    final unreadCount = _threads.fold<int>(
      0,
      (sum, t) => sum + t.unreadCount,
    );

    return Scaffold(
      backgroundColor: c.background,
      appBar: _buildAppBar(c),
      body: _loading
          ? const PageLoader(label: 'Loading messages...')
          : _error != null
          ? _buildError(c)
          : FadeTransition(
              opacity: _fade,
              child: Column(
                children: [
                  _buildSearchBar(c),
                  _buildTabs(c, pendingCount, unreadCount),
                  Expanded(
                    child: TabBarView(
                      controller: _tabCtrl,
                      children: [
                        _buildThreadsTab(c),
                        _buildFriendsTab(c),
                        _buildRequestsTab(c),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppColor c) {
    return AppBar(
      backgroundColor: c.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 20,
      title: Text(
        'Messages',
        style: TextStyle(
          color: c.textPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 26,
          letterSpacing: -0.6,
        ),
      ),
      actions: [
        if (_busy)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: c.primary,
              ),
            ),
          )
        else ...[
          IconButton(
            onPressed: () => _load(showLoader: true),
            icon: Icon(
              Icons.refresh_rounded,
              color: c.textSecondary,
              size: 20,
            ),
            tooltip: 'Refresh',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _busy ? null : _sendFriendRequest,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.person_add_alt_1_rounded,
                  color: c.primary,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSearchBar(AppColor c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(21),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              color: c.textSecondary.withOpacity(0.55),
              size: 19,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onSubmitted: (_) => _load(showLoader: false),
                style: TextStyle(color: c.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search messages, friends…',
                  hintStyle: TextStyle(
                    color: c.textSecondary.withOpacity(0.55),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs(AppColor c, int pendingCount, int unreadCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: TabBar(
          controller: _tabCtrl,
          padding: EdgeInsets.zero,
          indicatorPadding: const EdgeInsets.all(3),
          labelColor: Colors.white,
          unselectedLabelColor: c.textSecondary,
          indicator: BoxDecoration(
            color: c.primary,
            borderRadius: BorderRadius.circular(17),
            boxShadow: [
              BoxShadow(
                color: c.primary.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          tabs: [
            _tab('Chats', unreadCount),
            _tab('Friends', _friends.length),
            _tab('Requests', pendingCount),
          ],
        ),
      ),
    );
  }

  Tab _tab(String label, int count) {
    return Tab(
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                count > 99 ? '99+' : count.toString(),
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildError(AppColor c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: c.error.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.wifi_off_rounded, color: c.error, size: 28),
            ),
            const SizedBox(height: 14),
            Text(
              'Could not load messages',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            AppFilledButton(
              onPressed: () => _load(showLoader: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Chats tab ─────────────────────────────────────────────────────────────

  Widget _buildThreadsTab(AppColor c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_friends.isNotEmpty) _buildFriendsStrip(c),
        if (_threads.isEmpty)
          Expanded(
            child: _buildEmpty(
              c,
              'No conversations yet',
              'Message a friend to get started.',
              Icons.chat_bubble_outline_rounded,
            ),
          )
        else ...[
          if (_friends.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
              child: Text(
                'RECENT',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: _threads.length,
              itemBuilder: (_, i) => _buildThreadTile(c, _threads[i]),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFriendsStrip(AppColor c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            'FRIENDS',
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
        ),
        SizedBox(
          height: 84,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            itemCount: _friends.length,
            itemBuilder: (_, i) {
              final f = _friends[i];
              final name = _friendName(f.friend, f.friendUserId);
              final firstName = name.split(' ').first;
              return GestureDetector(
                onTap: _busy ? null : () => _openThreadWithFriend(f),
                child: Container(
                  width: 62,
                  margin: const EdgeInsets.only(right: 6),
                  child: Column(
                    children: [
                      ChatUserAvatar(
                        name: name,
                        avatarUrl: f.friend.avatarUrl,
                        size: 50,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        firstName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildThreadTile(AppColor c, ChatDirectThreadModel t) {
    final title = _friendName(t.friendUser, 'Direct Chat');
    final preview = t.lastMessage == null
        ? 'No messages yet'
        : ChatEnvelopeCodec.decodeText(t.lastMessage!.ciphertext);
    final at = t.updatedAt == null ? '' : _relativeTime(t.updatedAt!);
    final unread = t.unreadCount;

    return InkWell(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ChatThreadScreen(thread: t)),
        );
        if (mounted) _load(showLoader: false);
      },
      splashColor: c.primary.withOpacity(0.05),
      highlightColor: c.primary.withOpacity(0.03),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ChatUserAvatar(
                  name: title,
                  avatarUrl: t.friendUser?.avatarUrl,
                  size: 52,
                ),
                if (unread > 0)
                  Positioned(
                    bottom: 1,
                    right: 1,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: c.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.background, width: 2.5),
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 15,
                            fontWeight: unread > 0
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (at.isNotEmpty)
                        Text(
                          at,
                          style: TextStyle(
                            color: unread > 0
                                ? c.primary
                                : c.textSecondary,
                            fontSize: 11.5,
                            fontWeight: unread > 0
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: unread > 0
                                ? c.textPrimary.withOpacity(0.82)
                                : c.textSecondary,
                            fontSize: 13,
                            fontWeight: unread > 0
                                ? FontWeight.w500
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (unread > 1) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2.5,
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
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Friends tab ───────────────────────────────────────────────────────────

  Widget _buildFriendsTab(AppColor c) {
    if (_friends.isEmpty) {
      return _buildEmpty(
        c,
        'No friends yet',
        'Tap + to send a friend request.',
        Icons.people_outline_rounded,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: _friends.length,
      itemBuilder: (_, i) {
        final f = _friends[i];
        final name = _friendName(f.friend, f.friendUserId);
        final subtitle = _friendSubtitle(f.friend, '');

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          child: Row(
            children: [
              ChatUserAvatar(
                name: name,
                avatarUrl: f.friend.avatarUrl,
                size: 50,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _busy ? null : () => _openThreadWithFriend(f),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: c.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Message',
                    style: TextStyle(
                      color: c.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _busy ? null : () => _confirmRemoveFriend(f),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: c.error.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    Icons.person_remove_outlined,
                    color: c.error.withOpacity(0.75),
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Requests tab ──────────────────────────────────────────────────────────

  Widget _buildRequestsTab(AppColor c) {
    if (_incoming.isEmpty && _outgoing.isEmpty) {
      return _buildEmpty(
        c,
        'No pending requests',
        'Send a friend request to connect with someone.',
        Icons.inbox_outlined,
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (_incoming.isNotEmpty) ...[
          _sectionLabel(c, 'INCOMING'),
          for (final req in _incoming)
            _buildRequestCard(c, req, isIncoming: true),
        ],
        if (_outgoing.isNotEmpty) ...[
          if (_incoming.isNotEmpty) const SizedBox(height: 16),
          _sectionLabel(c, 'SENT'),
          for (final req in _outgoing)
            _buildRequestCard(c, req, isIncoming: false),
        ],
      ],
    );
  }

  Widget _sectionLabel(AppColor c, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4, left: 2),
      child: Text(
        text,
        style: TextStyle(
          color: c.textSecondary,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildRequestCard(
    AppColor c,
    ChatFriendRequestModel req, {
    required bool isIncoming,
  }) {
    final user = isIncoming ? req.sender : req.receiver;
    final name = isIncoming
        ? _friendName(req.sender, req.senderId)
        : _friendName(req.receiver, req.receiverId);
    final username = user?.username?.trim() ?? '';
    final avatarUrl = user?.avatarUrl;
    final note = req.note ?? '';
    final at = req.createdAt == null ? '' : _relativeTime(req.createdAt!);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChatUserAvatar(name: name, avatarUrl: avatarUrl, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (username.isNotEmpty)
                            Text(
                              '@$username',
                              style: TextStyle(
                                color: c.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: (isIncoming ? c.primary : c.textSecondary)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            isIncoming ? 'Incoming' : 'Sent',
                            style: TextStyle(
                              color: isIncoming ? c.primary : c.textSecondary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (at.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            at,
                            style: TextStyle(
                              color: c.textSecondary.withOpacity(0.6),
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                if (note.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    note,
                    style: TextStyle(color: c.textSecondary, fontSize: 12.5),
                  ),
                ],
                const SizedBox(height: 12),
                if (isIncoming)
                  Row(
                    children: [
                      Expanded(
                        child: AppElevatedButton(
                          onPressed: _busy
                              ? null
                              : () => _applyRequest(
                                    req,
                                    () => _chat.respondFriendRequest(
                                      req.id,
                                      RespondFriendRequestRequest(
                                        action: 'ACCEPTED',
                                      ),
                                    ),
                                  ),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(38),
                            backgroundColor: c.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11),
                            ),
                          ),
                          child: const Text(
                            'Accept',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppOutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _applyRequest(
                                    req,
                                    () => _chat.respondFriendRequest(
                                      req.id,
                                      RespondFriendRequestRequest(
                                        action: 'REJECTED',
                                      ),
                                    ),
                                  ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(38),
                            foregroundColor: c.error,
                            side: BorderSide(
                              color: c.error.withOpacity(0.3),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11),
                            ),
                          ),
                          child: const Text('Decline'),
                        ),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: AppOutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _applyRequest(
                                req,
                                () => _chat.cancelFriendRequest(req.id),
                              ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(38),
                        foregroundColor: c.textSecondary,
                        side: BorderSide(color: c.border.withOpacity(0.35)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                      child: const Text('Cancel Request'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(
    AppColor c,
    String title,
    String subtitle,
    IconData icon,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: c.textSecondary.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32,
                color: c.textSecondary.withOpacity(0.35),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add Friend bottom sheet ────────────────────────────────────────────────────

class _AddFriendSheet extends StatefulWidget {
  const _AddFriendSheet();

  @override
  State<_AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends State<_AddFriendSheet> {
  final _usernameCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(28),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.border.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: c.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.person_add_alt_1_rounded,
                      color: c.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add Friend',
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Search by username',
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _usernameCtrl,
                autofocus: true,
                textInputAction: TextInputAction.next,
                maxLength: 64,
                decoration: InputDecoration(
                  labelText: 'Username',
                  hintText: 'e.g. alice_merchant',
                  counterText: '',
                  prefixIcon: Icon(
                    Icons.alternate_email_rounded,
                    color: c.textSecondary,
                    size: 18,
                  ),
                  filled: true,
                  fillColor: c.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: c.border.withOpacity(0.22)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: c.border.withOpacity(0.22)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: c.primary.withOpacity(0.55),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _noteCtrl,
                minLines: 2,
                maxLines: 3,
                maxLength: 512,
                decoration: InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: "Hi! I'd like to connect with you.",
                  filled: true,
                  fillColor: c.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: c.border.withOpacity(0.22)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: c.border.withOpacity(0.22)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: c.primary.withOpacity(0.55),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: AppOutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        foregroundColor: c.textPrimary,
                        side: BorderSide(color: c.border.withOpacity(0.35)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppElevatedButton(
                      onPressed: () {
                        final username = _usernameCtrl.text.trim();
                        if (username.isEmpty) return;
                        final note = _noteCtrl.text.trim();
                        Navigator.of(context).pop(
                          (username, note.isEmpty ? null : note),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: c.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Send Request'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
