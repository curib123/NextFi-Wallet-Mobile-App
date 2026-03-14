class ApiException implements Exception {
  ApiException(this.statusCode, this.message, {this.body});

  final int statusCode;
  final String message;
  final String? body;

  @override
  String toString() {
    final b = (body == null || body!.isEmpty) ? '' : '\nbody: $body';
    return 'ApiException($statusCode): $message$b';
  }
}
