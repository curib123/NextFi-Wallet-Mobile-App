import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:next_fi/app/config/app_config.dart';
import 'package:next_fi/core/services/secure_storage/seed_storage.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

class WalletBackendClient {
  WalletBackendClient._();

  static final WalletBackendClient I = WalletBackendClient._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _sessionPrefix = 'nextfi.wallet_backend.session.v1.';

  final http.Client _client = http.Client();

  String _normalizeAddress(String value) => value.trim().toUpperCase();

  Uri _uri(String path, {Map<String, String>? queryParams}) {
    final base = Uri.parse(AppConfig.instance.backendBaseUrl);
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return base.replace(
      path: '${base.path}$normalizedPath',
      queryParameters: queryParams,
    );
  }

  String _sessionKey(String publicAddress) =>
      '$_sessionPrefix${_normalizeAddress(publicAddress)}';

  Future<void> _writeSession(
    String publicAddress, {
    required String token,
    required String sessionId,
    required String expiresAt,
  }) async {
    await _storage.write(
      key: _sessionKey(publicAddress),
      value: jsonEncode({
        'token': token,
        'sessionId': sessionId,
        'expiresAt': expiresAt,
      }),
    );
  }

  Future<Map<String, dynamic>?> _readSession(String publicAddress) async {
    final raw = await _storage.read(key: _sessionKey(publicAddress));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {}
    return null;
  }

  Future<void> clearSession(String publicAddress) async {
    await _storage.delete(key: _sessionKey(publicAddress));
  }

  Future<String?> currentActiveToken() async {
    final active = await SeedStorage.getActiveWalletMeta();
    final publicAddress = active?.publicAddress;
    if (publicAddress == null || publicAddress.trim().isEmpty) return null;
    return sessionTokenFor(publicAddress);
  }

  Future<String?> ensureCurrentActiveToken() async {
    final active = await SeedStorage.getActiveWalletMeta();
    final publicAddress = active?.publicAddress?.trim();
    if (publicAddress == null || publicAddress.isEmpty) {
      return null;
    }

    final cached = await sessionTokenFor(publicAddress);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    final mnemonic = await SeedStorage.getActiveSeed();
    if (mnemonic == null || mnemonic.trim().isEmpty) {
      return null;
    }

    final wallet = await Wallet.from(mnemonic.trim());
    final keyPair = await wallet.getKeyPair(index: 0);
    return ensureWalletSession(publicAddress: publicAddress, keyPair: keyPair);
  }

  Future<String?> sessionTokenFor(String publicAddress) async {
    final session = await _readSession(publicAddress);
    if (session == null) return null;

    final expiresAt = DateTime.tryParse(session['expiresAt']?.toString() ?? '');
    if (expiresAt != null && expiresAt.isBefore(DateTime.now().toUtc())) {
      await clearSession(publicAddress);
      return null;
    }

    final token = session['token']?.toString();
    return (token == null || token.isEmpty) ? null : token;
  }

  Future<Map<String, String>> _authHeaders(String publicAddress) async {
    final token = await sessionTokenFor(publicAddress);
    if (token == null || token.isEmpty) {
      throw WalletBackendException('Missing wallet session token.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'X-NextFi-Wallet': _normalizeAddress(publicAddress),
    };
  }

  Future<Map<String, dynamic>> _decodeJson(http.Response response) async {
    if (response.body.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{'data': decoded};
  }

  Future<Map<String, dynamic>> _requestJson({
    required Future<http.Response> Function() request,
    Set<int> okStatuses = const {200, 201},
  }) async {
    final response = await request();
    if (!okStatuses.contains(response.statusCode)) {
      throw WalletBackendException(
        'Wallet backend request failed (${response.statusCode}): ${response.body}',
      );
    }
    return _decodeJson(response);
  }

  String _extractString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key]?.toString();
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  Future<String> ensureWalletSession({
    required String publicAddress,
    required KeyPair keyPair,
    bool forceRefresh = false,
  }) async {
    final normalized = _normalizeAddress(publicAddress);
    if (!forceRefresh) {
      final cached = await _readSession(normalized);
      if (cached != null) {
        final token = _extractString(cached, const ['token']);
        final expiresAt = DateTime.tryParse(
          cached['expiresAt']?.toString() ?? '',
        );
        if (token.isNotEmpty &&
            expiresAt != null &&
            expiresAt.isAfter(
              DateTime.now().toUtc().add(const Duration(seconds: 10)),
            )) {
          return token;
        }
      }
    }

    final challengeData = await _requestJson(
      request: () => _client.post(
        _uri('/wallet-auth/challenge'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'publicKey': normalized}),
      ),
    );
    final nonceId = _extractString(challengeData, const ['nonceId']);
    final challenge = _extractString(challengeData, const ['challenge']);
    if (nonceId.isEmpty || challenge.isEmpty) {
      throw WalletBackendException('Wallet challenge response was invalid.');
    }

    final signature = base64Encode(keyPair.sign(utf8.encode(challenge)));
    final verifyData = await _requestJson(
      request: () => _client.post(
        _uri('/wallet-auth/verify'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'publicKey': normalized,
          'nonceId': nonceId,
          'signature': signature,
        }),
      ),
    );

    final token = _extractString(verifyData, const ['token']);
    final sessionId = _extractString(verifyData, const ['sessionId']);
    final expiresAt = _extractString(verifyData, const ['expiresAt']);
    if (token.isEmpty || sessionId.isEmpty || expiresAt.isEmpty) {
      throw WalletBackendException('Wallet verify response was invalid.');
    }

    await _writeSession(
      normalized,
      token: token,
      sessionId: sessionId,
      expiresAt: expiresAt,
    );
    return token;
  }

  Future<Map<String, dynamic>> registerWallet({
    required String publicAddress,
    required KeyPair keyPair,
  }) async {
    final normalized = _normalizeAddress(publicAddress);
    await ensureWalletSession(publicAddress: normalized, keyPair: keyPair);
    return _requestJson(
      request: () async => _client.post(
        _uri('/wallets/register'),
        headers: await _authHeaders(normalized),
      ),
    );
  }

  Future<Map<String, dynamic>> fetchWalletContext({
    required String publicAddress,
    required KeyPair keyPair,
  }) async {
    final normalized = _normalizeAddress(publicAddress);
    await ensureWalletSession(publicAddress: normalized, keyPair: keyPair);
    return _requestJson(
      request: () async => _client.get(
        _uri('/wallets/me'),
        headers: await _authHeaders(normalized),
      ),
    );
  }

  Future<Map<String, dynamic>> fetchPortfolio({
    required String publicAddress,
    required KeyPair keyPair,
    String range = '24H',
  }) async {
    final normalized = _normalizeAddress(publicAddress);
    await ensureWalletSession(publicAddress: normalized, keyPair: keyPair);
    return _requestJson(
      request: () async => _client.get(
        _uri('/portfolio/me', queryParams: {'range': range}),
        headers: await _authHeaders(normalized),
      ),
    );
  }

  Future<Map<String, dynamic>> updatePreferences({
    required String publicAddress,
    required KeyPair keyPair,
    required Map<String, dynamic> payload,
  }) async {
    final normalized = _normalizeAddress(publicAddress);
    await ensureWalletSession(publicAddress: normalized, keyPair: keyPair);
    return _requestJson(
      request: () async => _client.put(
        _uri('/wallets/preferences'),
        headers: await _authHeaders(normalized),
        body: jsonEncode(payload),
      ),
    );
  }

  Future<Map<String, dynamic>> createSnapshot({
    required String publicAddress,
    required KeyPair keyPair,
    required Map<String, dynamic> payload,
  }) async {
    final normalized = _normalizeAddress(publicAddress);
    await ensureWalletSession(publicAddress: normalized, keyPair: keyPair);
    return _requestJson(
      request: () async => _client.post(
        _uri('/portfolio/snapshots'),
        headers: await _authHeaders(normalized),
        body: jsonEncode(payload),
      ),
    );
  }

  Future<Map<String, dynamic>> createActivityEvent({
    required String publicAddress,
    required KeyPair keyPair,
    required String eventType,
    required String idempotencyKey,
    Map<String, dynamic>? metadata,
  }) async {
    final normalized = _normalizeAddress(publicAddress);
    await ensureWalletSession(publicAddress: normalized, keyPair: keyPair);
    return _requestJson(
      request: () async => _client.post(
        _uri('/wallet-activity/events'),
        headers: await _authHeaders(normalized),
        body: jsonEncode({
          'eventType': eventType,
          'idempotencyKey': idempotencyKey,
          if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
        }),
      ),
    );
  }
}

class WalletBackendException implements Exception {
  WalletBackendException(this.message);

  final String message;

  @override
  String toString() => 'WalletBackendException: $message';
}
