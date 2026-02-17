// lib/features/receive/viewmodel/receive_vm.dart
import 'package:flutter/foundation.dart';
import 'package:next_fi/services/federation_address/federation_address_core_service.dart';
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
    } catch (e) {
      _federationAddresses = const [];
      _federationError = '$e';
    } finally {
      _federationLoading = false;
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
    final base = _buildAliasFromAddress(accountId);
    final candidates = <String>[
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
            accountId: accountId,
            isActive: true,
          ),
        );
        await _loadFederationAddresses();
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
