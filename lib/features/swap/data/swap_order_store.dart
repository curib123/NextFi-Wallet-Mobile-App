// lib/features/swap/data/swap_order_store.dart
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../model/swap_order.dart';

class SwapOrderStore {
  static const _kKey = 'nextfi.swap.orders.v1';

  final FlutterSecureStorage _storage;
  final AndroidOptions _aOpts = const AndroidOptions(
    encryptedSharedPreferences: true, // uses EncryptedSharedPreferences on Android
  );
  final IOSOptions _iOpts = const IOSOptions(
    accessibility: KeychainAccessibility.first_unlock, // readable after first unlock
  );
  final MacOsOptions _mOpts = const MacOsOptions(
    accessibility: KeychainAccessibility.first_unlock,
  );
  final LinuxOptions _lOpts = const LinuxOptions(); // fallback (no-op encryption on some desktops)
  final WindowsOptions _wOpts = const WindowsOptions();

  SwapOrderStore({FlutterSecureStorage? storage})
      : _storage = storage ??
      const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
        iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
        mOptions: MacOsOptions(accessibility: KeychainAccessibility.first_unlock),
      );

  Future<List<SwapOrder>> load() async {
    final raw = await _storage.read(
      key: _kKey,
      aOptions: _aOpts,
      iOptions: _iOpts,
      mOptions: _mOpts,
      lOptions: _lOpts,
      wOptions: _wOpts,
    );
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map<SwapOrder>((e) {
          if (e is String) {
            // backward-compat if stored as list of JSON strings
            return SwapOrder.fromJson(e);
          } else if (e is Map<String, dynamic>) {
            return SwapOrder.fromMap(e);
          } else if (e is Map) {
            return SwapOrder.fromMap(Map<String, dynamic>.from(e));
          }
          throw const FormatException('Unsupported order entry type');
        }).toList(growable: false);
      }
    } catch (_) {
      // fallthrough to empty on any decoding issue
    }
    return const [];
  }

  Future<void> saveAll(List<SwapOrder> items) async {
    final list = items.map((e) => e.toMap()).toList(growable: false);
    final payload = jsonEncode(list);
    await _storage.write(
      key: _kKey,
      value: payload,
      aOptions: _aOpts,
      iOptions: _iOpts,
      mOptions: _mOpts,
      lOptions: _lOpts,
      wOptions: _wOpts,
    );
  }

  Future<void> upsert(SwapOrder order) async {
    final all = await load();
    final i = all.indexWhere((x) => x.id == order.id);
    if (i >= 0) {
      all[i] = order;
    } else {
      all.insert(0, order);
    }
    await saveAll(all);
  }

  Future<void> delete(String id) async {
    final all = await load();
    all.removeWhere((x) => x.id == id);
    await saveAll(all);
  }

  Future<void> clearInactive() async {
    final all = await load();
    await saveAll(all.where((x) => x.active).toList(growable: false));
  }
}
