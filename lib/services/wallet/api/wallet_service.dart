import 'dart:convert';
import 'package:http/http.dart' as http;

import 'wallet_endpoints.dart';
import '../helpers/wallet_helpers.dart';
import '../helpers/wallet_exceptions.dart';
import '../models/wallet_models.dart';
import '../models/wallet_dtos.dart';

typedef TokenProvider = Future<String?> Function();

class WalletService {
  WalletService({
    required this.tokenProvider,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final TokenProvider tokenProvider;
  final http.Client _client;

  Future<Map<String, String>> _headers() async {
    final token = await tokenProvider();

    if (token == null || token.isEmpty) {
      throw ApiException(401, 'Missing JWT token');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// ── GET /wallets ─────────────────────────────
  Future<List<WalletAddress>> list() async {
    final res = await _client.get(
      WalletHttp.uri(WalletEndpoints.list()),
      headers: await _headers(),
    );

    WalletHttp.ensureOk(res);

    final data = WalletHttp.decodeJson<dynamic>(res);

    if (data is List) {
      return data
          .map((e) => WalletAddress.fromJson(e))
          .toList();
    }

    throw ApiException(
      res.statusCode,
      'Unexpected response for GET /wallets',
      body: res.body,
    );
  }

  /// ── POST /wallets ────────────────────────────
  Future<WalletAddress> create(
      CreateWalletRequest req) async {
    final res = await _client.post(
      WalletHttp.uri(WalletEndpoints.create()),
      headers: await _headers(),
      body: jsonEncode(req.toJson()),
    );

    WalletHttp.ensureOk(res);

    final data = WalletHttp.decodeJson<dynamic>(res);

    if (data is Map<String, dynamic>) {
      return WalletAddress.fromJson(data);
    }

    throw ApiException(
      res.statusCode,
      'Unexpected response for POST /wallets',
      body: res.body,
    );
  }

  /// ── PATCH /wallets/:id ───────────────────────
  Future<WalletAddress> updateLabel(
      String id, {
        required String label,
      }) async {
    final res = await _client.patch(
      WalletHttp.uri(WalletEndpoints.update(id)),
      headers: await _headers(),
      body: jsonEncode(
        UpdateWalletRequest(label: label).toJson(),
      ),
    );

    WalletHttp.ensureOk(res);

    final data = WalletHttp.decodeJson<dynamic>(res);

    if (data is Map<String, dynamic>) {
      return WalletAddress.fromJson(data);
    }

    throw ApiException(
      res.statusCode,
      'Unexpected response for PATCH /wallets/$id',
      body: res.body,
    );
  }

  /// ── DELETE /wallets/:id ──────────────────────
  Future<void> remove(String id) async {
    final res = await _client.delete(
      WalletHttp.uri(WalletEndpoints.remove(id)),
      headers: await _headers(),
    );

    WalletHttp.ensureOk(res);
  }
}
