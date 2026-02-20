class ChatEndpoints {
  static const String base = '/chat';

  static String listMyKeys() => '$base/keys/me';
  static String upsertMyKey() => '$base/keys/me';
  static String deactivateMyKey(String keyId) =>
      '$base/keys/me/$keyId/deactivate';
  static String listUserPublicKeys(String userId) => '$base/keys/$userId';

  static String sendFriendRequest() => '$base/friends/requests';
  static String listIncomingFriendRequests() =>
      '$base/friends/requests/incoming';
  static String listOutgoingFriendRequests() =>
      '$base/friends/requests/outgoing';
  static String acceptFriendRequest(String requestId) =>
      '$base/friends/requests/$requestId/accept';
  static String rejectFriendRequest(String requestId) =>
      '$base/friends/requests/$requestId/reject';
  static String cancelFriendRequest(String requestId) =>
      '$base/friends/requests/$requestId/cancel';

  static String listFriends() => '$base/friends';
  static String removeFriend(String friendUserId) =>
      '$base/friends/$friendUserId';

  static String openThreadWithFriend(String friendUserId) =>
      '$base/threads/with/$friendUserId/open';
  static String listThreads() => '$base/threads';
  static String listThreadMessages(String threadId) =>
      '$base/threads/$threadId/messages';
  static String sendThreadMessage(String threadId) =>
      '$base/threads/$threadId/messages';
}
