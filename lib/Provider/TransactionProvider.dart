import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as stellar;

import 'package:next_fi/Services/stellar/stellar_wallet_services.dart';

typedef Tx = Map<String, dynamic>;

enum TxFilter { all, receive, send }

class TransactionsProvider extends ChangeNotifier {
  TransactionsProvider({required StellarWalletService stellarSvc})
      : _stellar = stellarSvc;

  final StellarWalletService _stellar;

  // Bound address from WalletHomeProvider (G...)
  String? address;

  // UI state
  bool loading = true;
  bool loadingMore = false;
  bool hasMore = true;
  String? errorMsg;
  bool accountMissing = false; // unfunded

  // Paging
  final int _limit = 20;
  String? _cursor;
  int _fetchGen = 0;

  // Data
  final List<Tx> _txs = <Tx>[];
  List<Tx> get txs => List.unmodifiable(_txs);
  final Set<String> _seenIds = <String>{};

  // Incoming events for UI chips/toasts
  final StreamController<Tx> _incomingController = StreamController<Tx>.broadcast();
  Stream<Tx> get incomingStream => _incomingController.stream;

  // SSE subscription
  StreamSubscription<stellar.PaymentOperationResponse>? _incomingSub;

  // Filter
  TxFilter filter = TxFilter.all;
  List<Tx> get visibleTxs {
    switch (filter) {
      case TxFilter.receive:
        return _txs.where((t) => (t['direction'] ?? 'other') == 'in').toList();
      case TxFilter.send:
        return _txs.where((t) => (t['direction'] ?? 'other') == 'out').toList();
      case TxFilter.all:
      default:
        return _txs;
    }
  }

  bool get isTestnet => _stellar.isTestnet ?? identical(_stellar.sdk, stellar.StellarSDK.TESTNET);

  // ───────────────── Bind to active wallet address (from WalletHomeProvider)
  void bindToAddress(String? newAddr) {
    final addr = (newAddr ?? '').trim();
    if (addr.isEmpty) {
      // No active wallet → clear
      if (address != null) {
        address = null;
        _clearAll();
        loading = false;
        errorMsg = 'No wallet found. Please import or create a wallet.';
        notifyListeners();
      }
      return;
    }

    if (address == addr) return; // no-op if unchanged

    address = addr;
    _restartForNewAddress();
  }

  void _restartForNewAddress() {
    stop(); // cancel old SSE
    _clearAll();
    loading = true;
    errorMsg = null;
    notifyListeners();

    // kick initial fetch then subscribe
    scheduleMicrotask(() async {
      await fetch(loadMore: false);
      _subscribeIncomingIfReady();
    });
  }

  // ───────────────── Public API
  void setFilter(TxFilter v) {
    if (filter == v) return;
    filter = v;
    notifyListeners();
  }

  Future<void> resetAndFetch() async {
    _cursor = null;
    hasMore = true;
    await fetch(loadMore: false);
  }

  Future<void> fetch({required bool loadMore}) async {
    final addr = address;
    if (addr == null || addr.isEmpty) {
      loading = false;
      errorMsg ??= 'No wallet found. Please import or create a wallet.';
      notifyListeners();
      return;
    }

    final myToken = ++_fetchGen;

    if (loadMore) {
      if (!hasMore || loadingMore) return;
      loadingMore = true;
    } else {
      loading = true;
      errorMsg = null;
      if (_txs.isEmpty) _cursor = null; // fresh list
    }
    notifyListeners();

    try {
      final builder = _stellar.sdk.payments
          .forAccount(addr)
          .order(stellar.RequestBuilderOrder.DESC)
          .limit(_limit);

      if (loadMore && _cursor != null && _cursor!.isNotEmpty) {
        builder.cursor(_cursor!);
      }

      final page = await builder.execute();
      final ops = page.records;

      final newTx = <Tx>[];
      for (final op in ops) {
        final tx = _opToTx(op, addr);
        if (tx != null) newTx.add(tx);
      }

      // stale response guard
      if (myToken != _fetchGen) return;

      if (loadMore) {
        _txs.addAll(newTx);
      } else {
        _txs
          ..clear()
          ..addAll(newTx);
        _seenIds
          ..clear()
          ..addAll(newTx.map((t) => (t['id'] ?? '').toString()).where((s) => s.isNotEmpty));
      }

      if (ops.isNotEmpty) _cursor = ops.last.pagingToken;
      hasMore = ops.length == _limit;
      accountMissing = false;
      errorMsg = null;
    } catch (e) {
      if (myToken != _fetchGen) return;
      if (_isAccountMissingError(e)) {
        accountMissing = true;
        _txs.clear();
        hasMore = false;
        errorMsg = null;
      } else {
        errorMsg = 'Error fetching history: $e';
      }
    } finally {
      loading = false;
      loadingMore = false;
      notifyListeners();
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

  // ───────────────── Internals
  void _clearAll() {
    _cursor = null;
    hasMore = true;
    _txs.clear();
    _seenIds.clear();
    accountMissing = false;
  }

  void _subscribeIncomingIfReady() {
    final addr = address;
    if (addr == null || addr.isEmpty || accountMissing) return;

    _incomingSub?.cancel();

    _incomingSub = _stellar.paymentsStream(addr).listen((op) {
      final tx = _opToTx(op, addr);
      if (tx == null) return;

      final id = (tx['id'] ?? '').toString();
      if (id.isEmpty || _seenIds.contains(id)) return;

      _seenIds.add(id);
      _txs.insert(0, tx);
      _incomingController.add(tx); // UI can show chip/toast
      notifyListeners();
    }, onError: (_) {
      // Silent; pull-to-refresh remains available
    });
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
      // Not emitted by paymentsStream, but we normalize just in case
      assetCode = 'XLM';
      amount = double.tryParse(op.startingBalance ?? '');
      from = op.funder;
      to = op.account;
    } else {
      return null; // ignore other ops
    }

    final hash = op.transactionHash ?? '';
    final id = '${op.pagingToken ?? hash}';
    final createdAt = op.createdAt; // ISO8601
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
    try {
      return DateTime.parse(iso).millisecondsSinceEpoch;
    } catch (_) {
      return null;
    }
  }
}
