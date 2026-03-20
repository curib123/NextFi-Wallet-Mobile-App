import 'dart:convert';
import 'dart:math';

import '../models/chat_dtos.dart';
import '../models/chat_models.dart';

class ChatEnvelopeCodec {
  ChatEnvelopeCodec._();

  static const String keyAlgorithm = 'x25519';
  static const String messageAlgorithm = 'xchacha20-poly1305';

  static final Random _rand = Random.secure();

  static String generateSenderKeyId() =>
      'device-${DateTime.now().millisecondsSinceEpoch}';

  static String generateClientMessageId() =>
      'msg-${DateTime.now().microsecondsSinceEpoch}-${_rand.nextInt(1 << 16)}';

  static String _randomBase64(int bytes) {
    final raw = List<int>.generate(bytes, (_) => _rand.nextInt(256));
    return base64Encode(raw);
  }

  static String generatePublicKeyPlaceholder() => _randomBase64(32);

  static UpsertChatEncryptionKeyRequest buildDeviceKeyUpsert({
    required String senderKeyId,
  }) {
    return UpsertChatEncryptionKeyRequest(
      keyId: senderKeyId,
      algorithm: keyAlgorithm,
      publicKey: generatePublicKeyPlaceholder(),
      isActive: true,
    );
  }

  static SendEncryptedChatMessageRequest encodeText({
    required String plainText,
    required String senderKeyId,
  }) {
    final text = plainText.trim();
    final bytes = utf8.encode(text);
    return SendEncryptedChatMessageRequest(
      clientMessageId: generateClientMessageId(),
      kind: ChatMessageKind.text,
      algorithm: messageAlgorithm,
      senderKeyId: senderKeyId,
      nonce: _randomBase64(24),
      ciphertext: base64Encode(bytes),
      metadata: const {'version': 1, 'encoding': 'utf8-base64'},
    );
  }

  static String decodeText(String ciphertext) {
    final raw = ciphertext.trim();
    if (raw.isEmpty) return '';
    try {
      final bytes = base64Decode(raw);
      final text = utf8.decode(bytes, allowMalformed: true);
      return text.trim();
    } catch (_) {
      return '[Encrypted message]';
    }
  }
}
