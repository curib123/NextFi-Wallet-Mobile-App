import 'dart:async';

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
  Timer? _searchDebounce;

  bool _loading = true;
  bool _busy = false;
  String? _error;

  List<ChatDirectThreadModel> _threads = const [];
  List<ChatFriendModel> _friends = const [];
  List<ChatFriendRequestModel> _incoming = const [];
  List<ChatFriendRequestModel> _outgoing = const [];

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

  Map<String, ChatFriendModel> get _friendsByUserId {
    final map = <String, ChatFriendModel>{};
    for (final f in _friends) {
      final id = f.friendUserId.trim().toLowerCase();
      if (id.isNotEmpty) map[id] = f;
    }
    return map;
  }

  Map<String, ChatFriendModel> get _friendsByUsername {
    final map = <String, ChatFriendModel>{};
    for (final f in _friends) {
      final username = (f.friend.username ?? '').trim().toLowerCase();
      if (username.isNotEmpty) map[username] = f;
    }
    return map;
  }

  List<ChatDirectThreadModel> _sortThreads(
    List<ChatDirectThreadModel> threads,
  ) {
    final sorted = [...threads];
    DateTime stamp(ChatDirectThreadModel t) =>
        t.lastMessage?.createdAt ??
        t.updatedAt ??
        t.createdAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
    sorted.sort((a, b) => stamp(b).compareTo(stamp(a)));
    return sorted;
  }

  ChatFriendModel? _resolvedThreadFriendModel(ChatDirectThreadModel t) {
    final idKey = t.friendUserId.trim().toLowerCase();
    if (idKey.isNotEmpty) {
      final byId = _friendsByUserId[idKey];
      if (byId != null) return byId;
    }
    final threadUsername = (t.friendUser?.username ?? '').trim().toLowerCase();
    if (threadUsername.isNotEmpty) {
      final byUsername = _friendsByUsername[threadUsername];
      if (byUsername != null) return byUsername;
    }
    return null;
  }

  ChatUserLite? _resolvedThreadFriend(ChatDirectThreadModel t) {
    return _resolvedThreadFriendModel(t)?.friend ?? t.friendUser;
  }

  String _threadFriendName(ChatDirectThreadModel t) {
    final id = t.friendUserId.trim();
    final name = _friendName(_resolvedThreadFriend(t), id);
    final normalized = name.trim();
    if (normalized.isNotEmpty) return normalized;
    if (id.isNotEmpty) return _looksLikeId(id) ? 'Friend' : id;
    return 'Friend';
  }

  String? _threadFriendAvatar(ChatDirectThreadModel t) {
    return _resolvedThreadFriend(t)?.avatarUrl;
  }

  String _threadFriendUsername(ChatDirectThreadModel t) {
    final username = _resolvedThreadFriend(t)?.username?.trim() ?? '';
    if (username.isNotEmpty) return '@$username';
    return '';
  }

  bool _isThreadFriendOnline(ChatDirectThreadModel t) {
    final friend = _resolvedThreadFriendModel(t);
    if (friend == null) return false;
    return _isFriendOnline(friend);
  }

  List<ChatDirectThreadModel> get _friendThreads {
    return _sortThreads(_threads);
  }

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
    _searchDebounce?.cancel();
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
      final query = const ChatListQuery(page: 1, limit: 50);
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
      final allThreads = (data[0] as ChatPaged<ChatDirectThreadModel>).items;
      final allFriends = (data[1] as ChatPaged<ChatFriendModel>).items;
      final allIncoming = (data[2] as ChatPaged<ChatFriendRequestModel>).items;
      final allOutgoing = (data[3] as ChatPaged<ChatFriendRequestModel>).items;

      final threads = _sortThreads(_filterThreads(allThreads, q));
      final friends = _sortFriends(_filterFriends(allFriends, q));
      final incoming = _filterRequests(allIncoming, q);
      final outgoing = _filterRequests(allOutgoing, q);

      if (!mounted) return;
      setState(() {
        _threads = threads;
        _friends = friends;
        _incoming = incoming;
        _outgoing = outgoing;
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
      backgroundColor: AppColor.of(context).surface,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Friend request sent.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
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
        MaterialPageRoute(
          builder: (_) => ChatThreadScreen(
            thread: thread,
            username: friend.friend.username,
            avatarUrl: friend.friend.avatarUrl,
          ),
        ),
      );
      if (mounted) await _load(showLoader: false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmRemoveFriend(ChatFriendModel friend) async {
    final c = AppColor.of(context);
    final name = _friendName(friend.friend, friend.friendUserId);

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColor.of(context).surface,
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
                  color: c.border.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: c.error.withValues(alpha: 0.1),
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
                        side: BorderSide(color: c.border.withValues(alpha: 0.35)),
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
                        foregroundColor: c.onPrimary,
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
    if (username.isNotEmpty) return '@$username';
    if (email.isNotEmpty) return email;
    return fallback;
  }

  String _presenceLabel(ChatFriendModel friend) {
    if (_isFriendOnline(friend)) return 'Online';
    final lastSeen = friend.friendLastSeenAt;
    if (lastSeen != null) {
      return 'Last seen ${_relativeTime(lastSeen)}';
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

  bool _containsQuery(String source, String q) =>
      source.toLowerCase().contains(q.toLowerCase());

  List<ChatFriendModel> _filterFriends(List<ChatFriendModel> friends, String q) {
    final query = q.trim();
    if (query.isEmpty) return friends;
    return friends.where((f) {
      final name = _friendName(f.friend, f.friendUserId);
      final subtitle = _friendSubtitle(f.friend, '');
      return _containsQuery(name, query) || _containsQuery(subtitle, query);
    }).toList();
  }

  List<ChatDirectThreadModel> _filterThreads(
    List<ChatDirectThreadModel> threads,
    String q,
  ) {
    final query = q.trim();
    if (query.isEmpty) return threads;
    return threads.where((t) {
      final title = _threadFriendName(t);
      final previewRaw = t.lastMessage == null
          ? ''
          : ChatEnvelopeCodec.decodeText(t.lastMessage!.ciphertext);
      final preview = previewRaw.trim().isEmpty ? 'Message' : previewRaw.trim();
      return _containsQuery(title, query) || _containsQuery(preview, query);
    }).toList();
  }

  List<ChatFriendRequestModel> _filterRequests(
    List<ChatFriendRequestModel> requests,
    String q,
  ) {
    final query = q.trim();
    if (query.isEmpty) return requests;
    return requests.where((r) {
      final sender = _friendName(r.sender, r.senderId);
      final receiver = _friendName(r.receiver, r.receiverId);
      final note = r.note ?? '';
      return _containsQuery(sender, query) ||
          _containsQuery(receiver, query) ||
          _containsQuery(note, query);
    }).toList();
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 250),
      () => _load(showLoader: false),
    );
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
    final unreadCount = _friendThreads.fold<int>(
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
            icon: Icon(Icons.refresh_rounded, color: c.textSecondary, size: 20),
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
                  color: c.primary.withValues(alpha: 0.12),
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
              color: c.textSecondary.withValues(alpha: 0.55),
              size: 19,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                onSubmitted: (_) => _load(showLoader: false),
                style: TextStyle(color: c.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search messages, friends…',
                  hintStyle: TextStyle(
                    color: c.textSecondary.withValues(alpha: 0.55),
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
          indicatorPadding: EdgeInsets.all(3),
          labelColor: c.onPrimary,
          unselectedLabelColor: c.textSecondary,
          indicator: BoxDecoration(
            color: c.primary,
            borderRadius: BorderRadius.circular(17),
            boxShadow: [
              BoxShadow(
                color: c.primary.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: c.surface,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          tabs: [
            _tab(c, 'Chats', unreadCount),
            _tab(c, 'Friends', _friends.length),
            _tab(c, 'Requests', pendingCount),
          ],
        ),
      ),
    );
  }

  Tab _tab(AppColor c, String label, int count) {
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
                color: c.onPrimary.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                count > 99 ? '99+' : count.toString(),
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: c.onPrimary,
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
                color: c.error.withValues(alpha: 0.08),
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
        if (_friendThreads.isEmpty)
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
              itemCount: _friendThreads.length,
              itemBuilder: (_, i) => _buildThreadTile(c, _friendThreads[i]),
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
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ChatUserAvatar(
                            name: name,
                            avatarUrl: f.friend.avatarUrl,
                            size: 50,
                          ),
                          if (_isFriendOnline(f))
                            Positioned(
                              right: 1,
                              bottom: 1,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: c.success,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: c.background,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
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
    final resolvedFriend = _resolvedThreadFriend(t);
    final title = _threadFriendName(t);
    final previewRaw = t.lastMessage == null
        ? 'No messages yet'
        : ChatEnvelopeCodec.decodeText(t.lastMessage!.ciphertext);
    final preview = previewRaw.trim().isEmpty
        ? (t.lastMessage == null ? 'No messages yet' : 'Message')
        : previewRaw.trim();
    final username = _threadFriendUsername(t);
    final stamp = t.lastMessage?.createdAt ?? t.updatedAt;
    final at = stamp == null ? '' : _relativeTime(stamp);
    final unread = t.unreadCount;
    final online = _isThreadFriendOnline(t);

    return InkWell(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatThreadScreen(
              thread: t,
              username: resolvedFriend?.username ?? t.friendUser?.username,
              avatarUrl: _threadFriendAvatar(t),
            ),
          ),
        );
        if (mounted) _load(showLoader: false);
      },
      splashColor: c.primary.withValues(alpha: 0.05),
      highlightColor: c.primary.withValues(alpha: 0.03),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: unread > 0
                  ? c.primary.withValues(alpha: 0.28)
                  : c.border.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ChatUserAvatar(
                    name: title,
                    avatarUrl: _threadFriendAvatar(t),
                    size: 50,
                  ),
                  if (online)
                    Positioned(
                      right: 1,
                      bottom: 1,
                      child: Container(
                        width: 12,
                        height: 12,
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
                    Row(
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
                        if (at.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            at,
                            style: TextStyle(
                              color: unread > 0 ? c.primary : c.textSecondary,
                              fontSize: 11.5,
                              fontWeight: unread > 0
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (username.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.textSecondary, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 3),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: unread > 0
                            ? c.textPrimary.withValues(alpha: 0.9)
                            : c.textSecondary,
                        fontSize: 13,
                        fontWeight: unread > 0
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: unread > 0
                      ? c.primary.withValues(alpha: 0.14)
                      : c.textSecondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  unread > 0
                      ? (unread > 99 ? 'Unread 99+' : 'Unread $unread')
                      : 'Read',
                  style: TextStyle(
                    color: unread > 0 ? c.primary : c.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
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
        final baseSubtitle = _friendSubtitle(f.friend, '');
        final presence = _presenceLabel(f);
        final subtitle = [
          baseSubtitle,
          presence,
        ].where((s) => s.trim().isNotEmpty).join(' · ');
        final unread = f.newUnreadMessageCount;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ChatUserAvatar(
                    name: name,
                    avatarUrl: f.friend.avatarUrl,
                    size: 50,
                  ),
                  if (_isFriendOnline(f))
                    Positioned(
                      right: 1,
                      bottom: 1,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: c.success,
                          shape: BoxShape.circle,
                          border: Border.all(color: c.background, width: 2),
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
                    style: TextStyle(
                      color: c.onPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              GestureDetector(
                onTap: _busy ? null : () => _openThreadWithFriend(f),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: c.primary.withValues(alpha: 0.1),
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
                    color: c.error.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    Icons.person_remove_outlined,
                    color: c.error.withValues(alpha: 0.75),
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
                                .withValues(alpha: 0.1),
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
                              color: c.textSecondary.withValues(alpha: 0.6),
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
                            foregroundColor: c.onPrimary,
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
                            side: BorderSide(color: c.error.withValues(alpha: 0.3)),
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
                        side: BorderSide(color: c.border.withValues(alpha: 0.35)),
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

  Widget _buildEmpty(AppColor c, String title, String subtitle, IconData icon) {
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
                color: c.textSecondary.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32,
                color: c.textSecondary.withValues(alpha: 0.35),
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
                    color: c.border.withValues(alpha: 0.4),
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
                      color: c.primary.withValues(alpha: 0.12),
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
                    borderSide: BorderSide(color: c.border.withValues(alpha: 0.22)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: c.border.withValues(alpha: 0.22)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: c.primary.withValues(alpha: 0.55),
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
                    borderSide: BorderSide(color: c.border.withValues(alpha: 0.22)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: c.border.withValues(alpha: 0.22)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: c.primary.withValues(alpha: 0.55),
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
                        side: BorderSide(color: c.border.withValues(alpha: 0.35)),
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
                        Navigator.of(
                          context,
                        ).pop((username, note.isEmpty ? null : note));
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: c.primary,
                        foregroundColor: c.onPrimary,
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


