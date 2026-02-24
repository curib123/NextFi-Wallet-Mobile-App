eclass ChatEndpoints {
  static const String base = '/direct-messages';
  static const String friendsBase = '/friends';

  // Encryption Keys
  static String listMyKeys() => '/chat/keys/me';
  static String upsertMyKey() => '/chat/keys/me';
  static String deactivateMyKey(String keyId) =>
      '/chat/keys/me/$keyId/deactivate';
  static String listUserPublicKeys(String userId) => '/chat/keys/$userId';

  // Friend Requests
  static String sendFriendRequest() => '$friendsBase/request';
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
      '/chat/threads/with/$friendUserId/open';

  // Direct Messages - Message Management
  static String listThreadMessages(String threadId) =>
      '$base/threads/$threadId/messages';
  static String sendThreadMessage(String threadId) =>
      '$base/threads/$threadId/messages';
  static String getMessage(String messageId) => '$base/messages/$messageId';
}
