import 'dart:async';

import 'package:next_fi/services/base_url/base_url.dart';
import 'package:next_fi/services/trades/models/trades_models.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

typedef TradeChatTokenProvider = Future<String?> Function();

class TradeChatSocketStatus {
  final bool connecting;
  final bool connected;
  final bool joined;

  const TradeChatSocketStatus({
    required this.connecting,
    required this.connected,
    required this.joined,
  });

  bool get ready => connected && joined;
}

class TradeChatSocketService {
  TradeChatSocketService({required this.tradeId, required this.tokenProvider});

  final String tradeId;
  final TradeChatTokenProvider tokenProvider;

  final _statusCtrl = StreamController<TradeChatSocketStatus>.broadcast();
  final _messagesCtrl = StreamController<TradeMessageModel>.broadcast();
  final _errorsCtrl = StreamController<String>.broadcast();

  io.Socket? _socket;
  TradeChatSocketStatus _status = const TradeChatSocketStatus(
    connecting: false,
    connected: false,
    joined: false,
  );
  bool _disposed = false;

  Stream<TradeChatSocketStatus> get statusStream => _statusCtrl.stream;
  Stream<TradeMessageModel> get messagesStream => _messagesCtrl.stream;
  Stream<String> get errorsStream => _errorsCtrl.stream;
  TradeChatSocketStatus get status => _status;

  Future<void> connect() async {
    if (_disposed || _socket != null) return;

    _updateStatus(
      const TradeChatSocketStatus(
        connecting: true,
        connected: false,
        joined: false,
      ),
    );

    final token = (await tokenProvider())?.trim();
    if (token == null || token.isEmpty) {
      _emitError('Realtime chat token is missing. Please login again.');
      _updateStatus(
        const TradeChatSocketStatus(
          connecting: false,
          connected: false,
          joined: false,
        ),
      );
      return;
    }

    final socketUrl = _tradeChatSocketUrl();
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
        const TradeChatSocketStatus(
          connecting: false,
          connected: true,
          joined: false,
        ),
      );
      _emitJoinTrade();
    });

    socket.onDisconnect((_) {
      _updateStatus(
        const TradeChatSocketStatus(
          connecting: false,
          connected: false,
          joined: false,
        ),
      );
    });

    socket.onConnectError((dynamic error) {
      _emitError(_humanizeError(error, fallback: 'Unable to connect chat.'));
      _updateStatus(
        const TradeChatSocketStatus(
          connecting: false,
          connected: false,
          joined: false,
        ),
      );
    });

    socket.onError((dynamic error) {
      _emitError(_humanizeError(error, fallback: 'Trade chat error.'));
    });

    socket.on('joined_trade', (dynamic payload) {
      final payloadTradeId = _readStringFromPayload(payload, const [
        'tradeId',
        'trade_id',
      ]);
      if (payloadTradeId.isNotEmpty && payloadTradeId != tradeId) return;
      _updateStatus(
        const TradeChatSocketStatus(
          connecting: false,
          connected: true,
          joined: true,
        ),
      );
    });

    socket.on('join_denied', (dynamic payload) {
      final reason = _readStringFromPayload(payload, const ['reason']);
      _updateStatus(
        const TradeChatSocketStatus(
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
      final reason = _readStringFromPayload(payload, const ['reason']);
      _emitError(
        reason.isEmpty
            ? 'Message rejected by server.'
            : 'Message rejected: $reason',
      );
    });

    socket.on('new_message', (dynamic payload) {
      final map = _asStringKeyMap(payload);
      if (map == null) return;
      final payloadTradeId = (map['tradeId'] ?? map['trade_id'])
          ?.toString()
          .trim();
      if (payloadTradeId != null &&
          payloadTradeId.isNotEmpty &&
          payloadTradeId != tradeId) {
        return;
      }
      final message = TradeMessageModel.fromJson(map);
      if (message.message.trim().isEmpty) return;
      if (_messagesCtrl.isClosed) return;
      _messagesCtrl.add(message);
    });

    socket.connect();
  }

  bool sendMessage(String message) {
    final text = message.trim();
    if (text.isEmpty) return false;
    if (text.length > 2000) {
      _emitError('Message is too long (max 2000 characters).');
      return false;
    }

    final socket = _socket;
    if (socket == null || !_status.ready) {
      _emitError('Chat is reconnecting. Please wait before sending.');
      return false;
    }

    socket.emit('send_message', {'tradeId': tradeId, 'message': text});
    return true;
  }

  void retryJoin() {
    if (_disposed) return;
    _emitJoinTrade();
  }

  void _emitJoinTrade() {
    final socket = _socket;
    if (socket == null || !socket.connected) return;
    socket.emit('join_trade', {'tradeId': tradeId});
  }

  void _updateStatus(TradeChatSocketStatus next) {
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

  String _tradeChatSocketUrl() {
    final base = Uri.parse(cetralized_baseUrl);
    final socketUri = base.replace(
      path: '/trade-chat',
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

    final socket = _socket;
    _socket = null;
    if (socket != null) {
      socket.off('joined_trade');
      socket.off('join_denied');
      socket.off('message_error');
      socket.off('new_message');
      socket.disconnect();
      socket.close();
    }

    _statusCtrl.close();
    _messagesCtrl.close();
    _errorsCtrl.close();
  }
}
