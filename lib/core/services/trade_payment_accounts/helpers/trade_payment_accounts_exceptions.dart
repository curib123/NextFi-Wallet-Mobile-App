class TradePaymentAccountsApiException implements Exception {
  final int statusCode;
  final String message;
  final String? body;

  TradePaymentAccountsApiException(this.statusCode, this.message, {this.body});

  @override
  String toString() =>
      'TradePaymentAccountsApiException($statusCode): $message';
}
