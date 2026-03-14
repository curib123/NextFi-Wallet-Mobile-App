import 'package:next_fi/features/contact/data/models/recipient_address_model.dart';

class ContactListState {
  const ContactListState({
    this.items = const [],
    this.loading = true,
    this.isAuthenticated = false,
    this.initialized = false,
    this.lastError,
  });

  final List<RecipientAddressModel> items;
  final bool loading;
  final bool isAuthenticated;
  final bool initialized;
  final Object? lastError;

  ContactListState copyWith({
    List<RecipientAddressModel>? items,
    bool? loading,
    bool? isAuthenticated,
    bool? initialized,
    Object? lastError = _sentinel,
  }) {
    return ContactListState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      initialized: initialized ?? this.initialized,
      lastError: identical(lastError, _sentinel) ? this.lastError : lastError,
    );
  }

  List<RecipientAddressModel> get sortedItems {
    final list = [...items];
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return List.unmodifiable(list);
  }

  RecipientAddressModel? byId(String id) {
    final index = items.indexWhere((item) => item.id == id);
    return index < 0 ? null : items[index];
  }

  RecipientAddressModel? byAddress(String address) {
    final key = address.trim().toLowerCase();
    final index = items.indexWhere(
      (item) => item.address.trim().toLowerCase() == key,
    );
    return index < 0 ? null : items[index];
  }
}

const Object _sentinel = Object();
