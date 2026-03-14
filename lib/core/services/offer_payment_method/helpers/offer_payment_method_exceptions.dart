class ApiException implements Exception {
  ApiException(
    this.statusCode,
    this.message, {
    this.body,
  });

  final int statusCode;
  final String message;
  final String? body;

  @override
  String toString() {
    return 'ApiException(statusCode: $statusCode, message: $message, body: $body)';
  }
}