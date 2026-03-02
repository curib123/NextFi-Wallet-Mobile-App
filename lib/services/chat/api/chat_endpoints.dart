class ChatEndpoints {
  static const String base = '/direct-messages';
  static const String friendsBase = '/friends';
  static const String encryptionBase = '/encryption-keys';

  // Encryption Keys
  static String listMyKeys() => '$encryptionBase/me';
  static String upsertMyKey() => encryptionBase;
  static String deactivateMyKey(String keyId) =>
      '$encryptionBase/$keyId/revoke';
  static String activateMyKey(String keyId) =>
      '$encryptionBase/$keyId/activate';
  static String listUserPublicKeys(String userId) =>
      '$encryptionBase/user/$userId';
  static String getMyKey(String keyId) => '$encryptionBase/$keyId';
  static String deleteMyKey(String keyId) => '$encryptionBase/$keyId';

  // Friend Requests
  /// Send a friend request (POST /friends/request)
  static String sendFriendRequest() => '$friendsBase/request';

  /// List received friend requests (GET /friends/requests)
  static String listFriendRequests() => '$friendsBase/requests';
  static String listSentFriendRequests() => '$friendsBase/requests/sent';
  static String getFriendRequest(String requestId) =>
      '$friendsBase/requests/$requestId';
  static String respondFriendRequest(String requestId) =>
      '/friends/requests/$requestId/respond';
  static String cancelFriendRequest(String requestId) =>
      '$friendsBase/requests/$requestId';

  // Friends
  static String listFriends() => '$friendsBase';
  static String removeFriendship(String friendshipId) =>
      '$friendsBase/$friendshipId';

  // Direct Messages - Thread Management
  static String createThread() => '$base/threads';
  static String listThreads() => '$base/threads';
  static String getThread(String threadId) => '$base/threads/$threadId';
  static String getThreadWithFriend(String friendId) =>
      '$base/threads/with/$friendId';
  static String openThreadWithFriend(String friendUserId) =>
      '$base/threads/with/$friendUserId';

  // Direct Messages - Message Management
  static String listThreadMessages(String threadId) =>
      '$base/threads/$threadId/messages';
  static String sendThreadMessage(String threadId) =>
      '$base/threads/$threadId/messages';
  static String getMessage(String messageId) => '$base/messages/$messageId';
}
