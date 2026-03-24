import 'dart:async';
import 'dart:convert';

import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

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

typedef ProgressCallback = void Function(String message);

class _KnownIssue {
  const _KnownIssue({
    required this.message,
    required this.advice,
    this.code,
  });

  final String message;
  final String advice;
  final String? code;
}

abstract class StellarBaseService {
  final StellarSDK sdk;

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

  StellarSDK? get quickNodeSdk => _sdkQuickNode;

  bool get isTestnet => identical(sdk, StellarSDK.TESTNET);

  Network get network => isTestnet ? Network.TESTNET : Network.PUBLIC;

  String get horizonBase => isTestnet
      ? 'https://horizon-testnet.stellar.org'
      : 'https://horizon.stellar.org';

  String? get _qnBase => isTestnet ? quickNodeUrlTestnet : quickNodeUrlMainnet;

  static String fmt7(num v) => v.toStringAsFixed(7);

  void validateMemoText(String? memoText) {
    final memo = memoText?.trim();
    if (memo == null || memo.isEmpty) return;
    final length = utf8.encode(memo).length;
    if (length > 28) {
      fail(
        'The memo is too long',
        technicalError: 'Memo length: $length bytes',
        advice: 'Use a shorter memo. Stellar text memos can be up to 28 bytes.',
        code: 'MEMO_TOO_LONG',
      );
    }
  }

  Never fail(
    String userMessage, {
    Object? technicalError,
    String? advice,
    String? code,
  }) {
    final raw = technicalError?.toString();
    final known = raw == null ? null : _detectKnownIssue(raw);
    final resolvedMessage =
        known != null && _looksGenericMessage(userMessage)
        ? known.message
        : userMessage;
    final resolvedAdvice =
        known != null && (advice == null || _looksGenericAdvice(advice))
        ? known.advice
        : advice;
    final resolvedCode = code ?? known?.code;
    throw StellarWalletError(
      resolvedMessage,
      technicalDetails: technicalError?.toString(),
      advice: resolvedAdvice,
      code: resolvedCode,
    );
  }

  String getUserFriendlyTxError(String code, List<String>? ops) {
    switch (code) {
      case 'tx_insufficient_balance':
        return 'Not enough funds to complete this transaction';
      case 'tx_bad_seq':
        return 'Another transaction was submitted too recently';
      case 'tx_insufficient_fee':
        return 'Network fee was too low';
      case 'tx_no_account':
        return 'Account not found on the network';
      case 'tx_bad_auth':
      case 'tx_bad_auth_extra':
        return 'This wallet could not authorize the transaction';
      case 'tx_missing_operation':
        return 'The transaction was missing a required operation';
      case 'tx_too_late':
        return 'Transaction expired before the network accepted it';
      case 'tx_too_early':
        return 'Transaction was submitted before it became valid';
      case 'tx_failed':
        if (ops != null) {
          if (ops.contains('op_underfunded')) {
            return 'Insufficient balance in your account';
          }
          if (ops.contains('op_no_trust')) {
            return 'Recipient hasn\'t added this asset yet';
          }
          if (ops.contains('op_no_issuer')) {
            return 'This asset issuer is not available on Stellar';
          }
          if (ops.contains('op_line_full')) {
            return 'Recipient\'s account is at maximum capacity for this asset';
          }
          if (ops.contains('op_low_reserve')) {
            return 'Not enough XLM reserve to complete this action';
          }
          if (ops.contains('op_not_authorized')) {
            return 'This asset is not authorized for this wallet';
          }
          if (ops.contains('op_not_authorized_to_maintain_liabilities')) {
            return 'This asset cannot maintain its current obligations';
          }
          if (ops.contains('op_offer_cross_self')) {
            return 'This trade would match your own offer';
          }
          if (ops.contains('op_no_issuer')) {
            return 'This asset is no longer issued on Stellar';
          }
          if (ops.contains('op_no_trust')) {
            return 'A required trustline is missing';
          }
          if (ops.contains('op_no_destination')) {
            return 'Recipient account doesn\'t exist';
          }
          if (ops.contains('op_src_no_trust')) {
            return 'Your wallet is missing the required trustline';
          }
          if (ops.contains('op_src_not_authorized')) {
            return 'Your wallet is not authorized to use this asset';
          }
          if (ops.contains('op_invalid_limit')) {
            return 'The asset trustline limit is invalid';
          }
          if (ops.contains('op_claimable_balance_does_not_exist')) {
            return 'That claimable payment no longer exists';
          }
          if (ops.contains('op_claimant_not_the_destination')) {
            return 'This wallet is not allowed to claim that payment';
          }
          if (ops.contains('op_cannot_create')) {
            return 'The recipient wallet cannot be created with this amount';
          }
        }
        return 'Transaction could not be completed';
      default:
        return 'Transaction failed';
    }
  }

  String? getTxErrorAdvice(String code, List<String>? ops) {
    switch (code) {
      case 'tx_insufficient_balance':
        return 'Check your balance and try sending a smaller amount';
      case 'tx_bad_seq':
        return 'Refresh the wallet and try again. This usually happens when another transaction was submitted just before this one.';
      case 'tx_insufficient_fee':
        return 'The app will automatically use the correct fee when you try again';
      case 'tx_no_account':
        return 'Make sure you\'re connected to the correct network (mainnet or testnet)';
      case 'tx_bad_auth':
      case 'tx_bad_auth_extra':
        return 'Reopen the wallet session and try again. If this keeps happening, reload your wallet keys.';
      case 'tx_missing_operation':
        return 'Please try again. The transaction payload was incomplete.';
      case 'tx_failed':
        if (ops != null) {
          if (ops.contains('op_underfunded')) {
            return 'You need more funds to complete this transaction, including network fees';
          }
          if (ops.contains('op_no_trust')) {
            return 'Ask the recipient to add this asset to their wallet first';
          }
          if (ops.contains('op_src_no_trust')) {
            return 'Add the required asset trustline to your wallet, then try again.';
          }
          if (ops.contains('op_line_full')) {
            return 'The recipient needs to reduce their balance of this asset before receiving more';
          }
          if (ops.contains('op_low_reserve')) {
            return 'Add more XLM to cover Stellar reserve requirements and network fees.';
          }
          if (ops.contains('op_no_issuer')) {
            return 'This asset may have been delisted or the issuer is unavailable. Please check the asset details.';
          }
          if (ops.contains('op_not_authorized') ||
              ops.contains('op_src_not_authorized')) {
            return 'This asset requires authorization from the issuer before it can be used.';
          }
          if (ops.contains('op_no_destination')) {
            return 'The recipient needs to create their Stellar account first';
          }
          if (ops.contains('op_claimable_balance_does_not_exist')) {
            return 'Refresh the claimable payments list. This payment may already be claimed or removed.';
          }
          if (ops.contains('op_claimant_not_the_destination')) {
            return 'Use the wallet that was originally listed as a claimant for this payment.';
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

  bool _looksGenericMessage(String value) {
    final text = value.trim().toLowerCase();
    return text.startsWith('unable to') ||
        text.startsWith('transaction failed') ||
        text.startsWith('swap failed') ||
        text.startsWith('payment failed') ||
        text.startsWith('failed to ');
  }

  bool _looksGenericAdvice(String value) {
    final text = value.trim().toLowerCase();
    return text.contains('check your internet connection') ||
        text.contains('please try again') ||
        text.contains('contact support');
  }

  _KnownIssue? _detectKnownIssue(String raw) {
    final text = raw.toLowerCase();

    if (text.contains('socketexception') ||
        text.contains('connection closed') ||
        text.contains('connection reset') ||
        text.contains('failed host lookup') ||
        text.contains('network is unreachable')) {
      return const _KnownIssue(
        message: 'The app could not reach the Stellar network',
        advice: 'Check your internet connection, then try again.',
        code: 'NETWORK_UNREACHABLE',
      );
    }
    if (text.contains('timeout') || text.contains('timed out')) {
      return const _KnownIssue(
        message: 'The Stellar network took too long to respond',
        advice: 'Please try again in a moment.',
        code: 'NETWORK_TIMEOUT',
      );
    }
    if (text.contains('429') || text.contains('rate limit')) {
      return const _KnownIssue(
        message: 'The Stellar service is busy right now',
        advice: 'Wait a moment, then try again.',
        code: 'RATE_LIMITED',
      );
    }
    if (text.contains('503') ||
        text.contains('502') ||
        text.contains('500') ||
        text.contains('bad gateway')) {
      return const _KnownIssue(
        message: 'The Stellar service is temporarily unavailable',
        advice: 'Please try again shortly.',
        code: 'SERVICE_UNAVAILABLE',
      );
    }
    if (text.contains('account not found') ||
        text.contains('op_no_destination') ||
        text.contains('tx_no_account')) {
      return const _KnownIssue(
        message: 'The destination Stellar account does not exist yet',
        advice: 'Ask the recipient to activate their wallet with XLM first.',
        code: 'DESTINATION_NOT_FOUND',
      );
    }
    if (text.contains('muxed address') || text.contains('invalid format')) {
      return const _KnownIssue(
        message: 'That Stellar address is not valid',
        advice: 'Use a classic Stellar address that starts with G and is 56 characters long.',
        code: 'INVALID_ADDRESS',
      );
    }
    if (text.contains('no trustline') ||
        text.contains('op_no_trust') ||
        text.contains('op_src_no_trust')) {
      return const _KnownIssue(
        message: 'A required trustline is missing',
        advice: 'Add the asset trustline first, then try again.',
        code: 'TRUSTLINE_MISSING',
      );
    }
    if (text.contains('line_full') || text.contains('op_line_full')) {
      return const _KnownIssue(
        message: 'This wallet cannot hold more of that asset right now',
        advice: 'Reduce the existing balance or free reserve, then try again.',
        code: 'TRUSTLINE_LIMIT_REACHED',
      );
    }
    if (text.contains('low reserve') || text.contains('op_low_reserve')) {
      return const _KnownIssue(
        message: 'Not enough XLM reserve to complete this action',
        advice: 'Add more XLM to cover Stellar reserve and fees.',
        code: 'LOW_RESERVE',
      );
    }
    if (text.contains('underfunded') || text.contains('insufficient_balance')) {
      return const _KnownIssue(
        message: 'Your wallet balance is too low for this action',
        advice: 'Reduce the amount or add more funds, including XLM for fees.',
        code: 'INSUFFICIENT_BALANCE',
      );
    }
    if (text.contains('not_authorized')) {
      return const _KnownIssue(
        message: 'This asset is not authorized for this wallet',
        advice: 'The asset issuer may require approval before you can hold or send it.',
        code: 'NOT_AUTHORIZED',
      );
    }
    if (text.contains('no_issuer')) {
      return const _KnownIssue(
        message: 'This asset issuer is not available',
        advice: 'The asset may no longer be supported or issued on Stellar.',
        code: 'NO_ISSUER',
      );
    }
    if (text.contains('claimable_balance_does_not_exist') ||
        text.contains('already been claimed')) {
      return const _KnownIssue(
        message: 'That claimable payment is no longer available',
        advice: 'Refresh the list. It may already be claimed or removed.',
        code: 'CLAIMABLE_BALANCE_MISSING',
      );
    }
    if (text.contains('claimant_not_the_destination')) {
      return const _KnownIssue(
        message: 'This wallet is not allowed to claim that payment',
        advice: 'Use the wallet that was originally set as the claimant.',
        code: 'INVALID_CLAIMANT',
      );
    }
    if (text.contains('tx_bad_seq')) {
      return const _KnownIssue(
        message: 'Another transaction was submitted too recently',
        advice: 'Wait a moment, refresh, and try again.',
        code: 'BAD_SEQUENCE',
      );
    }
    if (text.contains('memo') && text.contains('long')) {
      return const _KnownIssue(
        message: 'The memo is too long',
        advice: 'Use a shorter memo and try again.',
        code: 'MEMO_TOO_LONG',
      );
    }
    return null;
  }

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

  Stream<T> sseWithFallback<T>(Stream<T> Function(StellarSDK s) build) {
    final controller = StreamController<T>();
    StreamSubscription<T>? sub;
    Timer? retryTimer;
    bool usingQuickNode = false;
    bool closed = false;
    int retryAttempt = 0;
    String? lastErrorKey;
    DateTime? lastErrorAt;
    int repeatedErrorCount = 0;
    late Future<void> Function(StellarSDK s) start;

    Duration nextRetryDelay() {
      final seconds = switch (retryAttempt) {
        0 => 2,
        1 => 4,
        2 => 8,
        3 => 15,
        4 => 30,
        _ => 45,
      };
      retryAttempt += 1;
      return Duration(seconds: seconds);
    }

    bool shouldForwardError(Object error) {
      final key = '${error.runtimeType}:${error.toString()}';
      final now = DateTime.now();
      final sameError =
          lastErrorKey == key &&
          lastErrorAt != null &&
          now.difference(lastErrorAt!) < const Duration(seconds: 45);

      if (sameError) {
        repeatedErrorCount += 1;
      } else {
        repeatedErrorCount = 1;
      }

      lastErrorKey = key;
      lastErrorAt = now;

      final isEventSourceSubscription =
          error.runtimeType.toString() == 'EventSourceSubscriptionException' ||
          error.toString().contains('EventSourceSubscriptionException');

      if (!isEventSourceSubscription) return true;
      if (repeatedErrorCount <= 2) return true;
      return repeatedErrorCount % 10 == 0;
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

    Future<void> handleFailure(
      StellarSDK activeSdk,
      Object error, [
      StackTrace? stackTrace,
    ]) async {
      if (closed) return;
      if (!usingQuickNode &&
          _sdkQuickNode != null &&
          !identical(activeSdk, _sdkQuickNode)) {
        usingQuickNode = true;

        try {
          await sub?.cancel();
        } catch (_) {}

        sub = null;
        await start(_sdkQuickNode);
        return;
      }

      if (!controller.isClosed && shouldForwardError(error)) {
        controller.addError(error, stackTrace);
      }
      await scheduleRetry();
    }

    start = (StellarSDK s) async {
      if (closed) return;
      await runZonedGuarded(
        () async {
          final stream = build(s);
          sub = stream.listen(
            (event) {
              retryAttempt = 0;
              repeatedErrorCount = 0;
              lastErrorKey = null;
              lastErrorAt = null;
              controller.add(event);
            },
            onError: (e, st) async {
              await handleFailure(s, e, st);
            },
            onDone: () async {
              await scheduleRetry();
            },
          );
        },
        (error, stackTrace) async {
          await handleFailure(s, error, stackTrace);
        },
      );
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
