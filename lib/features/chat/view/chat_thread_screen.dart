import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/button/app_buttons.dart';
import 'package:next_fi/common/components/loader/page_loader.dart';
import 'package:next_fi/common/components/profile_avatar/user_avatar.dart';
import 'package:next_fi/services/chat/chat_core_service.dart';
import 'package:next_fi/services/chat/crypto/chat_envelope_codec.dart';
import 'package:next_fi/services/chat/models/chat_dtos.dart';
import 'package:next_fi/services/chat/models/chat_models.dart';
import 'package:next_fi/services/chat/realtime/mini_chat_socket_service.dart';
import 'package:next_fi/services/oath2.0/auth_service.dart';
import 'package:next_fi/services/secure_storage/security_storage.dart';
import 'package:next_fi/services/secure_storage/token_storage.dart';

class ChatThreadScreen extends StatefulWidget {
  const ChatThreadScreen({super.key, required this.thread});

  final ChatDirectThreadModel thread;

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen>
    with SingleTickerProviderStateMixin {
  static const String _kSenderKeyIdStoreKey = 'chat.sender_key_id.v1';

  final _chat = ChatCoreService.I;
  final _auth = AuthService();
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _timeShort = DateFormat('HH:mm');

  MiniChatSocketService? _socket;
  StreamSubscription<MiniChatSocketStatus>? _socketStatusSub;
  StreamSubscription<ChatDirectMessageModel>? _socketMessageSub;
  StreamSubscription<String>? _socketAckSub;
  StreamSubscription<String>? _socketErrorSub;

  bool _loading = true;
  bool _sending = false;
  String? _error;
  String? _socketError;
  String? _currentUserId;
  String? _senderKeyId;
  List<ChatDirectMessageModel> _messages = const [];
  final Set<String> _pendingClientMessageIds = <String>{};
  MiniChatSocketStatus _socketStatus = const MiniChatSocketStatus(
    connecting: false,
    connected: false,
    joined: false,
  );

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _socketStatusSub?.cancel();
    _socketMessageSub?.cancel();
    _socketAckSub?.cancel();
    _socketErrorSub?.cancel();
    _socket?.dispose();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final me = await _auth.currentUser;
      _currentUserId = me.id;
      _senderKeyId = await _ensureActiveSenderKeyId();
      await _loadMessages(showLoader: false);
      await _initSocket();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<String> _ensureActiveSenderKeyId() async {
    final stored = (await SecurityStorage.read(_kSenderKeyIdStoreKey))?.trim();
    final mine = await _chat.listMyKeys(
      const ChatListQuery(page: 1, limit: 50),
    );

    if (stored != null && stored.isNotEmpty) {
      final found = mine.items.where((k) => k.keyId == stored && k.isActive);
      if (found.isNotEmpty) return stored;
    }

    final existingActive = mine.items.firstWhere(
      (k) => k.isActive && k.keyId.trim().isNotEmpty,
      orElse: () => const ChatEncryptionKeyModel(
        userId: '',
        keyId: '',
        algorithm: '',
        publicKey: '',
        isActive: false,
      ),
    );
    if (existingActive.keyId.trim().isNotEmpty) {
      await SecurityStorage.save(_kSenderKeyIdStoreKey, existingActive.keyId);
      return existingActive.keyId;
    }

    final generated = ChatEnvelopeCodec.generateSenderKeyId();
    await _chat.upsertMyKey(
      ChatEnvelopeCodec.buildDeviceKeyUpsert(senderKeyId: generated),
    );
    await SecurityStorage.save(_kSenderKeyIdStoreKey, generated);
    return generated;
  }

  Future<void> _loadMessages({required bool showLoader}) async {
    if (showLoader) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final page = await _chat.listThreadMessages(
        widget.thread.id,
        const ChatListQuery(page: 1, limit: 100),
      );
      if (!mounted) return;
      final merged = _mergeMessages(_messages, page.items);
      setState(() {
        _messages = merged;
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _initSocket() async {
    _socketStatusSub?.cancel();
    _socketMessageSub?.cancel();
    _socketAckSub?.cancel();
    _socketErrorSub?.cancel();
    _socket?.dispose();

    final socket = MiniChatSocketService(
      threadId: widget.thread.id,
      tokenProvider: () async => TokenStorage().accessToken,
    );
    _socket = socket;

    _socketStatusSub = socket.statusStream.listen((status) {
      if (!mounted) return;
      setState(() {
        _socketStatus = status;
        if (status.ready) _socketError = null;
      });
      if (status.connected && !status.joined) {
        socket.retryJoin();
      }
    });

    _socketMessageSub = socket.messagesStream.listen((message) {
      if (!mounted) return;
      setState(() {
        _messages = _mergeMessages(_messages, [message]);
        final cid = message.clientMessageId?.trim();
        if (cid != null && cid.isNotEmpty) {
          _pendingClientMessageIds.remove(cid);
        }
      });
      _scrollToBottom();
    });

    _socketAckSub = socket.ackStream.listen((ackId) {
      if (!mounted) return;
      setState(() => _pendingClientMessageIds.remove(ackId));
    });

    _socketErrorSub = socket.errorsStream.listen((error) {
      if (!mounted) return;
      setState(() => _socketError = error);
    });

    await socket.connect();
  }

  Future<void> _sendMessage() async {
    if (_sending) return;
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    final senderKeyId = _senderKeyId?.trim();
    if (senderKeyId == null || senderKeyId.isEmpty) {
      _showSnack('Message key is not ready. Please refresh chat.');
      return;
    }

    setState(() => _sending = true);
    try {
      final envelope = ChatEnvelopeCodec.encodeText(
        plainText: text,
        senderKeyId: senderKeyId,
      );
      final optimistic = ChatDirectMessageModel(
        id: envelope.clientMessageId,
        threadId: widget.thread.id,
        senderId: _currentUserId ?? '',
        clientMessageId: envelope.clientMessageId,
        kind: envelope.kind,
        algorithm: envelope.algorithm,
        senderKeyId: envelope.senderKeyId,
        nonce: envelope.nonce,
        ciphertext: envelope.ciphertext,
        signature: envelope.signature,
        metadata: envelope.metadata,
        createdAt: DateTime.now().toUtc(),
      );

      final realtimeSent = _socket?.sendMessage(envelope) ?? false;
      if (realtimeSent) {
        if (!mounted) return;
        setState(() {
          _messages = _mergeMessages(_messages, [optimistic]);
          _pendingClientMessageIds.add(envelope.clientMessageId);
        });
        _inputCtrl.clear();
        _scrollToBottom();
        return;
      }

      final saved = await _chat.sendThreadMessage(widget.thread.id, envelope);
      if (!mounted) return;
      setState(() {
        _messages = _mergeMessages(_messages, [saved]);
      });
      _inputCtrl.clear();
      _scrollToBottom();
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  List<ChatDirectMessageModel> _mergeMessages(
    List<ChatDirectMessageModel> current,
    List<ChatDirectMessageModel> incoming,
  ) {
    final map = <String, ChatDirectMessageModel>{};

    String keyFor(ChatDirectMessageModel m) {
      final id = m.id.trim();
      if (id.isNotEmpty) return 'id:$id';
      final cid = m.clientMessageId?.trim() ?? '';
      if (cid.isNotEmpty) return 'cid:$cid';
      final ts = m.createdAt?.toUtc().toIso8601String() ?? '';
      return 'tmp:${m.senderId}|${m.ciphertext}|$ts';
    }

    for (final item in current) {
      map[keyFor(item)] = item;
    }
    for (final item in incoming) {
      map[keyFor(item)] = item;
    }

    final merged = map.values.toList();
    merged.sort(
      (a, b) => (a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
    );
    return merged;
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String get _friendTitle {
    final f = widget.thread.friendUser;
    if (f == null) return 'Direct Chat';
    final display = f.displayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final name = f.name.trim();
    if (name.isNotEmpty) return name;
    final username = f.username?.trim() ?? '';
    if (username.isNotEmpty) return '@$username';
    return f.email.trim().isNotEmpty ? f.email.trim() : 'Direct Chat';
  }

  String get _friendSubtitle {
    final f = widget.thread.friendUser;
    if (f == null) return '';
    final username = f.username?.trim() ?? '';
    final email = f.email.trim();
    if (username.isNotEmpty) return '@$username';
    if (email.isNotEmpty) return email;
    return '';
  }

  Color _statusDotColor(AppColor c) {
    if (_socketStatus.ready) return c.success;
    if (_socketStatus.connecting || _socketStatus.connected) return c.warning;
    return c.error;
  }

  String _statusText() {
    if (_socketStatus.ready) return 'End-to-end encrypted';
    if (_socketStatus.connecting) return 'Connecting...';
    if (_socketStatus.connected) return 'Joining room...';
    return 'Reconnecting — messages may be delayed';
  }

  bool _showDateHeader(int index) {
    if (index == 0) return true;
    final prev = _messages[index - 1].createdAt;
    final curr = _messages[index].createdAt;
    if (prev == null || curr == null) return false;
    final p = prev.toLocal();
    final c = curr.toLocal();
    return p.year != c.year || p.month != c.month || p.day != c.day;
  }

  String _dateHeader(DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return 'Today';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (local.year == yesterday.year &&
        local.month == yesterday.month &&
        local.day == yesterday.day) {
      return 'Yesterday';
    }
    return DateFormat('MMMM d, y').format(local);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: _buildAppBar(c),
      body: _loading
          ? const PageLoader(label: 'Loading messages...')
          : _error != null
          ? _buildErrorState(c)
          : _buildContent(c),
    );
  }

  PreferredSizeWidget _buildAppBar(AppColor c) {
    final dotColor = _statusDotColor(c);
    return AppBar(
      backgroundColor: c.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 4,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: c.textPrimary,
          size: 18,
        ),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Row(
        children: [
          // Avatar with network image support
          ChatUserAvatar(
            name: _friendTitle,
            avatarUrl: widget.thread.friendUser?.avatarUrl,
            size: 36,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _friendTitle,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: -0.2,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _friendSubtitle.isNotEmpty
                            ? _socketStatus.ready
                                ? '$_friendSubtitle · ${_statusText()}'
                                : _friendSubtitle
                            : _statusText(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 11.2,
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
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () => _loadMessages(showLoader: false),
          icon: Icon(Icons.refresh_rounded, color: c.textSecondary, size: 19),
        ),
      ],
    );
  }

  Widget _buildErrorState(AppColor c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
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
              'Cannot open thread',
              style: TextStyle(
                color: c.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            AppFilledButton.icon(
              onPressed: _bootstrap,
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

  Widget _buildContent(AppColor c) {
    return Column(
      children: [
        // Connection status banner (only show when not ready)
        if (!_socketStatus.ready)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: _socketStatus.connecting
                ? c.warning.withOpacity(0.08)
                : c.error.withOpacity(0.07),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 11,
                  height: 11,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: _socketStatus.connecting ? c.warning : c.error,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  _statusText(),
                  style: TextStyle(
                    color: _socketStatus.connecting ? c.warning : c.error,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        // Error banner
        if (_socketError != null && _socketError!.trim().isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            color: c.error.withOpacity(0.07),
            child: Text(
              _socketError!,
              style: TextStyle(color: c.error, fontSize: 11.2),
              textAlign: TextAlign.center,
            ),
          ),
        // Messages
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_rounded,
                        size: 32,
                        color: c.textSecondary.withOpacity(0.4),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'End-to-end encrypted',
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Messages are encrypted on your device.\nSay hello!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: c.textSecondary.withOpacity(0.65),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) {
                    final m = _messages[i];
                    final mine =
                        _currentUserId != null && m.senderId == _currentUserId;
                    final text = ChatEnvelopeCodec.decodeText(m.ciphertext);
                    final timestamp = m.createdAt == null
                        ? ''
                        : _timeShort.format(m.createdAt!.toLocal());
                    final pending = (() {
                      final cid = m.clientMessageId?.trim() ?? '';
                      if (cid.isEmpty) return false;
                      return _pendingClientMessageIds.contains(cid);
                    })();
                    final showDate =
                        m.createdAt != null && _showDateHeader(i);

                    return Column(
                      children: [
                        if (showDate) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: c.border.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  _dateHeader(m.createdAt!),
                                  style: TextStyle(
                                    color: c.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.72,
                            ),
                            child: Column(
                              crossAxisAlignment: mine
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    9,
                                    12,
                                    9,
                                  ),
                                  decoration: BoxDecoration(
                                    color: mine ? c.primary : c.surface,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(18),
                                      topRight: const Radius.circular(18),
                                      bottomLeft: mine
                                          ? const Radius.circular(18)
                                          : const Radius.circular(4),
                                      bottomRight: mine
                                          ? const Radius.circular(4)
                                          : const Radius.circular(18),
                                    ),
                                    border: mine
                                        ? null
                                        : Border.all(
                                            color: c.border.withOpacity(0.28),
                                          ),
                                  ),
                                  child: Text(
                                    text,
                                    style: TextStyle(
                                      color: mine
                                          ? Colors.white
                                          : c.textPrimary,
                                      fontSize: 13.5,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      timestamp,
                                      style: TextStyle(
                                        color: c.textSecondary.withOpacity(0.7),
                                        fontSize: 10.5,
                                      ),
                                    ),
                                    if (mine) ...[
                                      const SizedBox(width: 3),
                                      Icon(
                                        pending
                                            ? Icons.schedule_rounded
                                            : Icons.done_all_rounded,
                                        size: 13,
                                        color: pending
                                            ? c.textSecondary
                                            : c.primary,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
        // Input bar
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(
              top: BorderSide(color: c.border.withOpacity(0.2)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: c.background,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: c.border.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 14,
                          color: c.textSecondary.withOpacity(0.5),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: _inputCtrl,
                            minLines: 1,
                            maxLines: 4,
                            onSubmitted: (_) => _sendMessage(),
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 13.5,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Message…',
                              hintStyle: TextStyle(
                                color: c.textSecondary.withOpacity(0.6),
                                fontSize: 13.5,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 11),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sending ? null : _sendMessage,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _sending
                          ? c.primary.withOpacity(0.5)
                          : c.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                    ),
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
