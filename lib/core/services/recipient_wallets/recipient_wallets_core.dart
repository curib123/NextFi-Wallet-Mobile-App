import 'package:next_fi/core/services/recipient_wallets/recipient_wallets_service.dart';
import 'package:next_fi/core/services/recipient_wallets/models/recipient_wallet_models.dart';

import 'package:next_fi/core/services/secure_storage/token_storage.dart';

import '../base_url/base_url.dart' show centralizedBaseUrl;

class RecipientWalletsCore {
  final TokenStorage _tokenStorage;
  late final RecipientWalletsService svc;

  RecipientWalletsCore({TokenStorage? tokenStorage})
    : _tokenStorage = tokenStorage ?? TokenStorage() {
    svc = RecipientWalletsService(
      baseUrl: centralizedBaseUrl,
      tokenProvider: () async => await _tokenStorage.accessToken,
    );
  }

  Future<RecipientWallet> addRecipient({
    String? name,
    String? label,
    required String address,
    String? publicAddress,
    String? network,
    String? colorTag,
    String? color,
    bool? isActive,
    String? memo,
    String? memoType,
  }) {
    final resolvedName = (name ?? label)?.trim();
    final resolvedAddress = (publicAddress ?? address).trim();
    return svc.recipientWallets.create(
      CreateRecipientWalletRequest(
        name: (resolvedName == null || resolvedName.isEmpty)
            ? resolvedAddress
            : resolvedName,
        publicAddress: resolvedAddress,
        network: network ?? 'stellar',
        colorTag: (colorTag ?? color)?.trim().isEmpty == true
            ? null
            : (colorTag ?? color)?.trim(),
        isActive: isActive,
        memo: memo,
        memoType: memoType,
      ),
    );
  }

  Future<List<RecipientWallet>> getAllRecipients({
    String? network,
    bool activeOnly = false,
  }) {
    return svc.recipientWallets.list(
      network: network,
      activeOnly: activeOnly ? true : null,
    );
  }

  Future<List<RecipientWallet>> searchRecipients({
    required String query,
    String? network,
    bool activeOnly = false,
  }) {
    return svc.recipientWallets.list(
      q: query,
      network: network,
      activeOnly: activeOnly ? true : null,
    );
  }

  Future<RecipientWallet> getRecipient(String id) {
    return svc.recipientWallets.getById(id);
  }

  Future<RecipientWallet> updateRecipient({
    required String id,
    String? name,
    String? label,
    String? address,
    String? publicAddress,
    String? network,
    String? colorTag,
    String? color,
    bool? isActive,
    String? memo,
    String? memoType,
  }) {
    return svc.recipientWallets.update(
      id: id,
      name: name ?? label,
      publicAddress: publicAddress ?? address,
      network: network,
      colorTag: colorTag ?? color,
      isActive: isActive,
      memo: memo,
      memoType: memoType,
    );
  }

  Future<RecipientWallet> toggleRecipient(String id) {
    return svc.recipientWallets.toggleActive(id);
  }

  Future<bool> deleteRecipient(String id) {
    return svc.recipientWallets.delete(id);
  }

  Future<List<RecipientWallet>> getActiveRecipients({String? network}) {
    return getAllRecipients(network: network, activeOnly: true);
  }

  Future<List<RecipientWallet>> getRecipientsByNetwork(
    String network, {
    bool activeOnly = false,
  }) {
    return getAllRecipients(network: network, activeOnly: activeOnly);
  }

  void dispose() => svc.dispose();
}
