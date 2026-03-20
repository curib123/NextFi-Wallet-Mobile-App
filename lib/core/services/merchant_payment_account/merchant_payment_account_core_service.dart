import 'package:next_fi/core/services/secure_storage/token_storage.dart';

import 'api/merchant_payment_account_service.dart';
import 'models/merchant_payment_account_dtos.dart';
import 'models/merchant_payment_account_models.dart';

class MerchantPaymentAccountCoreService {
  MerchantPaymentAccountCoreService._();

  static final MerchantPaymentAccountCoreService I =
      MerchantPaymentAccountCoreService._();

  late final MerchantPaymentAccountService _api = MerchantPaymentAccountService(
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

  Future<MerchantPaymentAccountPagedResponse> listPaged({
    MerchantPaymentAccountListQuery query =
        const MerchantPaymentAccountListQuery(),
  }) async => _api.listPaged(query: query);

  Future<List<MerchantPaymentAccountModel>> listAll({
    bool? activeOnly,
    String? paymentMethodId,
  }) async {
    final res = await _api.listPaged(
      query: MerchantPaymentAccountListQuery(
        activeOnly: activeOnly,
        paymentMethodId: paymentMethodId,
        limit: 100,
      ),
    );
    return res.items;
  }

  Future<MerchantPaymentAccountModel> getOne(String id) async =>
      _api.getOne(id);

  Future<MerchantPaymentAccountModel> create(
    CreateMerchantPaymentAccountRequest req,
  ) async => _api.create(req);

  Future<MerchantPaymentAccountModel> update(
    String id,
    UpdateMerchantPaymentAccountRequest req,
  ) async => _api.update(id, req);

  Future<MerchantPaymentAccountModel> toggle(String id) async =>
      _api.toggle(id);

  Future<bool> remove(String id) async => _api.remove(id);
}
