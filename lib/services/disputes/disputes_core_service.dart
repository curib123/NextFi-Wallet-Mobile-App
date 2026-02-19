import 'dart:async';
import 'dart:io';

import 'package:next_fi/services/secure_storage/token_storage.dart';

import 'api/disputes_service.dart';
import 'models/disputes_dtos.dart';
import 'models/disputes_models.dart';

class DisputesCoreService {
  DisputesCoreService._();

  static final DisputesCoreService I = DisputesCoreService._();
  static final StreamController<void> _changesCtrl =
      StreamController<void>.broadcast();

  static Stream<void> get changes => _changesCtrl.stream;

  late final DisputesService _api = DisputesService(
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

  Future<DisputeModel> openDispute(OpenDisputeRequest req) async {
    final dispute = await _api.openDispute(req);
    _emitChanged();
    return dispute;
  }

  Future<List<DisputeModel>> listMyDisputes(DisputesQuery query) async =>
      _api.listMyDisputes(query);

  Future<List<DisputeModel>> listSellerDisputes(DisputesQuery query) async =>
      _api.listSellerDisputes(query);

  Future<DisputeModel> uploadEvidence(
    String disputeId, {
    required File image,
    String? note,
  }) async {
    final dispute = await _api.uploadEvidence(
      disputeId,
      image: image,
      note: note,
    );
    _emitChanged();
    return dispute;
  }

  void _emitChanged() {
    if (!_changesCtrl.isClosed) {
      _changesCtrl.add(null);
    }
  }
}
