

import 'package:next_fi/services/secure_storage/token_storage.dart';
import 'package:next_fi/services/wallet/api/wallet_service.dart';
import 'package:next_fi/services/wallet/helpers/wallet_exceptions.dart';
import 'package:next_fi/services/wallet/models/wallet_dtos.dart';
import 'package:next_fi/services/wallet/models/wallet_models.dart';

class WalletCoreService {
  WalletCoreService._();

  /// ── Singleton ─────────────────────────────────
  static final WalletCoreService I = WalletCoreService._();

  /// ── Lazy API instance ─────────────────────────
  late final WalletService _api = WalletService(
    tokenProvider: _safeTokenProvider,
  );

  // ─────────────────────────────────────────────
  // Safe token provider
  // ─────────────────────────────────────────────
  static Future<String?> _safeTokenProvider() async {
    try {
      final storage = TokenStorage();

      // If async getter exists
      return await storage.accessToken;

      // If sync getter
      return storage.accessToken;
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────
  // Wallet CRUD
  // ─────────────────────────────────────────────

  Future<List<WalletAddress>> list() async {
    try {
      return await _api.list();
    } on ApiException catch (e) {
      _handleAuthError(e);
      rethrow;
    }
  }

  Future<WalletAddress> create({
    required String publicAddress,
    String? label,
    String network = 'stellar',
  }) async {
    try {
      return await _api.create(
        CreateWalletRequest(
          publicAddress: publicAddress,
          label: label,
          network: network,
        ),
      );
    } on ApiException catch (e) {
      _handleAuthError(e);
      rethrow;
    }
  }

  Future<WalletAddress> updateLabel({
    required String walletId,
    required String label,
  }) async {
    try {
      return await _api.updateLabel(walletId, label: label);
    } on ApiException catch (e) {
      _handleAuthError(e);
      rethrow;
    }
  }

  Future<void> remove({
    required String walletId,
  }) async {
    try {
      await _api.remove(walletId);
    } on ApiException catch (e) {
      _handleAuthError(e);
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // Auth error handler
  // ─────────────────────────────────────────────
  void _handleAuthError(ApiException e) {
    if (e.statusCode == 401) {
      // Example actions:
      // - Force logout
      // - Refresh token
      // - Navigate to login
      // - Clear cache

      // For now just log:
      // ignore: avoid_print
      print('[WalletCoreService] Unauthorized — token expired');
    }
  }
}
