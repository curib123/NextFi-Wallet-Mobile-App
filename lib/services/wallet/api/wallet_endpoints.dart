class WalletEndpoints {
  static const String base = '/wallets';

  static String list() => base;
  static String create() => base;
  static String update(String id) => '$base/$id';
  static String remove(String id) => '$base/$id';
}
