// lib/features/wallet_home/view_model/recipient_address_vm.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:next_fi/features/wallet_home/model/recipient_address_model.dart';
import 'package:next_fi/services/recipient_wallets/recipient_wallets_core.dart';
import 'package:next_fi/services/recipient_wallets/models/recipient_wallet_models.dart';

/// Recipient addresses view model (ChangeNotifier-based)
/// - Uses RecipientWalletsCore API service (JWT-authenticated)
/// - Converts API RecipientWallet models to local RecipientAddressModel
/// - Handles authentication state
class RecipientAddressVM with ChangeNotifier {
  final RecipientWalletsCore _api;

  late final Future<void> _ready;

  List<RecipientAddressModel> _items = [];
  bool _loading = true;
  bool _isAuthenticated = false;
  Object? _lastError;

  RecipientAddressVM([RecipientWalletsCore? api])
    : _api = api ?? RecipientWalletsCore() {
    _ready = _init();
  }

  bool get loading => _loading;
  bool get isAuthenticated => _isAuthenticated;
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
    final idx = _items.indexWhere((e) => e.address.trim().toLowerCase() == key);
    return idx < 0 ? null : _items[idx];
  }

  Future<void> _init() async {
    try {
      // Try to fetch from API - if JWT is missing, this will throw
      final recipients = await _api.getAllRecipients(activeOnly: false);
      _items = recipients.map(_toLocal).toList();
      _isAuthenticated = true;
    } catch (e, st) {
      _lastError = e;
      _items = [];

      // Check if error is authentication-related
      final authError =
          e.toString().contains('Not authenticated') ||
          e.toString().contains('401');
      if (authError) {
        _isAuthenticated = false;
      } else {
        // Keep UI in authenticated mode for non-auth API failures.
        _isAuthenticated = true;
      }

      if (kDebugMode) {
        debugPrint('RecipientAddressVM _init error: $e\n$st');
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Convert API RecipientWallet to local RecipientAddressModel
  RecipientAddressModel _toLocal(RecipientWallet wallet) {
    final displayName = wallet.displayName.isEmpty
        ? wallet.effectiveAddress
        : wallet.displayName;
    return RecipientAddressModel(
      id: wallet.id,
      name: displayName,
      address: wallet.effectiveAddress,
      color:
          _parseColorTag(wallet.colorTag) ??
          _extractColorFromMemo(wallet.memo) ??
          0xFF7B16FF,
      createdAt: wallet.createdAt,
      updatedAt: wallet.updatedAt,
    );
  }

  int? _parseColorTag(String? colorTag) {
    if (colorTag == null) return null;
    final raw = colorTag.trim();
    if (raw.isEmpty) return null;
    if (raw.startsWith('#') && raw.length == 7) {
      final rgb = raw.substring(1);
      final parsed = int.tryParse('FF$rgb', radix: 16);
      return parsed;
    }
    if (raw.startsWith('0x')) {
      return int.tryParse(raw.substring(2), radix: 16);
    }
    return int.tryParse(raw);
  }

  String _toColorTag(int color) {
    final rgb = color & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  /// Extract color from memo field (format: "color:0xFF7B16FF;memo text")
  int? _extractColorFromMemo(String? memo) {
    if (memo == null || !memo.contains('color:')) return null;
    try {
      final colorPart = memo
          .split(';')
          .firstWhere((part) => part.startsWith('color:'), orElse: () => '');
      if (colorPart.isEmpty) return null;
      final colorStr = colorPart.replaceFirst('color:', '').trim();
      return int.tryParse(colorStr);
    } catch (_) {
      return null;
    }
  }

  /// Refresh data from API
  Future<void> refresh() async {
    _loading = true;
    notifyListeners();

    try {
      final recipients = await _api.getAllRecipients(activeOnly: false);
      _items = recipients.map(_toLocal).toList();
      _isAuthenticated = true;
      _lastError = null;
    } catch (e, st) {
      _lastError = e;
      final authError =
          e.toString().contains('Not authenticated') ||
          e.toString().contains('401');
      if (authError) {
        _isAuthenticated = false;
        _items = [];
      } else {
        _isAuthenticated = true;
      }
      if (kDebugMode) {
        debugPrint('RecipientAddressVM refresh error: $e\n$st');
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Create recipient via API
  Future<RecipientAddressModel> add({
    required String name,
    required String address,
    required int color,
  }) async {
    if (!_isAuthenticated) {
      throw Exception('Not authenticated. Please login first.');
    }

    await _ready;

    try {
      final wallet = await _api.addRecipient(
        name: name.trim(),
        address: address.trim(),
        network: 'stellar',
        colorTag: _toColorTag(color),
      );

      final local = _toLocal(wallet);

      // Update local cache
      final existingIndex = _items.indexWhere(
        (e) => e.address.trim().toLowerCase() == address.trim().toLowerCase(),
      );

      if (existingIndex >= 0) {
        _items[existingIndex] = local;
      } else {
        _items.add(local);
      }

      notifyListeners();
      return local;
    } catch (e) {
      if (e.toString().contains('Not authenticated') ||
          e.toString().contains('401')) {
        _isAuthenticated = false;
        notifyListeners();
      }
      rethrow;
    }
  }

  /// Update recipient via API
  Future<RecipientAddressModel?> update(
    String id, {
    String? name,
    String? address,
    int? color,
  }) async {
    if (!_isAuthenticated) {
      throw Exception('Not authenticated. Please login first.');
    }

    await _ready;

    try {
      final current = byId(id);
      if (current == null) return null;

      // Prepare memo with color
      final wallet = await _api.updateRecipient(
        id: id,
        name: name?.trim(),
        address: address?.trim(),
        colorTag: color == null ? null : _toColorTag(color),
      );

      final local = _toLocal(wallet);

      // Update local cache
      final idx = _items.indexWhere((e) => e.id == id);
      if (idx >= 0) {
        _items[idx] = local;
      }

      notifyListeners();
      return local;
    } catch (e) {
      if (e.toString().contains('Not authenticated') ||
          e.toString().contains('401')) {
        _isAuthenticated = false;
        notifyListeners();
      }
      rethrow;
    }
  }

  /// Delete recipient via API
  Future<void> remove(String id) async {
    if (!_isAuthenticated) {
      throw Exception('Not authenticated. Please login first.');
    }

    await _ready;

    try {
      await _api.deleteRecipient(id);

      // Update local cache
      _items.removeWhere((e) => e.id == id);
      notifyListeners();
    } catch (e) {
      if (e.toString().contains('Not authenticated') ||
          e.toString().contains('401')) {
        _isAuthenticated = false;
        notifyListeners();
      }
      rethrow;
    }
  }

  /// Search recipients via API
  Future<List<RecipientAddressModel>> search(String query) async {
    if (!_isAuthenticated) return [];

    try {
      final results = await _api.searchRecipients(
        query: query,
        activeOnly: false,
      );
      return results.map(_toLocal).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Search error: $e');
      }
      return [];
    }
  }

  /// Set authentication state (call this after login/logout)
  void setAuthState(bool isAuth) {
    _isAuthenticated = isAuth;
    if (!isAuth) {
      _items = [];
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }
}
