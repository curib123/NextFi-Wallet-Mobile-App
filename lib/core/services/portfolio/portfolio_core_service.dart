import 'package:next_fi/core/services/portfolio/api/portfolio_service.dart';
import 'package:next_fi/core/services/portfolio/models/portfolio_models.dart';
import 'package:next_fi/core/services/wallet_sync/wallet_backend_client.dart';
import 'package:next_fi/core/services/wallet/helpers/wallet_exceptions.dart';

class PortfolioCoreService {
  PortfolioCoreService._();

  static final PortfolioCoreService I = PortfolioCoreService._();

  late final PortfolioService _api = PortfolioService(
    tokenProvider: _safeTokenProvider,
  );

  static Future<String?> _safeTokenProvider() async {
    try {
      return await WalletBackendClient.I.currentActiveToken();
    } catch (_) {
      return null;
    }
  }

  Future<void> createSnapshot(CreatePortfolioSnapshotRequest request) async {
    try {
      await _api.createSnapshot(request);
    } on ApiException catch (error) {
      _handleAuthError(error);
      rethrow;
    }
  }

  Future<WalletPortfolioData> getWalletPortfolio({
    required String walletId,
    required PortfolioRange range,
  }) async {
    try {
      return await _api.getWalletPortfolio(walletId: walletId, range: range);
    } on ApiException catch (error) {
      _handleAuthError(error);
      rethrow;
    }
  }

  void _handleAuthError(ApiException error) {
    if (error.statusCode == 401) {
      // Ignored here; shell/auth flow handles reauthentication.
    }
  }

  void dispose() {
    _api.dispose();
  }
}
