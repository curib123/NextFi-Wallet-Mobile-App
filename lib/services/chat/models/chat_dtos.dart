import 'chat_models.dart';

class ChatListQuery {
  final int? page;
  final int? limit;
  final String? cursor;
  final String? q;
  final ChatFriendRequestStatus? status;

  const ChatListQuery({
    this.page,
    this.limit,
    this.cursor,
    this.q,
    this.status,
  });

  Map<String, String> toQueryMap() => {
    if (page != null && page! > 0) 'page': page!.toString(),
    if (limit != null && limit! > 0) 'limit': limit!.toString(),
    if (cursor != null && cursor!.trim().isNotEmpty) 'cursor': cursor!.trim(),
    if (q != null && q!.trim().isNotEmpty) 'q': q!.trim(),
    if (status != null && status != ChatFriendRequestStatus.unknown)
      'status': chatFriendRequestStatusToApi(status!),
  };
}

class UpsertChatEncryptionKeyRequest {
  final String keyId;
  final String algorithm;
  final String publicKey;
  final String? signaturePublicKey;
  final bool isActive;

  const UpsertChatEncryptionKeyRequest({
    required this.keyId,
    required this.algorithm,
    required this.publicKey,
    this.signaturePublicKey,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
    'keyId': keyId.trim(),
    'algorithm': algorithm.trim(),
    'publicKey': publicKey.trim(),
    if (signaturePublicKey != null && signaturePublicKey!.trim().isNotEmpty)
      'signaturePublicKey': signaturePublicKey!.trim(),
    'isActive': isActive,
  };
}

class SendChatFriendRequestRequest {
  final String receiverUsername;
  final String? note;

  const SendChatFriendRequestRequest({
    required this.receiverUsername,
    this.note,
  });

  Map<String, dynamic> toJson() => {
    'receiverUsername': receiverUsername.trim(),
    if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
  };
}

class RespondFriendRequestRequest {
  final String action;
  final String? note;

  const RespondFriendRequestRequest({required this.action, this.note});

  Map<String, dynamic> toJson() => {
    'action': action.trim().toUpperCase(),
    if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
  };
}

class SendEncryptedChatMessageRequest {
  final String clientMessageId;
  final ChatMessageKind kind;
  final String algorithm;
  final String senderKeyId;
  final String nonce;
  final String ciphertext;
  final String? signature;
  final Map<String, dynamic>? metadata;

  const SendEncryptedChatMessageRequest({
    required this.clientMessageId,
    this.kind = ChatMessageKind.text,
    required this.algorithm,
    required this.senderKeyId,
    required this.nonce,
    required this.ciphertext,
    this.signature,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'clientMessageId': clientMessageId.trim(),
    'kind': chatMessageKindToApi(kind),
    'algorithm': algorithm.trim(),
    'senderKeyId': senderKeyId.trim(),
    'nonce': nonce.trim(),
    'ciphertext': ciphertext.trim(),
    if (signature != null && signature!.trim().isNotEmpty)
      'signature': signature!.trim(),
    if (metadata != null) 'metadata': metadata,
  };
}

class CreateThreadRequest {
  final String friendId;

  const CreateThreadRequest({required this.friendId});

  Map<String, dynamic> toJson() => {'friendId': friendId.trim()};
}
