import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/button/app_buttons.dart';
import 'package:next_fi/common/components/loader/page_loader.dart';
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
  final _time = DateFormat('MMM d, HH:mm');

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

  String _statusText() {
    if (_socketStatus.ready) return 'Realtime connected to secure thread room.';
    if (_socketStatus.connecting) return 'Connecting to secure chat room...';
    if (_socketStatus.connected && !_socketStatus.joined) {
      return 'Connected. Joining thread room...';
    }
    return 'Realtime disconnected. Sending will fallback to API.';
  }

  Color _statusColor(AppColor c) {
    if (_socketStatus.ready) return c.success;
    if (_socketStatus.connecting) return c.warning;
    if (_socketStatus.connected) return c.warning;
    return c.error;
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
        titleSpacing: 20,
        title: Text(
          _friendTitle,
          style: TextStyle(
            color: c.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.35,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => _loadMessages(showLoader: false),
            icon: Icon(Icons.refresh_rounded, color: c.textPrimary, size: 19),
          ),
        ],
      ),
      body: _loading
          ? const PageLoader(label: 'Loading thread...')
          : _error != null
          ? _buildErrorState(c)
          : _buildContent(c),
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
    final accent = _statusColor(c);
    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border.withOpacity(0.25)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.025),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.11),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(Icons.lock_rounded, color: accent, size: 15),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusText(),
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 12.2,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
              if (_socketError != null && _socketError!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  _socketError!,
                  style: TextStyle(
                    color: c.error,
                    fontSize: 11.2,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Text(
                      'No messages yet. Start the conversation.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.textSecondary, fontSize: 12.8),
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) {
                    final m = _messages[i];
                    final mine =
                        _currentUserId != null && m.senderId == _currentUserId;
                    final text = ChatEnvelopeCodec.decodeText(m.ciphertext);
                    final timestamp = m.createdAt == null
                        ? ''
                        : _time.format(m.createdAt!.toLocal());
                    final pending = (() {
                      final cid = m.clientMessageId?.trim() ?? '';
                      if (cid.isEmpty) return false;
                      return _pendingClientMessageIds.contains(cid);
                    })();

                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.fromLTRB(11, 9, 11, 8),
                        constraints: const BoxConstraints(maxWidth: 290),
                        decoration: BoxDecoration(
                          color: mine ? c.primary : c.surface,
                          borderRadius: BorderRadius.circular(13),
                          border: mine
                              ? null
                              : Border.all(color: c.border.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              text,
                              style: TextStyle(
                                color: mine ? Colors.white : c.textPrimary,
                                fontSize: 12.9,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  timestamp,
                                  style: TextStyle(
                                    color: mine
                                        ? Colors.white.withOpacity(0.72)
                                        : c.textSecondary,
                                    fontSize: 10.7,
                                  ),
                                ),
                                if (mine && pending) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    'Sending...',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.72),
                                      fontSize: 10.7,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(top: BorderSide(color: c.border.withOpacity(0.25))),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputCtrl,
                  minLines: 1,
                  maxLines: 4,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    filled: true,
                    fillColor: c.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AppElevatedButton(
                onPressed: _sending ? null : _sendMessage,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(48, 46),
                  backgroundColor: c.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
