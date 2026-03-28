import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:next_fi/core/services/federation_address/models/federation_address_models.dart';
import 'package:next_fi/features/contact/data/models/recipient_address_model.dart';

enum RecipientInputMode { savedRecipient, scannedQr, publicAddress, federation }

enum RecipientValueKind { empty, publicAddress, federation, invalid }

typedef RecipientLookup =
    Future<RecipientAddressModel?> Function(String address);
typedef FederationLookup =
    Future<FederationResolveResponse> Function(
      String federationAddress, {
      required String domain,
    });

@immutable
class ParsedRecipientQr {
  const ParsedRecipientQr({
    required this.rawValue,
    required this.recipientValue,
    required this.kind,
    this.memoText,
    this.memoType,
  });

  final String rawValue;
  final String recipientValue;
  final RecipientValueKind kind;
  final String? memoText;
  final String? memoType;

  bool get hasSupportedTextMemo =>
      memoText != null &&
      memoText!.trim().isNotEmpty &&
      (memoType == null || memoType!.trim().toLowerCase() == 'text');
}

class RecipientInputParser {
  const RecipientInputParser._();

  static final RegExp _publicAddressPattern = RegExp(r'^G[A-Z2-7]{55}$');
  static final RegExp _publicAddressSearchPattern = RegExp(
    r'\bG[A-Z2-7]{55}\b',
  );
  static final RegExp _federationPattern = RegExp(r'^[^*\s]+\*[^*\s]+$');
  static final RegExp _federationAliasPattern = RegExp(r'^[a-zA-Z0-9._-]+$');

  static bool isStellarPublicAddress(String value) {
    return _publicAddressPattern.hasMatch(value.trim());
  }

  static bool isFederationAddress(String value) {
    return _federationPattern.hasMatch(value.trim());
  }

  static bool isFederationAliasInput(String value) {
    return _federationAliasPattern.hasMatch(value.trim());
  }

  static RecipientValueKind detectKind(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return RecipientValueKind.empty;
    if (isStellarPublicAddress(trimmed)) {
      return RecipientValueKind.publicAddress;
    }
    if (isFederationAddress(trimmed)) {
      return RecipientValueKind.federation;
    }
    return RecipientValueKind.invalid;
  }

  static ParsedRecipientQr parseQr(String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      return const ParsedRecipientQr(
        rawValue: '',
        recipientValue: '',
        kind: RecipientValueKind.empty,
      );
    }

    String? recipientValue;
    String? memoText;
    String? memoType;

    final schemeIndex = trimmed.toLowerCase().indexOf('stellar:');
    if (schemeIndex != -1) {
      final afterScheme = trimmed.substring(schemeIndex + 'stellar:'.length);
      final queryIndex = afterScheme.indexOf('?');
      final pathAndMaybeFragment = queryIndex == -1
          ? afterScheme
          : afterScheme.substring(0, queryIndex);
      final path = pathAndMaybeFragment.split(RegExp(r'[#/]')).first.trim();
      final query = queryIndex == -1
          ? null
          : afterScheme.substring(queryIndex + 1);

      if (path.isNotEmpty) {
        recipientValue = path;
      }
      if (query != null && query.isNotEmpty) {
        try {
          final params = Uri.splitQueryString(query);
          memoText = params['memo'];
          memoType = params['memo_type'];
        } catch (_) {}
      }
    }

    recipientValue ??= trimmed;
    final directKind = detectKind(recipientValue);
    if (directKind != RecipientValueKind.invalid) {
      return ParsedRecipientQr(
        rawValue: trimmed,
        recipientValue: recipientValue,
        kind: directKind,
        memoText: memoText,
        memoType: memoType,
      );
    }

    final embeddedAddress = _publicAddressSearchPattern
        .firstMatch(trimmed)
        ?.group(0);
    if (embeddedAddress != null) {
      return ParsedRecipientQr(
        rawValue: trimmed,
        recipientValue: embeddedAddress,
        kind: RecipientValueKind.publicAddress,
        memoText: memoText,
        memoType: memoType,
      );
    }

    return ParsedRecipientQr(
      rawValue: trimmed,
      recipientValue: recipientValue.trim(),
      kind: RecipientValueKind.invalid,
      memoText: memoText,
      memoType: memoType,
    );
  }

  static List<String> buildFederationSuggestions(String input, String domain) {
    final trimmedInput = input.trim();
    final trimmedDomain = domain.trim();
    if (trimmedDomain.isEmpty ||
        trimmedInput.isEmpty ||
        trimmedInput.contains('*') ||
        !isFederationAliasInput(trimmedInput)) {
      return const [];
    }
    return ['${trimmedInput.toLowerCase()}*$trimmedDomain'];
  }
}

@immutable
class RecipientInputState {
  const RecipientInputState({
    required this.mode,
    required this.federationDomain,
    required this.savedRecipient,
    required this.scannedRawValue,
    required this.manualPublicAddress,
    required this.federationInput,
    required this.recipientLoading,
    required this.federationLoading,
    this.resolvedRecipient,
    this.resolvedFederation,
    this.federationError,
  });

  factory RecipientInputState.initial({
    required String federationDomain,
    RecipientInputMode mode = RecipientInputMode.publicAddress,
    RecipientAddressModel? savedRecipient,
    String scannedRawValue = '',
    String manualPublicAddress = '',
    String federationInput = '',
  }) {
    return RecipientInputState(
      mode: mode,
      federationDomain: federationDomain,
      savedRecipient: savedRecipient,
      scannedRawValue: scannedRawValue.trim(),
      manualPublicAddress: manualPublicAddress.trim(),
      federationInput: federationInput.trim(),
      recipientLoading: false,
      federationLoading: false,
      resolvedRecipient: savedRecipient,
    );
  }

  final RecipientInputMode mode;
  final String federationDomain;
  final RecipientAddressModel? savedRecipient;
  final String scannedRawValue;
  final String manualPublicAddress;
  final String federationInput;
  final bool recipientLoading;
  final bool federationLoading;
  final RecipientAddressModel? resolvedRecipient;
  final FederationResolveResponse? resolvedFederation;
  final String? federationError;

  static const Object _sentinel = Object();

  ParsedRecipientQr get scannedPayload =>
      RecipientInputParser.parseQr(scannedRawValue);

  String get activeInputValue {
    switch (mode) {
      case RecipientInputMode.savedRecipient:
        return savedRecipient?.address.trim() ?? '';
      case RecipientInputMode.scannedQr:
        return scannedPayload.recipientValue.trim();
      case RecipientInputMode.publicAddress:
        return manualPublicAddress.trim();
      case RecipientInputMode.federation:
        return federationInput.trim();
    }
  }

  RecipientValueKind get activeValueKind {
    switch (mode) {
      case RecipientInputMode.savedRecipient:
        return RecipientInputParser.detectKind(savedRecipient?.address ?? '');
      case RecipientInputMode.scannedQr:
        return scannedPayload.kind;
      case RecipientInputMode.publicAddress:
        final value = manualPublicAddress.trim();
        if (value.isEmpty) return RecipientValueKind.empty;
        return RecipientInputParser.isStellarPublicAddress(value)
            ? RecipientValueKind.publicAddress
            : RecipientValueKind.invalid;
      case RecipientInputMode.federation:
        final value = federationInput.trim();
        if (value.isEmpty) return RecipientValueKind.empty;
        return RecipientInputParser.isFederationAddress(value)
            ? RecipientValueKind.federation
            : RecipientValueKind.invalid;
    }
  }

  bool get shouldShowFederationUi {
    return mode == RecipientInputMode.federation ||
        (mode == RecipientInputMode.scannedQr &&
            activeValueKind == RecipientValueKind.federation);
  }

  List<String> get federationSuggestions {
    if (mode != RecipientInputMode.federation) return const [];
    return RecipientInputParser.buildFederationSuggestions(
      federationInput,
      federationDomain,
    );
  }

  String? get resolvedFederationAccountId {
    final accountId = resolvedFederation?.accountId.trim() ?? '';
    if (!RecipientInputParser.isStellarPublicAddress(accountId)) {
      return null;
    }
    return accountId;
  }

  String? get finalDestinationAddress {
    switch (activeValueKind) {
      case RecipientValueKind.publicAddress:
        return RecipientInputParser.isStellarPublicAddress(activeInputValue)
            ? activeInputValue
            : null;
      case RecipientValueKind.federation:
        return resolvedFederationAccountId;
      case RecipientValueKind.empty:
      case RecipientValueKind.invalid:
        return null;
    }
  }

  RecipientAddressModel? get activeRecipient {
    if (mode == RecipientInputMode.savedRecipient && savedRecipient != null) {
      return savedRecipient;
    }
    return resolvedRecipient;
  }

  RecipientInputState copyWith({
    RecipientInputMode? mode,
    String? federationDomain,
    Object? savedRecipient = _sentinel,
    String? scannedRawValue,
    String? manualPublicAddress,
    String? federationInput,
    bool? recipientLoading,
    bool? federationLoading,
    Object? resolvedRecipient = _sentinel,
    Object? resolvedFederation = _sentinel,
    Object? federationError = _sentinel,
  }) {
    return RecipientInputState(
      mode: mode ?? this.mode,
      federationDomain: federationDomain ?? this.federationDomain,
      savedRecipient: identical(savedRecipient, _sentinel)
          ? this.savedRecipient
          : savedRecipient as RecipientAddressModel?,
      scannedRawValue: scannedRawValue ?? this.scannedRawValue,
      manualPublicAddress: manualPublicAddress ?? this.manualPublicAddress,
      federationInput: federationInput ?? this.federationInput,
      recipientLoading: recipientLoading ?? this.recipientLoading,
      federationLoading: federationLoading ?? this.federationLoading,
      resolvedRecipient: identical(resolvedRecipient, _sentinel)
          ? this.resolvedRecipient
          : resolvedRecipient as RecipientAddressModel?,
      resolvedFederation: identical(resolvedFederation, _sentinel)
          ? this.resolvedFederation
          : resolvedFederation as FederationResolveResponse?,
      federationError: identical(federationError, _sentinel)
          ? this.federationError
          : federationError as String?,
    );
  }
}

class RecipientFlowController {
  RecipientFlowController({
    required RecipientInputState initialState,
    required this.lookupRecipient,
    required this.resolveFederation,
    required this.onStateChanged,
  }) : _state = initialState;

  final RecipientLookup lookupRecipient;
  final FederationLookup resolveFederation;
  final ValueChanged<RecipientInputState> onStateChanged;

  RecipientInputState _state;
  int _requestVersion = 0;

  RecipientInputState get state => _state;

  Future<void> initialize() {
    return _syncCurrentState(forceLookupForSavedRecipient: false);
  }

  Future<void> switchMode(RecipientInputMode mode) async {
    if (_state.mode == mode) return;
    _requestVersion++;
    _applyState(_transientStateForMode(mode));
    await _syncCurrentState(forceLookupForSavedRecipient: false);
  }

  Future<void> selectSavedRecipient(RecipientAddressModel? recipient) async {
    _requestVersion++;
    _applyState(
      _transientStateForMode(
        RecipientInputMode.savedRecipient,
      ).copyWith(savedRecipient: recipient, resolvedRecipient: recipient),
    );
    await _syncCurrentState(forceLookupForSavedRecipient: false);
  }

  Future<void> setScannedValue(String rawValue) async {
    _requestVersion++;
    _applyState(
      _transientStateForMode(
        RecipientInputMode.scannedQr,
      ).copyWith(scannedRawValue: rawValue.trim()),
    );
    await _syncCurrentState(forceLookupForSavedRecipient: false);
  }

  Future<void> setManualPublicAddress(String value) async {
    _requestVersion++;
    _applyState(
      _transientStateForMode(
        RecipientInputMode.publicAddress,
      ).copyWith(manualPublicAddress: value.trim()),
    );
    await _syncCurrentState(forceLookupForSavedRecipient: false);
  }

  Future<void> setFederationInput(String value) async {
    _requestVersion++;
    _applyState(
      _transientStateForMode(
        RecipientInputMode.federation,
      ).copyWith(federationInput: value.trim()),
    );
    await _syncCurrentState(forceLookupForSavedRecipient: false);
  }

  Future<void> clearFederationSelection() async {
    _requestVersion++;
    _applyState(
      _state.copyWith(
        federationInput: '',
        federationLoading: false,
        federationError: null,
        resolvedFederation: null,
        recipientLoading: false,
        resolvedRecipient: _state.mode == RecipientInputMode.savedRecipient
            ? _state.savedRecipient
            : null,
      ),
    );
    await _syncCurrentState(forceLookupForSavedRecipient: false);
  }

  RecipientInputState _transientStateForMode(RecipientInputMode mode) {
    return _state.copyWith(
      mode: mode,
      recipientLoading: false,
      federationLoading: false,
      resolvedFederation: null,
      federationError: null,
      resolvedRecipient: mode == RecipientInputMode.savedRecipient
          ? _state.savedRecipient
          : null,
    );
  }

  void _applyState(RecipientInputState nextState) {
    _state = nextState;
    onStateChanged(_state);
  }

  Future<void> _syncCurrentState({
    required bool forceLookupForSavedRecipient,
  }) async {
    final requestVersion = _requestVersion;
    final kind = _state.activeValueKind;
    final activeValue = _state.activeInputValue;

    if (kind == RecipientValueKind.empty) {
      _applyState(
        _state.copyWith(
          recipientLoading: false,
          federationLoading: false,
          resolvedFederation: null,
          federationError: null,
          resolvedRecipient: _state.mode == RecipientInputMode.savedRecipient
              ? _state.savedRecipient
              : null,
        ),
      );
      return;
    }

    if (kind == RecipientValueKind.invalid) {
      _applyState(
        _state.copyWith(
          recipientLoading: false,
          federationLoading: false,
          resolvedFederation: null,
          federationError: null,
          resolvedRecipient: _state.mode == RecipientInputMode.savedRecipient
              ? _state.savedRecipient
              : null,
        ),
      );
      return;
    }

    if (kind == RecipientValueKind.publicAddress) {
      if (_state.mode == RecipientInputMode.savedRecipient &&
          !forceLookupForSavedRecipient) {
        _applyState(
          _state.copyWith(
            recipientLoading: false,
            federationLoading: false,
            resolvedFederation: null,
            federationError: null,
            resolvedRecipient: _state.savedRecipient,
          ),
        );
        return;
      }

      _applyState(
        _state.copyWith(
          recipientLoading: true,
          federationLoading: false,
          resolvedFederation: null,
          federationError: null,
          resolvedRecipient: _state.mode == RecipientInputMode.savedRecipient
              ? _state.savedRecipient
              : null,
        ),
      );

      final match = await lookupRecipient(activeValue);
      if (requestVersion != _requestVersion) return;

      _applyState(
        _state.copyWith(
          recipientLoading: false,
          resolvedRecipient: _state.mode == RecipientInputMode.savedRecipient
              ? (_state.savedRecipient ?? match)
              : match,
        ),
      );
      return;
    }

    _applyState(
      _state.copyWith(
        federationLoading: true,
        federationError: null,
        resolvedFederation: null,
        recipientLoading: _state.mode != RecipientInputMode.savedRecipient,
        resolvedRecipient: _state.mode == RecipientInputMode.savedRecipient
            ? _state.savedRecipient
            : null,
      ),
    );

    try {
      final resolved = await resolveFederation(
        activeValue,
        domain: _state.federationDomain,
      );
      if (requestVersion != _requestVersion) return;

      final accountId = resolved.accountId.trim();
      if (!RecipientInputParser.isStellarPublicAddress(accountId)) {
        throw StateError('Resolved federation has no valid Stellar account id');
      }

      if (_state.mode == RecipientInputMode.savedRecipient) {
        _applyState(
          _state.copyWith(
            federationLoading: false,
            resolvedFederation: resolved,
            federationError: null,
            recipientLoading: false,
            resolvedRecipient: _state.savedRecipient,
          ),
        );
        return;
      }

      _applyState(
        _state.copyWith(
          federationLoading: false,
          resolvedFederation: resolved,
          federationError: null,
          recipientLoading: true,
        ),
      );

      final match = await lookupRecipient(accountId);
      if (requestVersion != _requestVersion) return;

      _applyState(
        _state.copyWith(
          recipientLoading: false,
          resolvedRecipient: match,
          resolvedFederation: resolved,
        ),
      );
    } catch (_) {
      if (requestVersion != _requestVersion) return;
      _applyState(
        _state.copyWith(
          federationLoading: false,
          recipientLoading: false,
          resolvedFederation: null,
          federationError: 'Federation not found or unavailable.',
          resolvedRecipient: _state.mode == RecipientInputMode.savedRecipient
              ? _state.savedRecipient
              : null,
        ),
      );
    }
  }
}
