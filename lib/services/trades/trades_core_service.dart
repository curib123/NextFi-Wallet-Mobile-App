import 'dart:async';
import 'dart:io';

import 'package:next_fi/services/secure_storage/token_storage.dart';

import 'api/trades_service.dart';
import 'models/trades_dtos.dart';
import 'models/trades_models.dart';

class TradesCoreService {
  TradesCoreService._();

  static final TradesCoreService I = TradesCoreService._();
  static final StreamController<void> _changesCtrl =
      StreamController<void>.broadcast();

  static Stream<void> get changes => _changesCtrl.stream;

  late final TradesService _api = TradesService(
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

  Future<TradeModel> createTrade(CreateTradeRequest req) async {
    final trade = await _api.createTrade(req);
    _emitChanged();
    return trade;
  }

  Future<List<TradeModel>> listMyTrades(TradesQuery query) async =>
      _api.listMyTrades(query);

  Future<TradeModel> getMyTradeById(String id) async => _api.getMyTradeById(id);

  Future<TradeModel> markPaid(
    String id, {
    required String idempotencyKey,
  }) async {
    final trade = await _api.markPaid(id, idempotencyKey: idempotencyKey);
    _emitChanged();
    return trade;
  }

  Future<TradeModel> cancelMyTrade(
    String id, {
    required String idempotencyKey,
    String? txHash,
    String? reason,
  }) async {
    final trade = await _api.cancelMyTrade(
      id,
      idempotencyKey: idempotencyKey,
      txHash: txHash,
      reason: reason,
    );
    _emitChanged();
    return trade;
  }

  Future<TradeModel> uploadPaymentProof(
    String tradeId, {
    required File image,
    String? note,
  }) async {
    final trade = await _api.uploadPaymentProof(
      tradeId,
      image: image,
      note: note,
    );
    _emitChanged();
    return trade;
  }

  Future<TradeMessageModel> sendMyMessage(
    String tradeId,
    String message,
  ) async {
    final msg = await _api.sendMyMessage(tradeId, message);
    _emitChanged();
    return msg;
  }

  Future<List<TradeModel>> listSellerTrades(TradesQuery query) async =>
      _api.listSellerTrades(query);

  Future<TradeModel> getSellerTradeById(String id) async =>
      _api.getSellerTradeById(id);

  Future<TradeModel> releaseSellerTrade(
    String id, {
    required String idempotencyKey,
    String? txHash,
  }) async {
    final trade = await _api.releaseSellerTrade(
      id,
      idempotencyKey: idempotencyKey,
      txHash: txHash,
    );
    _emitChanged();
    return trade;
  }

  Future<TradeModel> cancelSellerTrade(
    String id, {
    required String idempotencyKey,
    String? txHash,
    String? reason,
  }) async {
    final trade = await _api.cancelSellerTrade(
      id,
      idempotencyKey: idempotencyKey,
      txHash: txHash,
      reason: reason,
    );
    _emitChanged();
    return trade;
  }

  void _emitChanged() {
    if (!_changesCtrl.isClosed) {
      _changesCtrl.add(null);
    }
  }
}
