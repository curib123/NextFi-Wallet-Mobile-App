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
    this.imageUrl,
    this.typeLabel,
    this.actionLabel,
    this.dismissLabel,
    this.actionUrl,
    this.minAppVersion,
    this.requiresUpdate = false,
    this.isForceUpdate = false,
    this.acknowledged = false,
    this.updatedAt,
  });

  final String id;
  final AnnouncementType type;
  final String title;
  final String message;
  final bool isCompulsory;
  final String? imageUrl;
  final String? typeLabel;
  final String? actionLabel;
  final String? dismissLabel;
  final String? actionUrl;
  final String? minAppVersion;
  final bool requiresUpdate;
  final bool isForceUpdate;
  final bool acknowledged;
  final DateTime? updatedAt;

  String get displayKey =>
      '$id:${updatedAt?.millisecondsSinceEpoch ?? 0}:${isForceUpdate ? 1 : 0}:${isCompulsory ? 1 : 0}';

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
      imageUrl: _readOptionalText(json, const ['imageUrl', 'image']),
      typeLabel: _readOptionalText(json, const ['typeLabel', 'label']),
      actionLabel: json['actionLabel']?.toString().trim(),
      dismissLabel: _readOptionalText(json, const ['dismissLabel', 'secondaryActionLabel']),
      actionUrl: json['actionUrl']?.toString().trim(),
      minAppVersion: json['minAppVersion']?.toString().trim(),
      requiresUpdate: json['requiresUpdate'] == true,
      isForceUpdate:
          json['isForceUpdate'] == true || json['requiresForceUpdate'] == true,
      acknowledged: json['acknowledged'] == true,
      updatedAt: _readDateTime(json, const ['updatedAt', 'createdAt', 'startsAt']),
    );
  }

  static String? _readOptionalText(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final raw = json[key]?.toString().trim();
      if (raw != null && raw.isNotEmpty) return raw;
    }
    return null;
  }

  static DateTime? _readDateTime(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final raw = json[key]?.toString().trim();
      if (raw == null || raw.isEmpty) continue;
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed;
    }
    return null;
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
    Map<String, dynamic> body;
    if (hasToken) {
      try {
        final authUri = Uri.parse(
          '$centralized_baseUrl/announcements/me/active?appVersion=$appVersion',
        );
        body = await _getJson(authUri, auth: true);
      } catch (_) {
        final publicUri = Uri.parse('$centralized_baseUrl/announcements/active');
        body = await _getJson(publicUri, auth: false);
      }
    } else {
      final publicUri = Uri.parse('$centralized_baseUrl/announcements/active');
      body = await _getJson(publicUri, auth: false);
    }

    final itemsRaw = _extractList(
      body,
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
    final directData = root['data'];
    if (directData is List) return directData;

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

    final nestedData = root['data'];
    if (nestedData is Map<String, dynamic>) {
      for (final k in keys) {
        final v = nestedData[k];
        if (v is List) return v;
      }
    }

    return const [];
  }

  void dispose() => _client.close();
}
