// lib/features/transactions/viewmodel/transactions_vm.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as stellar;

import 'package:next_fi/services/stellar/stellar_wallet_services.dart';
import '../model/tx.dart';
import '../model/transactions_state.dart';

class TransactionsVM extends ChangeNotifier {
  TransactionsVM({required StellarWalletServices stellarSvc}) : _stellar = stellarSvc;

  final StellarWalletServices _stellar;

  TransactionsState _state = const TransactionsState();
  TransactionsState get state => _state;
  void _set(TransactionsState s) { _state = s; notifyListeners(); }

  // Paging + guards
  final int _limit = 20;
  int _fetchGen = 0;

  // Internals
  final Set<String> _seenIds = <String>{};
  StreamSubscription<stellar.PaymentOperationResponse>? _incomingSub;

  // Public incoming stream for UI chips/toasts
  final StreamController<Tx> _incomingController = StreamController<Tx>.broadcast();
  Stream<Tx> get incomingStream => _incomingController.stream;

  bool get isTestnet => _stellar.isTestnet ?? identical(_stellar.sdk, stellar.StellarSDK.TESTNET);

  // ───────── Bind to wallet address ─────────
  void bindToAddress(String? newAddr) {
    final addr = (newAddr ?? '').trim();
    if (addr.isEmpty) {
      if (_state.address != null) {
        // clear when wallet disappears
        _set(_state.copyWith(
          address: null,
          loading: false,
          errorMsg: 'No wallet found. Please import or create a wallet.',
          cursor: null,
          hasMore: true,
          txs: <Tx>[],
          accountMissing: false,
        ));
        _seenIds.clear();
        stop();
      }
      return;
    }
    if (_state.address == addr) return;

    _restartForNewAddress(addr);
  }

  void _restartForNewAddress(String addr) {
    stop();
    _seenIds.clear();
    _set(_state.copyWith(
      address: addr,
      loading: true,
      errorMsg: null,
      cursor: null,
      hasMore: true,
      txs: <Tx>[],
      accountMissing: false,
    ));

    scheduleMicrotask(() async {
      await fetch(loadMore: false);
      _subscribeIncomingIfReady();
    });
  }

  // ───────── Public API ─────────
  void setFilter(TxFilter v) {
    if (_state.filter == v) return;
    _set(_state.copyWith(filter: v));
  }

  Future<void> resetAndFetch() async {
    _set(_state.copyWith(cursor: null, hasMore: true));
    await fetch(loadMore: false);
  }

  Future<void> fetch({required bool loadMore}) async {
    final addr = _state.address;
    if (addr == null || addr.isEmpty) {
      _set(_state.copyWith(loading: false, errorMsg: _state.errorMsg ?? 'No wallet found. Please import or create a wallet.'));
      return;
    }

    final myToken = ++_fetchGen;

    if (loadMore) {
      if (!_state.hasMore || _state.loadingMore) return;
      _set(_state.copyWith(loadingMore: true));
    } else {
      _set(_state.copyWith(loading: true, errorMsg: null, cursor: _state.txs.isEmpty ? null : _state.cursor));
    }

    try {
      final builder = _stellar.sdk.payments
          .forAccount(addr)
          .order(stellar.RequestBuilderOrder.DESC)
          .limit(_limit);

      final cursor = _state.cursor;
      if (loadMore && cursor != null && cursor.isNotEmpty) {
        builder.cursor(cursor);
      }

      final page = await builder.execute();
      final ops = page.records;

      final newTx = <Tx>[];
      for (final op in ops) {
        final tx = _opToTx(op, addr);
        if (tx != null) newTx.add(tx);
      }

      if (myToken != _fetchGen) return; // stale

      List<Tx> nextList;
      Set<String> nextSeen = _seenIds;
      if (loadMore) {
        nextList = [..._state.txs, ...newTx];
      } else {
        nextList = [...newTx];
        nextSeen = newTx
            .map((t) => (t['id'] ?? '').toString())
            .where((s) => s.isNotEmpty)
            .toSet();
      }

      _seenIds
        ..clear()
        ..addAll(nextSeen);

      _set(_state.copyWith(
        txs: nextList,
        cursor: ops.isNotEmpty ? ops.last.pagingToken : _state.cursor,
        hasMore: ops.length == _limit,
        accountMissing: false,
        errorMsg: null,
      ));
    } catch (e) {
      if (myToken != _fetchGen) return;
      if (_isAccountMissingError(e)) {
        _set(_state.copyWith(
          accountMissing: true,
          txs: <Tx>[],
          hasMore: false,
          errorMsg: null,
        ));
      } else {
        _set(_state.copyWith(errorMsg: 'Error fetching history: $e'));
      }
    } finally {
      _set(_state.copyWith(loading: false, loadingMore: false));
    }
  }

  void stop() {
    _incomingSub?.cancel();
    _incomingSub = null;
  }

  @override
  void dispose() {
    stop();
    _incomingController.close();
    super.dispose();
  }

  // ───────── Internals ─────────
  void _subscribeIncomingIfReady() {
    final addr = _state.address;
    if (addr == null || addr.isEmpty || _state.accountMissing) return;

    _incomingSub?.cancel();
    _incomingSub = _stellar.paymentsStream(addr).listen((op) {
      final tx = _opToTx(op, addr);
      if (tx == null) return;

      final id = (tx['id'] ?? '').toString();
      if (id.isEmpty || _seenIds.contains(id)) return;

      _seenIds.add(id);
      final updated = [tx, ..._state.txs];
      _set(_state.copyWith(txs: updated));
      _incomingController.add(tx);
    }, onError: (_) {/* silent; pull-to-refresh available */});
  }

  Tx? _opToTx(stellar.OperationResponse op, String myAddr) {
    String? assetCode;
    double? amount;
    String? from;
    String? to;

    if (op is stellar.PaymentOperationResponse) {
      assetCode = (op.assetType == 'native') ? 'XLM' : (op.assetCode ?? 'ASSET');
      amount = double.tryParse(op.amount);
      from = op.from;
      to = op.to;
    } else if (op is stellar.PathPaymentStrictSendOperationResponse) {
      assetCode = (op.assetType == 'native') ? 'XLM' : (op.assetCode ?? 'ASSET');
      amount = double.tryParse(op.amount);
      from = op.from;
      to = op.to;
    } else if (op is stellar.PathPaymentStrictReceiveOperationResponse) {
      assetCode = (op.assetType == 'native') ? 'XLM' : (op.assetCode ?? 'ASSET');
      amount = double.tryParse(op.amount);
      from = op.from;
      to = op.to;
    } else if (op is stellar.CreateAccountOperationResponse) {
      assetCode = 'XLM';
      amount = double.tryParse(op.startingBalance ?? '');
      from = op.funder;
      to = op.account;
    } else {
      return null;
    }

    final hash = op.transactionHash ?? '';
    final id = '${op.pagingToken ?? hash}';
    final createdAt = op.createdAt;
    final ts = _safeParseMillis(createdAt);
    final isIncoming = (to != null && to == myAddr);

    return <String, dynamic>{
      'id': id,
      'hash': hash,
      'timestamp': ts,
      'asset': assetCode ?? 'ASSET',
      'amount': amount ?? 0.0,
      'from': from ?? '',
      'to': to ?? '',
      'direction': isIncoming ? 'in' : 'out',
      'recName': null,
      'recColor': null,
    };
  }

  bool _isAccountMissingError(Object e) {
    try {
      final dynamic x = e;
      final int? code = x.response?.statusCode as int?;
      final String? body = x.response?.body as String?;
      if (code == 404) return true;
      if (body != null &&
          (body.contains('Resource Missing') ||
              body.contains('"title":"Resource Missing"') ||
              body.contains('not_found'))) {
        return true;
      }
    } catch (_) {}
    final s = e.toString();
    return s.contains('404') || s.contains('Resource Missing') || s.contains('not_found');
  }

  int? _safeParseMillis(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    try { return DateTime.parse(iso).millisecondsSinceEpoch; } catch (_) { return null; }
  }
}
