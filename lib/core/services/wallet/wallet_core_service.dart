import 'package:next_fi/core/services/secure_storage/token_storage.dart';
import 'package:next_fi/core/services/wallet/api/wallet_service.dart';
import 'package:next_fi/core/services/wallet/helpers/wallet_exceptions.dart';
import 'package:next_fi/core/services/wallet/models/wallet_dtos.dart';
import 'package:next_fi/core/services/wallet/models/wallet_models.dart';

class WalletCoreService {
  WalletCoreService._();

  static final WalletCoreService I = WalletCoreService._();

  late final WalletService _api = WalletService(
    tokenProvider: _safeTokenProvider,
  );

  static Future<String?> _safeTokenProvider() async {
    try {
      final storage = TokenStorage();
      return await storage.accessToken;
    } catch (_) {
      return null;
    }
  }

  Future<WalletPagedResponse> listPaged({
    WalletListQuery query = const WalletListQuery(),
  }) async {
    try {
      return await _api.listPaged(query: query);
    } on ApiException catch (e) {
      _handleAuthError(e);
      rethrow;
    }
  }

  Future<List<WalletAddress>> list({
    WalletListQuery query = const WalletListQuery(),
  }) async {
    try {
      return await _api.list(query: query);
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

  Future<WalletAddress> updateWallet({
    required String walletId,
    String? label,
    String? publicAddress,
    String? network,
  }) async {
    try {
      return await _api.update(
        walletId,
        UpdateWalletRequest(
          label: label,
          publicAddress: publicAddress,
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
    return updateWallet(walletId: walletId, label: label);
  }

  Future<WalletAddress> setActive({required String walletId}) async {
    try {
      return await _api.setActive(walletId);
    } on ApiException catch (e) {
      _handleAuthError(e);
      rethrow;
    }
  }

  Future<WalletAddress> remove({required String walletId}) async {
    try {
      return await _api.remove(walletId);
    } on ApiException catch (e) {
      _handleAuthError(e);
      rethrow;
    }
  }

  void _handleAuthError(ApiException e) {
    if (e.statusCode == 401) {
      // ignore: avoid_print
      print('[WalletCoreService] Unauthorized token');
    }
  }

  void dispose() {
    _api.dispose();
  }
}
