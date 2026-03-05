import 'package:next_fi/services/secure_storage/token_storage.dart';

import 'api/payment_method_and_accounts_service.dart';
import 'models/payment_method_and_accounts_dtos.dart';
import 'models/payment_method_and_accounts_models.dart';

class PaymentMethodAndAccountsCoreService {
  PaymentMethodAndAccountsCoreService._();

  static final PaymentMethodAndAccountsCoreService I =
      PaymentMethodAndAccountsCoreService._();

  late final PaymentMethodAndAccountsService _api =
      PaymentMethodAndAccountsService(tokenProvider: _safeTokenProvider);

  static Future<String?> _safeTokenProvider() async {
    try {
      final storage = TokenStorage();
      return await storage.accessToken;
    } catch (_) {
      return null;
    }
  }

  Future<List<PaymentMethodModel>> listPaymentMethods({
    bool? activeOnly,
    String? q,
  }) async => _api.listPaymentMethods(
    PaymentMethodsQuery(activeOnly: activeOnly, q: q),
  );

  Future<PaymentMethodModel> getPaymentMethodById(String id) async =>
      _api.getPaymentMethodById(id);

  Future<List<UserPaymentAccountModel>> listMyPaymentAccounts({
    bool? activeOnly,
    String? q,
    String? paymentMethodId,
    int? page,
    int? limit,
  }) async => _api.listMyPaymentAccounts(
    PaymentAccountsQuery(
      activeOnly: activeOnly,
      q: q,
      paymentMethodId: paymentMethodId,
      page: page,
      limit: limit,
    ),
  );

  Future<UserPaymentAccountModel> getMyPaymentAccountById(String id) async =>
      _api.getMyPaymentAccountById(id);

  Future<UserPaymentAccountModel> createMyPaymentAccount(
    CreateUserPaymentAccountRequest req,
  ) async => _api.createMyPaymentAccount(req);

  Future<UserPaymentAccountModel> updateMyPaymentAccount(
    String id,
    UpdateUserPaymentAccountRequest req,
  ) async => _api.updateMyPaymentAccount(id, req);

  Future<UserPaymentAccountModel> editMyPaymentAccount(
    String id,
    UpdateUserPaymentAccountRequest req,
  ) async => _api.editMyPaymentAccount(id, req);

  Future<UserPaymentAccountModel> toggleMyPaymentAccount(String id) async =>
      _api.toggleMyPaymentAccount(id);

  Future<bool> deleteMyPaymentAccount(String id) async =>
      _api.deleteMyPaymentAccount(id);
}
