import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:next_fi/app/config/app_providers.dart';
import 'package:next_fi/features/contact/data/models/recipient_address_model.dart';
import 'package:next_fi/features/contact/data/services/contact_service.dart';
import 'package:next_fi/features/contact/presentation/viewmodels/contact_list_state.dart';

final contactServiceProvider = Provider<ContactService>((ref) {
  final service = ContactService();
  ref.onDispose(service.dispose);
  return service;
});

final contactListProvider =
    NotifierProvider<ContactListNotifier, ContactListState>(
      ContactListNotifier.new,
    );

class ContactListNotifier extends Notifier<ContactListState> {
  static const Duration _loadTimeout = Duration(seconds: 15);
  Future<void>? _loadFuture;
  String? _activeWalletAddress;

  ContactService get _service => ref.read(contactServiceProvider);

  @override
  ContactListState build() {
    final isAuthenticated = ref.watch(
      appShellProvider.select((state) => state.isAuthenticated),
    );
    final activeWalletAddress = ref.watch(
      seedKeypairProvider.select((vm) => vm.accountId),
    );
    _activeWalletAddress = activeWalletAddress?.trim().toUpperCase();

    ref.listen<bool>(
      appShellProvider.select((state) => state.isAuthenticated),
      (previous, next) {
        if (previous == next) return;
        _syncAuthentication(next);
      },
    );

    ref.listen<String?>(
      seedKeypairProvider.select((vm) => vm.accountId),
      (previous, next) {
        final normalized = next?.trim().toUpperCase();
        if (previous?.trim().toUpperCase() == normalized) return;
        _syncWallet(normalized);
      },
    );

    if (isAuthenticated && _activeWalletAddress != null && _activeWalletAddress!.isNotEmpty) {
      Future<void>.microtask(ensureLoaded);
    }

    return ContactListState(
      loading: isAuthenticated && _activeWalletAddress != null && _activeWalletAddress!.isNotEmpty,
      isAuthenticated:
          isAuthenticated && _activeWalletAddress != null && _activeWalletAddress!.isNotEmpty,
    );
  }

  Future<void> ensureLoaded() {
    final pending = _loadFuture;
    if (pending != null) return pending;
    if (state.initialized && !state.loading) {
      return Future<void>.value();
    }
    _loadFuture = _load();
    return _loadFuture!;
  }

  Future<void> _load() async {
    state = state.copyWith(loading: true);
    try {
      final items = await _service
          .fetchAll(activeOnly: false)
          .timeout(_loadTimeout);
      state = state.copyWith(
        items: items,
        loading: false,
        initialized: true,
        isAuthenticated: true,
        lastError: null,
      );
    } catch (e, st) {
      final authError = _isAuthError(e);
      if (kDebugMode) {
        debugPrint('ContactListNotifier load error: $e\n$st');
      }
      state = state.copyWith(
        items: authError ? const [] : state.items,
        loading: false,
        initialized: true,
        isAuthenticated: !authError,
        lastError: e,
      );
    } finally {
      _loadFuture = null;
    }
  }

  Future<void> refresh() async {
    _loadFuture = _load();
    await _loadFuture;
  }

  Future<RecipientAddressModel> add({
    required String name,
    required String address,
    required int color,
  }) async {
    await ensureLoaded();
    if (!state.isAuthenticated) {
      throw Exception('No active wallet session. Connect or reopen your wallet first.');
    }
    final added = await _service.add(
      name: name,
      address: address,
      color: color,
    );
    final next = [...state.items];
    final index = next.indexWhere(
      (item) =>
          item.address.trim().toLowerCase() ==
          added.address.trim().toLowerCase(),
    );
    if (index >= 0) {
      next[index] = added;
    } else {
      next.add(added);
    }
    state = state.copyWith(items: next, lastError: null);
    return added;
  }

  Future<RecipientAddressModel?> update(
    String id, {
    String? name,
    String? address,
    int? color,
  }) async {
    await ensureLoaded();
    if (!state.isAuthenticated) {
      throw Exception('No active wallet session. Connect or reopen your wallet first.');
    }
    final current = state.byId(id);
    if (current == null) return null;
    final updated = await _service.update(
      id,
      name: name,
      address: address,
      color: color,
    );
    final next = [...state.items];
    final index = next.indexWhere((item) => item.id == id);
    if (index >= 0) next[index] = updated;
    state = state.copyWith(items: next, lastError: null);
    return updated;
  }

  Future<void> remove(String id) async {
    await ensureLoaded();
    if (!state.isAuthenticated) {
      throw Exception('No active wallet session. Connect or reopen your wallet first.');
    }
    await _service.remove(id);
    state = state.copyWith(
      items: state.items.where((item) => item.id != id).toList(),
      lastError: null,
    );
  }

  Future<List<RecipientAddressModel>> search(String query) async {
    await ensureLoaded();
    if (!state.isAuthenticated) return const [];
    try {
      return await _service.search(query);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('ContactListNotifier search error: $e\n$st');
      }
      return const [];
    }
  }

  void setAuthenticated(bool isAuthenticated) {
    _syncAuthentication(isAuthenticated);
  }

  bool _isAuthError(Object error) {
    final raw = error.toString();
    return raw.contains('Not authenticated') ||
        raw.contains('401') ||
        raw.contains('Missing wallet session token') ||
        raw.contains('Wallet session token');
  }

  void _syncAuthentication(bool isAuthenticated) {
    if (!isAuthenticated || _activeWalletAddress == null || _activeWalletAddress!.isEmpty) {
      _loadFuture = null;
      state = state.copyWith(
        items: const [],
        loading: false,
        isAuthenticated: false,
        initialized: false,
        lastError: null,
      );
      return;
    }

    state = state.copyWith(
      isAuthenticated: true,
      loading: !state.initialized || state.items.isEmpty,
      lastError: null,
    );
    unawaited(refresh());
  }

  void _syncWallet(String? normalizedAddress) {
    _activeWalletAddress = normalizedAddress;
    _loadFuture = null;
    state = state.copyWith(
      items: const [],
      loading: normalizedAddress != null && normalizedAddress.isNotEmpty,
      isAuthenticated: normalizedAddress != null && normalizedAddress.isNotEmpty,
      initialized: false,
      lastError: null,
    );
    if (normalizedAddress != null && normalizedAddress.isNotEmpty) {
      unawaited(refresh());
    }
  }
}
