import 'dart:convert';

import 'package:http/http.dart' as http;

import '../helpers/chat_exceptions.dart';
import '../helpers/chat_helpers.dart';
import '../models/chat_dtos.dart';
import '../models/chat_models.dart';
import 'chat_endpoints.dart';

typedef ChatTokenProvider = Future<String?> Function();

class ChatService {
  ChatService({required this.tokenProvider, http.Client? client})
    : _client = client ?? http.Client();

  final ChatTokenProvider tokenProvider;
  final http.Client _client;

  static const Set<String> _envelopeKeys = {
    'data',
    'item',
    'items',
    'meta',
    'success',
    'ok',
    'status',
    'message',
    'error',
    'errors',
    'total',
    'page',
    'limit',
    'totalPages',
    'total_pages',
    'pagination',
  };

  bool _isEnvelopeMap(Map<String, dynamic> map) =>
      map.keys.every((key) => _envelopeKeys.contains(key.toString()));

  Future<Map<String, String>> _headers() async {
    final token = await tokenProvider();
    if (token == null || token.isEmpty) {
      throw ChatApiException(401, 'Missing JWT token');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic>? _asStringKeyMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  Map<String, dynamic>? _extractMap(
    dynamic data, {
    List<String> keys = const [],
    int depth = 0,
  }) {
    if (depth > 8) return null;
    if (data == null || data == '') return null;
    if (data is String && data.trim().toLowerCase() == 'null') return null;

    if (data is List) {
      for (final item in data) {
        final extracted = _extractMap(item, keys: keys, depth: depth + 1);
        if (extracted != null) return extracted;
      }
      return null;
    }

    final map = _asStringKeyMap(data);
    if (map == null || map.isEmpty) return null;

    for (final key in keys) {
      if (!map.containsKey(key)) continue;
      final extracted = _extractMap(map[key], keys: keys, depth: depth + 1);
      if (extracted != null) return extracted;
    }

    if (!_isEnvelopeMap(map)) return map;

    for (final value in map.values) {
      final extracted = _extractMap(value, keys: keys, depth: depth + 1);
      if (extracted != null) return extracted;
    }

    return null;
  }

  List<Map<String, dynamic>> _extractListMaps(
    dynamic data, {
    List<String> keys = const [],
    int depth = 0,
  }) {
    if (depth > 8 || data == null) return const [];

    if (data is List) {
      final direct = data
          .map(_asStringKeyMap)
          .whereType<Map<String, dynamic>>()
          .toList();
      if (direct.isNotEmpty) return direct;

      for (final item in data) {
        final nested = _extractListMaps(item, keys: keys, depth: depth + 1);
        if (nested.isNotEmpty) return nested;
      }
      return const [];
    }

    final map = _asStringKeyMap(data);
    if (map == null) return const [];

    for (final key in keys) {
      if (!map.containsKey(key)) continue;
      final nested = _extractListMaps(map[key], keys: keys, depth: depth + 1);
      if (nested.isNotEmpty) return nested;
    }

    for (final value in map.values) {
      final nested = _extractListMaps(value, keys: keys, depth: depth + 1);
      if (nested.isNotEmpty) return nested;
    }

    return const [];
  }

  ChatPaginationMeta _extractMeta(dynamic data, {required int fallbackCount}) {
    final map = _asStringKeyMap(data);
    if (map != null) {
      final metaDirect = _asStringKeyMap(map['meta']);
      if (metaDirect != null) return ChatPaginationMeta.fromJson(metaDirect);

      final pagination = _asStringKeyMap(map['pagination']);
      if (pagination != null) return ChatPaginationMeta.fromJson(pagination);

      final maybeInlineMeta = ChatPaginationMeta.fromJson(map);
      if (maybeInlineMeta.page > 0 &&
          maybeInlineMeta.limit > 0 &&
          (map.containsKey('page') || map.containsKey('totalPages'))) {
        return maybeInlineMeta;
      }
    }

    return ChatPaginationMeta(
      total: fallbackCount,
      page: 1,
      limit: fallbackCount == 0 ? 20 : fallbackCount,
      totalPages: 1,
    );
  }

  ChatPaged<T> _toPaged<T>(
    dynamic data, {
    required List<String> itemKeys,
    required T Function(Map<String, dynamic> json) map,
  }) {
    final items = _extractListMaps(data, keys: itemKeys);
    final parsedItems = items.map(map).toList();
    final meta = _extractMeta(data, fallbackCount: parsedItems.length);
    return ChatPaged<T>(items: parsedItems, meta: meta);
  }

  Future<ChatPaged<ChatEncryptionKeyModel>> listMyKeys(
    ChatListQuery query,
  ) async {
    final res = await _client.get(
      ChatHttp.uri(ChatEndpoints.listMyKeys(), queryParams: query.toQueryMap()),
      headers: await _headers(),
    );

    ChatHttp.ensureOk(res);
    final data = ChatHttp.decodeJson<dynamic>(res);
    return _toPaged<ChatEncryptionKeyModel>(
      data,
      itemKeys: const ['items', 'keys', 'data', 'list'],
      map: ChatEncryptionKeyModel.fromJson,
    );
  }

  Future<ChatEncryptionKeyModel> upsertMyKey(
    UpsertChatEncryptionKeyRequest req,
  ) async {
    final res = await _client.post(
      ChatHttp.uri(ChatEndpoints.upsertMyKey()),
      headers: await _headers(),
      body: jsonEncode(req.toJson()),
    );

    ChatHttp.ensureOk(res);
    if (res.body.isEmpty) {
      return ChatEncryptionKeyModel(
        userId: '',
        keyId: req.keyId,
        algorithm: req.algorithm,
        publicKey: req.publicKey,
        signaturePublicKey: req.signaturePublicKey,
        isActive: req.isActive,
      );
    }
    final data = ChatHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'item', 'key']);
    if (map != null && map.isNotEmpty) {
      return ChatEncryptionKeyModel.fromJson(map);
    }
    return ChatEncryptionKeyModel(
      userId: '',
      keyId: req.keyId,
      algorithm: req.algorithm,
      publicKey: req.publicKey,
      signaturePublicKey: req.signaturePublicKey,
      isActive: req.isActive,
    );
  }

  Future<bool> deactivateMyKey(String keyId) async {
    final res = await _client.post(
      ChatHttp.uri(ChatEndpoints.deactivateMyKey(keyId)),
      headers: await _headers(),
      body: jsonEncode(const <String, dynamic>{}),
    );
    ChatHttp.ensureOk(res);
    final data = ChatHttp.decodeJson<dynamic>(res);
    final map = _asStringKeyMap(data);
    if (map == null) return true;
    final wrapped = _asStringKeyMap(map['data']);
    if (wrapped != null && wrapped['success'] is bool) {
      return wrapped['success'] as bool;
    }
    if (map['success'] is bool) return map['success'] as bool;
    return true;
  }

  Future<ChatPaged<ChatEncryptionKeyModel>> listUserPublicKeys(
    String userId,
    ChatListQuery query,
  ) async {
    final res = await _client.get(
      ChatHttp.uri(
        ChatEndpoints.listUserPublicKeys(userId),
        queryParams: query.toQueryMap(),
      ),
      headers: await _headers(),
    );

    ChatHttp.ensureOk(res);
    final data = ChatHttp.decodeJson<dynamic>(res);
    return _toPaged<ChatEncryptionKeyModel>(
      data,
      itemKeys: const ['items', 'keys', 'data', 'list'],
      map: ChatEncryptionKeyModel.fromJson,
    );
  }

  Future<ChatFriendRequestModel> sendFriendRequest(
    SendChatFriendRequestRequest req,
  ) async {
    final res = await _client.post(
      ChatHttp.uri(ChatEndpoints.sendFriendRequest()),
      headers: await _headers(),
      body: jsonEncode(req.toJson()),
    );

    ChatHttp.ensureOk(res);
    // Social layering: Handle empty or null responses gracefully
    if (res.body.isEmpty) {
      return ChatFriendRequestModel(
        id: '',
        senderId: '',
        receiverId: req.receiverUsername,
        status: ChatFriendRequestStatus.pending,
      );
    }
    final data = ChatHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'item', 'request']);
    if (map != null && map.isNotEmpty)
      return ChatFriendRequestModel.fromJson(map);

    // Return placeholder on empty response
    return ChatFriendRequestModel(
      id: '',
      senderId: '',
      receiverId: req.receiverUsername,
      status: ChatFriendRequestStatus.pending,
    );
  }

  Future<ChatPaged<ChatFriendRequestModel>> listFriendRequests(
    ChatListQuery query,
  ) async {
    final res = await _client.get(
      ChatHttp.uri(
        ChatEndpoints.listFriendRequests(),
        queryParams: query.toQueryMap(),
      ),
      headers: await _headers(),
    );

    ChatHttp.ensureOk(res);
    final data = ChatHttp.decodeJson<dynamic>(res);
    return _toPaged<ChatFriendRequestModel>(
      data,
      itemKeys: const ['items', 'requests', 'data', 'list'],
      map: ChatFriendRequestModel.fromJson,
    );
  }

  Future<ChatPaged<ChatFriendRequestModel>> listSentFriendRequests(
    ChatListQuery query,
  ) async {
    final res = await _client.get(
      ChatHttp.uri(
        ChatEndpoints.listSentFriendRequests(),
        queryParams: query.toQueryMap(),
      ),
      headers: await _headers(),
    );

    ChatHttp.ensureOk(res);
    final data = ChatHttp.decodeJson<dynamic>(res);
    return _toPaged<ChatFriendRequestModel>(
      data,
      itemKeys: const ['items', 'requests', 'data', 'list'],
      map: ChatFriendRequestModel.fromJson,
    );
  }

  Future<ChatFriendRequestModel> getFriendRequest(String requestId) async {
    final res = await _client.get(
      ChatHttp.uri(ChatEndpoints.getFriendRequest(requestId)),
      headers: await _headers(),
    );

    ChatHttp.ensureOk(res);
    // Social layering: Handle empty or null responses gracefully
    if (res.body.isEmpty) {
      return ChatFriendRequestModel(
        id: requestId,
        senderId: '',
        receiverId: '',
        status: ChatFriendRequestStatus.unknown,
      );
    }
    final data = ChatHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'item', 'request']);
    if (map != null && map.isNotEmpty)
      return ChatFriendRequestModel.fromJson(map);

    return ChatFriendRequestModel(
      id: requestId,
      senderId: '',
      receiverId: '',
      status: ChatFriendRequestStatus.unknown,
    );
  }

  Future<ChatFriendRequestModel> respondFriendRequest(
    String requestId,
    RespondFriendRequestRequest req,
  ) async {
    final res = await _client.post(
      ChatHttp.uri(ChatEndpoints.respondFriendRequest(requestId)),
      headers: await _headers(),
      body: jsonEncode(req.toJson()),
    );

    ChatHttp.ensureOk(res);
    // Social layering: Handle empty or null responses gracefully
    if (res.body.isEmpty) {
      final status = req.action == 'ACCEPTED'
          ? ChatFriendRequestStatus.accepted
          : ChatFriendRequestStatus.rejected;
      return ChatFriendRequestModel(
        id: requestId,
        senderId: '',
        receiverId: '',
        status: status,
      );
    }
    final data = ChatHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'item', 'request']);
    if (map != null && map.isNotEmpty)
      return ChatFriendRequestModel.fromJson(map);

    final status = req.action == 'ACCEPTED'
        ? ChatFriendRequestStatus.accepted
        : ChatFriendRequestStatus.rejected;
    return ChatFriendRequestModel(
      id: requestId,
      senderId: '',
      receiverId: '',
      status: status,
    );
  }

  Future<ChatFriendRequestModel> cancelFriendRequest(String requestId) async {
    final res = await _client.delete(
      ChatHttp.uri(ChatEndpoints.cancelFriendRequest(requestId)),
      headers: await _headers(),
    );

    ChatHttp.ensureOk(res);
    // Social layering: Handle empty or null responses gracefully
    if (res.body.isEmpty) {
      return ChatFriendRequestModel(
        id: requestId,
        senderId: '',
        receiverId: '',
        status: ChatFriendRequestStatus.canceled,
      );
    }
    final data = ChatHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'item', 'request']);
    if (map != null && map.isNotEmpty)
      return ChatFriendRequestModel.fromJson(map);

    return ChatFriendRequestModel(
      id: requestId,
      senderId: '',
      receiverId: '',
      status: ChatFriendRequestStatus.canceled,
    );
  }

  Future<ChatPaged<ChatFriendModel>> listFriends(ChatListQuery query) async {
    final res = await _client.get(
      ChatHttp.uri(
        ChatEndpoints.listFriends(),
        queryParams: query.toQueryMap(),
      ),
      headers: await _headers(),
    );

    ChatHttp.ensureOk(res);
    final data = ChatHttp.decodeJson<dynamic>(res);
    return _toPaged<ChatFriendModel>(
      data,
      itemKeys: const ['items', 'friends', 'data', 'list'],
      map: ChatFriendModel.fromJson,
    );
  }

  Future<bool> removeFriendship(String friendshipId) async {
    final res = await _client.delete(
      ChatHttp.uri(ChatEndpoints.removeFriendship(friendshipId)),
      headers: await _headers(),
    );

    ChatHttp.ensureOk(res);
    final data = ChatHttp.decodeJson<dynamic>(res);
    final map = _asStringKeyMap(data);
    if (map == null) return true;
    final wrapped = _asStringKeyMap(map['data']);
    if (wrapped != null && wrapped['success'] is bool) {
      return wrapped['success'] as bool;
    }
    if (map['success'] is bool) return map['success'] as bool;
    return true;
  }

  Future<ChatDirectThreadModel> openThreadWithFriend(
    String friendUserId,
  ) async {
    final res = await _client.get(
      ChatHttp.uri(ChatEndpoints.openThreadWithFriend(friendUserId)),
      headers: await _headers(),
    );

    ChatHttp.ensureOk(res);
    final data = ChatHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'item', 'thread']);
    if (map != null) return ChatDirectThreadModel.fromJson(map);

    throw ChatApiException(
      res.statusCode,
      'Unexpected response for GET /direct-messages/threads/with/$friendUserId',
      body: res.body,
    );
  }

  Future<ChatPaged<ChatDirectThreadModel>> listThreads(
    ChatListQuery query,
  ) async {
    final res = await _client.get(
      ChatHttp.uri(
        ChatEndpoints.listThreads(),
        queryParams: query.toQueryMap(),
      ),
      headers: await _headers(),
    );

    ChatHttp.ensureOk(res);
    final data = ChatHttp.decodeJson<dynamic>(res);
    return _toPaged<ChatDirectThreadModel>(
      data,
      itemKeys: const ['items', 'threads', 'data', 'list'],
      map: ChatDirectThreadModel.fromJson,
    );
  }

  Future<ChatPaged<ChatDirectMessageModel>> listThreadMessages(
    String threadId,
    ChatListQuery query,
  ) async {
    final res = await _client.get(
      ChatHttp.uri(
        ChatEndpoints.listThreadMessages(threadId),
        queryParams: query.toQueryMap(),
      ),
      headers: await _headers(),
    );

    ChatHttp.ensureOk(res);
    final data = ChatHttp.decodeJson<dynamic>(res);
    return _toPaged<ChatDirectMessageModel>(
      data,
      itemKeys: const ['items', 'messages', 'data', 'list'],
      map: ChatDirectMessageModel.fromJson,
    );
  }

  Future<ChatDirectMessageModel> sendThreadMessage(
    String threadId,
    SendEncryptedChatMessageRequest req,
  ) async {
    final res = await _client.post(
      ChatHttp.uri(ChatEndpoints.sendThreadMessage(threadId)),
      headers: await _headers(),
      body: jsonEncode(req.toJson()),
    );

    ChatHttp.ensureOk(res);
    if (res.body.isEmpty) {
      return ChatDirectMessageModel(
        id: req.clientMessageId,
        threadId: threadId,
        senderId: '',
        clientMessageId: req.clientMessageId,
        kind: req.kind,
        algorithm: req.algorithm,
        senderKeyId: req.senderKeyId,
        nonce: req.nonce,
        ciphertext: req.ciphertext,
        signature: req.signature,
        metadata: req.metadata,
        createdAt: DateTime.now().toUtc(),
      );
    }
    final data = ChatHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'item', 'message']);
    if (map != null && map.isNotEmpty) {
      return ChatDirectMessageModel.fromJson(map);
    }

    // Fallback for APIs returning success envelopes without message payload.
    return ChatDirectMessageModel(
      id: req.clientMessageId,
      threadId: threadId,
      senderId: '',
      clientMessageId: req.clientMessageId,
      kind: req.kind,
      algorithm: req.algorithm,
      senderKeyId: req.senderKeyId,
      nonce: req.nonce,
      ciphertext: req.ciphertext,
      signature: req.signature,
      metadata: req.metadata,
      createdAt: DateTime.now().toUtc(),
    );
  }

  Future<ChatDirectThreadModel> createThread(CreateThreadRequest req) async {
    final res = await _client.post(
      ChatHttp.uri(ChatEndpoints.createThread()),
      headers: await _headers(),
      body: jsonEncode(req.toJson()),
    );

    ChatHttp.ensureOk(res);
    // Social layering: Handle empty or null responses gracefully
    if (res.body.isEmpty) {
      return ChatDirectThreadModel(
        id: req.friendId,
        friendUserId: req.friendId,
        isActive: true,
        unreadCount: 0,
      );
    }
    final data = ChatHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'item', 'thread']);
    if (map != null && map.isNotEmpty)
      return ChatDirectThreadModel.fromJson(map);

    // Return fallback thread on empty response
    return ChatDirectThreadModel(
      id: req.friendId,
      friendUserId: req.friendId,
      isActive: true,
      unreadCount: 0,
    );
  }

  Future<ChatDirectThreadModel> getThread(String threadId) async {
    final res = await _client.get(
      ChatHttp.uri(ChatEndpoints.getThread(threadId)),
      headers: await _headers(),
    );

    ChatHttp.ensureOk(res);
    // Social layering: Handle empty or null responses gracefully
    if (res.body.isEmpty) {
      return ChatDirectThreadModel(
        id: threadId,
        friendUserId: '',
        isActive: false,
        unreadCount: 0,
      );
    }
    final data = ChatHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'item', 'thread']);
    if (map != null && map.isNotEmpty)
      return ChatDirectThreadModel.fromJson(map);

    // Return fallback thread on empty response
    return ChatDirectThreadModel(
      id: threadId,
      friendUserId: '',
      isActive: false,
      unreadCount: 0,
    );
  }

  Future<ChatDirectThreadModel> getThreadWithFriend(String friendId) async {
    // Keep backward compatibility while preventing invalid empty-thread
    // objects from reaching UI. This endpoint currently opens or returns.
    return openThreadWithFriend(friendId);
  }

  Future<ChatDirectMessageModel> getMessage(String messageId) async {
    final res = await _client.get(
      ChatHttp.uri(ChatEndpoints.getMessage(messageId)),
      headers: await _headers(),
    );

    ChatHttp.ensureOk(res);
    // Social layering: Handle empty or null responses gracefully
    if (res.body.isEmpty) {
      return ChatDirectMessageModel(
        id: messageId,
        threadId: '',
        senderId: '',
        kind: ChatMessageKind.unknown,
        algorithm: '',
        senderKeyId: '',
        nonce: '',
        ciphertext: '',
      );
    }
    final data = ChatHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'item', 'message']);
    if (map != null && map.isNotEmpty)
      return ChatDirectMessageModel.fromJson(map);

    // Return fallback message on empty response
    return ChatDirectMessageModel(
      id: messageId,
      threadId: '',
      senderId: '',
      kind: ChatMessageKind.unknown,
      algorithm: '',
      senderKeyId: '',
      nonce: '',
      ciphertext: '',
    );
  }
}
