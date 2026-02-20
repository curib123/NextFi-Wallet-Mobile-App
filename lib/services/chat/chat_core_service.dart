import 'package:next_fi/services/secure_storage/token_storage.dart';

import 'api/chat_service.dart';
import 'models/chat_dtos.dart';
import 'models/chat_models.dart';

class ChatCoreService {
  ChatCoreService._();

  static final ChatCoreService I = ChatCoreService._();

  late final ChatService _api = ChatService(tokenProvider: _safeTokenProvider);

  static Future<String?> _safeTokenProvider() async {
    try {
      final storage = TokenStorage();
      return await storage.accessToken;
    } catch (_) {
      return null;
    }
  }

  Future<ChatPaged<ChatEncryptionKeyModel>> listMyKeys(
    ChatListQuery query,
  ) async => _api.listMyKeys(query);

  Future<ChatEncryptionKeyModel> upsertMyKey(
    UpsertChatEncryptionKeyRequest req,
  ) async => _api.upsertMyKey(req);

  Future<bool> deactivateMyKey(String keyId) async =>
      _api.deactivateMyKey(keyId);

  Future<ChatPaged<ChatEncryptionKeyModel>> listUserPublicKeys(
    String userId,
    ChatListQuery query,
  ) async => _api.listUserPublicKeys(userId, query);

  Future<ChatFriendRequestModel> sendFriendRequest(
    SendChatFriendRequestRequest req,
  ) async => _api.sendFriendRequest(req);

  Future<ChatPaged<ChatFriendRequestModel>> listIncomingFriendRequests(
    ChatListQuery query,
  ) async => _api.listIncomingFriendRequests(query);

  Future<ChatPaged<ChatFriendRequestModel>> listOutgoingFriendRequests(
    ChatListQuery query,
  ) async => _api.listOutgoingFriendRequests(query);

  Future<ChatFriendRequestModel> acceptFriendRequest(String requestId) async =>
      _api.acceptFriendRequest(requestId);

  Future<ChatFriendRequestModel> rejectFriendRequest(String requestId) async =>
      _api.rejectFriendRequest(requestId);

  Future<ChatFriendRequestModel> cancelFriendRequest(String requestId) async =>
      _api.cancelFriendRequest(requestId);

  Future<ChatPaged<ChatFriendModel>> listFriends(ChatListQuery query) async =>
      _api.listFriends(query);

  Future<bool> removeFriend(String friendUserId) async =>
      _api.removeFriend(friendUserId);

  Future<ChatDirectThreadModel> openThreadWithFriend(
    String friendUserId,
  ) async => _api.openThreadWithFriend(friendUserId);

  Future<ChatPaged<ChatDirectThreadModel>> listThreads(
    ChatListQuery query,
  ) async => _api.listThreads(query);

  Future<ChatPaged<ChatDirectMessageModel>> listThreadMessages(
    String threadId,
    ChatListQuery query,
  ) async => _api.listThreadMessages(threadId, query);

  Future<ChatDirectMessageModel> sendThreadMessage(
    String threadId,
    SendEncryptedChatMessageRequest req,
  ) async => _api.sendThreadMessage(threadId, req);
}
