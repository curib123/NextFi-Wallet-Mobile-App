// lib/features/transactions/model/transactions_state.dart
import 'package:next_fi/features/transactions/data/models/tx.dart';

class TransactionsState {
  final String? address;

  // UI state
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final String? errorMsg;
  final bool accountMissing;

  // Paging
  final String? cursor;

  // Data
  final List<Tx> txs;

  // Filter
  final TxFilter filter;

  const TransactionsState({
    this.address,
    this.loading = true,
    this.loadingMore = false,
    this.hasMore = true,
    this.errorMsg,
    this.accountMissing = false,
    this.cursor,
    this.txs = const <Tx>[],
    this.filter = TxFilter.all,
  });

  List<Tx> get visibleTxs {
    switch (filter) {
      case TxFilter.receive:
        return txs.where((t) => (t['direction'] ?? 'other') == 'in').toList();
      case TxFilter.send:
        return txs.where((t) => (t['direction'] ?? 'other') == 'out').toList();
      case TxFilter.all:
        return txs;
    }
  }

  TransactionsState copyWith({
    String? address,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    String? errorMsg,
    bool? accountMissing,
    String? cursor,
    List<Tx>? txs,
    TxFilter? filter,
  }) {
    return TransactionsState(
      address: address ?? this.address,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
      errorMsg: errorMsg,
      accountMissing: accountMissing ?? this.accountMissing,
      cursor: cursor ?? this.cursor,
      txs: txs ?? this.txs,
      filter: filter ?? this.filter,
    );
  }
}
