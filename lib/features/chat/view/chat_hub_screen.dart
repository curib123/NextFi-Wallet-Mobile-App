import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/button/app_buttons.dart';
import 'package:next_fi/common/components/loader/page_loader.dart';
import 'package:next_fi/common/components/modal/chat_consent_modal.dart';
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
        _chat.listIncomingFriendRequests(
          ChatListQuery(
            page: 1,
            limit: 50,
            q: q.isEmpty ? null : q,
            status: ChatFriendRequestStatus.pending,
          ),
        ),
        _chat.listOutgoingFriendRequests(
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
    } catch (_) {
      // Ask consent now when read fails.
    }

    final accepted = await showChatConsentModal(context);
    if (!accepted) return false;

    try {
      await SecurityStorage.save(_kChatConsentKey, 'accepted');
      await SecurityStorage.save(
        _kChatConsentAtKey,
        DateTime.now().toUtc().toIso8601String(),
      );
    } catch (_) {
      // Allow this session even if persistence fails.
    }
    return true;
  }

  Future<void> _sendFriendRequest() async {
    final receiverCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final c = AppColor.of(context);

    final payload = await showDialog<(String, String?)>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.surface,
        title: const Text('Send Friend Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: receiverCtrl,
              decoration: const InputDecoration(
                labelText: 'Receiver user ID',
                hintText: 'uuid',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
          ],
        ),
        actions: [
          AppTextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          AppElevatedButton(
            onPressed: () {
              final receiver = receiverCtrl.text.trim();
              if (receiver.isEmpty) return;
              final note = noteCtrl.text.trim();
              Navigator.of(context).pop((receiver, note.isEmpty ? null : note));
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );

    receiverCtrl.dispose();
    noteCtrl.dispose();
    if (payload == null) return;

    setState(() => _busy = true);
    try {
      await _chat.sendFriendRequest(
        SendChatFriendRequestRequest(receiverId: payload.$1, note: payload.$2),
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
        MaterialPageRoute(builder: (_) => ChatThreadScreen(thread: thread)),
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

  Widget _empty(AppColor c, String text) {
    return Center(
      child: Text(
        text,
        style: TextStyle(color: c.textSecondary, fontSize: 12.6),
      ),
    );
  }

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
        title: Text(
          'Messenger',
          style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: () => _load(showLoader: true),
            icon: Icon(Icons.refresh_rounded, color: c.textPrimary),
          ),
        ],
      ),
      body: _loading
          ? const PageLoader(label: 'Loading messenger...')
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    AppFilledButton(
                      onPressed: () => _load(showLoader: true),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : FadeTransition(
              opacity: _fade,
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: c.border.withOpacity(0.26)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Secure Mini Chat',
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Encrypted payload fields + realtime thread rooms.',
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 12.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Threads: ${_threads.length}  |  Unread: $unreadCount  |  Requests: $pendingCount',
                          style: TextStyle(
                            color: c.primary,
                            fontSize: 11.8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: c.border.withOpacity(0.26)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            onSubmitted: (_) => _load(showLoader: false),
                            decoration: const InputDecoration(
                              hintText: 'Search...',
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        AppTextButton(
                          onPressed: () => _load(showLoader: false),
                          child: const Icon(Icons.search_rounded, size: 18),
                        ),
                      ],
                    ),
                  ),
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
                      tabs: const [
                        Tab(text: 'Threads'),
                        Tab(text: 'Friends'),
                        Tab(text: 'Requests'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabCtrl,
                      children: [
                        _threads.isEmpty
                            ? _empty(c, 'No threads yet.')
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  8,
                                ),
                                itemCount: _threads.length,
                                itemBuilder: (_, i) {
                                  final t = _threads[i];
                                  final title = _friendName(
                                    t.friendUser,
                                    'Direct Chat',
                                  );
                                  final preview = t.lastMessage == null
                                      ? 'No messages yet'
                                      : ChatEnvelopeCodec.decodeText(
                                          t.lastMessage!.ciphertext,
                                        );
                                  final at = t.updatedAt == null
                                      ? ''
                                      : _time.format(t.updatedAt!.toLocal());
                                  final unread = t.unreadCount;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: c.surface,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: c.border.withOpacity(0.26),
                                      ),
                                    ),
                                    child: ListTile(
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              ChatThreadScreen(thread: t),
                                        ),
                                      ),
                                      title: Text(
                                        title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        preview,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          if (at.isNotEmpty)
                                            Text(
                                              at,
                                              style: TextStyle(
                                                color: c.textSecondary,
                                                fontSize: 11,
                                              ),
                                            ),
                                          if (unread > 0) ...[
                                            const SizedBox(height: 4),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 7,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: c.primary.withOpacity(
                                                  0.12,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(99),
                                              ),
                                              child: Text(
                                                unread > 99
                                                    ? '99+'
                                                    : unread.toString(),
                                                style: TextStyle(
                                                  color: c.primary,
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                        _friends.isEmpty
                            ? _empty(c, 'No friends yet.')
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  8,
                                ),
                                itemCount: _friends.length,
                                itemBuilder: (_, i) {
                                  final f = _friends[i];
                                  final name = _friendName(
                                    f.friend,
                                    f.friendUserId,
                                  );
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: c.surface,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: c.border.withOpacity(0.26),
                                      ),
                                    ),
                                    child: ListTile(
                                      title: Text(name),
                                      subtitle: Text(
                                        _friendSubtitle(
                                          f.friend,
                                          f.friendUserId,
                                        ),
                                      ),
                                      trailing: AppTextButton(
                                        onPressed: _busy
                                            ? null
                                            : () => _openThreadWithFriend(f),
                                        style: TextButton.styleFrom(
                                          backgroundColor: c.primary
                                              .withOpacity(0.1),
                                          foregroundColor: c.primary,
                                        ),
                                        child: const Text('Chat'),
                                      ),
                                    ),
                                  );
                                },
                              ),
                        (_incoming.isEmpty && _outgoing.isEmpty)
                            ? _empty(c, 'No pending requests.')
                            : ListView(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  8,
                                ),
                                children: [
                                  for (final req in _incoming)
                                    _requestCard(
                                      c,
                                      title: _friendName(
                                        req.sender,
                                        req.senderId,
                                      ),
                                      subtitle: req.note ?? '',
                                      actions: [
                                        AppTextButton(
                                          onPressed: _busy
                                              ? null
                                              : () => _applyRequest(
                                                  req,
                                                  () =>
                                                      _chat.acceptFriendRequest(
                                                        req.id,
                                                      ),
                                                ),
                                          style: TextButton.styleFrom(
                                            backgroundColor: c.success
                                                .withOpacity(0.12),
                                            foregroundColor: c.success,
                                          ),
                                          child: const Text('Accept'),
                                        ),
                                        AppTextButton(
                                          onPressed: _busy
                                              ? null
                                              : () => _applyRequest(
                                                  req,
                                                  () =>
                                                      _chat.rejectFriendRequest(
                                                        req.id,
                                                      ),
                                                ),
                                          style: TextButton.styleFrom(
                                            backgroundColor: c.error
                                                .withOpacity(0.1),
                                            foregroundColor: c.error,
                                          ),
                                          child: const Text('Reject'),
                                        ),
                                      ],
                                    ),
                                  for (final req in _outgoing)
                                    _requestCard(
                                      c,
                                      title: _friendName(
                                        req.receiver,
                                        req.receiverId,
                                      ),
                                      subtitle: req.note ?? '',
                                      actions: [
                                        AppTextButton(
                                          onPressed: _busy
                                              ? null
                                              : () => _applyRequest(
                                                  req,
                                                  () =>
                                                      _chat.cancelFriendRequest(
                                                        req.id,
                                                      ),
                                                ),
                                          style: TextButton.styleFrom(
                                            backgroundColor: c.warning
                                                .withOpacity(0.1),
                                            foregroundColor: c.warning,
                                          ),
                                          child: const Text('Cancel'),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: AppElevatedButton.icon(
                        onPressed: _busy ? null : _sendFriendRequest,
                        icon: const Icon(
                          Icons.person_add_alt_1_rounded,
                          size: 16,
                        ),
                        label: const Text('Send Friend Request'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
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

  Widget _requestCard(
    AppColor c, {
    required String title,
    required String subtitle,
    required List<Widget> actions,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border.withOpacity(0.26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 13.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: c.textSecondary, fontSize: 12.1),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ),
    );
  }
}
