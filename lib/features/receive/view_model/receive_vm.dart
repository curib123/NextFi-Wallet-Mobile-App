// lib/features/receive/viewmodel/receive_vm.dart
import 'package:flutter/foundation.dart';
import 'package:next_fi/services/federation_address/federation_address_core_service.dart';
import 'package:next_fi/services/federation_address/helpers/federation_address_exceptions.dart';
import 'package:next_fi/services/federation_address/models/federation_address_dtos.dart';
import 'package:next_fi/services/federation_address/models/federation_address_models.dart';

import '../model/receive_state.dart';

class ReceiveVM extends ChangeNotifier {
  ReceiveState _state;
  List<FederationAddressModel> _federationAddresses = const [];
  bool _federationLoading = false;
  String? _federationError;
  bool _generatingFederation = false;
  String? _generateFederationError;

  String _federationAliasDraft = '';
  bool _checkingAliasAvailability = false;
  bool? _isAliasAvailable;
  String? _aliasAvailabilityMessage;
  String? _federationDomain;
  String? _editingFederationId;
  String? _editFederationError;

  ReceiveVM({
    required String address,
    required double xlmBalance,
    required double usdcBalance,
    String initialToken = 'XLM',
  }) : _state = ReceiveState(
         address: address,
         xlmBalance: xlmBalance,
         usdcBalance: usdcBalance,
         xlmSelected: initialToken.toUpperCase() != 'USDC',
       ) {
    _loadFederationAddresses();
  }

  ReceiveState get state => _state;

  void _set(ReceiveState s) {
    _state = s;
    notifyListeners();
  }

  List<FederationAddressModel> get federationAddresses => _federationAddresses;
  bool get federationLoading => _federationLoading;
  String? get federationError => _federationError;
  bool get generatingFederation => _generatingFederation;
  String? get generateFederationError => _generateFederationError;

  String get federationAliasDraft => _federationAliasDraft;
  bool get checkingAliasAvailability => _checkingAliasAvailability;
  bool? get isAliasAvailable => _isAliasAvailable;
  String? get aliasAvailabilityMessage => _aliasAvailabilityMessage;
  String? get federationDomain => _federationDomain;
  String? get editingFederationId => _editingFederationId;
  String? get editFederationError => _editFederationError;

  String get federationAddressPreview {
    final alias = _normalizeAlias(_federationAliasDraft);
    final domain = _federationDomain?.trim();
    if (alias.isEmpty) return '';
    if (domain == null || domain.isEmpty) return alias;
    return '$alias*$domain';
  }

  void selectXLM() => _set(_state.copyWith(xlmSelected: true));
  void selectUSDC() => _set(_state.copyWith(xlmSelected: false));

  String get token => _state.token;

  String get safetyNote => _state.xlmSelected
      ? 'Send only XLM (native Stellar) to this address. Sending other assets or from other networks may result in permanent loss.'
      : 'Send only USDC on the Stellar network to this address. A USDC trustline is required to receive funds.';

  Future<void> _loadFederationAddresses() async {
    _federationLoading = true;
    _federationError = null;
    notifyListeners();

    try {
      final items = await FederationAddressCoreService.I.listMine();
      _federationAddresses = items
          .where((e) => e.isActive && e.federationAddress.isNotEmpty)
          .toList();
      _federationDomain = _resolveDomainFromList(_federationAddresses);
      _federationDomain ??= await _resolveDomainFromToml();
    } catch (e) {
      _federationAddresses = const [];
      _federationError = '$e';
      _federationDomain ??= await _resolveDomainFromToml();
    } finally {
      _federationLoading = false;
      notifyListeners();
    }
  }

  void setFederationAliasDraft(String raw) {
    final normalized = _normalizeAlias(raw);
    if (normalized == _federationAliasDraft) return;
    _federationAliasDraft = normalized;
    _isAliasAvailable = null;
    _aliasAvailabilityMessage = null;
    notifyListeners();
  }

  Future<void> checkAliasAvailability() async {
    final alias = _normalizeAlias(_federationAliasDraft);
    final domain = _federationDomain?.trim();
    if (alias.isEmpty) {
      _isAliasAvailable = null;
      _aliasAvailabilityMessage = 'Type an alias first.';
      notifyListeners();
      return;
    }
    if (domain == null || domain.isEmpty) {
      _isAliasAvailable = null;
      _aliasAvailabilityMessage = 'Federation domain is not ready yet.';
      notifyListeners();
      return;
    }

    _checkingAliasAvailability = true;
    _isAliasAvailable = null;
    _aliasAvailabilityMessage = null;
    notifyListeners();

    final full = '$alias*$domain';

    try {
      final res = await FederationAddressCoreService.I.resolveByName(full);
      if (res.accountId.trim().isNotEmpty) {
        _isAliasAvailable = false;
        _aliasAvailabilityMessage = '$full is already taken.';
      } else {
        _isAliasAvailable = true;
        _aliasAvailabilityMessage = '$full is available.';
      }
    } catch (e) {
      if (e is ApiException && e.statusCode == 404) {
        _isAliasAvailable = true;
        _aliasAvailabilityMessage = '$full is available.';
      } else {
        _isAliasAvailable = null;
        _aliasAvailabilityMessage = 'Unable to check availability right now.';
      }
    } finally {
      _checkingAliasAvailability = false;
      notifyListeners();
    }
  }

  Future<bool> generateFederationAddress() async {
    if (_generatingFederation) return false;

    _generatingFederation = true;
    _generateFederationError = null;
    notifyListeners();

    final accountId = _state.address.trim();
    final now = DateTime.now().millisecondsSinceEpoch;
    final typedAlias = _normalizeAlias(_federationAliasDraft);
    final base = typedAlias.isNotEmpty
        ? typedAlias
        : _buildAliasFromAddress(accountId);

    final candidates = typedAlias.isNotEmpty
        ? <String>[typedAlias]
        : <String>[
            base,
            '${base}${(now % 10000).toString().padLeft(4, '0')}',
            '${base}${(now % 100000).toString().padLeft(5, '0')}',
          ];

    Object? lastError;
    for (final alias in candidates) {
      try {
        await FederationAddressCoreService.I.create(
          CreateFederationAddressRequest(
            alias: alias,
            domain: _federationDomain,
            accountId: accountId,
            isActive: true,
          ),
        );
        await _loadFederationAddresses();
        _federationAliasDraft = '';
        _isAliasAvailable = null;
        _aliasAvailabilityMessage = null;
        _generatingFederation = false;
        notifyListeners();
        return true;
      } catch (e) {
        lastError = e;
      }
    }

    _generateFederationError =
        'Failed to generate federation address. ${lastError ?? ''}'.trim();
    _generatingFederation = false;
    notifyListeners();
    return false;
  }

  Future<bool> updateFederationAddress({
    required String id,
    required String alias,
    String? domain,
  }) async {
    final normalizedAlias = _normalizeAlias(alias);
    final normalizedDomain = (domain ?? _federationDomain ?? '').trim();

    if (normalizedAlias.isEmpty) {
      _editFederationError = 'Alias is required.';
      notifyListeners();
      return false;
    }
    if (normalizedDomain.isEmpty) {
      _editFederationError = 'Domain is required.';
      notifyListeners();
      return false;
    }

    _editingFederationId = id;
    _editFederationError = null;
    notifyListeners();

    try {
      await FederationAddressCoreService.I.update(
        id,
        UpdateFederationAddressRequest(
          alias: normalizedAlias,
          domain: normalizedDomain,
          accountId: _state.address.trim(),
        ),
      );
      await _loadFederationAddresses();
      _editingFederationId = null;
      _editFederationError = null;
      notifyListeners();
      return true;
    } catch (e) {
      _editingFederationId = null;
      _editFederationError = 'Failed to update federation address. $e';
      notifyListeners();
      return false;
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

  String? _resolveDomainFromList(List<FederationAddressModel> items) {
    for (final item in items) {
      final d = item.domain.trim();
      if (d.isNotEmpty) return d;
    }
    return null;
  }

  Future<String?> _resolveDomainFromToml() async {
    try {
      final toml = await FederationAddressCoreService.I.getStellarToml();
      final match = RegExp(
        r'FEDERATION_SERVER\s*=\s*"([^"]+)"',
        caseSensitive: false,
      ).firstMatch(toml);
      final url = match?.group(1)?.trim();
      if (url == null || url.isEmpty) return null;
      final uri = Uri.tryParse(url);
      final host = uri?.host.trim();
      return (host == null || host.isEmpty) ? null : host;
    } catch (_) {
      return null;
    }
  }
}
