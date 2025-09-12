import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
import '../model/recipient_address.dart';

class RecipientAddressProvider with ChangeNotifier {
  static const _storageKey = 'recipient_addresses_v1';

  // Stronger, explicit platform options (same ones you used elsewhere)
  static const AndroidOptions _android = AndroidOptions(
    encryptedSharedPreferences: true,
    resetOnError: true,
  );
  static const IOSOptions _ios = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
  );

  final FlutterSecureStorage _storage;

  // Make init awaitable to avoid races
  late final Future<void> _ready;

  List<RecipientAddress> _items = [];
  bool _loading = true;
  Object? _lastError;

  RecipientAddressProvider([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage() {
    _ready = _init();
  }

  bool get loading => _loading;
  Object? get lastError => _lastError;
  Future<void> get ready => _ready;

  /// Returns a **sorted copy** to avoid mutating the backing list.
  List<RecipientAddress> get items {
    final list = [..._items];
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return List.unmodifiable(list);
  }

  /// Safe nullable lookup by id.
  RecipientAddress? byId(String id) {
    final idx = _items.indexWhere((e) => e.id == id);
    return idx < 0 ? null : _items[idx];
  }

  /// Lookup by address (case-insensitive, trimmed).
  RecipientAddress? byAddress(String address) {
    final key = address.trim().toLowerCase();
    final idx = _items.indexWhere(
          (e) => e.address.trim().toLowerCase() == key,
    );
    return idx < 0 ? null : _items[idx];
  }

  Future<void> _init() async {
    try {
      final s = await _storage.read(
        key: _storageKey,
        aOptions: _android,
        iOptions: _ios,
      );
      // decodeList MUST handle null safely and return []
      _items = RecipientAddress.decodeList(s);
    } catch (e, st) {
      _lastError = e;
      _items = [];
      if (kDebugMode) {
        debugPrint('RecipientAddressProvider _init error: $e\n$st');
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    final payload = RecipientAddress.encodeList(_items);
    await _storage.write(
      key: _storageKey,
      value: payload,
      aOptions: _android,
      iOptions: _ios,
    );
  }

  /// Create (de-dup by address, **case-insensitive**, trimmed).
  Future<RecipientAddress> add({
    required String name,
    required String address,
    required int color,
  }) async {
    await _ready; // prevent init race
    final now = DateTime.now();
    final normAddr = address.trim().toLowerCase();

    final existingIndex = _items.indexWhere(
          (e) => e.address.trim().toLowerCase() == normAddr,
    );

    if (existingIndex >= 0) {
      final updated = _items[existingIndex].copyWith(
        name: name.trim(),
        // keep original address casing as stored, but we could update too:
        // address: address.trim(),
        color: color,
        updatedAt: now,
      );
      _items[existingIndex] = updated;
      await _persist();
      notifyListeners();
      return updated;
    }

    final rec = RecipientAddress(
      id: now.microsecondsSinceEpoch.toString(),
      name: name.trim(),
      address: address.trim(),
      color: color,
      createdAt: now,
      updatedAt: now,
    );
    _items.add(rec);
    await _persist();
    notifyListeners();
    return rec;
  }

  /// Update
  Future<RecipientAddress?> update(
      String id, {
        String? name,
        String? address,
        int? color,
      }) async {
    await _ready; // prevent init race
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx < 0) return null;

    // If address is changing, enforce case-insensitive de-dup to the same id
    if (address != null) {
      final norm = address.trim().toLowerCase();
      final otherIdx = _items.indexWhere(
            (e) => e.id != id && e.address.trim().toLowerCase() == norm,
      );
      if (otherIdx >= 0) {
        // Merge into the existing record instead of creating a dup.
        // Here we choose to update that existing record with the new fields.
        final now = DateTime.now();
        final merged = _items[otherIdx].copyWith(
          name: name?.trim(),
          address: address.trim(),
          color: color,
          updatedAt: now,
        );
        _items.removeAt(idx);
        // Update the other record
        _items[otherIdx] = merged;
        await _persist();
        notifyListeners();
        return merged;
      }
    }

    final now = DateTime.now();
    final next = _items[idx].copyWith(
      name: name?.trim(),
      address: address?.trim(),
      color: color,
      updatedAt: now,
    );
    _items[idx] = next;
    await _persist();
    notifyListeners();
    return next;
  }

  /// Delete
  Future<void> remove(String id) async {
    await _ready; // prevent init race
    _items.removeWhere((e) => e.id == id);
    await _persist();
    notifyListeners();
  }

  /// Wipe all
  Future<void> clear() async {
    await _ready; // prevent init race
    _items.clear();
    // Delete the key to be explicit
    await _storage.delete(
      key: _storageKey,
      aOptions: _android,
      iOptions: _ios,
    );
    notifyListeners();
  }
}
