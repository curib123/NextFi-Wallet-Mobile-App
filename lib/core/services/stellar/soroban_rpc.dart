import 'dart:convert';
import 'package:http/http.dart' as http;

class SorobanRpc {
  final String base;
  final Map<String, String>? headers;
  const SorobanRpc(this.base, [this.headers]);

  Future<Map<String, dynamic>?> _rpc(
    String method, {
    Object? params,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final uri = Uri.parse(base);
    final payload = json.encode({
      'jsonrpc': '2.0',
      'id': 1,
      'method': method,
      'params': params ?? {},
    });
    final resp = await http
        .post(
          uri,
          headers: {
            'content-type': 'application/json',
            if (headers != null) ...headers!,
          },
          body: payload,
        )
        .timeout(timeout);
    if (resp.statusCode != 200) return null;
    final j = json.decode(resp.body) as Map<String, dynamic>;
    if (j['error'] != null) return null;
    return j['result'] as Map<String, dynamic>?;
  }

  Future<String?> sendTransaction(String envelopeB64) async {
    final r = await _rpc(
      'sendTransaction',
      params: {'transaction': envelopeB64},
    );
    return (r?['hash'] as String?);
  }

  Future<int?> getLatestLedgerSequence() async {
    final r = await _rpc('getLatestLedger');
    final n = r?['sequence'];
    if (n is int) return n;
    if (n is num) return n.toInt();
    return null;
  }
}
