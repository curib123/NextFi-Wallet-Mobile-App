class PortfolioEndpoints {
  static const String base = '/portfolio';

  static String createSnapshot() => '$base/snapshots';

  static String wallet(String walletId) => '$base/wallets/$walletId';
}
