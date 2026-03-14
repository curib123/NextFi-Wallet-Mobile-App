import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  Future<void>? _loadFuture;

  ContactService get _service => ref.read(contactServiceProvider);

  @override
  ContactListState build() {
    _loadFuture ??= _load();
    return const ContactListState();
  }

  Future<void> ensureLoaded() => _loadFuture ??= _load();

  Future<void> _load() async {
    state = state.copyWith(loading: true);
    try {
      final items = await _service.fetchAll(activeOnly: false);
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
      throw Exception('Not authenticated. Please login first.');
    }
    final added = await _service.add(name: name, address: address, color: color);
    final next = [...state.items];
    final index = next.indexWhere(
      (item) => item.address.trim().toLowerCase() == added.address.trim().toLowerCase(),
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
      throw Exception('Not authenticated. Please login first.');
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
      throw Exception('Not authenticated. Please login first.');
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
    state = state.copyWith(
      isAuthenticated: isAuthenticated,
      items: isAuthenticated ? state.items : const [],
    );
    if (isAuthenticated) {
      unawaited(refresh());
    }
  }

  bool _isAuthError(Object error) {
    final raw = error.toString();
    return raw.contains('Not authenticated') || raw.contains('401');
  }
}
