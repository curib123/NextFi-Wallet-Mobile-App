class AuthException implements Exception {
  final String message;
  final int? statusCode;

  const AuthException(this.message, {this.statusCode});

  @override
  String toString() => 'AuthException($statusCode): $message';
}

class TokenExpiredException extends AuthException {
  const TokenExpiredException() : super('Token expired', statusCode: 401);
}

class RefreshFailedException extends AuthException {
  const RefreshFailedException()
    : super('Session expired. Please log in again.', statusCode: 401);
}
