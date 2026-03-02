import 'package:next_fi/services/secure_storage/token_storage.dart';

import 'api/merchant_payment_account_service.dart';
import 'models/merchant_payment_account_dtos.dart';
import 'models/merchant_payment_account_models.dart';

class MerchantPaymentAccountCoreService {
  MerchantPaymentAccountCoreService._();

  static final MerchantPaymentAccountCoreService I =
      MerchantPaymentAccountCoreService._();

  late final MerchantPaymentAccountService _api =
      MerchantPaymentAccountService(tokenProvider: _safeTokenProvider);

  static Future<String?> _safeTokenProvider() async {
    try {
      final storage = TokenStorage();
      return await storage.accessToken;
    } catch (_) {
      return null;
    }
  }

  /// List own merchant payment accounts (paginated).
  Future<MerchantPaymentAccountPagedResponse> listPaged({
    MerchantPaymentAccountListQuery query =
        const MerchantPaymentAccountListQuery(),
  }) async => _api.listPaged(query: query);

  /// Convenience: fetch all accounts without pagination.
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

  /// Get a single account by ID.
  Future<MerchantPaymentAccountModel> getOne(String id) async =>
      _api.getOne(id);

  /// Create a new payment account. Setting [isActive] to true will deactivate
  /// all other accounts of this merchant (single-active pattern).
  Future<MerchantPaymentAccountModel> create(
    CreateMerchantPaymentAccountRequest req,
  ) async => _api.create(req);

  /// Update a payment account.
  Future<MerchantPaymentAccountModel> update(
    String id,
    UpdateMerchantPaymentAccountRequest req,
  ) async => _api.update(id, req);

  /// Toggle the isActive flag for a payment account.
  Future<MerchantPaymentAccountModel> toggle(String id) async =>
      _api.toggle(id);

  /// Delete a payment account.
  Future<bool> remove(String id) async => _api.remove(id);
}
