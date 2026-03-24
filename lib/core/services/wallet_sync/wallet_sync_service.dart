import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:next_fi/core/services/wallet_sync/wallet_backend_client.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import 'package:uuid/uuid.dart';

class WalletSyncService {
  WalletSyncService._();

  static final WalletSyncService I = WalletSyncService._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _queueKey = 'nextfi.wallet_sync.queue.v1';
  static const _contextPrefix = 'nextfi.wallet_sync.context.v1.';
  static const _portfolioPrefix = 'nextfi.wallet_sync.portfolio.v1.';
  static const _preferencesPrefix = 'nextfi.wallet_sync.preferences.v1.';

  final _uuid = const Uuid();
  final WalletBackendClient _backend = WalletBackendClient.I;

  String _normalizeAddress(String value) => value.trim().toUpperCase();
  String _contextKey(String address) => '$_contextPrefix${_normalizeAddress(address)}';
  String _portfolioKey(String address) => '$_portfolioPrefix${_normalizeAddress(address)}';
  String _preferencesKey(String address) =>
      '$_preferencesPrefix${_normalizeAddress(address)}';

  Future<List<Map<String, dynamic>>> _readQueue() async {
    final raw = await _storage.read(key: _queueKey);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded
          .whereType<Map>()
          .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
          .cast<Map<String, dynamic>>()
          .toList(growable: false);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _writeQueue(List<Map<String, dynamic>> queue) async {
    await _storage.write(key: _queueKey, value: jsonEncode(queue));
  }

  Future<void> _cacheJson(String key, Map<String, dynamic> value) async {
    await _storage.write(key: key, value: jsonEncode(value));
  }

  Future<Map<String, dynamic>?> _readCachedJson(String key) async {
    final raw = await _storage.read(key: key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {}
    return null;
  }

  Future<void> _enqueue({
    required String type,
    required String publicAddress,
    required Map<String, dynamic> payload,
    String? uniqueKey,
  }) async {
    final normalized = _normalizeAddress(publicAddress);
    final queue = await _readQueue();
    if (uniqueKey != null && uniqueKey.trim().isNotEmpty) {
      queue.removeWhere(
        (item) =>
            item['type'] == type &&
            item['publicAddress'] == normalized &&
            item['uniqueKey'] == uniqueKey,
      );
    }
    queue.add({
      'id': _uuid.v4(),
      'type': type,
      'publicAddress': normalized,
      'payload': payload,
      'uniqueKey': uniqueKey,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
    await _writeQueue(queue);
  }

  Future<void> queueWalletRegistration({
    required String publicAddress,
    String? nickname,
  }) {
    final normalized = _normalizeAddress(publicAddress);
    return _enqueue(
      type: 'register',
      publicAddress: normalized,
      payload: {
        if (nickname != null && nickname.trim().isNotEmpty)
          'nickname': nickname.trim(),
      },
      uniqueKey: normalized,
    );
  }

  Future<void> queuePreferences({
    required String publicAddress,
    required Map<String, dynamic> payload,
  }) async {
    final normalized = _normalizeAddress(publicAddress);
    await _cacheJson(_preferencesKey(normalized), payload);
    await _enqueue(
      type: 'preferences',
      publicAddress: normalized,
      payload: payload,
      uniqueKey: normalized,
    );
  }

  Future<void> queueSnapshot({
    required String publicAddress,
    required Map<String, dynamic> payload,
    required String dedupeKey,
  }) {
    return _enqueue(
      type: 'snapshot',
      publicAddress: publicAddress,
      payload: payload,
      uniqueKey: dedupeKey,
    );
  }

  Future<void> queueActivity({
    required String publicAddress,
    required String eventType,
    required String idempotencyKey,
    Map<String, dynamic>? metadata,
  }) {
    return _enqueue(
      type: 'activity',
      publicAddress: publicAddress,
      payload: {
        'eventType': eventType,
        'idempotencyKey': idempotencyKey,
        if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
      },
      uniqueKey: idempotencyKey,
    );
  }

  Future<WalletSyncBootstrapResult> initializeActiveWallet({
    required String publicAddress,
    required String walletName,
    required KeyPair keyPair,
  }) async {
    final normalized = _normalizeAddress(publicAddress);
    final cachedContext = await getCachedWalletContext(normalized);
    final cachedPortfolio = await getCachedPortfolio(normalized);

    try {
      await _backend.registerWallet(
        publicAddress: normalized,
        keyPair: keyPair,
      );
      await flushPendingForWallet(publicAddress: normalized, keyPair: keyPair);

      final context = await _backend.fetchWalletContext(
        publicAddress: normalized,
        keyPair: keyPair,
      );
      await _cacheJson(_contextKey(normalized), context);

      final preferences = _extractMap(context['preferences']);
      if (preferences != null) {
        await _cacheJson(_preferencesKey(normalized), preferences);
      }

      final portfolio = await _backend.fetchPortfolio(
        publicAddress: normalized,
        keyPair: keyPair,
      );
      await _cacheJson(_portfolioKey(normalized), portfolio);

      final activityId =
          'wallet_initialized|$normalized|${DateTime.now().toUtc().toIso8601String().substring(0, 13)}';
      await _backend.createActivityEvent(
        publicAddress: normalized,
        keyPair: keyPair,
        eventType: cachedContext == null ? 'wallet_initialized' : 'session_restored',
        idempotencyKey: activityId,
        metadata: {
          'walletName': walletName,
        },
      );

      return WalletSyncBootstrapResult(
        context: context,
        portfolio: portfolio,
        usedCache: false,
      );
    } catch (error) {
      debugPrint('WalletSyncService.initializeActiveWallet fallback: $error');
      await queueWalletRegistration(
        publicAddress: normalized,
        nickname: walletName,
      );
      return WalletSyncBootstrapResult(
        context: cachedContext,
        portfolio: cachedPortfolio,
        usedCache: true,
      );
    }
  }

  Future<void> syncImportedWallet({
    required String publicAddress,
    required String walletName,
    required KeyPair keyPair,
  }) async {
    final normalized = _normalizeAddress(publicAddress);
    await queueWalletRegistration(
      publicAddress: normalized,
      nickname: walletName,
    );

    try {
      await initializeActiveWallet(
        publicAddress: normalized,
        walletName: walletName,
        keyPair: keyPair,
      );
    } catch (_) {}
  }

  Future<void> flushPendingForWallet({
    required String publicAddress,
    required KeyPair keyPair,
  }) async {
    final normalized = _normalizeAddress(publicAddress);
    final queue = await _readQueue();
    if (queue.isEmpty) return;

    final remaining = <Map<String, dynamic>>[];
    for (final item in queue) {
      if (item['publicAddress'] != normalized) {
        remaining.add(item);
        continue;
      }

      final payload = _extractMap(item['payload']) ?? <String, dynamic>{};
      final type = item['type']?.toString() ?? '';
      try {
        if (type == 'register') {
          await _backend.registerWallet(
            publicAddress: normalized,
            keyPair: keyPair,
          );
          final nickname = payload['nickname']?.toString();
          if (nickname != null && nickname.trim().isNotEmpty) {
            await _backend.updatePreferences(
              publicAddress: normalized,
              keyPair: keyPair,
              payload: {'nickname': nickname.trim()},
            );
          }
        } else if (type == 'preferences') {
          await _backend.updatePreferences(
            publicAddress: normalized,
            keyPair: keyPair,
            payload: payload,
          );
        } else if (type == 'snapshot') {
          await _backend.createSnapshot(
            publicAddress: normalized,
            keyPair: keyPair,
            payload: payload,
          );
        } else if (type == 'activity') {
          await _backend.createActivityEvent(
            publicAddress: normalized,
            keyPair: keyPair,
            eventType: payload['eventType']?.toString() ?? 'app_open',
            idempotencyKey:
                payload['idempotencyKey']?.toString() ?? _uuid.v4(),
            metadata: _extractMap(payload['metadata']),
          );
        } else {
          remaining.add(item);
        }
      } catch (error) {
        debugPrint('WalletSyncService.flushPendingForWallet error: $error');
        remaining.add(item);
      }
    }

    await _writeQueue(remaining);
  }

  Future<Map<String, dynamic>?> getCachedWalletContext(String publicAddress) {
    return _readCachedJson(_contextKey(publicAddress));
  }

  Future<Map<String, dynamic>?> getCachedPortfolio(String publicAddress) {
    return _readCachedJson(_portfolioKey(publicAddress));
  }

  Future<Map<String, dynamic>?> getCachedPreferences(String publicAddress) {
    return _readCachedJson(_preferencesKey(publicAddress));
  }

  Map<String, dynamic>? _extractMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }
}

class WalletSyncBootstrapResult {
  const WalletSyncBootstrapResult({
    required this.context,
    required this.portfolio,
    required this.usedCache,
  });

  final Map<String, dynamic>? context;
  final Map<String, dynamic>? portfolio;
  final bool usedCache;
}
