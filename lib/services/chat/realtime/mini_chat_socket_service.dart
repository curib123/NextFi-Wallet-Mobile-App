import 'dart:async';

import 'package:next_fi/services/base_url/base_url.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../models/chat_dtos.dart';
import '../models/chat_models.dart';

typedef MiniChatTokenProvider = Future<String?> Function();

class MiniChatSocketStatus {
  final bool connecting;
  final bool connected;
  final bool joined;

  const MiniChatSocketStatus({
    required this.connecting,
    required this.connected,
    required this.joined,
  });

  bool get ready => connected && joined;
}

class MiniChatSocketService {
  MiniChatSocketService({required this.threadId, required this.tokenProvider});

  final String threadId;
  final MiniChatTokenProvider tokenProvider;

  final _statusCtrl = StreamController<MiniChatSocketStatus>.broadcast();
  final _messagesCtrl = StreamController<ChatDirectMessageModel>.broadcast();
  final _acksCtrl = StreamController<String>.broadcast();
  final _errorsCtrl = StreamController<String>.broadcast();

  io.Socket? _socket;
  MiniChatSocketStatus _status = const MiniChatSocketStatus(
    connecting: false,
    connected: false,
    joined: false,
  );
  bool _disposed = false;

  Stream<MiniChatSocketStatus> get statusStream => _statusCtrl.stream;
  Stream<ChatDirectMessageModel> get messagesStream => _messagesCtrl.stream;
  Stream<String> get ackStream => _acksCtrl.stream;
  Stream<String> get errorsStream => _errorsCtrl.stream;
  MiniChatSocketStatus get status => _status;

  Future<void> connect() async {
    if (_disposed || _socket != null) return;

    _updateStatus(
      const MiniChatSocketStatus(
        connecting: true,
        connected: false,
        joined: false,
      ),
    );

    final token = (await tokenProvider())?.trim();
    if (token == null || token.isEmpty) {
      _emitError('Realtime chat token is missing. Please login again.');
      _updateStatus(
        const MiniChatSocketStatus(
          connecting: false,
          connected: false,
          joined: false,
        ),
      );
      return;
    }

    final socketUrl = _miniChatSocketUrl();
    final socket = io.io(
      socketUrl,
      io.OptionBuilder()
          .setTransports(const ['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setAuth({'token': token})
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .build(),
    );
    _socket = socket;

    socket.onConnect((_) {
      _updateStatus(
        const MiniChatSocketStatus(
          connecting: false,
          connected: true,
          joined: false,
        ),
      );
      _emitJoinThread();
    });

    socket.onDisconnect((_) {
      _updateStatus(
        const MiniChatSocketStatus(
          connecting: false,
          connected: false,
          joined: false,
        ),
      );
    });

    socket.onConnectError((dynamic error) {
      _emitError(_humanizeError(error, fallback: 'Unable to connect chat.'));
      _updateStatus(
        const MiniChatSocketStatus(
          connecting: false,
          connected: false,
          joined: false,
        ),
      );
    });

    socket.onError((dynamic error) {
      _emitError(_humanizeError(error, fallback: 'Mini chat socket error.'));
    });

    socket.on('joined_thread', (dynamic payload) {
      final payloadThreadId = _readStringFromPayload(payload, const [
        'threadId',
        'thread_id',
      ]);
      if (payloadThreadId.isNotEmpty && payloadThreadId != threadId) return;
      _updateStatus(
        const MiniChatSocketStatus(
          connecting: false,
          connected: true,
          joined: true,
        ),
      );
    });

    socket.on('join_denied', (dynamic payload) {
      final reason = _readStringFromPayload(payload, const ['reason']);
      _updateStatus(
        const MiniChatSocketStatus(
          connecting: false,
          connected: true,
          joined: false,
        ),
      );
      _emitError(
        reason.isEmpty
            ? 'Chat room access denied.'
            : 'Chat room denied: $reason',
      );
    });

    socket.on('message_error', (dynamic payload) {
      final reason = _readStringFromPayload(payload, const [
        'reason',
        'message',
      ]);
      _emitError(
        reason.isEmpty
            ? 'Message rejected by server.'
            : 'Message rejected: $reason',
      );
    });

    socket.on('chat_message', (dynamic payload) {
      _emitMessageFromPayload(payload);
    });

    socket.on('new_message', (dynamic payload) {
      _emitMessageFromPayload(payload);
    });

    socket.on('message_ack', (dynamic payload) {
      final ackId = _readStringFromPayload(payload, const [
        'clientMessageId',
        'client_message_id',
        'id',
      ]);
      if (ackId.isEmpty || _acksCtrl.isClosed) return;
      _acksCtrl.add(ackId);
    });

    socket.connect();
  }

  bool sendMessage(SendEncryptedChatMessageRequest req) {
    final socket = _socket;
    if (socket == null || !_status.ready) {
      _emitError('Chat is reconnecting. Please wait before sending.');
      return false;
    }

    final payload = <String, dynamic>{'threadId': threadId, ...req.toJson()};
    socket.emit('send_message', payload);
    return true;
  }

  void retryJoin() {
    if (_disposed) return;
    _emitJoinThread();
  }

  void _emitJoinThread() {
    final socket = _socket;
    if (socket == null || !socket.connected) return;
    socket.emit('join_thread', {'threadId': threadId});
  }

  void _emitLeaveThread() {
    final socket = _socket;
    if (socket == null || !socket.connected) return;
    socket.emit('leave_thread', {'threadId': threadId});
  }

  void _emitMessageFromPayload(dynamic payload) {
    final map = _extractMessageMap(payload);
    if (map == null) return;

    final payloadThreadId = _readStringFromPayload(map, const [
      'threadId',
      'thread_id',
    ]);
    if (payloadThreadId.isNotEmpty && payloadThreadId != threadId) return;

    final message = ChatDirectMessageModel.fromJson(map);
    if (message.ciphertext.trim().isEmpty) return;
    if (_messagesCtrl.isClosed) return;
    _messagesCtrl.add(message);
  }

  Map<String, dynamic>? _extractMessageMap(dynamic payload) {
    final map = _asStringKeyMap(payload);
    if (map == null) return null;

    if (map.containsKey('ciphertext') &&
        map.containsKey('nonce') &&
        map.containsKey('senderKeyId')) {
      return map;
    }

    for (final key in const ['data', 'message', 'item', 'payload']) {
      final nested = _asStringKeyMap(map[key]);
      if (nested == null) continue;
      if (nested.containsKey('ciphertext') &&
          nested.containsKey('nonce') &&
          nested.containsKey('senderKeyId')) {
        return nested;
      }
    }

    return null;
  }

  void _updateStatus(MiniChatSocketStatus next) {
    if (_disposed) return;
    if (_status.connecting == next.connecting &&
        _status.connected == next.connected &&
        _status.joined == next.joined) {
      return;
    }
    _status = next;
    if (_statusCtrl.isClosed) return;
    _statusCtrl.add(next);
  }

  void _emitError(String error) {
    if (_disposed || _errorsCtrl.isClosed) return;
    _errorsCtrl.add(error);
  }

  String _miniChatSocketUrl() {
    final base = Uri.parse(cetralized_baseUrl);
    final socketUri = base.replace(
      path: '/mini-chat',
      query: null,
      fragment: null,
    );
    return socketUri.toString();
  }

  Map<String, dynamic>? _asStringKeyMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  String _readStringFromPayload(dynamic payload, List<String> keys) {
    final map = _asStringKeyMap(payload);
    if (map == null) return '';
    for (final key in keys) {
      final value = map[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String _humanizeError(dynamic error, {required String fallback}) {
    if (error == null) return fallback;
    final text = error.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;

    _emitLeaveThread();

    final socket = _socket;
    _socket = null;
    if (socket != null) {
      socket.off('joined_thread');
      socket.off('join_denied');
      socket.off('message_error');
      socket.off('chat_message');
      socket.off('new_message');
      socket.off('message_ack');
      socket.disconnect();
      socket.close();
    }

    _statusCtrl.close();
    _messagesCtrl.close();
    _acksCtrl.close();
    _errorsCtrl.close();
  }
}
