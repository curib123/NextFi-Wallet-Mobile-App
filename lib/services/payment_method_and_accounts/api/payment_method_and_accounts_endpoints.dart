class PaymentMethodAndAccountsEndpoints {
  static const String methodsBase = '/payment-methods';
  static const String accountsBase = '/payment-accounts';

  static String paymentMethods() => methodsBase;
  static String paymentMethodById(String id) => '$methodsBase/$id';

  static String paymentAccounts() => accountsBase;
  static String paymentAccountById(String id) => '$accountsBase/$id';
  static String togglePaymentAccount(String id) => '$accountsBase/$id/toggle';
}
