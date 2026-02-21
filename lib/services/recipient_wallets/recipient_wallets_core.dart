// lib/services/recipient_wallets/recipient_wallets_core.dart
//
// Core / single place to access Recipient Wallets API.
// Uses:
//   - _baseUrl = centralized_baseUrl
//   - TokenStorage (FlutterSecureStorage)
//
// Usage:
//   final recipientCore = RecipientWalletsCore();
//   await recipientCore.addRecipient(name: "Mom", address: "GCFH...");
//   final recipients = await recipientCore.getAllRecipients();
//   await recipientCore.searchRecipients(query: "mom");
//   await recipientCore.updateRecipient(id: "...", name: "Mother");
//   await recipientCore.toggleRecipient(id: "...");
//   await recipientCore.deleteRecipient(id: "...");

import 'package:next_fi/services/recipient_wallets/recipient_wallets_service.dart';
import 'package:next_fi/services/recipient_wallets/models/recipient_wallet_models.dart';

import 'package:next_fi/services/secure_storage/token_storage.dart';

import '../base_url/base_url.dart' show centralized_baseUrl;

class RecipientWalletsCore {
  static const String _baseUrl = centralized_baseUrl;

  final TokenStorage _tokenStorage;
  late final RecipientWalletsService svc;

  RecipientWalletsCore({TokenStorage? tokenStorage})
      : _tokenStorage = tokenStorage ?? TokenStorage() {
    svc = RecipientWalletsService(
      baseUrl: _baseUrl,
      tokenProvider: () async => await _tokenStorage.accessToken,
    );
  }

  // ────────────────────────────────────────────────────────────────────
  // Convenience helpers (UI-friendly)
  // ────────────────────────────────────────────────────────────────────

  /// Add a new recipient wallet address (JWT required).
  Future<RecipientWallet> addRecipient({
    required String name,
    required String address,
    String? network,
    String? memo,
    bool isActive = true,
  }) {
    return svc.recipientWallets.create(
      CreateRecipientWalletRequest(
        name: name,
        publicAddress: address,
        network: network ?? 'stellar',
        memo: memo,
        isActive: isActive,
      ),
    );
  }

  /// Get all recipient wallets (optionally filtered by network and active status).
  Future<List<RecipientWallet>> getAllRecipients({
    String? network,
    bool activeOnly = false,
  }) {
    return svc.recipientWallets.list(
      network: network,
      activeOnly: activeOnly ? true : null,
    );
  }

  /// Search recipients by name or address (JWT required).
  Future<List<RecipientWallet>> searchRecipients({
    required String query,
    String? network,
    bool activeOnly = false,
  }) {
    return svc.recipientWallets.list(
      q: query,
      network: network,
      activeOnly: activeOnly ? true : null,
    );
  }

  /// Get a specific recipient by ID (JWT required).
  Future<RecipientWallet> getRecipient(String id) {
    return svc.recipientWallets.getById(id);
  }

  /// Update recipient details (JWT required).
  Future<RecipientWallet> updateRecipient({
    required String id,
    String? name,
    String? address,
    String? network,
    String? memo,
    bool? isActive,
  }) {
    return svc.recipientWallets.update(
      id: id,
      name: name,
      publicAddress: address,
      network: network,
      memo: memo,
      isActive: isActive,
    );
  }

  /// Toggle recipient active status (JWT required).
  Future<RecipientWallet> toggleRecipient(String id) {
    return svc.recipientWallets.toggleActive(id);
  }

  /// Delete a recipient (JWT required).
  Future<bool> deleteRecipient(String id) {
    return svc.recipientWallets.delete(id);
  }

  /// Get only active recipients (convenience method).
  Future<List<RecipientWallet>> getActiveRecipients({String? network}) {
    return getAllRecipients(network: network, activeOnly: true);
  }

  /// Get recipients for a specific network.
  Future<List<RecipientWallet>> getRecipientsByNetwork(String network, {bool activeOnly = false}) {
    return getAllRecipients(network: network, activeOnly: activeOnly);
  }

  /// Optional: free http client.
  void dispose() => svc.dispose();
}