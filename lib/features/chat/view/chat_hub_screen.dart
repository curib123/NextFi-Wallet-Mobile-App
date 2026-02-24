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
  final _time = DateFormat('MMM d, HH:mm');

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
      duration: const Duration(milliseconds: 360),
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
    final c = AppColor.of(context);
    final usernameCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    final payload = await showModalBottomSheet<(String, String?)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setS) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: c.border.withOpacity(0.25)),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: c.border.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: c.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(
                              Icons.person_add_alt_1_rounded,
                              color: c.primary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
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
                                'Find user by username',
                                style: TextStyle(
                                  color: c.textSecondary,
                                  fontSize: 12.2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: usernameCtrl,
                        autofocus: true,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Username',
                          hintText: 'e.g. alice_merchant',
                          prefixIcon: Icon(
                            Icons.alternate_email_rounded,
                            color: c.textSecondary,
                            size: 18,
                          ),
                          filled: true,
                          fillColor: c.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: c.border.withOpacity(0.24),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: c.border.withOpacity(0.24),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: c.primary.withOpacity(0.5),
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: noteCtrl,
                        minLines: 2,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Note (optional)',
                          hintText: "Hi! I'd like to connect with you.",
                          filled: true,
                          fillColor: c.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: c.border.withOpacity(0.24),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: c.border.withOpacity(0.24),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: c.primary.withOpacity(0.5),
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: AppOutlinedButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                foregroundColor: c.textPrimary,
                                side: BorderSide(
                                  color: c.border.withOpacity(0.4),
                                ),
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
                                final username = usernameCtrl.text.trim();
                                if (username.isEmpty) return;
                                final note = noteCtrl.text.trim();
                                Navigator.of(ctx).pop(
                                  (username, note.isEmpty ? null : note),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
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
          },
        );
      },
    );

    usernameCtrl.dispose();
    noteCtrl.dispose();
    if (payload == null) return;

    setState(() => _busy = true);
    try {
      await _chat.sendFriendRequest(
        SendChatFriendRequestRequest(
          receiverId: payload.$1,
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
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: c.border.withOpacity(0.2)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: c.border.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: c.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person_remove_rounded, color: c.error, size: 24),
              ),
              const SizedBox(height: 14),
              Text(
                'Remove Friend',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Remove $name from your friends?\nYou can add them again later.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: AppOutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: c.textPrimary,
                        side: BorderSide(color: c.border.withOpacity(0.4)),
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
                        minimumSize: const Size.fromHeight(48),
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
      await _chat.removeFriend(friend.friendUserId);
      await _load(showLoader: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── helpers ──────────────────────────────────────────────────────────────

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
    if (username.isNotEmpty && email.isNotEmpty) return '@$username · $email';
    if (username.isNotEmpty) return '@$username';
    if (email.isNotEmpty) return email;
    return fallback;
  }

  Widget _empty(AppColor c, String text) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_rounded,
            size: 38,
            color: c.textSecondary.withOpacity(0.4),
          ),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
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
      (sum, thread) => sum + thread.unreadCount,
    );

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Messages',
              style: TextStyle(
                color: c.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 20,
                letterSpacing: -0.4,
              ),
            ),
            if (!_loading && (unreadCount > 0 || pendingCount > 0))
              Text(
                [
                  if (unreadCount > 0) '$unreadCount unread',
                  if (pendingCount > 0)
                    '$pendingCount request${pendingCount > 1 ? 's' : ''}',
                ].join(' · '),
                style: TextStyle(
                  color: c.primary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        actions: [
          if (_busy)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: c.primary,
                ),
              ),
            )
          else
            IconButton(
              onPressed: () => _load(showLoader: true),
              icon: Icon(Icons.refresh_rounded, color: c.textSecondary, size: 20),
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: _loading
          ? const PageLoader(label: 'Loading messages...')
          : _error != null
          ? _buildError(c)
          : FadeTransition(
              opacity: _fade,
              child: Column(
                children: [
                  // Search + add friend bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(10, 0, 4, 0),
                            decoration: BoxDecoration(
                              color: c.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: c.border.withOpacity(0.26),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.search_rounded,
                                  color: c.textSecondary.withOpacity(0.6),
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: TextField(
                                    controller: _searchCtrl,
                                    onSubmitted: (_) =>
                                        _load(showLoader: false),
                                    style: TextStyle(
                                      color: c.textPrimary,
                                      fontSize: 13.5,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Search messages, friends…',
                                      hintStyle: TextStyle(
                                        color:
                                            c.textSecondary.withOpacity(0.6),
                                        fontSize: 13.5,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _busy ? null : _sendFriendRequest,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: c.primary,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.person_add_alt_1_rounded,
                              color: Colors.white,
                              size: 19,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Tabs
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: c.border.withOpacity(0.26)),
                    ),
                    child: TabBar(
                      controller: _tabCtrl,
                      labelColor: c.primary,
                      unselectedLabelColor: c.textSecondary,
                      indicatorColor: c.primary,
                      indicatorSize: TabBarIndicatorSize.label,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Chats'),
                              if (unreadCount > 0) ...[
                                const SizedBox(width: 5),
                                _badge(c, unreadCount),
                              ],
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Friends'),
                              if (_friends.isNotEmpty) ...[
                                const SizedBox(width: 5),
                                _countChip(c, _friends.length),
                              ],
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Requests'),
                              if (pendingCount > 0) ...[
                                const SizedBox(width: 5),
                                _badge(c, pendingCount),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
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

  Widget _buildError(AppColor c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: c.error.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.wifi_off_rounded, color: c.error, size: 26),
            ),
            const SizedBox(height: 12),
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
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
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
    if (_threads.isEmpty) {
      return _empty(c, 'No conversations yet.\nMessage a friend to get started.');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: _threads.length,
      itemBuilder: (_, i) {
        final t = _threads[i];
        final title = _friendName(t.friendUser, 'Direct Chat');
        final subtitle = _friendSubtitle(t.friendUser, '');
        final preview = t.lastMessage == null
            ? 'No messages yet'
            : ChatEnvelopeCodec.decodeText(t.lastMessage!.ciphertext);
        final at = t.updatedAt == null
            ? ''
            : _time.format(t.updatedAt!.toLocal());
        final unread = t.unreadCount;

        return GestureDetector(
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ChatThreadScreen(thread: t)),
            );
            if (mounted) _load(showLoader: false);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            decoration: BoxDecoration(
              color: unread > 0 ? c.primary.withOpacity(0.04) : c.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: unread > 0
                    ? c.primary.withOpacity(0.18)
                    : c.border.withOpacity(0.24),
              ),
            ),
            child: Row(
              children: [
                // Avatar
                ChatUserAvatar(
                  name: title,
                  avatarUrl: t.friendUser?.avatarUrl,
                  size: 44,
                ),
                const SizedBox(width: 11),
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
                                fontSize: 13.5,
                                fontWeight: unread > 0
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                          if (at.isNotEmpty)
                            Text(
                              at,
                              style: TextStyle(
                                color: unread > 0
                                    ? c.primary
                                    : c.textSecondary,
                                fontSize: 10.8,
                                fontWeight: unread > 0
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                        ],
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.textSecondary.withOpacity(0.7),
                            fontSize: 11.2,
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: unread > 0
                                    ? c.textPrimary.withOpacity(0.8)
                                    : c.textSecondary,
                                fontSize: 12.4,
                                fontWeight: unread > 0
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (unread > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: c.primary,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                unread > 99 ? '99+' : unread.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
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
        );
      },
    );
  }

  // ── Friends tab ───────────────────────────────────────────────────────────

  Widget _buildFriendsTab(AppColor c) {
    if (_friends.isEmpty) {
      return _empty(
        c,
        'No friends yet.\nTap + to send a friend request.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: _friends.length,
      itemBuilder: (_, i) {
        final f = _friends[i];
        final name = _friendName(f.friend, f.friendUserId);
        final subtitle = _friendSubtitle(f.friend, '');

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border.withOpacity(0.24)),
          ),
          child: Row(
            children: [
              ChatUserAvatar(
                name: name,
                avatarUrl: f.friend.avatarUrl,
                size: 44,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              // Action buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextButton(
                    onPressed: _busy ? null : () => _openThreadWithFriend(f),
                    style: TextButton.styleFrom(
                      backgroundColor: c.primary.withOpacity(0.1),
                      foregroundColor: c.primary,
                      minimumSize: const Size(64, 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text(
                      'Chat',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _busy ? null : () => _confirmRemoveFriend(f),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: c.error.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.person_remove_outlined,
                        color: c.error.withOpacity(0.8),
                        size: 16,
                      ),
                    ),
                  ),
                ],
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
      return _empty(c, 'No pending requests.');
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        if (_incoming.isNotEmpty) ...[
          _sectionLabel(c, 'INCOMING'),
          for (final req in _incoming)
            _requestCard(
              c,
              name: _friendName(req.sender, req.senderId),
              subtitle: req.note ?? '',
              avatarUrl: req.sender?.avatarUrl,
              isIncoming: true,
              actions: [
                Expanded(
                  child: AppElevatedButton(
                    onPressed: _busy
                        ? null
                        : () => _applyRequest(
                              req,
                              () => _chat.respondFriendRequest(
                                req.id,
                                RespondFriendRequestRequest(action: 'ACCEPTED'),
                              ),
                            ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(38),
                      backgroundColor: c.success,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Accept'),
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
                                RespondFriendRequestRequest(action: 'REJECTED'),
                              ),
                            ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(38),
                      foregroundColor: c.error,
                      side: BorderSide(color: c.error.withOpacity(0.35)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
              ],
            ),
        ],
        if (_outgoing.isNotEmpty) ...[
          if (_incoming.isNotEmpty) const SizedBox(height: 10),
          _sectionLabel(c, 'SENT'),
          for (final req in _outgoing)
            _requestCard(
              c,
              name: _friendName(req.receiver, req.receiverId),
              subtitle: req.note ?? '',
              avatarUrl: req.receiver?.avatarUrl,
              isIncoming: false,
              actions: [
                Expanded(
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
                      side: BorderSide(color: c.border.withOpacity(0.4)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Cancel Request'),
                  ),
                ),
              ],
            ),
        ],
      ],
    );
  }

  // ── small helpers ─────────────────────────────────────────────────────────

  Widget _sectionLabel(AppColor c, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        text,
        style: TextStyle(
          color: c.textSecondary,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _badge(AppColor c, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.primary,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _countChip(AppColor c, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.textSecondary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        count.toString(),
        style: TextStyle(
          color: c.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _requestCard(
    AppColor c, {
    required String name,
    required String subtitle,
    required String? avatarUrl,
    required bool isIncoming,
    required List<Widget> actions,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border.withOpacity(0.26)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChatUserAvatar(name: name, avatarUrl: avatarUrl, size: 42),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: (isIncoming ? c.primary : c.textSecondary)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
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
                  ],
                ),
                if (subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 12.2,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(children: actions),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
