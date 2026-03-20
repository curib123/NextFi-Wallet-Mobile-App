import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/core/widgets/loader/page_loader.dart';
import 'package:next_fi/core/widgets/profile_avatar/user_avatar.dart';
import 'package:next_fi/core/services/chat/chat_core_service.dart';
import 'package:next_fi/core/services/chat/crypto/chat_envelope_codec.dart';
import 'package:next_fi/core/services/chat/models/chat_dtos.dart';
import 'package:next_fi/core/services/chat/models/chat_models.dart';
import 'package:next_fi/core/services/chat/realtime/mini_chat_socket_service.dart';
import 'package:next_fi/core/services/auth/auth_service.dart';
import 'package:next_fi/core/services/secure_storage/security_storage.dart';
import 'package:next_fi/core/services/secure_storage/token_storage.dart';
import 'package:next_fi/core/widgets/snackbar/snack_bar.dart';

class ChatThreadScreen extends StatefulWidget {
  const ChatThreadScreen({
    super.key,
    required this.thread,
    this.username,
    this.avatarUrl,
  });

  final ChatDirectThreadModel thread;
  final String? username;
  final String? avatarUrl;

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
  bool _inputHasText = false;
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
    _inputCtrl.addListener(_onInputChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    _inputCtrl.removeListener(_onInputChanged);
    _socketStatusSub?.cancel();
    _socketMessageSub?.cancel();
    _socketAckSub?.cancel();
    _socketErrorSub?.cancel();
    _socket?.dispose();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    final has = _inputCtrl.text.trim().isNotEmpty;
    if (has != _inputHasText) setState(() => _inputHasText = has);
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
      if (mounted) setState(() => _loading = false);
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
      userIdProvider: () async => _currentUserId,
    );
    _socket = socket;

    _socketStatusSub = socket.statusStream.listen((status) {
      if (!mounted) return;
      setState(() {
        _socketStatus = status;
        if (status.ready) _socketError = null;
      });
      if (status.connected && !status.joined) socket.retryJoin();
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
    String? pendingClientId;
    try {
      final envelope = ChatEnvelopeCodec.encodeText(
        plainText: text,
        senderKeyId: senderKeyId,
      );
      pendingClientId = envelope.clientMessageId;
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
      if (!mounted) return;
      setState(() {
        _messages = _mergeMessages(_messages, [optimistic]);
        _pendingClientMessageIds.add(envelope.clientMessageId);
      });
      _inputCtrl.clear();
      _scrollToBottom();

      final saved = await _chat.sendThreadMessage(widget.thread.id, envelope);
      if (!mounted) return;
      setState(() {
        _messages = _mergeMessages(_messages, [saved]);
        _pendingClientMessageIds.remove(envelope.clientMessageId);
      });
      _scrollToBottom();
    } catch (e) {
      if (pendingClientId != null && pendingClientId.isNotEmpty) {
        setState(() => _pendingClientMessageIds.remove(pendingClientId));
      }
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
      final cid = m.clientMessageId?.trim() ?? '';
      if (cid.isNotEmpty) return 'cid:$cid';
      final id = m.id.trim();
      if (id.isNotEmpty) return 'id:$id';
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
    showFloatingSnackBar(context, message: message, type: SnackBarType.info);
  }

  bool _isSameSenderAsPrev(int index) {
    if (index == 0) return false;
    final prev = _messages[index - 1];
    final curr = _messages[index];
    if (prev.senderId != curr.senderId) return false;
    final a = prev.createdAt;
    final b = curr.createdAt;
    if (a == null || b == null) return false;
    return b.difference(a).inMinutes < 5;
  }

  bool _isSameSenderAsNext(int index) {
    if (index >= _messages.length - 1) return false;
    final curr = _messages[index];
    final next = _messages[index + 1];
    if (curr.senderId != next.senderId) return false;
    final a = curr.createdAt;
    final b = next.createdAt;
    if (a == null || b == null) return false;
    return b.difference(a).inMinutes < 5;
  }

  BorderRadius _bubbleRadius({
    required bool mine,
    required bool prevSame,
    required bool nextSame,
  }) {
    const full = Radius.circular(20);
    const tight = Radius.circular(5);
    if (mine) {
      return BorderRadius.only(
        topLeft: full,
        topRight: prevSame ? tight : full,
        bottomLeft: full,
        bottomRight: nextSame ? tight : full,
      );
    } else {
      return BorderRadius.only(
        topLeft: prevSame ? tight : full,
        topRight: full,
        bottomLeft: nextSame ? tight : full,
        bottomRight: full,
      );
    }
  }

  String get _friendTitle {
    final passedUsername = (widget.username ?? '').trim();
    if (passedUsername.isNotEmpty) {
      return passedUsername.startsWith('@')
          ? passedUsername
          : '@$passedUsername';
    }
    final f = widget.thread.friendUser;
    if (f == null) {
      final fallbackId = widget.thread.friendUserId.trim();
      if (fallbackId.isNotEmpty) {
        return '@${fallbackId.length > 12 ? fallbackId.substring(0, 12) : fallbackId}';
      }
      return '@friend';
    }
    final username = f.username?.trim() ?? '';
    if (username.isNotEmpty) return '@$username';
    final fallbackId = widget.thread.friendUserId.trim();
    if (fallbackId.isNotEmpty) {
      return '@${fallbackId.length > 12 ? fallbackId.substring(0, 12) : fallbackId}';
    }
    final email = f.email.trim();
    if (email.isNotEmpty) return email;
    final display = f.displayName?.trim() ?? '';
    if (display.isNotEmpty) return display;
    final name = f.name.trim();
    if (name.isNotEmpty) return name;
    return '@friend';
  }

  String get _friendSubtitle {
    final passedUsername = (widget.username ?? '').trim();
    if (passedUsername.isNotEmpty) return '';
    final f = widget.thread.friendUser;
    if (f == null) return '';
    final username = f.username?.trim() ?? '';
    if (username.isNotEmpty) {
      final email = f.email.trim();
      return email.isNotEmpty ? email : '';
    }
    final email = f.email.trim();
    return email.isNotEmpty ? email : '';
  }

  Color _statusColor(AppColor c) {
    if (_socketStatus.ready) return c.success;
    if (_socketStatus.connecting || _socketStatus.connected) return c.warning;
    return c.error;
  }

  String _statusText() {
    if (_socketStatus.ready) return 'End-to-end encrypted';
    if (_socketStatus.connecting) return 'Connecting...';
    if (_socketStatus.connected) return 'Joining room...';
    return 'Reconnecting...';
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

  String _dateLabel(DateTime dt) {
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
    return AppBar(
      backgroundColor: c.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 0,
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
          ChatUserAvatar(
            name: _friendTitle,
            avatarUrl: (widget.avatarUrl ?? '').trim().isNotEmpty
                ? widget.avatarUrl
                : widget.thread.friendUser?.avatarUrl,
            size: 38,
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
                        color: _statusColor(c),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        _friendSubtitle.isNotEmpty && _socketStatus.ready
                            ? '$_friendSubtitle | ${_statusText()}'
                            : _socketStatus.ready && _friendSubtitle.isEmpty
                            ? _statusText()
                            : _friendSubtitle.isNotEmpty
                            ? _friendSubtitle
                            : _statusText(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 11.5,
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
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: AppColor.of(context).border.withValues(alpha: 0.15),
        ),
      ),
    );
  }

  Widget _buildErrorState(AppColor c) {
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
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
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
        if (!_socketStatus.ready) _buildStatusBanner(c),
        if (_socketError != null && _socketError!.trim().isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            color: c.error.withValues(alpha: 0.07),
            child: Text(
              _socketError!,
              style: TextStyle(color: c.error, fontSize: 11.5),
              textAlign: TextAlign.center,
            ),
          ),
        if (_socketStatus.ready && _messages.isEmpty) _buildE2ENotice(c),
        Expanded(
          child: _messages.isEmpty
              ? _buildEmptyMessages(c)
              : _buildMessageList(c),
        ),
        _buildInputBar(c),
      ],
    );
  }

  Widget _buildStatusBanner(AppColor c) {
    final isConnecting = _socketStatus.connecting || _socketStatus.connected;
    final color = isConnecting ? c.warning : c.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      color: color.withValues(alpha: 0.08),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
          ),
          const SizedBox(width: 8),
          Text(
            _statusText(),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildE2ENotice(AppColor c) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_rounded,
            size: 11,
            color: c.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 4),
          Text(
            'End-to-end encrypted',
            style: TextStyle(
              color: c.textSecondary.withValues(alpha: 0.6),
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMessages(AppColor c) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: c.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock_rounded,
              size: 28,
              color: c.primary.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'End-to-end encrypted',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Messages are encrypted on your device.\nSay hello!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(AppColor c) {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _buildMessageItem(c, i),
    );
  }

  Widget _buildMessageItem(AppColor c, int i) {
    final m = _messages[i];
    final mine = _currentUserId != null && m.senderId == _currentUserId;
    final text = ChatEnvelopeCodec.decodeText(m.ciphertext);
    final timestamp = m.createdAt == null
        ? ''
        : _timeShort.format(m.createdAt!.toLocal());
    final pending = (() {
      final cid = m.clientMessageId?.trim() ?? '';
      if (cid.isEmpty) return false;
      return _pendingClientMessageIds.contains(cid);
    })();
    final showDate = m.createdAt != null && _showDateHeader(i);
    final prevSame = _isSameSenderAsPrev(i);
    final nextSame = _isSameSenderAsNext(i);
    final showAvatar = !mine && !nextSame;

    return Column(
      children: [
        if (showDate)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 16, bottom: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: c.border.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  _dateLabel(m.createdAt!),
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.only(bottom: nextSame ? 2 : 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: mine
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              if (!mine) ...[
                SizedBox(
                  width: 30,
                  child: showAvatar
                      ? ChatUserAvatar(
                          name: _friendTitle,
                          avatarUrl: widget.thread.friendUser?.avatarUrl,
                          size: 28,
                        )
                      : const SizedBox(width: 28),
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.70,
                  ),
                  child: Column(
                    crossAxisAlignment: mine
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
                        decoration: BoxDecoration(
                          color: mine ? c.primary : c.surface,
                          borderRadius: _bubbleRadius(
                            mine: mine,
                            prevSame: prevSame,
                            nextSame: nextSame,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: c.textPrimary.withValues(alpha: 0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          text,
                          style: TextStyle(
                            color: mine ? c.onPrimary : c.textPrimary,
                            fontSize: 14,
                            height: 1.38,
                          ),
                        ),
                      ),
                      if (!nextSame) ...[
                        const SizedBox(height: 3),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              timestamp,
                              style: TextStyle(
                                color: c.textSecondary.withValues(alpha: 0.65),
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
                                    ? c.textSecondary.withValues(alpha: 0.6)
                                    : c.primary,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (!mine) const SizedBox(width: 40),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputBar(AppColor c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(
          top: BorderSide(color: c.border.withValues(alpha: 0.15)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
                decoration: BoxDecoration(
                  color: c.background,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: c.border.withValues(alpha: 0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputCtrl,
                        minLines: 1,
                        maxLines: 5,
                        onSubmitted: (_) => _sendMessage(),
                        style: TextStyle(color: c.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Message...',
                          hintStyle: TextStyle(
                            color: c.textSecondary.withValues(alpha: 0.6),
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 11,
                          ),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 13,
                      color: c.textSecondary.withValues(alpha: 0.35),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _inputHasText
                    ? (_sending ? c.primary.withValues(alpha: 0.6) : c.primary)
                    : c.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                boxShadow: _inputHasText
                    ? [
                        BoxShadow(
                          color: c.primary.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: GestureDetector(
                onTap: (_sending || !_inputHasText) ? null : _sendMessage,
                child: Center(
                  child: _sending
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: c.onPrimary,
                          ),
                        )
                      : Icon(
                          Icons.send_rounded,
                          color: _inputHasText
                              ? c.onPrimary
                              : c.primary.withValues(alpha: 0.5),
                          size: 18,
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
