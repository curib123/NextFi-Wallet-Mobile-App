// stellar_stream_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:next_fi/core/services/stellar/soroban_rpc.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'package:next_fi/core/services/stellar/stellar_base_service.dart';
import 'package:next_fi/core/services/stellar/stellar_fee_service.dart';
import 'package:next_fi/core/services/stellar/wallet_models.dart';


/// Service for real-time streaming data
class StellarStreamService extends StellarBaseService {
  final String usdcIssuer;
  final StellarFeeService feeService;
  final SorobanRpc? soroban;

  StellarStreamService({
    required this.usdcIssuer,
    required this.feeService,
    required super.sdk,
    super.sdkQuickNode,
    this.soroban,
    super.quickNodeUrlMainnet,
    super.quickNodeUrlTestnet,
    super.quickNodeDefaultHeaders,
  });

  Asset get xlm => Asset.NATIVE;
  Asset get usdc => AssetTypeCreditAlphaNum4('USDC', usdcIssuer);

  String _assetKey(Asset asset) => AccountState.assetKeyForAsset(asset);

  void _putAssetQuery(
    Map<String, String> query,
    Asset asset, {
    required String role,
  }) {
    if (asset is AssetTypeNative) {
      query['${role}_asset_type'] = 'native';
      return;
    }
    if (asset is AssetTypeCreditAlphaNum) {
      query['${role}_asset_type'] = 'credit_alphanum${asset.code.length}';
      query['${role}_asset_code'] = asset.code;
      query['${role}_asset_issuer'] = asset.issuerId;
    }
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // Payment Streams
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // Account State Stream
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Stream<AccountState> accountStateStream(String accountId) {
    final controller = StreamController<AccountState>();
    Timer? coolDown;
    bool closed = false;

    Future<void> emitSnapshot() async {
      if (closed) return;
      try {
        final acc = await loadAccount(accountId);
        final balancesByAssetKey = <String, double>{};
        final trustlinesByAssetKey = <String, bool>{};

        for (final b in acc.balances) {
          if (b.assetType == Asset.TYPE_NATIVE) {
            balancesByAssetKey[AccountState.nativeAssetKey] =
                double.tryParse(b.balance) ?? 0.0;
            continue;
          }

          final assetCode = b.assetCode;
          if (assetCode == null || assetCode.isEmpty) continue;

          balancesByAssetKey[assetCode] = double.tryParse(b.balance) ?? 0.0;
          trustlinesByAssetKey[assetCode] = true;

          if (b.limit != null && b.limit!.isNotEmpty) {
            final limit = double.tryParse(b.limit!);
            if (limit != null && limit <= 0) {
              trustlinesByAssetKey[assetCode] = false;
            }
          }
        }

        controller.add(AccountState(
          balancesByAssetKey: balancesByAssetKey,
          trustlinesByAssetKey: trustlinesByAssetKey,
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
        s.payments.forAccount(accountId).cursor("now").stream().map((_) {});
    Stream<void> effStream(StellarSDK s) =>
        s.effects.forAccount(accountId).cursor("now").stream().map((_) {});

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

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // Fee Estimate Stream
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
        s.ledgers.cursor("now").stream().map((_) {});

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

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // Price Streams
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Stream<PairPrice> assetPairPriceStream({
    required Asset baseAsset,
    required Asset counterAsset,
  }) {
    Stream<PairPrice> build(StellarSDK s) {
      final tradesBuilder = s.trades;
      _putAssetQuery(
        tradesBuilder.queryParameters,
        baseAsset,
        role: 'base',
      );
      _putAssetQuery(
        tradesBuilder.queryParameters,
        counterAsset,
        role: 'counter',
      );

      return tradesBuilder.cursor('now').stream().map((t) {
        double? price;
        final ba = double.tryParse(t.baseAmount);
        final ca = double.tryParse(t.counterAmount);

        if (ba != null && ba > 0 && ca != null && ca > 0) {
          price = ca / ba;
        }

        price ??= double.tryParse('${t.price}');

        if (price != null && price > 0) {
          return PairPrice(
            baseAssetKey: _assetKey(baseAsset),
            counterAssetKey: _assetKey(counterAsset),
            counterPerBase: price,
            at: DateTime.now(),
          );
        }
        throw StateError('Invalid trade price');
      });
    }

    return sseWithFallback<PairPrice>(build);
  }

  Stream<double> quoteStrictSendStream({
    required Asset sourceAsset,
    required Asset destinationAsset,
    required double sendAmount,
  }) => assetPairPriceStream(
    baseAsset: sourceAsset,
    counterAsset: destinationAsset,
  ).map((p) => sendAmount * p.counterPerBase);

  Stream<PairPrice> xlmUsdcPriceStream() =>
      assetPairPriceStream(baseAsset: xlm, counterAsset: usdc);

  Stream<double> quoteXlmToUsdcStream(double sendAmountXlm) =>
      quoteStrictSendStream(
        sourceAsset: xlm,
        destinationAsset: usdc,
        sendAmount: sendAmountXlm,
      );

  Stream<double> quoteUsdcToXlmStream(double sendAmountUsdc) =>
      assetPairPriceStream(baseAsset: usdc, counterAsset: xlm).map(
        (p) => sendAmountUsdc * p.counterPerBase,
      );
}
