import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:next_fi/core/services/base_url/base_url.dart';

class AppCoverConfig {
  const AppCoverConfig({required this.imageUrl, required this.isVisible});

  final String? imageUrl;
  final bool isVisible;

  bool get hasUsableImage =>
      isVisible && imageUrl != null && imageUrl!.trim().isNotEmpty;
}

class AppCoverService {
  AppCoverService({
    http.Client? client,
    FlutterSecureStorage? secureStorage,
    Duration timeout = const Duration(seconds: 12),
  }) : _client = client ?? http.Client(),
       _secureStorage =
           secureStorage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(encryptedSharedPreferences: true),
             iOptions: IOSOptions(
               accessibility: KeychainAccessibility.first_unlock,
             ),
           ),
       _timeout = timeout;

  final http.Client _client;
  final FlutterSecureStorage _secureStorage;
  final Duration _timeout;

  static const String _kCacheKey = 'nextfi.app_cover.current.v1';

  Future<AppCoverConfig?> getCurrent() async {
    final cached = await _readCached();
    try {
      final live = await _fetchCurrent();
      if (live != null) {
        await _writeCache(live);
      }
      return live ?? cached;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AppCoverService] Primary fetch failed: $e');
      }

      if (_isRetryable(e)) {
        try {
          await Future<void>.delayed(const Duration(milliseconds: 650));
          final retry = await _fetchCurrent();
          if (retry != null) {
            await _writeCache(retry);
          }
          return retry ?? cached;
        } catch (retryError) {
          if (kDebugMode) {
            debugPrint('[AppCoverService] Retry failed: $retryError');
          }
        }
      }

      if (cached != null && kDebugMode) {
        debugPrint(
          '[AppCoverService] Using cached app cover: ${cached.imageUrl}',
        );
      }
      return cached;
    }
  }

  Future<AppCoverConfig?> _fetchCurrent() async {
    final uri = Uri.parse('$centralizedBaseUrl/app-cover');
    final headers = const <String, String>{
      HttpHeaders.acceptHeader: 'application/json',
    };

    final res = await _client.get(uri, headers: headers).timeout(_timeout);

    if (res.statusCode == 404) {
      return null;
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw http.ClientException(
        'App cover request failed with status ${res.statusCode}',
        uri,
      );
    }

    final dynamic decoded = res.body.trim().isEmpty
        ? <String, dynamic>{}
        : jsonDecode(res.body);
    final map = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    final root = _unwrapMap(map);

    final imageUrl = _normalizeImageUrl(
      _readOptionalText(root, const <String>[
        'imageUrl',
        'coverImageUrl',
        'image',
      ]),
    );
    final isVisible = root['isVisible'] != false;

    return AppCoverConfig(imageUrl: imageUrl, isVisible: isVisible);
  }

  Map<String, dynamic> _unwrapMap(Map<String, dynamic> raw) {
    final data = raw['data'];
    if (data is Map<String, dynamic>) return data;
    return raw;
  }

  String? _readOptionalText(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  String? _normalizeImageUrl(String? rawUrl) {
    if (rawUrl == null) return null;

    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return null;

    final parsed = Uri.tryParse(trimmed);
    if (parsed != null && parsed.hasScheme && parsed.host.isNotEmpty) {
      return parsed.toString();
    }

    final base = Uri.parse(centralizedBaseUrl);

    if (trimmed.startsWith('//')) {
      return base
          .replace(path: '', query: null, fragment: null)
          .resolve('${base.scheme}:$trimmed')
          .toString();
    }

    final root = base.replace(path: '', query: null, fragment: null);
    if (trimmed.startsWith('/')) {
      return root.resolve(trimmed).toString();
    }

    return base.resolve(trimmed).toString();
  }

  Future<void> _writeCache(AppCoverConfig config) async {
    final payload = jsonEncode(<String, dynamic>{
      'imageUrl': config.imageUrl,
      'isVisible': config.isVisible,
    });
    await _secureStorage.write(key: _kCacheKey, value: payload);
  }

  Future<AppCoverConfig?> _readCached() async {
    try {
      final raw = await _secureStorage.read(key: _kCacheKey);
      if (raw == null || raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return AppCoverConfig(
        imageUrl: _normalizeImageUrl(decoded['imageUrl']?.toString()),
        isVisible: decoded['isVisible'] != false,
      );
    } catch (_) {
      return null;
    }
  }

  bool _isRetryable(Object error) =>
      error is SocketException ||
      error is TimeoutException ||
      error is http.ClientException;

  void dispose() => _client.close();
}
