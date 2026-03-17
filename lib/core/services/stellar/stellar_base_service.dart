// stellar_base_service.dart
import 'dart:async';

import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

/// User-friendly error with actionable advice
class StellarWalletError implements Exception {
  final String message;
  final String? technicalDetails;
  final String? advice;
  final String? code;

  StellarWalletError(
    this.message, {
    this.technicalDetails,
    this.advice,
    this.code,
  });

  @override
  String toString() {
    final parts = [message];
    if (advice != null) parts.add('\n$advice');
    return parts.join();
  }

  String toDetailedString() {
    final parts = [message];
    if (advice != null) parts.add('Advice: $advice');
    if (technicalDetails != null) parts.add('Details: $technicalDetails');
    if (code != null) parts.add('Code: $code');
    return parts.join('\n');
  }
}

/// Callback for progress updates during operations
typedef ProgressCallback = void Function(String message);

/// Base class for all Stellar services
abstract class StellarBaseService {
  final StellarSDK sdk;

  /// Private QuickNode SDK (fallback)
  final StellarSDK? _sdkQuickNode;

  final String? quickNodeUrlMainnet;
  final String? quickNodeUrlTestnet;
  final Map<String, String>? quickNodeDefaultHeaders;

  StellarBaseService({
    required this.sdk,
    StellarSDK? sdkQuickNode,
    this.quickNodeUrlMainnet,
    this.quickNodeUrlTestnet,
    this.quickNodeDefaultHeaders,
  }) : _sdkQuickNode = sdkQuickNode;

  /// ✅ Protected getter for subclasses
  StellarSDK? get quickNodeSdk => _sdkQuickNode;

  bool get isTestnet => identical(sdk, StellarSDK.TESTNET);

  Network get network => isTestnet ? Network.TESTNET : Network.PUBLIC;

  String get horizonBase => isTestnet
      ? 'https://horizon-testnet.stellar.org'
      : 'https://horizon.stellar.org';

  String? get _qnBase => isTestnet ? quickNodeUrlTestnet : quickNodeUrlMainnet;

  // ──────────────────────────────────────────────────────────────────────────
  // Error Helpers
  // ──────────────────────────────────────────────────────────────────────────

  static String fmt7(num v) => v.toStringAsFixed(7);

  Never fail(
    String userMessage, {
    Object? technicalError,
    String? advice,
    String? code,
  }) {
    throw StellarWalletError(
      userMessage,
      technicalDetails: technicalError?.toString(),
      advice: advice,
      code: code,
    );
  }

  String getUserFriendlyTxError(String code, List<String>? ops) {
    switch (code) {
      case 'tx_insufficient_balance':
        return 'Not enough funds to complete this transaction';
      case 'tx_bad_seq':
        return 'Transaction timed out';
      case 'tx_insufficient_fee':
        return 'Network fee was too low';
      case 'tx_no_account':
        return 'Account not found on the network';
      case 'tx_failed':
        if (ops != null) {
          if (ops.contains('op_underfunded')) {
            return 'Insufficient balance in your account';
          }
          if (ops.contains('op_no_trust')) {
            return 'Recipient hasn\'t added this asset yet';
          }
          if (ops.contains('op_line_full')) {
            return 'Recipient\'s account is at maximum capacity for this asset';
          }
          if (ops.contains('op_no_destination')) {
            return 'Recipient account doesn\'t exist';
          }
        }
        return 'Transaction could not be completed';
      case 'tx_too_late':
        return 'Transaction expired - took too long to process';
      case 'tx_too_early':
        return 'Transaction submitted too early';
      default:
        return 'Transaction failed';
    }
  }

  String? getTxErrorAdvice(String code, List<String>? ops) {
    switch (code) {
      case 'tx_insufficient_balance':
        return 'Check your balance and try sending a smaller amount';
      case 'tx_bad_seq':
        return 'Please wait a moment and try again. This happens when multiple transactions are sent at once';
      case 'tx_insufficient_fee':
        return 'The app will automatically use the correct fee when you try again';
      case 'tx_no_account':
        return 'Make sure you\'re connected to the correct network (mainnet or testnet)';
      case 'tx_failed':
        if (ops != null) {
          if (ops.contains('op_underfunded')) {
            return 'You need more funds to complete this transaction, including network fees';
          }
          if (ops.contains('op_no_trust')) {
            return 'Ask the recipient to add this asset to their wallet first';
          }
          if (ops.contains('op_line_full')) {
            return 'The recipient needs to reduce their balance of this asset before receiving more';
          }
          if (ops.contains('op_no_destination')) {
            return 'The recipient needs to create their Stellar account first';
          }
        }
        return 'Please check your transaction details and try again';
      case 'tx_too_late':
      case 'tx_too_early':
        return 'Please try again - the network timing will be adjusted automatically';
      default:
        return 'If this problem continues, please contact support';
    }
  }

  Never failSubmit(
    SubmitTransactionResponse res, {
    String prefix = 'Transaction failed',
  }) {
    final code = res.extras?.resultCodes?.transactionResultCode ?? 'unknown';

    final ops = res.extras?.resultCodes?.operationsResultCodes;

    final hash = res.hash;

    final userMessage = getUserFriendlyTxError(code, ops?.cast<String>());

    final technicalDetails =
        'Code: $code'
        '${ops != null ? ', Operations: ${ops.join(", ")}' : ''}'
        '${hash != null ? ', Hash: $hash' : ''}';

    final advice = getTxErrorAdvice(code, ops?.cast<String>());

    throw StellarWalletError(
      userMessage,
      technicalDetails: technicalDetails,
      advice: advice,
      code: code,
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // HTTP with fallback
  // ──────────────────────────────────────────────────────────────────────────

  Future<dynamic> getWithFallback(
    String path, {
    Map<String, String>? query,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final primary = Uri.parse(
      '$horizonBase$path',
    ).replace(queryParameters: query);

    try {
      final r = await sdk.httpClient.get(primary).timeout(timeout);

      if (r.statusCode == 200) return r;

      if (r.statusCode == 429 || (r.statusCode >= 500 && r.statusCode <= 599)) {
        final fr = await _tryQuickNode(path, query: query, timeout: timeout);
        if (fr != null) return fr;
      }

      return r;
    } catch (_) {
      final fr = await _tryQuickNode(path, query: query, timeout: timeout);
      if (fr != null) return fr;
      rethrow;
    }
  }

  Future<dynamic> _tryQuickNode(
    String path, {
    Map<String, String>? query,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final base = _qnBase;
    if (base == null || base.isEmpty) return null;

    final uri = Uri.parse('$base$path').replace(queryParameters: query);

    try {
      if (_sdkQuickNode != null) {
        return await _sdkQuickNode.httpClient.get(uri).timeout(timeout);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // SSE Stream with Fallback
  // ──────────────────────────────────────────────────────────────────────────

  Stream<T> sseWithFallback<T>(Stream<T> Function(StellarSDK s) build) {
    final controller = StreamController<T>();
    StreamSubscription<T>? sub;
    Timer? retryTimer;
    bool usingQuickNode = false;
    bool closed = false;
    int retryAttempt = 0;
    late Future<void> Function(StellarSDK s) start;

    Duration nextRetryDelay() {
      final seconds = switch (retryAttempt) {
        0 => 1,
        1 => 2,
        2 => 4,
        3 => 8,
        _ => 15,
      };
      retryAttempt += 1;
      return Duration(seconds: seconds);
    }

    Future<void> scheduleRetry() async {
      if (closed) return;
      retryTimer?.cancel();
      try {
        await sub?.cancel();
      } catch (_) {}
      sub = null;
      usingQuickNode = false;
      retryTimer = Timer(nextRetryDelay(), () {
        if (closed) return;
        unawaited(start(sdk));
      });
    }

    start = (StellarSDK s) async {
      if (closed) return;
      try {
        final stream = build(s);
        sub = stream.listen(
          (event) {
            retryAttempt = 0;
            controller.add(event);
          },
          onError: (e, st) async {
            if (!usingQuickNode &&
                _sdkQuickNode != null &&
                !identical(s, _sdkQuickNode)) {
              usingQuickNode = true;

              try {
                await sub?.cancel();
              } catch (_) {}

              await start(_sdkQuickNode);
            } else {
              await scheduleRetry();
            }
          },
          onDone: () async {
            await scheduleRetry();
          },
        );
      } catch (e) {
        if (!usingQuickNode &&
            _sdkQuickNode != null &&
            !identical(s, _sdkQuickNode)) {
          usingQuickNode = true;
          await start(_sdkQuickNode);
        } else {
          await scheduleRetry();
        }
      }
    };

    unawaited(start(sdk));

    controller.onCancel = () async {
      closed = true;
      retryTimer?.cancel();
      try {
        await sub?.cancel();
      } catch (_) {}
    };

    return controller.stream;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Utilities
  // ──────────────────────────────────────────────────────────────────────────

  int toStroops(double amount) => (amount * 1e7).round();

  double fromStroops(int stroops) => stroops / 1e7;

  String toClassicAccountId(String addr) {
    final a = addr.trim();

    if (a.isEmpty) {
      fail(
        'Please enter a valid Stellar address',
        code: 'EMPTY_ADDRESS',
        advice: 'Stellar addresses start with "G" and are 56 characters long',
      );
    }

    if (a.startsWith('G') && a.length >= 56) {
      return a;
    }

    if (a.startsWith('M')) {
      fail(
        'This address format isn\'t supported yet',
        technicalError: 'Muxed address (M...) provided',
        advice:
            'Please use a standard Stellar address (starts with "G") and add a memo if needed',
        code: 'MUXED_ADDRESS',
      );
    }

    fail(
      'This doesn\'t look like a valid Stellar address',
      technicalError: 'Invalid format: $a',
      advice:
          'Stellar addresses start with "G" and are 56 characters long. Please check and try again',
      code: 'INVALID_ADDRESS',
    );
  }

  Future<AccountResponse> loadAccount(String accountId) async {
    try {
      return await sdk.accounts.account(accountId);
    } catch (e) {
      fail(
        'Unable to load account information',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }

  Future<bool> accountExists(String accountId) async {
    try {
      await sdk.accounts.account(accountId);
      return true;
    } catch (e) {
      final msg = e.toString().toLowerCase();
      final isNotFound =
          msg.contains('404') ||
          msg.contains('not found') ||
          msg.contains('resource missing');
      if (isNotFound) return false;
      fail(
        'Unable to verify destination account',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
        code: 'ACCOUNT_CHECK_FAILED',
      );
    }
  }
}
