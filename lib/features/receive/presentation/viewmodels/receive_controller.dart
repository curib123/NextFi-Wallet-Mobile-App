import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:next_fi/features/receive/data/services/receive_federation_service.dart';
import 'package:next_fi/features/receive/presentation/viewmodels/receive_view_state.dart';
import 'package:next_fi/core/services/federation_address/helpers/federation_address_exceptions.dart';
import 'package:next_fi/core/services/federation_address/models/federation_address_dtos.dart';

final receiveFederationServiceProvider = Provider<ReceiveFederationService>(
  (ref) => const ReceiveFederationService(),
);

class ReceiveControllerArgs {
  const ReceiveControllerArgs({
    required this.address,
    required this.initialAssetId,
  });

  final String address;
  final String initialAssetId;

  @override
  bool operator ==(Object other) {
    return other is ReceiveControllerArgs &&
        other.address == address &&
        other.initialAssetId == initialAssetId;
  }

  @override
  int get hashCode => Object.hash(address, initialAssetId);
}

final receiveControllerProvider = NotifierProvider.autoDispose
    .family<ReceiveController, ReceiveViewState, ReceiveControllerArgs>(
      ReceiveController.new,
    );

class ReceiveController extends Notifier<ReceiveViewState> {
  ReceiveController(this.args);

  final ReceiveControllerArgs args;

  @override
  ReceiveViewState build() {
    final service = ref.read(receiveFederationServiceProvider);
    Future.microtask(_loadFederationAddresses);
    return ReceiveViewState.initial(
      address: args.address,
      initialAssetId: args.initialAssetId,
      federationDomain: service.defaultDomain,
    );
  }

  ReceiveFederationService get _service =>
      ref.read(receiveFederationServiceProvider);

  void selectAsset(String assetKey) {
    final normalized = assetKey.trim();
    if (normalized.isEmpty || normalized == state.selectedAssetId) return;
    state = state.copyWith(selectedAssetId: normalized);
  }

  void setFederationAliasDraft(String raw) {
    final normalized = _normalizeAlias(raw);
    if (normalized == state.federationAliasDraft) return;
    state = state.copyWith(
      federationAliasDraft: normalized,
      isAliasAvailable: null,
      aliasAvailabilityMessage: null,
    );
  }

  Future<void> checkAliasAvailability() async {
    final alias = _normalizeAlias(state.federationAliasDraft);
    final domain = state.federationDomain.trim();
    if (alias.isEmpty) {
      state = state.copyWith(
        isAliasAvailable: null,
        aliasAvailabilityMessage: 'Type an alias first.',
      );
      return;
    }
    if (domain.isEmpty) {
      state = state.copyWith(
        isAliasAvailable: null,
        aliasAvailabilityMessage: 'Federation domain is not ready yet.',
      );
      return;
    }

    state = state.copyWith(
      checkingAliasAvailability: true,
      isAliasAvailable: null,
      aliasAvailabilityMessage: null,
    );

    final full = '$alias*$domain';
    try {
      final res = await _service.resolveByName(full);
      if (res.accountId.trim().isNotEmpty) {
        state = state.copyWith(
          isAliasAvailable: false,
          aliasAvailabilityMessage: '$full is already taken.',
        );
      } else {
        state = state.copyWith(
          isAliasAvailable: true,
          aliasAvailabilityMessage: '$full is available.',
        );
      }
    } catch (e) {
      if (e is ApiException && e.statusCode == 404) {
        state = state.copyWith(
          isAliasAvailable: true,
          aliasAvailabilityMessage: '$full is available.',
        );
      } else {
        state = state.copyWith(
          isAliasAvailable: null,
          aliasAvailabilityMessage: 'Unable to check availability right now.',
        );
      }
    } finally {
      state = state.copyWith(checkingAliasAvailability: false);
    }
  }

  Future<bool> generateFederationAddress() async {
    if (state.generatingFederation) return false;

    state = state.copyWith(
      generatingFederation: true,
      generateFederationError: null,
    );

    final accountId = state.address.trim();
    final now = DateTime.now().millisecondsSinceEpoch;
    final typedAlias = _normalizeAlias(state.federationAliasDraft);
    final base = typedAlias.isNotEmpty
        ? typedAlias
        : _buildAliasFromAddress(accountId);

    final candidates = typedAlias.isNotEmpty
        ? <String>[typedAlias]
        : <String>[
            base,
            '$base${(now % 10000).toString().padLeft(4, '0')}',
            '$base${(now % 100000).toString().padLeft(5, '0')}',
          ];

    Object? lastError;
    for (final alias in candidates) {
      try {
        await _service.create(
          CreateFederationAddressRequest(
            alias: alias,
            domain: _service.defaultDomain,
            accountId: accountId,
            isActive: true,
          ),
        );
        await _loadFederationAddresses();
        state = state.copyWith(
          federationAliasDraft: '',
          isAliasAvailable: null,
          aliasAvailabilityMessage: null,
          generatingFederation: false,
        );
        return true;
      } catch (e) {
        lastError = e;
      }
    }

    state = state.copyWith(
      generateFederationError:
          'Failed to generate federation address. ${lastError ?? ''}'.trim(),
      generatingFederation: false,
    );
    return false;
  }

  Future<bool> updateFederationAddress({
    required String id,
    required String alias,
  }) async {
    final normalizedAlias = _normalizeAlias(alias);
    final normalizedDomain = _service.defaultDomain;

    if (normalizedAlias.isEmpty) {
      state = state.copyWith(editFederationError: 'Alias is required.');
      return false;
    }
    if (normalizedDomain.isEmpty) {
      state = state.copyWith(editFederationError: 'Domain is required.');
      return false;
    }

    state = state.copyWith(editingFederationId: id, editFederationError: null);

    try {
      await _service.update(
        id,
        UpdateFederationAddressRequest(
          alias: normalizedAlias,
          domain: normalizedDomain,
          accountId: state.address.trim(),
        ),
      );
      await _loadFederationAddresses();
      state = state.copyWith(
        editingFederationId: null,
        editFederationError: null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        editingFederationId: null,
        editFederationError: 'Failed to update federation address. $e',
      );
      return false;
    }
  }

  Future<void> _loadFederationAddresses() async {
    state = state.copyWith(federationLoading: true, federationError: null);

    try {
      final items = await _service.listMine();
      state = state.copyWith(
        federationAddresses: items
            .where((item) => item.isActive && item.federationAddress.isNotEmpty)
            .toList(),
        federationDomain: _service.defaultDomain,
      );
    } catch (e) {
      state = state.copyWith(
        federationAddresses: const [],
        federationError: '$e',
        federationDomain: _service.defaultDomain,
      );
    } finally {
      state = state.copyWith(federationLoading: false);
    }
  }

  String _normalizeAlias(String raw) {
    return raw.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9._-]'), '');
  }

  String _buildAliasFromAddress(String address) {
    final normalized = address.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    if (normalized.length >= 12) {
      return 'nf${normalized.substring(0, 6)}${normalized.substring(normalized.length - 4)}';
    }
    if (normalized.isNotEmpty) return 'nf$normalized';
    return 'nfuser';
  }
}
