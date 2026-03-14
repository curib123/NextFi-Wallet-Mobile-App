import 'package:next_fi/features/contact/data/models/recipient_address_model.dart';
import 'package:next_fi/core/services/recipient_wallets/models/recipient_wallet_models.dart';
import 'package:next_fi/core/services/recipient_wallets/recipient_wallets_core.dart';

class ContactService {
  ContactService([RecipientWalletsCore? api]) : _api = api ?? RecipientWalletsCore();

  final RecipientWalletsCore _api;

  Future<List<RecipientAddressModel>> fetchAll({bool activeOnly = false}) async {
    final recipients = await _api.getAllRecipients(activeOnly: activeOnly);
    return recipients.map(_toLocal).toList();
  }

  Future<List<RecipientAddressModel>> search(String query) async {
    final recipients = await _api.searchRecipients(
      query: query,
      activeOnly: false,
    );
    return recipients.map(_toLocal).toList();
  }

  Future<RecipientAddressModel> add({
    required String name,
    required String address,
    required int color,
  }) async {
    final wallet = await _api.addRecipient(
      name: name.trim(),
      address: address.trim(),
      network: 'stellar',
      colorTag: _toColorTag(color),
    );
    return _toLocal(wallet);
  }

  Future<RecipientAddressModel> update(
    String id, {
    String? name,
    String? address,
    int? color,
  }) async {
    final wallet = await _api.updateRecipient(
      id: id,
      name: name?.trim(),
      address: address?.trim(),
      colorTag: color == null ? null : _toColorTag(color),
    );
    return _toLocal(wallet);
  }

  Future<void> remove(String id) => _api.deleteRecipient(id);

  void dispose() => _api.dispose();

  RecipientAddressModel _toLocal(RecipientWallet wallet) {
    final displayName = wallet.displayName.isEmpty
        ? wallet.effectiveAddress
        : wallet.displayName;
    return RecipientAddressModel(
      id: wallet.id,
      name: displayName,
      address: wallet.effectiveAddress,
      color:
          _parseColorTag(wallet.colorTag) ??
          _extractColorFromMemo(wallet.memo) ??
          0xFF3A5BFF,
      createdAt: wallet.createdAt,
      updatedAt: wallet.updatedAt,
    );
  }

  int? _parseColorTag(String? colorTag) {
    if (colorTag == null) return null;
    final raw = colorTag.trim();
    if (raw.isEmpty) return null;
    if (raw.startsWith('#') && raw.length == 7) {
      return int.tryParse('FF${raw.substring(1)}', radix: 16);
    }
    if (raw.startsWith('0x')) {
      return int.tryParse(raw.substring(2), radix: 16);
    }
    return int.tryParse(raw);
  }

  int? _extractColorFromMemo(String? memo) {
    if (memo == null || !memo.contains('color:')) return null;
    try {
      final colorPart = memo
          .split(';')
          .firstWhere((part) => part.startsWith('color:'), orElse: () => '');
      if (colorPart.isEmpty) return null;
      return int.tryParse(colorPart.replaceFirst('color:', '').trim());
    } catch (_) {
      return null;
    }
  }

  String _toColorTag(int color) {
    final rgb = color & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}
