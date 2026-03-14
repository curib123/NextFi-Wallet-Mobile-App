String? explorerUrlFor(String hash, bool isTestnet) {
  if (hash.isEmpty) return null;
  final net = isTestnet ? 'testnet' : 'public';
  return 'https://stellar.expert/explorer/$net/tx/$hash';
}

String shortAddr(String addr) {
  if (addr.isEmpty) return '—';
  if (addr.length <= 12) return addr;
  return '${addr.substring(0, 6)}…${addr.substring(addr.length - 4)}';
}
