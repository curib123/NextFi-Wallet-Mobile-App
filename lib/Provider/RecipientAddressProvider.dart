import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
import '../model/recipient_address.dart';

class RecipientAddressProvider with ChangeNotifier {
  static const _storageKey = 'recipient_addresses_v1';
  final FlutterSecureStorage _storage;
  List<RecipientAddress> _items = [];
  bool _loading = true;

  RecipientAddressProvider([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage() {
    _init();
  }

  bool get loading => _loading;

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

  /// NEW: Lookup by address (case-insensitive, trimmed).
  RecipientAddress? byAddress(String address) {
    final key = address.trim().toLowerCase();
    final idx = _items.indexWhere(
          (e) => e.address.trim().toLowerCase() == key,
    );
    return idx < 0 ? null : _items[idx];
  }

  Future<void> _init() async {
    try {
      final s = await _storage.read(key: _storageKey);
      _items = RecipientAddress.decodeList(s);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    await _storage.write(key: _storageKey, value: RecipientAddress.encodeList(_items));
  }

  /// Create (de-dup by exact address string, trimmed).
  Future<RecipientAddress> add({
    required String name,
    required String address,
    required int color,
  }) async {
    final now = DateTime.now();
    final existingIndex = _items.indexWhere((e) => e.address.trim() == address.trim());
    if (existingIndex >= 0) {
      final updated = _items[existingIndex].copyWith(
        name: name.trim(),
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
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx < 0) return null;
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
    _items.removeWhere((e) => e.id == id);
    await _persist();
    notifyListeners();
  }

  /// Wipe all
  Future<void> clear() async {
    _items.clear();
    await _persist();
    notifyListeners();
  }
}
