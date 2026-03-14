class FederationAddressEndpoints {
  static const String authBase = '/federation-address';
  static const String publicFederation = '/federation';
  static const String publicToml = '/.well-known/stellar.toml';

  static String myList() => authBase;
  static String create() => authBase;
  static String byId(String id) => '$authBase/$id';
  static String resolveExternal() => '$authBase/resolve-external';
  static String resolveLegacy() => '$authBase/resolve';
}
