import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:next_fi/services/base_url/base_url.dart';
import 'package:next_fi/services/secure_storage/token_storage.dart';

enum AnnouncementType { announcement, update, maintenance }

class AnnouncementItem {
  const AnnouncementItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.isCompulsory,
    this.actionLabel,
    this.actionUrl,
    this.minAppVersion,
    this.requiresUpdate = false,
    this.isForceUpdate = false,
    this.acknowledged = false,
  });

  final String id;
  final AnnouncementType type;
  final String title;
  final String message;
  final bool isCompulsory;
  final String? actionLabel;
  final String? actionUrl;
  final String? minAppVersion;
  final bool requiresUpdate;
  final bool isForceUpdate;
  final bool acknowledged;

  factory AnnouncementItem.fromJson(Map<String, dynamic> json) {
    AnnouncementType parseType(String? raw) {
      switch ((raw ?? '').toUpperCase().trim()) {
        case 'UPDATE':
          return AnnouncementType.update;
        case 'MAINTENANCE':
          return AnnouncementType.maintenance;
        default:
          return AnnouncementType.announcement;
      }
    } 

    return AnnouncementItem(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      type: parseType(json['type']?.toString()),
      title: (json['title'] ?? '').toString().trim(),
      message: (json['message'] ?? '').toString().trim(),
      isCompulsory: json['isCompulsory'] == true,
      actionLabel: json['actionLabel']?.toString().trim(),
      actionUrl: json['actionUrl']?.toString().trim(),
      minAppVersion: json['minAppVersion']?.toString().trim(),
      requiresUpdate: json['requiresUpdate'] == true,
      isForceUpdate:
          json['isForceUpdate'] == true || json['requiresForceUpdate'] == true,
      acknowledged: json['acknowledged'] == true,
    );
  }
}

class VersionCheckResult {
  const VersionCheckResult({
    required this.requiresUpdate,
    required this.requiresForceUpdate,
    this.requiredMinVersion,
    this.updates = const [],
  });
 
  final bool requiresUpdate;
  final bool requiresForceUpdate;
  final String? requiredMinVersion;
  final List<AnnouncementItem> updates;
}

class AnnouncementsService {
  AnnouncementsService({http.Client? client, TokenStorage? tokenStorage})
    : _client = client ?? http.Client(),
      _tokenStorage = tokenStorage ?? TokenStorage();

  final http.Client _client;
  final TokenStorage _tokenStorage;
  static const _timeout = Duration(seconds: 20);

  Future<VersionCheckResult> versionCheck({required String appVersion}) async {
    final uri = Uri.parse(
      '$centralized_baseUrl/announcements/version-check?appVersion=$appVersion',
    );
    final body = await _getJson(uri, auth: false);
    final root = _unwrapEnvelope(body);

    final updatesRaw = _extractList(root, keys: const ['updates', 'items']);
    final updates = updatesRaw
        .whereType<Map>()
        .map((e) => AnnouncementItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return VersionCheckResult(
      requiresUpdate: root['requiresUpdate'] == true,
      requiresForceUpdate: root['requiresForceUpdate'] == true,
      requiredMinVersion: root['requiredMinVersion']?.toString(),
      updates: updates,
    );
  }

  Future<List<AnnouncementItem>> getActiveForCurrentUser({
    required String appVersion,
  }) async {
    final hasToken = await _tokenStorage.accessToken != null;
    final uri = hasToken
        ? Uri.parse(
            '$centralized_baseUrl/announcements/me/active?appVersion=$appVersion',
          )
        : Uri.parse('$centralized_baseUrl/announcements/active');

    final body = await _getJson(uri, auth: hasToken);
    final root = _unwrapEnvelope(body);
    final itemsRaw = _extractList(
      root,
      keys: const ['items', 'announcements', 'data'],
    );

    return itemsRaw
        .whereType<Map>()
        .map((e) => AnnouncementItem.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.id.isNotEmpty && e.title.isNotEmpty)
        .toList();
  }

  Future<void> acknowledge(String announcementId) async {
    if (announcementId.trim().isEmpty) return;
    final token = await _tokenStorage.accessToken;
    if (token == null) return;

    final uri = Uri.parse(
      '$centralized_baseUrl/announcements/${announcementId.trim()}/ack',
    );
    await _postJson(uri, auth: true);
  }

  Future<Map<String, dynamic>> _getJson(Uri uri, {required bool auth}) async {
    final headers = await _headers(auth: auth);
    final res = await _client.get(uri, headers: headers).timeout(_timeout);
    return _decodeMap(res);
  }

  Future<Map<String, dynamic>> _postJson(Uri uri, {required bool auth}) async {
    final headers = await _headers(auth: auth);
    final res = await _client.post(uri, headers: headers).timeout(_timeout);
    return _decodeMap(res);
  }

  Future<Map<String, String>> _headers({required bool auth}) async {
    final headers = <String, String>{HttpHeaders.acceptHeader: 'application/json'};
    if (auth) {
      final token = await _tokenStorage.accessToken;
      if (token != null && token.isNotEmpty) {
        headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
      }
    }
    return headers;
  }

  Map<String, dynamic> _decodeMap(http.Response res) {
    final dynamic decoded = res.body.trim().isEmpty ? <String, dynamic>{} : jsonDecode(res.body);
    final map = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{'data': decoded};

    if (res.statusCode >= 200 && res.statusCode < 300) return map;
    throw Exception(map['message']?.toString() ?? 'Announcements request failed');
  }

  Map<String, dynamic> _unwrapEnvelope(Map<String, dynamic> raw) {
    final data = raw['data'];
    if (data is Map<String, dynamic>) return data;
    return raw;
  }

  List<dynamic> _extractList(
    Map<String, dynamic> root, {
    required List<String> keys,
  }) {
    for (final k in keys) {
      final v = root[k];
      if (v is List) return v;
      if (v is Map<String, dynamic>) {
        for (final nested in keys) {
          final nv = v[nested];
          if (nv is List) return nv;
        }
      }
    }
    return const [];
  }

  void dispose() => _client.close();
}
