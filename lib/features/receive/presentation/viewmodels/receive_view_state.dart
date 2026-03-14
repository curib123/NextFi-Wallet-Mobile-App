import 'package:next_fi/core/services/federation_address/models/federation_address_models.dart';

class ReceiveViewState {
  const ReceiveViewState({
    required this.address,
    required this.xlmBalance,
    required this.usdcBalance,
    required this.xlmSelected,
    required this.federationAddresses,
    required this.federationLoading,
    this.federationError,
    required this.generatingFederation,
    this.generateFederationError,
    required this.federationAliasDraft,
    required this.checkingAliasAvailability,
    this.isAliasAvailable,
    this.aliasAvailabilityMessage,
    required this.federationDomain,
    this.editingFederationId,
    this.editFederationError,
  });

  factory ReceiveViewState.initial({
    required String address,
    required double xlmBalance,
    required double usdcBalance,
    required String initialToken,
    required String federationDomain,
  }) {
    return ReceiveViewState(
      address: address,
      xlmBalance: xlmBalance,
      usdcBalance: usdcBalance,
      xlmSelected: initialToken.toUpperCase() != 'USDC',
      federationAddresses: const [],
      federationLoading: true,
      generatingFederation: false,
      federationAliasDraft: '',
      checkingAliasAvailability: false,
      federationDomain: federationDomain,
    );
  }

  final String address;
  final double xlmBalance;
  final double usdcBalance;
  final bool xlmSelected;
  final List<FederationAddressModel> federationAddresses;
  final bool federationLoading;
  final String? federationError;
  final bool generatingFederation;
  final String? generateFederationError;
  final String federationAliasDraft;
  final bool checkingAliasAvailability;
  final bool? isAliasAvailable;
  final String? aliasAvailabilityMessage;
  final String federationDomain;
  final String? editingFederationId;
  final String? editFederationError;

  String get token => xlmSelected ? 'XLM' : 'USDC';

  String get safetyNote => xlmSelected
      ? 'Send only XLM (native Stellar) to this address. Sending other assets or from other networks may result in permanent loss.'
      : 'Send only USDC on the Stellar network to this address. A USDC trustline is required to receive funds.';

  String get federationAddressPreview {
    final alias = federationAliasDraft.trim();
    if (alias.isEmpty) return '';
    if (federationDomain.trim().isEmpty) return alias;
    return '$alias*$federationDomain';
  }

  ReceiveViewState copyWith({
    String? address,
    double? xlmBalance,
    double? usdcBalance,
    bool? xlmSelected,
    List<FederationAddressModel>? federationAddresses,
    bool? federationLoading,
    Object? federationError = _sentinel,
    bool? generatingFederation,
    Object? generateFederationError = _sentinel,
    String? federationAliasDraft,
    bool? checkingAliasAvailability,
    Object? isAliasAvailable = _sentinel,
    Object? aliasAvailabilityMessage = _sentinel,
    String? federationDomain,
    Object? editingFederationId = _sentinel,
    Object? editFederationError = _sentinel,
  }) {
    return ReceiveViewState(
      address: address ?? this.address,
      xlmBalance: xlmBalance ?? this.xlmBalance,
      usdcBalance: usdcBalance ?? this.usdcBalance,
      xlmSelected: xlmSelected ?? this.xlmSelected,
      federationAddresses: federationAddresses ?? this.federationAddresses,
      federationLoading: federationLoading ?? this.federationLoading,
      federationError: identical(federationError, _sentinel)
          ? this.federationError
          : federationError as String?,
      generatingFederation: generatingFederation ?? this.generatingFederation,
      generateFederationError: identical(generateFederationError, _sentinel)
          ? this.generateFederationError
          : generateFederationError as String?,
      federationAliasDraft: federationAliasDraft ?? this.federationAliasDraft,
      checkingAliasAvailability:
          checkingAliasAvailability ?? this.checkingAliasAvailability,
      isAliasAvailable: identical(isAliasAvailable, _sentinel)
          ? this.isAliasAvailable
          : isAliasAvailable as bool?,
      aliasAvailabilityMessage:
          identical(aliasAvailabilityMessage, _sentinel)
              ? this.aliasAvailabilityMessage
              : aliasAvailabilityMessage as String?,
      federationDomain: federationDomain ?? this.federationDomain,
      editingFederationId: identical(editingFederationId, _sentinel)
          ? this.editingFederationId
          : editingFederationId as String?,
      editFederationError: identical(editFederationError, _sentinel)
          ? this.editFederationError
          : editFederationError as String?,
    );
  }
}

const Object _sentinel = Object();
