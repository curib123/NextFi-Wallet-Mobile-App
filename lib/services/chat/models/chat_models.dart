enum ChatFriendRequestStatus { pending, accepted, rejected, canceled, unknown }

enum ChatMessageKind { text, binary, system, unknown }

ChatFriendRequestStatus chatFriendRequestStatusFromApi(dynamic raw) {
  final v = raw?.toString().trim().toUpperCase();
  switch (v) {
    case 'PENDING':
      return ChatFriendRequestStatus.pending;
    case 'ACCEPTED':
      return ChatFriendRequestStatus.accepted;
    case 'REJECTED':
      return ChatFriendRequestStatus.rejected;
    case 'CANCELED':
      return ChatFriendRequestStatus.canceled;
    default:
      return ChatFriendRequestStatus.unknown;
  }
}

String chatFriendRequestStatusToApi(ChatFriendRequestStatus status) {
  switch (status) {
    case ChatFriendRequestStatus.pending:
      return 'PENDING';
    case ChatFriendRequestStatus.accepted:
      return 'ACCEPTED';
    case ChatFriendRequestStatus.rejected:
      return 'REJECTED';
    case ChatFriendRequestStatus.canceled:
      return 'CANCELED';
    case ChatFriendRequestStatus.unknown:
      return 'PENDING';
  }
}

ChatMessageKind chatMessageKindFromApi(dynamic raw) {
  final v = raw?.toString().trim().toUpperCase();
  switch (v) {
    case 'TEXT':
      return ChatMessageKind.text;
    case 'BINARY':
      return ChatMessageKind.binary;
    case 'SYSTEM':
      return ChatMessageKind.system;
    default:
      return ChatMessageKind.unknown;
  }
}

String chatMessageKindToApi(ChatMessageKind kind) {
  switch (kind) {
    case ChatMessageKind.text:
      return 'TEXT';
    case ChatMessageKind.binary:
      return 'BINARY';
    case ChatMessageKind.system:
      return 'SYSTEM';
    case ChatMessageKind.unknown:
      return 'TEXT';
  }
}

String _readString(
  Map<String, dynamic> json,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return fallback;
}

bool _readBool(
  Map<String, dynamic> json,
  List<String> keys, {
  bool fallback = false,
}) {
  for (final key in keys) {
    final value = json[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
  }
  return fallback;
}

int _readInt(Map<String, dynamic> json, List<String> keys, {int fallback = 0}) {
  for (final key in keys) {
    final value = json[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
  }
  return fallback;
}

DateTime? _readDate(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    final parsed = DateTime.tryParse(value.toString());
    if (parsed != null) return parsed;
  }
  return null;
}

Map<String, dynamic>? _readMap(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
  }
  return null;
}

class ChatPaginationMeta {
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  const ChatPaginationMeta({
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory ChatPaginationMeta.fromJson(Map<String, dynamic> json) {
    return ChatPaginationMeta(
      total: _readInt(json, const ['total'], fallback: 0),
      page: _readInt(json, const ['page'], fallback: 1),
      limit: _readInt(json, const ['limit'], fallback: 20),
      totalPages: _readInt(json, const [
        'totalPages',
        'total_pages',
      ], fallback: 1),
    );
  }
}

class ChatPaged<T> {
  final List<T> items;
  final ChatPaginationMeta meta;

  const ChatPaged({required this.items, required this.meta});
}

class ChatUserLite {
  final String id;
  final String email;
  final String name;
  final String? avatarUrl;
  final String? username;
  final String? displayName;

  const ChatUserLite({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
    this.username,
    this.displayName,
  });

  factory ChatUserLite.fromJson(Map<String, dynamic> json) {
    final profileMap = _readMap(json, const ['profile', 'userProfile']);

    String readFromProfile(List<String> keys) {
      if (profileMap == null) return '';
      return _readString(profileMap, keys);
    }

    String composeProfileName() {
      if (profileMap == null) return '';
      final direct = _readString(profileMap, const [
        'name',
        'fullName',
        'full_name',
      ]);
      if (direct.isNotEmpty) return direct;

      final parts = [
        _readString(profileMap, const ['firstName', 'first_name']),
        _readString(profileMap, const ['middleName', 'middle_name']),
        _readString(profileMap, const ['lastName', 'last_name']),
      ].where((part) => part.isNotEmpty).toList();
      return parts.join(' ').trim();
    }

    final parsedDisplayName = (() {
      final direct = _readString(json, const ['displayName', 'display_name']);
      if (direct.isNotEmpty) return direct;
      final fromProfile = readFromProfile(const [
        'displayName',
        'display_name',
      ]);
      return fromProfile.isEmpty ? null : fromProfile;
    })();

    final parsedUsername = (() {
      final direct = _readString(json, const ['username']);
      if (direct.isNotEmpty) return direct;
      final fromProfile = readFromProfile(const ['username']);
      return fromProfile.isEmpty ? null : fromProfile;
    })();

    final parsedAvatarUrl = (() {
      final direct = _readString(json, const [
        'avatarUrl',
        'avatar_url',
        'avatar',
        'profileImage',
        'profile_image',
        'photoUrl',
        'photo_url',
      ]);
      if (direct.isNotEmpty) return direct;
      final fromProfile = readFromProfile(const [
        'avatarUrl',
        'avatar_url',
        'avatar',
        'profileImage',
        'profile_image',
        'photoUrl',
        'photo_url',
      ]);
      return fromProfile.isEmpty ? null : fromProfile;
    })();

    final parsedName = (() {
      final direct = _readString(json, const ['name', 'fullName', 'full_name']);
      if (direct.isNotEmpty) return direct;
      if (parsedDisplayName != null && parsedDisplayName.trim().isNotEmpty) {
        return parsedDisplayName.trim();
      }
      final profileName = composeProfileName();
      return profileName.isEmpty ? '' : profileName;
    })();

    return ChatUserLite(
      id: _readString(json, const ['id', 'userId', 'user_id']),
      email: _readString(json, const ['email']),
      name: parsedName,
      avatarUrl: parsedAvatarUrl,
      username: parsedUsername,
      displayName: parsedDisplayName,
    );
  }
}

class ChatEncryptionKeyModel {
  final String userId;
  final String keyId;
  final String algorithm;
  final String publicKey;
  final String? signaturePublicKey;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ChatEncryptionKeyModel({
    required this.userId,
    required this.keyId,
    required this.algorithm,
    required this.publicKey,
    this.signaturePublicKey,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory ChatEncryptionKeyModel.fromJson(Map<String, dynamic> json) {
    return ChatEncryptionKeyModel(
      userId: _readString(json, const ['userId', 'user_id']),
      keyId: _readString(json, const ['keyId', 'key_id']),
      algorithm: _readString(json, const ['algorithm']),
      publicKey: _readString(json, const ['publicKey', 'public_key']),
      signaturePublicKey: (() {
        final value = _readString(json, const [
          'signaturePublicKey',
          'signature_public_key',
        ]);
        return value.isEmpty ? null : value;
      })(),
      isActive: _readBool(json, const [
        'isActive',
        'is_active',
      ], fallback: true),
      createdAt: _readDate(json, const ['createdAt', 'created_at']),
      updatedAt: _readDate(json, const ['updatedAt', 'updated_at']),
    );
  }
}

class ChatFriendRequestModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String? note;
  final ChatFriendRequestStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final ChatUserLite? sender;
  final ChatUserLite? receiver;

  const ChatFriendRequestModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    this.note,
    required this.status,
    this.createdAt,
    this.updatedAt,
    this.sender,
    this.receiver,
  });

  factory ChatFriendRequestModel.fromJson(Map<String, dynamic> json) {
    final senderMap = _readMap(json, const ['sender', 'senderUser', 'from']);
    final receiverMap = _readMap(json, const [
      'receiver',
      'receiverUser',
      'to',
    ]);

    return ChatFriendRequestModel(
      id: _readString(json, const ['id', 'requestId', 'request_id']),
      senderId: _readString(json, const ['senderId', 'sender_id']),
      receiverId: _readString(json, const ['receiverId', 'receiver_id']),
      note: (() {
        final text = _readString(json, const ['note']);
        return text.isEmpty ? null : text;
      })(),
      status: chatFriendRequestStatusFromApi(json['status']),
      createdAt: _readDate(json, const ['createdAt', 'created_at']),
      updatedAt: _readDate(json, const ['updatedAt', 'updated_at']),
      sender: senderMap == null ? null : ChatUserLite.fromJson(senderMap),
      receiver: receiverMap == null ? null : ChatUserLite.fromJson(receiverMap),
    );
  }
}

class ChatFriendModel {
  final String friendshipId;
  final String friendUserId;
  final ChatUserLite friend;
  final String friendStatus;
  final DateTime? friendLastSeenAt;
  final bool friendIsOnline;
  final int newUnreadMessageCount;
  final DateTime? createdAt;

  const ChatFriendModel({
    required this.friendshipId,
    required this.friendUserId,
    required this.friend,
    this.friendStatus = '',
    this.friendLastSeenAt,
    this.friendIsOnline = false,
    this.newUnreadMessageCount = 0,
    this.createdAt,
  });

  factory ChatFriendModel.fromJson(Map<String, dynamic> json) {
    final friendMap =
        _readMap(json, const ['friend', 'friendUser', 'user']) ??
        const <String, dynamic>{};

    final friendUser = ChatUserLite.fromJson(friendMap);
    final friendUserId = _readString(json, const [
      'friendUserId',
      'friend_user_id',
      'userId',
      'user_id',
    ], fallback: friendUser.id);
    final friendStatus = _readString(json, const [
      'friendStatus',
      'friend_status',
      'presence',
      'presenceStatus',
      'presence_status',
    ]);
    final friendIsOnline = _readBool(json, const [
      'friendIsOnline',
      'friend_is_online',
      'isOnline',
      'is_online',
      'online',
    ], fallback: friendStatus.toUpperCase() == 'ONLINE');

    return ChatFriendModel(
      friendshipId: _readString(json, const [
        'id',
        'friendshipId',
        'friendship_id',
      ]),
      friendUserId: friendUserId,
      friend: friendUser,
      friendStatus: friendStatus,
      friendLastSeenAt: _readDate(json, const [
        'friendLastSeenAt',
        'friend_last_seen_at',
        'lastSeenAt',
        'last_seen_at',
        'friendLastActiveAt',
        'friend_last_active_at',
      ]),
      friendIsOnline: friendIsOnline,
      newUnreadMessageCount: _readInt(json, const [
        'newUnreadMessageCount',
        'new_unread_message_count',
      ]),
      createdAt: _readDate(json, const ['createdAt', 'created_at']),
    );
  }
}

class ChatDirectMessageModel {
  final String id;
  final String threadId;
  final String senderId;
  final String? clientMessageId;
  final ChatMessageKind kind;
  final String algorithm;
  final String senderKeyId;
  final String nonce;
  final String ciphertext;
  final String? signature;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;
  final ChatUserLite? sender;

  const ChatDirectMessageModel({
    required this.id,
    required this.threadId,
    required this.senderId,
    this.clientMessageId,
    required this.kind,
    required this.algorithm,
    required this.senderKeyId,
    required this.nonce,
    required this.ciphertext,
    this.signature,
    this.metadata,
    this.createdAt,
    this.sender,
  });

  factory ChatDirectMessageModel.fromJson(Map<String, dynamic> json) {
    final senderMap = _readMap(json, const ['sender', 'senderUser', 'from']);
    final metadata = _readMap(json, const ['metadata']);

    return ChatDirectMessageModel(
      id: _readString(json, const ['id', 'messageId', 'message_id']),
      threadId: _readString(json, const ['threadId', 'thread_id']),
      senderId: _readString(json, const ['senderId', 'sender_id']),
      clientMessageId: (() {
        final value = _readString(json, const [
          'clientMessageId',
          'client_message_id',
        ]);
        return value.isEmpty ? null : value;
      })(),
      kind: chatMessageKindFromApi(json['kind']),
      algorithm: _readString(json, const [
        'algorithm',
      ], fallback: 'xchacha20-poly1305'),
      senderKeyId: _readString(json, const ['senderKeyId', 'sender_key_id']),
      nonce: _readString(json, const ['nonce']),
      ciphertext: _readString(json, const ['ciphertext']),
      signature: (() {
        final value = _readString(json, const ['signature']);
        return value.isEmpty ? null : value;
      })(),
      metadata: metadata,
      createdAt: _readDate(json, const ['createdAt', 'created_at']),
      sender: senderMap == null ? null : ChatUserLite.fromJson(senderMap),
    );
  }
}

class ChatDirectThreadModel {
  final String id;
  final String friendUserId;
  final ChatUserLite? friendUser;
  final bool isActive;
  final int unreadCount;
  final ChatDirectMessageModel? lastMessage;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ChatDirectThreadModel({
    required this.id,
    required this.friendUserId,
    this.friendUser,
    required this.isActive,
    required this.unreadCount,
    this.lastMessage,
    this.createdAt,
    this.updatedAt,
  });

  factory ChatDirectThreadModel.fromJson(Map<String, dynamic> json) {
    final friendMap = _readMap(json, const [
      'friendUser',
      'friend',
      'counterparty',
      'otherUser',
      'user',
      'participant',
      'participantUser',
    ]);
    final lastMessageMap = _readMap(json, const [
      'lastMessage',
      'last_message',
      'message',
    ]);

    final friendUser = friendMap == null
        ? null
        : ChatUserLite.fromJson(friendMap);
    final friendUserId = _readString(json, const [
      'friendUserId',
      'friend_user_id',
      'otherUserId',
      'other_user_id',
      'counterpartyUserId',
      'counterparty_user_id',
      'participantUserId',
      'participant_user_id',
    ], fallback: friendUser?.id ?? '');

    return ChatDirectThreadModel(
      id: _readString(json, const ['id', 'threadId', 'thread_id']),
      friendUserId: friendUserId,
      friendUser: friendUser,
      isActive: _readBool(json, const [
        'isActive',
        'is_active',
      ], fallback: true),
      unreadCount: _readInt(json, const [
        'unreadCount',
        'unread_count',
      ], fallback: 0),
      lastMessage: lastMessageMap == null
          ? null
          : ChatDirectMessageModel.fromJson(lastMessageMap),
      createdAt: _readDate(json, const ['createdAt', 'created_at']),
      updatedAt: _readDate(json, const ['updatedAt', 'updated_at']),
    );
  }
}
