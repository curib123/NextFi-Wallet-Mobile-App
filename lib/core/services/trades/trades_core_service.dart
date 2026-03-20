import 'dart:io';

import 'package:next_fi/core/services/secure_storage/token_storage.dart';
import 'package:next_fi/core/services/trades/api/trades_service.dart';
import 'package:next_fi/core/services/trades/models/trades_dtos.dart';
import 'package:next_fi/core/services/trades/models/trades_models.dart';

class TradesCoreService {
  TradesCoreService._();

  static final TradesCoreService I = TradesCoreService._();

  late final TradesService _api = TradesService(
    tokenProvider: _safeTokenProvider,
  );

  static Future<String?> _safeTokenProvider() async {
    try {
      return await TokenStorage().accessToken;
    } catch (_) {
      return null;
    }
  }

  Future<TradeModel> create(CreateTradeRequest req) => _api.create(req);

  Future<TradesPagedResponse> listPaged({
    TradesListQuery query = const TradesListQuery(),
  }) => _api.listPaged(query: query);

  Future<List<TradeModel>> list([
    TradesListQuery query = const TradesListQuery(),
  ]) async {
    final page = await _api.listPaged(query: query);
    return page.items;
  }

  Future<TradeModel> getOne(String id) => _api.getOne(id);

  Future<TradeModel> markFiatSent(String id) => _api.markFiatSent(id);

  Future<TradeModel> confirmRequest(String id) => _api.confirmRequest(id);

  Future<TradeModel> confirmFiat(String id, {String? fiatRefNo}) =>
      _api.confirmFiat(id, fiatRefNo: fiatRefNo);

  Future<TradeModel> cancelTrade(String id, {String? reason}) =>
      _api.cancelTrade(id, reason: reason);

  Future<TradeModel> lockCrypto(
    String id, {
    required String claimableBalanceId,
    required String createTxHash,
  }) => _api.lockCrypto(
    id,
    claimableBalanceId: claimableBalanceId,
    createTxHash: createTxHash,
  );

  Future<TradeModel> claimCrypto(String id, {required String claimTxHash}) =>
      _api.claimCrypto(id, claimTxHash: claimTxHash);

  Future<TradeModel> refundCrypto(String id, {required String refundTxHash}) =>
      _api.refundCrypto(id, refundTxHash: refundTxHash);

  Future<TradeModel> markFiatSentWithProof(
    String id, {
    String? note,
    List<String>? proofUrls,
  }) => _api.markFiatSentWithProof(id, note: note, proofUrls: proofUrls);

  Future<TradeModel> openDispute(
    String id, {
    required String reason,
    String? details,
    String? description,
  }) => _api.openDispute(
    id,
    reason: reason,
    details: details,
    description: description,
  );

  Future<String?> uploadProof(
    String id, {
    required File file,
    String type = 'FIAT',
    String? note,
    String? referenceNo,
    String? txHash,
  }) => _api.uploadPaymentProof(
    id,
    file: file,
    type: type,
    note: note,
    referenceNo: referenceNo,
    txHash: txHash,
  );

  Future<List<Map<String, dynamic>>> getTradeProofs(String id) =>
      _api.getTradeProofs(id);

  Future<List<Map<String, dynamic>>> getDisputeEvidence(String disputeId) =>
      _api.getDisputeEvidence(disputeId);

  Future<void> uploadDisputeEvidence(
    String disputeId, {
    required File file,
    String? note,
  }) => _api.uploadDisputeEvidence(disputeId, file: file, note: note);

  Future<List<Map<String, dynamic>>> getTradeMessages(String id) =>
      _api.getTradeMessages(id);

  Future<void> sendTradeMessage(
    String id, {
    required String ciphertext,
    required String algorithm,
    required String senderKeyId,
    required String nonce,
    String kind = 'TEXT',
  }) => _api.sendTradeMessage(
    id,
    ciphertext: ciphertext,
    algorithm: algorithm,
    senderKeyId: senderKeyId,
    nonce: nonce,
    kind: kind,
  );

  void dispose() => _api.dispose();
}
