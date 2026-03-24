import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'package:next_fi/core/services/base_url/base_url.dart';

class WebsiteLinksConfig {
  const WebsiteLinksConfig({
    required this.privacyPolicyUrl,
    required this.termsAndConditionsUrl,
    required this.nextfiWebsiteUrl,
    required this.stellarWebsiteUrl,
    this.updatedAt,
  });

  final String privacyPolicyUrl;
  final String termsAndConditionsUrl;
  final String nextfiWebsiteUrl;
  final String stellarWebsiteUrl;
  final String? updatedAt;

  static const WebsiteLinksConfig fallback = WebsiteLinksConfig(
    privacyPolicyUrl: 'https://nextfi.io/privacy-policy',
    termsAndConditionsUrl: 'https://nextfi.io/terms-and-conditions',
    nextfiWebsiteUrl: 'https://nextfi.io',
    stellarWebsiteUrl: 'https://stellar.org',
  );

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'privacyPolicyUrl': privacyPolicyUrl,
      'termsAndConditionsUrl': termsAndConditionsUrl,
      'nextfiWebsiteUrl': nextfiWebsiteUrl,
      'stellarWebsiteUrl': stellarWebsiteUrl,
      'updatedAt': updatedAt,
    };
  }

  factory WebsiteLinksConfig.fromJson(Map<String, dynamic> json) {
    String read(String key, String fallback) {
      final value = json[key]?.toString().trim();
      return value == null || value.isEmpty ? fallback : value;
    }

    return WebsiteLinksConfig(
      privacyPolicyUrl: read(
        'privacyPolicyUrl',
        WebsiteLinksConfig.fallback.privacyPolicyUrl,
      ),
      termsAndConditionsUrl: read(
        'termsAndConditionsUrl',
        WebsiteLinksConfig.fallback.termsAndConditionsUrl,
      ),
      nextfiWebsiteUrl: read(
        'nextfiWebsiteUrl',
        WebsiteLinksConfig.fallback.nextfiWebsiteUrl,
      ),
      stellarWebsiteUrl: read(
        'stellarWebsiteUrl',
        WebsiteLinksConfig.fallback.stellarWebsiteUrl,
      ),
      updatedAt: json['updatedAt']?.toString(),
    );
  }
}

class WebsiteLinksService {
  WebsiteLinksService({
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

  static const String _cacheKey = 'nextfi.website_links.current.v1';

  Future<WebsiteLinksConfig> getCurrent() async {
    final cached = await readCached();

    try {
      final live = await _fetchCurrent();
      await _writeCache(live);
      return live;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[WebsiteLinksService] Fetch failed: $error');
      }
      return cached ?? WebsiteLinksConfig.fallback;
    }
  }

  Future<WebsiteLinksConfig?> readCached() async {
    try {
      final raw = await _secureStorage.read(key: _cacheKey);
      if (raw == null || raw.trim().isEmpty) {
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return WebsiteLinksConfig.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<WebsiteLinksConfig> _fetchCurrent() async {
    final uri = Uri.parse('$centralizedBaseUrl/website-links');
    final headers = const <String, String>{
      HttpHeaders.acceptHeader: 'application/json',
    };

    final res = await _client.get(uri, headers: headers).timeout(_timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw http.ClientException(
        'Website links request failed with status ${res.statusCode}',
        uri,
      );
    }

    final dynamic decoded = res.body.trim().isEmpty
        ? <String, dynamic>{}
        : jsonDecode(res.body);
    final map = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    final root = _unwrapMap(map);
    return WebsiteLinksConfig.fromJson(root);
  }

  Map<String, dynamic> _unwrapMap(Map<String, dynamic> raw) {
    final data = raw['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    return raw;
  }

  Future<void> _writeCache(WebsiteLinksConfig config) async {
    await _secureStorage.write(
      key: _cacheKey,
      value: jsonEncode(config.toJson()),
    );
  }

  void dispose() => _client.close();
}
