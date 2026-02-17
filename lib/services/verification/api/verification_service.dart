import 'dart:io';

import 'package:http/http.dart' as http;

import '../helpers/verification_exceptions.dart';
import '../helpers/verification_helpers.dart';
import '../models/verification_models.dart';
import 'verification_endpoints.dart';

typedef TokenProvider = Future<String?> Function();

class VerificationService {
  VerificationService({
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

  Future<String> _tokenOrThrow() async {
    final token = await tokenProvider();
    if (token == null || token.isEmpty) {
      throw ApiException(401, 'Missing JWT token');
    }
    return token;
  }

  Future<VerificationModel> getMe() async {
    final res = await _client.get(
      VerificationHttp.uri(VerificationEndpoints.me()),
      headers: await _headers(),
    );

    VerificationHttp.ensureOk(res);
    final data = VerificationHttp.decodeJson<dynamic>(res);

    if (data is Map<String, dynamic>) {
      return VerificationModel.fromJson(data);
    }

    throw ApiException(
      res.statusCode,
      'Unexpected response for GET /verification/me',
      body: res.body,
    );
  }

  Future<VerificationModel> submit({
    required File selfie,
    String? paymentAccountId,
  }) async {
    final token = await _tokenOrThrow();

    final req = http.MultipartRequest(
      'POST',
      VerificationHttp.uri(VerificationEndpoints.submit()),
    )
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json'
      ..files.add(await http.MultipartFile.fromPath('selfie', selfie.path));

    if (paymentAccountId != null && paymentAccountId.trim().isNotEmpty) {
      req.fields['paymentAccountId'] = paymentAccountId;
    }

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);

    VerificationHttp.ensureOk(res);
    final data = VerificationHttp.decodeJson<dynamic>(res);

    if (data is Map<String, dynamic>) {
      return VerificationModel.fromJson(data);
    }

    throw ApiException(
      res.statusCode,
      'Unexpected response for POST /verification/submit',
      body: res.body,
    );
  }
}
