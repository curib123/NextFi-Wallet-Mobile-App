import 'package:next_fi/core/services/secure_storage/token_storage.dart';

import 'api/fee_config_service.dart';
import 'models/fee_config_dtos.dart';
import 'models/fee_config_models.dart';

class FeeConfigCoreService {
  FeeConfigCoreService._();

  static final FeeConfigCoreService I = FeeConfigCoreService._();

  late final FeeConfigService _api = FeeConfigService(
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

  Future<FeeConfigModel> getCurrent() => _api.getCurrent();

  Future<FeeConfigModel> patch(UpdateFeeConfigRequest req) => _api.patch(req);
}
