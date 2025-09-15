// lib/features/wallet_home/vm/recipient_address_vm.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:next_fi/features/wallet_home/model/recipient_address_model.dart';

/// Recipient addresses reusable_view_model (ChangeNotifier-based)
/// - Persists to FlutterSecureStorage
/// - Case-insensitive de-dup by address
/// - Awaitable init via [ready] to avoid races
class RecipientAddressVM with ChangeNotifier {
  static const _storageKey = 'recipient_addresses_v1';

  // Stronger, explicit platform options (same as elsewhere)
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

  List<RecipientAddressModel> _items = [];
  bool _loading = true;
  Object? _lastError;

  RecipientAddressVM([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage() {
    _ready = _init();
  }

  bool get loading => _loading;
  Object? get lastError => _lastError;
  Future<void> get ready => _ready;

  /// Returns a **sorted copy** to avoid mutating the backing list.
  List<RecipientAddressModel> get items {
    final list = [..._items];
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return List.unmodifiable(list);
  }

  /// Safe nullable lookup by id.
  RecipientAddressModel? byId(String id) {
    final idx = _items.indexWhere((e) => e.id == id);
    return idx < 0 ? null : _items[idx];
  }

  /// Lookup by address (case-insensitive, trimmed).
  RecipientAddressModel? byAddress(String address) {
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
      _items = RecipientAddressModel.decodeList(s);
    } catch (e, st) {
      _lastError = e;
      _items = [];
      if (kDebugMode) {
        debugPrint('RecipientAddressVM _init error: $e\n$st');
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    final payload = RecipientAddressModel.encodeList(_items);
    await _storage.write(
      key: _storageKey,
      value: payload,
      aOptions: _android,
      iOptions: _ios,
    );
  }

  /// Create (de-dup by address, **case-insensitive**, trimmed).
  Future<RecipientAddressModel> add({
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

    final rec = RecipientAddressModel(
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

  /// Update (merges if another record already has the same address, case-insensitive).
  Future<RecipientAddressModel?> update(
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
