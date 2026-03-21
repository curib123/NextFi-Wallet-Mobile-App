import 'api/portfolio_service.dart';
import 'package:next_fi/core/services/secure_storage/token_storage.dart';

class PortfolioCoreService {
  PortfolioCoreService._();

  static final PortfolioCoreService I = PortfolioCoreService._();

  final TokenStorage _tokens = TokenStorage();
  PortfolioService? _service;

  PortfolioService get _api =>
      _service ??= PortfolioService(tokenProvider: () => _tokens.accessToken);

  PortfolioService get api => _api;

  void dispose() {
    _service?.dispose();
    _service = null;
  }
}
