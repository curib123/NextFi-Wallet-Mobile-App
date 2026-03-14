import 'dart:convert';

class ChatApiException implements Exception {
  final int statusCode;
  final String message;
  final String? body;

  ChatApiException(this.statusCode, this.message, {this.body});

  String get _friendlyMessage {
    if (body == null || body!.isEmpty) return message;
    try {
      final json = jsonDecode(body!) as Map<String, dynamic>?;
      if (json == null) return message;
      final msg = json['message'];
      if (msg is String && msg.trim().isNotEmpty) return msg.trim();
      if (msg is List && msg.isNotEmpty) return msg.first.toString().trim();
      final error = json['error'];
      if (error is String && error.trim().isNotEmpty) return error.trim();
    } catch (_) {}
    return message;
  }

  @override
  String toString() => _friendlyMessage;
}
