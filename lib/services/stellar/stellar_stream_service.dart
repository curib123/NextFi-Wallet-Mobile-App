// stellar_stream_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:next_fi/services/stellar/soroban_rpc.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'package:next_fi/services/stellar/stellar_base_service.dart';
import 'package:next_fi/services/stellar/stellar_fee_service.dart';
import 'package:next_fi/services/stellar/wallet_models.dart';


/// Service for real-time streaming data
class StellarStreamService extends StellarBaseService {
  final String usdcIssuer;
  final StellarFeeService feeService;
  final SorobanRpc? soroban;

  StellarStreamService({
    required this.usdcIssuer,
    required this.feeService,
    required StellarSDK sdk,
    StellarSDK? sdkQuickNode,
    this.soroban,
    String? quickNodeUrlMainnet,
    String? quickNodeUrlTestnet,
    Map<String, String>? quickNodeDefaultHeaders,
  }) : super(
    sdk: sdk,
    sdkQuickNode: sdkQuickNode,
    quickNodeUrlMainnet: quickNodeUrlMainnet,
    quickNodeUrlTestnet: quickNodeUrlTestnet,
    quickNodeDefaultHeaders: quickNodeDefaultHeaders,
  );

  Asset get xlm => Asset.NATIVE;
  Asset get usdc => AssetTypeCreditAlphaNum4('USDC', usdcIssuer);

  // ──────────────────────────────────────────────────────────────────────────
  // Payment Streams
  // ──────────────────────────────────────────────────────────────────────────

  Stream<PaymentOperationResponse> paymentsStream(String accountId) {
    Stream<PaymentOperationResponse> build(StellarSDK s) {
      return s.payments
          .forAccount(accountId)
          .cursor("now")
          .stream()
          .where((resp) =>
      resp is PaymentOperationResponse && resp.transactionSuccessful)
          .cast<PaymentOperationResponse>();
    }

    return sseWithFallback<PaymentOperationResponse>(build);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Account State Stream
  // ──────────────────────────────────────────────────────────────────────────

  Stream<AccountState> accountStateStream(String accountId) {
    final controller = StreamController<AccountState>();
    Timer? coolDown;
    bool closed = false;

    Future<void> emitSnapshot() async {
      if (closed) return;
      try {
        final acc = await loadAccount(accountId);
        double xlm = 0, usdc = 0;
        bool tl = false;

        for (final b in acc.balances) {
          if (b.assetType == Asset.TYPE_NATIVE) {
            xlm = double.parse(b.balance);
          }
          if (b.assetCode == 'USDC' && b.assetIssuer == usdcIssuer) {
            usdc = double.parse(b.balance);
            tl = true;
          }
        }

        controller.add(AccountState(
          xlm: xlm,
          usdc: usdc,
          hasUsdcTrustline: tl,
          updatedAt: DateTime.now(),
        ));
      } catch (e, st) {
        if (!closed) {
          controller.addError(e, st);
        }
      }
    }

    emitSnapshot();

    Stream<void> payStream(StellarSDK s) =>
        s.payments.forAccount(accountId).cursor("now").stream().map((_) => null);
    Stream<void> effStream(StellarSDK s) =>
        s.effects.forAccount(accountId).cursor("now").stream().map((_) => null);

    final pay = sseWithFallback<void>(payStream).listen(
          (_) {
        coolDown?.cancel();
        coolDown = Timer(const Duration(milliseconds: 250), emitSnapshot);
      },
      onError: (e, st) {
        if (!closed) controller.addError(e, st);
      },
    );

    final eff = sseWithFallback<void>(effStream).listen(
          (_) {
        coolDown?.cancel();
        coolDown = Timer(const Duration(milliseconds: 250), emitSnapshot);
      },
      onError: (e, st) {
        if (!closed) controller.addError(e, st);
      },
    );

    controller.onCancel = () async {
      closed = true;
      coolDown?.cancel();
      await pay.cancel();
      await eff.cancel();
    };

    return controller.stream;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Fee Estimate Stream
  // ──────────────────────────────────────────────────────────────────────────

  Stream<FeeEstimate> feeEstimateStream({
    int opCount = 1,
    int percentile = 90,
  }) {
    final controller = StreamController<FeeEstimate>();
    int? lastSorobanLedger;

    Future<void> push(DateTime at) async {
      try {
        final x = await feeService.estimateNetworkFeeXlm(
            opCount: opCount, percentile: percentile);

        int base = 100;
        try {
          final resp = await getWithFallback(
            '/fee_stats',
            timeout: const Duration(seconds: 6),
          );
          if (resp.statusCode == 200) {
            final data = json.decode(resp.body) as Map<String, dynamic>;
            base =
                int.tryParse('${data['last_ledger_base_fee'] ?? '100'}') ?? 100;
          }
        } catch (_) {}

        final ops = opCount <= 0 ? 1 : opCount;
        final perOp = (x * 1e7 / ops).round();
        final total = (x * 1e7).round();

        controller.add(FeeEstimate(
          perOpStroops: perOp,
          totalStroops: total,
          totalXlm: x,
          baseFee: base,
          opCount: ops,
          percentile: percentile.clamp(10, 99),
          ledgerClosedAt: at,
        ));
      } catch (e, st) {
        controller.addError(e, st);
      }
    }

    push(DateTime.now());

    Stream<void> ledgerStream(StellarSDK s) =>
        s.ledgers.cursor("now").stream().map((_) => null);

    final ledSub = sseWithFallback<void>(ledgerStream).listen(
          (_) => push(DateTime.now()),
      onError: controller.addError,
      onDone: controller.close,
    );

    Timer? sorobanTicker;
    if (soroban != null) {
      sorobanTicker = Timer.periodic(const Duration(seconds: 8), (_) async {
        try {
          final seq = await soroban!.getLatestLedgerSequence();
          if (seq == null) return;
          if (lastSorobanLedger == null || seq > lastSorobanLedger!) {
            lastSorobanLedger = seq;
            await push(DateTime.now());
          }
        } catch (_) {}
      });
    }

    controller.onCancel = () async {
      sorobanTicker?.cancel();
      await ledSub.cancel();
    };

    return controller.stream;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Price Streams
  // ──────────────────────────────────────────────────────────────────────────

  Stream<PairPrice> xlmUsdcPriceStream() {
    Stream<PairPrice> build(StellarSDK s) {
      final tradesBuilder = s.trades;
      tradesBuilder.queryParameters['base_asset_type'] = 'native';
      tradesBuilder.queryParameters['counter_asset_type'] = 'credit_alphanum4';
      tradesBuilder.queryParameters['counter_asset_code'] = 'USDC';
      tradesBuilder.queryParameters['counter_asset_issuer'] = usdcIssuer;

      return tradesBuilder.cursor('now').stream().map((t) {
        double? price;
        final ba = double.tryParse('${t.baseAmount}');
        final ca = double.tryParse('${t.counterAmount}');

        if (ba != null && ba > 0 && ca != null && ca > 0) {
          price = ca / ba;
        }

        price ??= double.tryParse('${t.price}');

        if (price != null && price > 0) {
          return PairPrice(price, DateTime.now());
        }
        throw StateError('Invalid trade price');
      });
    }

    return sseWithFallback<PairPrice>(build);
  }

  Stream<double> quoteXlmToUsdcStream(double sendAmountXlm) =>
      xlmUsdcPriceStream().map((p) => sendAmountXlm * p.usdcPerXlm);

  Stream<double> quoteUsdcToXlmStream(double sendAmountUsdc) =>
      xlmUsdcPriceStream().map((p) => sendAmountUsdc * p.xlmPerUsdc);
}