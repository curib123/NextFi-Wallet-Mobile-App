import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:next_fi/services/oath2.0/api/endpoints.dart';
import 'package:next_fi/services/oath2.0/models/auth_exception.dart';
import 'package:next_fi/services/oath2.0/models/auth_response.dart';
import 'package:next_fi/services/secure_storage/token_storage.dart';

import '../../base_url/base_url.dart';


/// HTTP client that auto-attaches Bearer tokens and handles 401 refresh.
class AuthHttpClient {
  static const _baseUrl = cetralized_baseUrl;

  final http.Client _client;
  final TokenStorage _tokenStorage;
  final Duration _timeout;

  bool _isRefreshing = false;
  final _refreshQueue = <Completer<void>>[];

  AuthHttpClient({
    http.Client? client,
    required TokenStorage tokenStorage,
    Duration timeout = const Duration(seconds: 15),
  })  : _client = client ?? http.Client(),
        _tokenStorage = tokenStorage,
        _timeout = timeout;

  // ── Public HTTP methods ──────────────────────────────────────────

  Future<Map<String, dynamic>> get(
      String path, {
        bool auth = true,
      }) =>
      _request('GET', path, auth: auth);

  Future<Map<String, dynamic>> post(
      String path, {
        Map<String, dynamic>? body,
        bool auth = true,
      }) =>
      _request('POST', path, body: body, auth: auth);

  // ── Core request handler ─────────────────────────────────────────

  Future<Map<String, dynamic>> _request(
      String method,
      String path, {
        Map<String, dynamic>? body,
        bool auth = true,
      }) async {
    final response = await _execute(method, path, body: body, auth: auth);

    if (response.statusCode == 401 && auth) {
      await _refreshTokens();
      final retry = await _execute(method, path, body: body, auth: auth);
      return _parseResponse(retry);
    }

    return _parseResponse(response);
  }

  Future<http.Response> _execute(
      String method,
      String path, {
        Map<String, dynamic>? body,
        bool auth = true,
      }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final headers = <String, String>{
      HttpHeaders.contentTypeHeader: 'application/json',
    };

    if (auth) {
      final token = await _tokenStorage.accessToken;
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }

    final request = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);

    final streamed = await _client.send(request).timeout(_timeout);
    return http.Response.fromStream(streamed);
  }

  // ── Token refresh with queue dedup ───────────────────────────────

  Future<void> _refreshTokens() async {
    if (_isRefreshing) {
      final completer = Completer<void>();
      _refreshQueue.add(completer);
      return completer.future;
    }

    _isRefreshing = true;
    try {
      final refreshToken = await _tokenStorage.refreshToken;
      if (refreshToken == null) throw const RefreshFailedException();

      final response = await _execute(
        'POST',
        AuthEndpoints.refresh,
        body: {'refreshToken': refreshToken},
        auth: false,
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        await _tokenStorage.clear();
        throw const RefreshFailedException();
      }

      final tokens = TokenResponse.fromJson(jsonDecode(response.body));
      await _tokenStorage.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );

      for (final c in _refreshQueue) {
        c.complete();
      }
    } catch (e) {
      for (final c in _refreshQueue) {
        c.completeError(e);
      }
      rethrow;
    } finally {
      _refreshQueue.clear();
      _isRefreshing = false;
    }
  }

  // ── Response parsing ─────────────────────────────────────────────

  Map<String, dynamic> _parseResponse(http.Response response) {
    final body = response.body.isNotEmpty
        ? jsonDecode(response.body) as Map<String, dynamic>
        : <String, dynamic>{};

    if (response.statusCode >= 200 && response.statusCode < 300) return body;

    throw AuthException(
      body['message']?.toString() ?? 'Request failed',
      statusCode: response.statusCode,
    );
  }

  void dispose() => _client.close();
}