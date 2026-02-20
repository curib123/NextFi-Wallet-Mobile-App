class ChatApiException implements Exception {
  final int statusCode;
  final String message;
  final String? body;

  ChatApiException(this.statusCode, this.message, {this.body});

  @override
  String toString() {
    final suffix = body == null ? '' : ' | $body';
    return 'ChatApiException($statusCode): $message$suffix';
  }
}
