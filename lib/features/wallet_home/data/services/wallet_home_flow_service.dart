import 'package:next_fi/core/services/auth/auth_service.dart';
import 'package:next_fi/core/services/verification/models/verification_models.dart';
import 'package:next_fi/core/services/verification/verification_core_service.dart';
import 'package:next_fi/core/services/wallet/wallet_manager.dart';

class WalletHomeFlowService {
  WalletHomeFlowService({
    AuthService? authService,
    VerificationCoreService? verificationService,
    WalletManager? walletManager,
  }) : _authService = authService ?? AuthService(),
       _verificationService = verificationService ?? VerificationCoreService.I,
       _walletManager = walletManager ?? WalletManager.I;

  final AuthService _authService;
  final VerificationCoreService _verificationService;
  final WalletManager _walletManager;

  Future<bool> ensureWalletSavedIfMissing({
    required String address,
    String? label,
  }) async {
    final normalized = address.trim();
    if (normalized.isEmpty) return false;

    final authenticated = await _authService.isAuthenticated;
    if (!authenticated) return false;

    final existsInBackend = await _walletManager.hasAddressInBackend(normalized);
    if (existsInBackend) return true;

    await _walletManager.saveAddressIfMissing(
      publicAddress: normalized,
      label: label,
    );
    return true;
  }

  Future<bool> hasTradeAccess() async {
    final verification = await _verificationService.getMe();
    return verification.status == TrustStatus.ready;
  }
}

