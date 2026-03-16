// lib/services/device_meta/device_meta_service.dart
//
// Simple class you can call to get deviceId/platform/appVersion.
// No constructor args needed.
//
// pubspec.yaml:
//   device_info_plus: ^10.1.0
//   package_info_plus: ^8.0.0
//   flutter_secure_storage: ^9.2.2
//   uuid: ^4.4.0

import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

class DeviceMeta {
  final String deviceId;
  final String platform;   // android | ios | web
  final String appVersion; // 1.2.3+45

  const DeviceMeta({
    required this.deviceId,
    required this.platform,
    required this.appVersion,
  });
}

class DeviceMetaService {
  DeviceMetaService._();
  static final DeviceMetaService instance = DeviceMetaService._();

  static const _deviceIdKey = 'nextfi.device_id.v1';

  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  DeviceMeta? _cached;

  /// Call this once and reuse the returned meta (cached).
  Future<DeviceMeta> getMeta({bool forceRefresh = false}) async {
    if (!forceRefresh && _cached != null) return _cached!;

    final id = await _getOrCreateInstallId();
    final plat = _platform;
    final ver = await _appVersion;

    // optional warm-up (safe)
    await _warmDeviceInfo(plat);

    final m = DeviceMeta(deviceId: id, platform: plat, appVersion: ver);
    _cached = m;
    return m;
  }

  // ───────────────────────── internals ─────────────────────────

  Future<String> _getOrCreateInstallId() async {
    final existing = await _secure.read(key: _deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final id = const Uuid().v4();
    await _secure.write(key: _deviceIdKey, value: id);
    return id;
  }

  String get _platform {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'web';
  }

  Future<String> get _appVersion async {
    final info = await PackageInfo.fromPlatform();
    return '${info.version}+${info.buildNumber}';
  }

  Future<void> _warmDeviceInfo(String platform) async {
    try {
      if (platform == 'android') {
        await _deviceInfo.androidInfo;
      } else if (platform == 'ios') {
        await _deviceInfo.iosInfo;
      }
    } catch (_) {}
  }
}
