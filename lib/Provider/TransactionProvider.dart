// lib/Provider/TransactionsProvider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as stellar;

import 'package:next_fi/Services/seed_storage.dart';
import 'package:next_fi/Services/stellar/stellar_wallet_services.dart';

typedef Tx = Map<String, dynamic>;

enum TxFilter { all, receive, send }

class TransactionsProvider extends ChangeNotifier {
  TransactionsProvider({StellarWalletService? stellarSvc})
      : _stellar = stellarSvc ?? StellarWalletService();

  final StellarWalletService _stellar;

  String? address; // G...
  bool loading = true;
  bool loadingMore = false;
  bool hasMore = true;
  String? errorMsg;
  bool accountMissing = false; // unfunded

  final int _limit = 20;
  String? _cursor;
  int _fetchGen = 0;

  final List<Tx> _txs = <Tx>[];
  List<Tx> get txs => List.unmodifiable(_txs);

  final Set<String> _seenIds = <String>{};

  // Incoming payment stream for UI (chips, toasts, etc.)
  final StreamController<Tx> _incomingController = StreamController<Tx>.broadcast();
  Stream<Tx> get incomingStream => _incomingController.stream;

  // Use our service’s stream (event-driven; no polling)
  StreamSubscription<stellar.PaymentOperationResponse>? _incomingSub;

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

  bool get isTestnet => identical(_stellar.sdk, stellar.StellarSDK.TESTNET);

  // ----- Lifecycle from UI -----
  Future<void> start() async {
    await _loadWallet();
    await fetch(loadMore: false);
    _subscribeIncomingIfReady();
  }

  void stop() {
    _incomingSub?.cancel();
    _incomingSub = null;
  }

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
      loadingMore = true;
    } else {
      loading = true;
      errorMsg = null;
      _cursor = null;
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

      if (myToken != _fetchGen) return; // late response

      // merge
      if (loadMore) {
        _txs.addAll(newTx);
      } else {
        _txs
          ..clear()
          ..addAll(newTx);
        _seenIds.clear();
      }
      for (final t in newTx) {
        final id = (t['id'] ?? '').toString();
        if (id.isNotEmpty) _seenIds.add(id);
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

  // ----- Internals -----
  Future<void> _loadWallet() async {
    // Try both APIs to be compatible with single- or multi-wallet storage
    String? mnemonic;
    try {
      mnemonic = await SeedStorage.getActiveSeed();
    } catch (_) {}
    mnemonic ??= await SeedStorage.getSeed();

    if (mnemonic == null || mnemonic.trim().isEmpty) {
      address = null;
      loading = false;
      errorMsg = 'No wallet found. Please import or create a wallet.';
      notifyListeners();
      return;
    }

    final wallet = await StellarWalletService.walletFromMnemonic(mnemonic);
    final kp = await StellarWalletService.getKeyPair(wallet, index: 0);
    address = kp.accountId;
    notifyListeners();
  }

  void _subscribeIncomingIfReady() {
    final addr = address;
    if (addr == null || addr.isEmpty || accountMissing) return;

    _incomingSub?.cancel();

    // Use the service’s paymentsStream (filters to successful payment-like ops)
    _incomingSub = _stellar
        .paymentsStream(addr)
        .listen((op) {
      final tx = _opToTx(op, addr);
      if (tx == null) return;

      final id = (tx['id'] ?? '').toString();
      if (id.isEmpty || _seenIds.contains(id)) return;

      _seenIds.add(id);
      _txs.insert(0, tx);
      _incomingController.add(tx); // notify UI for chip/toast
      notifyListeners();
    }, onError: (_) {
      // Silent; user can pull-to-refresh
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
      // Note: create_account won't arrive on paymentsStream (we still get it via fetch)
      assetCode = 'XLM';
      amount = double.tryParse(op.startingBalance ?? '');
      from = op.funder;
      to = op.account;
    } else {
      return null; // ignore non-payment ops
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

  @override
  void dispose() {
    stop();
    _incomingController.close();
    super.dispose();
  }
}
