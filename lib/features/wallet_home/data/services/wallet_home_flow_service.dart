import 'package:next_fi/core/services/wallet_sync/wallet_sync_service.dart';

class WalletHomeFlowService {
  WalletHomeFlowService({
    WalletSyncService? walletSyncService,
  }) : _walletSyncService = walletSyncService ?? WalletSyncService.I;

  final WalletSyncService _walletSyncService;

  Future<bool> ensureWalletSavedIfMissing({
    required String address,
    String? label,
  }) async {
    final normalized = address.trim().toUpperCase();
    if (normalized.isEmpty) return false;

    await _walletSyncService.queueWalletRegistration(
      publicAddress: normalized,
      nickname: label,
    );
    return true;
  }

  Future<bool> hasTradeAccess() async {
    return false;
  }
}
