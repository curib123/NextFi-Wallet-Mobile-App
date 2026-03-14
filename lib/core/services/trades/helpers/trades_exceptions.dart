class TradeApiException implements Exception {
  final int statusCode;
  final String message;
  final String? body;

  TradeApiException(this.statusCode, this.message, {this.body});

  @override
  String toString() =>
      'TradeApiException($statusCode): $message${body == null ? '' : ' | $body'}';
}
