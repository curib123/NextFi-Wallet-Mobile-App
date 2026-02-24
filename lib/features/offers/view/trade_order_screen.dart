import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/snackbar/SnackBar.dart';
import 'package:next_fi/reusable_view_model/seed_keypair_vm.dart';
import 'package:next_fi/services/offers/models/offers_dtos.dart';
import 'package:next_fi/services/offers/models/offers_models.dart';
import 'package:next_fi/services/reviews/models/reviews_dtos.dart';
import 'package:next_fi/services/reviews/reviews_core_service.dart';
import 'package:next_fi/services/stellar/stellar_wallet_services.dart';
import 'package:next_fi/services/trades/models/trades_models.dart';
import 'package:next_fi/services/trades/trades_core_service.dart';
import 'package:provider/provider.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

class TradeOrderScreen extends StatefulWidget {
  const TradeOrderScreen({
    super.key,
    required this.trade,
    required this.offer,
  });

  final TradeModel trade;
  final OfferModel offer;

  @override
  State<TradeOrderScreen> createState() => _TradeOrderScreenState();
}

class _TradeOrderScreenState extends State<TradeOrderScreen>
    with WidgetsBindingObserver {
  final _tradesCore = TradesCoreService.I;

  late TradeModel _trade;
  bool _refreshing = false;
  bool _actionLoading = false;
  String? _actionError;

  // Connectivity
  bool _isOnline = true;
  late final StreamSubscription<List<ConnectivityResult>> _connectivitySub;

  // Countdown timer
  Timer? _countdownTimer;
  Duration _timeLeft = Duration.zero;

  // Auto-refresh polling (every 30 s while trade is active)
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _trade = widget.trade;
    WidgetsBinding.instance.addObserver(this);
    _startConnectivityMonitor();
    _startCountdown();
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub.cancel();
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  // ── App lifecycle: refresh on foreground resume ──────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _trade.status.isActive) {
      _refresh(silent: true);
    }
  }

  // ── Connectivity ─────────────────────────────────────────────────────────────

  void _startConnectivityMonitor() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (!mounted) return;
      final wasOffline = !_isOnline;
      setState(() => _isOnline = online);
      // Auto-retry when connection comes back
      if (online && wasOffline && _trade.status.isActive) {
        _refresh(silent: true);
      }
    });
  }

  // ── Countdown timer ──────────────────────────────────────────────────────────

  void _startCountdown() {
    final expires = _trade.expiresAt;
    if (expires == null) {
      // Compute from createdAt + paymentWindowMinutes
      final created = _trade.createdAt;
      final window = _trade.paymentWindowMinutes;
      if (created != null && window != null) {
        final computed = created.add(Duration(minutes: window));
        _updateTimeLeft(computed);
      }
      return;
    }
    _updateTimeLeft(expires);
  }

  void _updateTimeLeft(DateTime deadline) {
    final left = deadline.difference(DateTime.now());
    setState(() => _timeLeft = left.isNegative ? Duration.zero : left);
    if (_timeLeft > Duration.zero) {
      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final updated = deadline.difference(DateTime.now());
        setState(() => _timeLeft = updated.isNegative ? Duration.zero : updated);
        if (_timeLeft == Duration.zero) _countdownTimer?.cancel();
      });
    }
  }

  // ── Polling ──────────────────────────────────────────────────────────────────

  void _startPolling() {
    if (!_trade.status.isActive) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_trade.status.isActive) {
        _refresh(silent: true);
      } else {
        _pollTimer?.cancel();
      }
    });
  }

  // ── Refresh ──────────────────────────────────────────────────────────────────

  Future<void> _refresh({bool silent = false}) async {
    if (_refreshing) return;
    if (!silent) setState(() => _refreshing = true);
    try {
      final updated = await _tradesCore.getOne(_trade.id);
      if (!mounted) return;
      setState(() {
        _trade = updated;
        _refreshing = false;
        if (!_trade.status.isActive) _pollTimer?.cancel();
      });
      _startCountdown();
    } catch (_) {
      if (!mounted) return;
      if (!silent) setState(() => _refreshing = false);
    }
  }

  // ── Actions ──────────────────────────────────────────────────────────────────

  Future<void> _markFiatSent() async {
    final confirmed = await _showConfirm(
      title: 'Confirm payment sent',
      body: 'Have you sent the fiat payment? This action cannot be undone.',
      confirmLabel: 'Yes, I sent it',
    );
    if (!confirmed) return;
    _runAction(() async {
      // Optionally attach proof of payment before marking sent
      final proofFile = await _showProofPickSheet();
      if (proofFile != null) {
        await _tradesCore.uploadProof(_trade.id, file: proofFile, type: 'FIAT');
      }
      final updated = await _tradesCore.markFiatSent(_trade.id);
      if (mounted) setState(() => _trade = updated);
    }, successMsg: 'Payment marked as sent');
  }

  Future<void> _confirmFiat() async {
    final confirmed = await _showConfirm(
      title: 'Confirm fiat received',
      body: 'Have you received the fiat payment from the buyer?',
      confirmLabel: 'Yes, I received it',
    );
    if (!confirmed) return;
    _runAction(() async {
      final updated = await _tradesCore.confirmFiat(_trade.id);
      if (mounted) setState(() => _trade = updated);
    }, successMsg: 'Trade completed');
  }

  Future<void> _cancelTrade() async {
    final confirmed = await _showConfirm(
      title: 'Cancel trade',
      body: 'Are you sure you want to cancel this trade? The escrow will be released back.',
      confirmLabel: 'Cancel trade',
      isDestructive: true,
    );
    if (!confirmed) return;
    _runAction(() async {
      final updated = await _tradesCore.cancelTrade(_trade.id, reason: 'User cancelled');
      if (mounted) setState(() => _trade = updated);
    }, successMsg: 'Trade cancelled');
  }

  // Lock crypto into escrow — only shown for BUY offers where user is the seller
  Future<void> _lockCrypto() async {
    final confirmed = await _showConfirm(
      title: 'Lock Crypto in Escrow',
      body: 'Your crypto will be locked in a Stellar Claimable Balance. '
            'The merchant can claim it after confirming your payment.',
      confirmLabel: 'Lock Crypto',
    );
    if (!confirmed) return;
    _runAction(() async {
      final stellarSvc = context.read<StellarWalletServices>();
      final seedVM = context.read<SeedKeypairVM>();
      final kp = await seedVM.deriveKeyPair();

      final asset = _trade.asset.toUpperCase() == 'XLM'
          ? Asset.NATIVE
          : AssetTypeCreditAlphaNum4('USDC', stellarSvc.usdcIssuer);

      final merchantAddress = (_trade.offer?['seller']?['walletAddress'] ??
                               _trade.offer?['seller']?['stellarAddress'] ??
                               '').toString();
      if (merchantAddress.isEmpty) {
        throw Exception('Merchant Stellar address not available. Contact support.');
      }

      final expiry = _trade.expiresAt ?? DateTime.now().add(const Duration(hours: 24));

      final createTxHash = await stellarSvc.claimableBalanceService
          .createUnconditionalWithExpiry(
        keyPair: kp,
        asset: asset,
        amount: _trade.cryptoAmount,
        recipientId: merchantAddress,
        expiryTime: expiry,
      );

      // Fetch the Claimable Balance ID from the transaction's operations
      final ops = await stellarSvc.sdk.operations
          .forTransaction(createTxHash)
          .execute();
      final cbOp = ops.records.whereType<CreateClaimableBalanceOperationResponse>()
          .firstOrNull;
      final cbId = cbOp?.claimants;
      if (cbId == null) {
        throw Exception('Could not retrieve Claimable Balance ID from transaction.');
      }

      final updated = await _tradesCore.lockCrypto(
        _trade.id,
        claimableBalanceId: cbId.toString(),
        createTxHash: createTxHash,
      );
      if (mounted) setState(() => _trade = updated);
    }, successMsg: 'Crypto locked in escrow');
  }

  // Claim crypto from escrow — only shown for SELL offers where user is the buyer
  Future<void> _claimCrypto() async {
    final cbId = _trade.escrow?.claimableBalanceId;
    if (cbId == null) {
      showFloatingSnackBar(context,
          message: 'Escrow balance ID not available. Refresh and try again.',
          type: SnackBarType.error);
      return;
    }
    final confirmed = await _showConfirm(
      title: 'Claim Your Crypto',
      body: 'This will claim ${_trade.cryptoAmount.toStringAsFixed(7)} '
            '${_trade.asset} to your wallet.',
      confirmLabel: 'Claim Crypto',
    );
    if (!confirmed) return;
    _runAction(() async {
      final stellarSvc = context.read<StellarWalletServices>();
      final seedVM = context.read<SeedKeypairVM>();
      final kp = await seedVM.deriveKeyPair();
      final claimTxHash = await stellarSvc.claimableBalanceService
          .claimClaimableBalance(keyPair: kp, balanceId: cbId);
      final updated = await _tradesCore.claimCrypto(
        _trade.id,
        claimTxHash: claimTxHash,
      );
      if (mounted) setState(() => _trade = updated);
    }, successMsg: 'Crypto claimed to your wallet');
  }

  // Refund expired escrow — only the original locker (user in BUY offer) can reclaim
  Future<void> _refundCrypto() async {
    final cbId = _trade.escrow?.claimableBalanceId;
    if (cbId == null) {
      showFloatingSnackBar(context,
          message: 'No escrow to refund.',
          type: SnackBarType.error);
      return;
    }
    final confirmed = await _showConfirm(
      title: 'Refund Escrow',
      body: 'The trade has expired. Reclaim your crypto back to your wallet.',
      confirmLabel: 'Refund',
    );
    if (!confirmed) return;
    _runAction(() async {
      final stellarSvc = context.read<StellarWalletServices>();
      final seedVM = context.read<SeedKeypairVM>();
      final kp = await seedVM.deriveKeyPair();
      final refundTxHash = await stellarSvc.claimableBalanceService
          .claimClaimableBalance(keyPair: kp, balanceId: cbId);
      final updated = await _tradesCore.refundCrypto(
        _trade.id,
        refundTxHash: refundTxHash,
      );
      if (mounted) setState(() => _trade = updated);
    }, successMsg: 'Crypto refunded to your wallet');
  }

  // Open a dispute
  Future<void> _openDispute() async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DisputeSheet(c: AppColor.of(context)),
    );
    if (reason == null || reason.isEmpty) return;
    _runAction(() async {
      final updated = await _tradesCore.openDispute(_trade.id, reason: reason);
      if (mounted) setState(() => _trade = updated);
    }, successMsg: 'Dispute opened. Support will contact you.');
  }

  // Proof picker sheet — returns File or null (skip)
  Future<File?> _showProofPickSheet() async {
    final c = AppColor.of(context);
    final pick = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProofPickSheet(c: c),
    );
    if (pick != true) return null;
    final result = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (result == null) return null;
    return File(result.path);
  }

  Future<void> _runAction(
    Future<void> Function() action, {
    required String successMsg,
  }) async {
    setState(() { _actionLoading = true; _actionError = null; });
    try {
      await action();
      if (mounted) {
        showFloatingSnackBar(context, message: successMsg, type: SnackBarType.success);
      }
    } catch (e) {
      if (!mounted) return;
      String msg = e.toString();
      if (msg.contains('TradeApiException')) {
        msg = msg.replaceAll(RegExp(r'TradeApiException\(\d+\): '), '');
      }
      setState(() => _actionError = msg);
      showFloatingSnackBar(context, message: msg, type: SnackBarType.error);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<bool> _showConfirm({
    required String title,
    required String body,
    required String confirmLabel,
    bool isDestructive = false,
  }) async {
    final c = AppColor.of(context);
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ConfirmSheet(
        c: c,
        title: title,
        body: body,
        confirmLabel: confirmLabel,
        isDestructive: isDestructive,
      ),
    );
    return result ?? false;
  }

  // ── Navigation guard ─────────────────────────────────────────────────────────

  Future<bool> _onWillPop() async {
    if (!_trade.status.isActive) return true;
    final c = AppColor.of(context);
    final leave = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmSheet(
        c: c,
        title: 'Leave trade room?',
        body: 'Your trade is still active. You can return to it from the Trade History.',
        confirmLabel: 'Leave',
        isDestructive: false,
      ),
    );
    return leave ?? false;
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final offer = widget.offer;
    final isBuy = offer.type == OfferType.sell; // user is buyer if offer type is sell

    return PopScope(
      canPop: !_trade.status.isActive,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && _trade.status.isActive) {
          final leave = await _onWillPop();
          if (leave && context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          backgroundColor: c.background,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleSpacing: 20,
          title: Text(
            'Trade Room',
            style: TextStyle(
              color: c.textPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          actions: [
            if (_refreshing)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: c.primary,
                  ),
                ),
              )
            else if (_trade.status.isActive)
              IconButton(
                icon: Icon(Icons.refresh_rounded, color: c.textSecondary),
                tooltip: 'Refresh',
                onPressed: () => _refresh(),
              ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          color: c.primary,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            children: [
              // ── Connectivity banner ──────────────────────────────────
              if (!_isOnline) _ConnectivityBanner(c: c),

              // ── Status hero ──────────────────────────────────────────
              _StatusHero(c: c, trade: _trade, isBuy: isBuy),
              const SizedBox(height: 14),

              // ── Timer (if active and has deadline) ───────────────────
              if (_trade.status.isActive && _timeLeft > Duration.zero) ...[
                _CountdownCard(c: c, timeLeft: _timeLeft),
                const SizedBox(height: 14),
              ],

              // ── Trade details ────────────────────────────────────────
              _TradeDetailsCard(c: c, trade: _trade, offer: offer, isBuy: isBuy),
              const SizedBox(height: 14),

              // ── Escrow tracking ──────────────────────────────────────
              if (_trade.escrow != null) ...[
                _EscrowCard(c: c, escrow: _trade.escrow!),
                const SizedBox(height: 14),
              ],

              // ── Payment instructions (for buyer, if crypto is locked) ────
              if (isBuy && _trade.status == TradeStatus.cryptoLocked) ...[
                _PaymentInstructionsCard(c: c, trade: _trade),
                const SizedBox(height: 14),
              ],

              // ── Status timeline ──────────────────────────────────────
              _StatusTimeline(c: c, status: _trade.status, isBuy: isBuy),
              const SizedBox(height: 14),

              // ── Action error ─────────────────────────────────────────
              if (_actionError != null) ...[
                _ErrorBanner(c: c, message: _actionError!),
                const SizedBox(height: 10),
              ],

              // ── App resume notice ────────────────────────────────────
              if (_trade.status.isActive) ...[
                _ResumeSafetyNote(c: c),
                const SizedBox(height: 14),
              ],

              // ── Completed / cancelled state ──────────────────────────
              if (_trade.status == TradeStatus.completed)
                _CompletedCard(c: c, trade: _trade),
              if (_trade.status == TradeStatus.cancelled)
                _CancelledCard(c: c),
            ],
          ),
        ),
        bottomNavigationBar: _BottomActions(
          c: c,
          trade: _trade,
          isBuy: isBuy,
          loading: _actionLoading,
          onLockCrypto: _lockCrypto,
          onMarkFiatSent: _markFiatSent,
          onConfirmFiat: _confirmFiat,
          onClaimCrypto: _claimCrypto,
          onCancel: _cancelTrade,
          onDispute: _openDispute,
          onRefund: _refundCrypto,
        ),
      ),
    );
  }
}

// ─── Connectivity banner ───────────────────────────────────────────────────────

class _ConnectivityBanner extends StatelessWidget {
  const _ConnectivityBanner({required this.c});
  final AppColor c;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: c.warning.withOpacity(0.12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: c.warning.withOpacity(0.3)),
    ),
    child: Row(
      children: [
        Icon(Icons.wifi_off_rounded, color: c.warning, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No internet connection',
                style: TextStyle(color: c.warning, fontWeight: FontWeight.w700, fontSize: 13),
              ),
              Text(
                'Your trade is safe. Updates will resume when connection is restored.',
                style: TextStyle(color: c.warning.withOpacity(0.8), fontSize: 11.5),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ─── Status hero ───────────────────────────────────────────────────────────────

class _StatusHero extends StatelessWidget {
  const _StatusHero({required this.c, required this.trade, required this.isBuy});
  final AppColor c;
  final TradeModel trade;
  final bool isBuy;

  Color _getStatusColor(TradeStatus status) {
    switch (status) {
      case TradeStatus.created:
        return const Color(0xFFFAA040); // Orange - waiting
      case TradeStatus.cryptoLocked:
        return const Color(0xFF5B8DEF); // Blue - ready to pay
      case TradeStatus.fiatSent:
        return const Color(0xFFFAA040); // Orange - awaiting confirmation
      case TradeStatus.fiatConfirmed:
        return const Color(0xFF00C48C); // Green - confirmed
      case TradeStatus.completed:
        return const Color(0xFF00C48C); // Green
      case TradeStatus.cancelled:
        return const Color(0xFFFF5C72); // Red
      case TradeStatus.disputed:
        return const Color(0xFFFF5C72); // Red
      case TradeStatus.expired:
        return const Color(0xFF9CA3AF); // Gray
      case TradeStatus.unknown:
        return const Color(0xFF9CA3AF);
    }
  }

  IconData _getStatusIcon(TradeStatus status) {
    switch (status) {
      case TradeStatus.created:
        return Icons.hourglass_empty_rounded;
      case TradeStatus.cryptoLocked:
        return Icons.lock_clock_rounded;
      case TradeStatus.fiatSent:
        return Icons.pending_rounded;
      case TradeStatus.fiatConfirmed:
        return Icons.check_circle_outline_rounded;
      case TradeStatus.completed:
        return Icons.check_circle_rounded;
      case TradeStatus.cancelled:
        return Icons.cancel_rounded;
      case TradeStatus.disputed:
        return Icons.report_rounded;
      case TradeStatus.expired:
        return Icons.schedule_rounded;
      case TradeStatus.unknown:
        return Icons.help_outline_rounded;
    }
  }

  String _getStatusLabel(TradeStatus status, bool isBuy) {
    switch (status) {
      case TradeStatus.created:
        return 'Waiting for Escrow';
      case TradeStatus.cryptoLocked:
        return isBuy ? 'Ready to Pay' : 'Escrow Funded - Awaiting Payment';
      case TradeStatus.fiatSent:
        return isBuy ? 'Payment Sent - Awaiting Confirmation' : 'Payment Sent';
      case TradeStatus.fiatConfirmed:
        return 'Payment Confirmed';
      case TradeStatus.completed:
        return 'Trade Completed';
      case TradeStatus.cancelled:
        return 'Trade Cancelled';
      case TradeStatus.disputed:
        return 'Under Dispute';
      case TradeStatus.expired:
        return 'Trade Expired';
      case TradeStatus.unknown:
        return 'Unknown Status';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor(trade.status);
    final icon = _getStatusIcon(trade.status);
    final label = _getStatusLabel(trade.status, isBuy);

    // Show auto-dispute trigger if present
    final showDisputeBanner = trade.status == TradeStatus.disputed && 
                              trade.autoDisputeTrigger != null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Trade ID: ${trade.id.length > 14 ? '${trade.id.substring(0, 10)}...' : trade.id}',
                      style: TextStyle(color: c.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: trade.id));
                  showFloatingSnackBar(context, message: 'Trade ID copied', type: SnackBarType.success);
                },
                child: Icon(Icons.copy_rounded, size: 16, color: c.textSecondary.withOpacity(0.5)),
              ),
            ],
          ),
          if (showDisputeBanner) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: c.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: c.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Auto-dispute: ${trade.autoDisputeTrigger}',
                      style: TextStyle(color: c.error, fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Countdown card ────────────────────────────────────────────────────────────

class _CountdownCard extends StatelessWidget {
  const _CountdownCard({required this.c, required this.timeLeft});
  final AppColor c;
  final Duration timeLeft;

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isUrgent = timeLeft.inMinutes < 5;
    final color = isUrgent ? c.error : c.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_rounded, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Payment window',
              style: TextStyle(color: c.textSecondary, fontSize: 13),
            ),
          ),
          Text(
            _fmt(timeLeft),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Trade details card ────────────────────────────────────────────────────────

class _TradeDetailsCard extends StatelessWidget {
  const _TradeDetailsCard({
    required this.c,
    required this.trade,
    required this.offer,
    required this.isBuy,
  });
  final AppColor c;
  final TradeModel trade;
  final OfferModel offer;
  final bool isBuy;

  @override
  Widget build(BuildContext context) {
    return _Card(
      c: c,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(c: c, icon: Icons.receipt_long_rounded, label: 'Trade Details'),
          const SizedBox(height: 14),
          _Row(c: c, label: 'Asset', value: trade.asset),
          _Row(c: c, label: 'Fiat currency', value: trade.fiatCurrency),
          _Row(c: c, label: isBuy ? 'You pay' : 'You receive', value: '${trade.fiatAmount.toStringAsFixed(2)} ${trade.fiatCurrency}'),
          _Row(c: c, label: isBuy ? 'You receive' : 'You send', value: '${trade.cryptoAmount.toStringAsFixed(7)} ${trade.asset}'),
          _Row(
            c: c,
            label: isBuy ? 'Receiving address' : 'Sending address',
            value: trade.cryptoReceiverAddress,
            copyable: true,
            isLast: trade.cryptoReceiverMemo == null,
          ),
          if (trade.cryptoReceiverMemo != null)
            _Row(c: c, label: 'Memo', value: trade.cryptoReceiverMemo!, copyable: true, isLast: true),
        ],
      ),
    );
  }
}

// ─── Payment instructions (for buyer in ESCROW_FUNDED state) ──────────────────

class _PaymentInstructionsCard extends StatelessWidget {
  const _PaymentInstructionsCard({required this.c, required this.trade});
  final AppColor c;
  final TradeModel trade;

  @override
  Widget build(BuildContext context) {
    final spa = trade.sellerPaymentAccount;
    final accountName = spa?['accountName']?.toString();
    final accountNo = spa?['accountNo']?.toString();
    final instructions = spa?['instructions']?.toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF5B8DEF).withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF5B8DEF).withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.send_rounded, size: 16, color: Color(0xFF5B8DEF)),
            const SizedBox(width: 8),
            Text(
              'Send payment to:',
              style: TextStyle(
                color: c.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          if (accountName != null)
            _Row(c: c, label: 'Account name', value: accountName, copyable: true),
          if (accountNo != null)
            _Row(c: c, label: 'Account no.', value: accountNo, copyable: true),
          if (instructions != null && instructions.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              instructions,
              style: TextStyle(color: c.textSecondary, fontSize: 12.5, height: 1.4),
            ),
          ],
          if (accountName == null && accountNo == null)
            Text(
              'Contact the merchant for payment details via the trade chat.',
              style: TextStyle(color: c.textSecondary, fontSize: 12.5),
            ),
        ],
      ),
    );
  }
}

// ─── Escrow card ───────────────────────────────────────────────────────────────

class _EscrowCard extends StatelessWidget {
  const _EscrowCard({required this.c, required this.escrow});
  final AppColor c;
  final TradeEscrowModel escrow;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (escrow.status?.toString()) {
      'FUNDED' || 'ACTIVE' => const Color(0xFF00C48C),
      'RELEASED' => const Color(0xFF5B8DEF),
      'CANCELLED' || 'FAILED' => const Color(0xFFFF5C72),
      _ => const Color(0xFFFAA040),
    };

    return _Card(
      c: c,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CardHeader(c: c, icon: Icons.lock_rounded, label: 'Escrow'),
              const Spacer(),
              if (escrow.status != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: statusColor.withOpacity(0.2)),
                  ),
                  child: Text(
                    escrow.status!.toString(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (escrow.claimableBalanceId != null)
            _Row(
              c: c,
              label: 'Balance ID',
              value: escrow.claimableBalanceId!.length > 20
                  ? '${escrow.claimableBalanceId!.substring(0, 10)}...${escrow.claimableBalanceId!.substring(escrow.claimableBalanceId!.length - 8)}'
                  : escrow.claimableBalanceId!,
              copyable: true,
              fullCopyValue: escrow.claimableBalanceId,
            ),
          if (escrow.txHash != null)
            _Row(
              c: c,
              label: 'Tx hash',
              value: escrow.txHash!.length > 20
                  ? '${escrow.txHash!.substring(0, 10)}...${escrow.txHash!.substring(escrow.txHash!.length - 8)}'
                  : escrow.txHash!,
              copyable: true,
              fullCopyValue: escrow.txHash,
              isLast: true,
            ),
        ],
      ),
    );
  }
}

// ─── Status timeline ───────────────────────────────────────────────────────────

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.c, required this.status, required this.isBuy});
  final AppColor c;
  final TradeStatus status;
  final bool isBuy;

  // Get timeline steps based on offer type (BUY vs SELL)
  List<(TradeStatus, String, String)> _getSteps(bool isBuy) {
    if (isBuy) {
      // BUY flow: user is buying crypto, pays fiat, receives crypto
      return [
        (TradeStatus.created, 'Trade Created', 'Waiting for merchant to lock crypto in escrow'),
        (TradeStatus.cryptoLocked, 'Crypto Locked', 'Crypto is in escrow — send your fiat payment'),
        (TradeStatus.fiatSent, 'Payment Sent', 'Waiting for merchant to confirm receipt'),
        (TradeStatus.fiatConfirmed, 'Payment Confirmed', 'Merchant confirmed — claim your crypto'),
        (TradeStatus.completed, 'Completed', 'Crypto has been released to your wallet'),
      ];
    } else {
      // SELL flow: user is selling crypto, receives fiat, locks crypto
      return [
        (TradeStatus.created, 'Trade Created', 'Waiting for you to lock crypto in escrow'),
        (TradeStatus.cryptoLocked, 'Crypto Locked', 'Crypto is in escrow — buyer will send fiat'),
        (TradeStatus.fiatSent, 'Payment Received', 'Merchant sent fiat — confirm you received it'),
        (TradeStatus.fiatConfirmed, 'Payment Confirmed', 'You confirmed — merchant will now claim crypto'),
        (TradeStatus.completed, 'Completed', 'Crypto released to buyer'),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = _getSteps(isBuy);
    
    final statusOrder = [
      TradeStatus.created,
      TradeStatus.cryptoLocked,
      TradeStatus.fiatSent,
      TradeStatus.fiatConfirmed,
      TradeStatus.completed,
    ];

    // Handle unknown status
    final currentIdx = statusOrder.contains(status) 
        ? statusOrder.indexOf(status) 
        : -1;

    // Check for terminal states
    final isCancelled = status == TradeStatus.cancelled;
    final isDisputed = status == TradeStatus.disputed;
    final isExpired = status == TradeStatus.expired;

    return _Card(
      c: c,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(c: c, icon: Icons.linear_scale_rounded, label: 'Progress'),
          const SizedBox(height: 16),
          ...steps.asMap().entries.map((e) {
            final i = e.key;
            final step = e.value;
            final stepStatus = step.$1;
            final stepIdx = statusOrder.indexOf(stepStatus);

            final isCompleted = status == TradeStatus.completed;
            final isDone = currentIdx > stepIdx || isCompleted;
            final isCurrent = stepIdx == currentIdx && status.isActive;
            final isSkipped = isCancelled || isDisputed || isExpired;

            Color dotColor;
            IconData dotIcon;
            if (isSkipped && stepIdx > 0) {
              dotColor = c.textSecondary.withOpacity(0.3);
              dotIcon = Icons.remove_rounded;
            } else if (isDone) {
              dotColor = const Color(0xFF00C48C);
              dotIcon = Icons.check_rounded;
            } else if (isCurrent) {
              dotColor = c.primary;
              dotIcon = Icons.circle_rounded;
            } else {
              dotColor = c.border.withOpacity(0.4);
              dotIcon = Icons.circle_outlined;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: dotColor.withOpacity(isCurrent ? 0.15 : 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: dotColor, width: isCurrent ? 2 : 1.5),
                        ),
                        child: Icon(dotIcon, size: 14, color: dotColor),
                      ),
                      if (i < steps.length - 1)
                        Container(
                          width: 2,
                          height: 28,
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          color: isDone
                              ? const Color(0xFF00C48C).withOpacity(0.3)
                              : c.border.withOpacity(0.2),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.$2,
                            style: TextStyle(
                              color: isCurrent || isDone ? c.textPrimary : c.textSecondary,
                              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            step.$3,
                            style: TextStyle(color: c.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Resume safety note ────────────────────────────────────────────────────────

class _ResumeSafetyNote extends StatelessWidget {
  const _ResumeSafetyNote({required this.c});
  final AppColor c;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: c.border.withOpacity(0.15)),
    ),
    child: Row(
      children: [
        Icon(Icons.info_outline_rounded, size: 15, color: c.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'If you leave the app, your trade stays active. Return here to continue.',
            style: TextStyle(color: c.textSecondary, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

// ─── Error banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.c, required this.message});
  final AppColor c;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: c.error.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: c.error.withOpacity(0.25)),
    ),
    child: Row(
      children: [
        Icon(Icons.error_outline_rounded, color: c.error, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message, style: TextStyle(color: c.error, fontSize: 12.5)),
        ),
      ],
    ),
  );
}

// ─── Completed card ────────────────────────────────────────────────────────────

class _CompletedCard extends StatefulWidget {
  const _CompletedCard({required this.c, required this.trade});
  final AppColor c;
  final TradeModel trade;

  @override
  State<_CompletedCard> createState() => _CompletedCardState();
}

class _CompletedCardState extends State<_CompletedCard> {
  bool _reviewSubmitted = false;

  Future<void> _openReviewSheet() async {
    final c = widget.c;
    final result = await showModalBottomSheet<_ReviewResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReviewSheet(c: c, tradeId: widget.trade.id),
    );
    if (result == null) return;
    try {
      await ReviewsCoreService.I.create(CreateReviewRequest(
        tradeId: widget.trade.id,
        rating: result.rating,
        comment: result.comment.isNotEmpty ? result.comment : null,
      ));
      if (mounted) setState(() => _reviewSubmitted = true);
      if (mounted) {
        showFloatingSnackBar(context,
            message: 'Review submitted. Thank you!',
            type: SnackBarType.success);
      }
    } catch (e) {
      if (mounted) {
        showFloatingSnackBar(context,
            message: 'Failed to submit review: $e',
            type: SnackBarType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final trade = widget.trade;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF00C48C).withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF00C48C).withOpacity(0.25)),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF00C48C), size: 48),
          const SizedBox(height: 12),
          Text(
            'Trade completed!',
            style: TextStyle(
              color: c.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${trade.cryptoAmount.toStringAsFixed(7)} ${trade.asset} has been released.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textSecondary, fontSize: 13.5),
          ),
          const SizedBox(height: 16),
          _reviewSubmitted
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded,
                        size: 16, color: const Color(0xFF00C48C)),
                    const SizedBox(width: 6),
                    Text(
                      'Review submitted',
                      style: TextStyle(
                        color: const Color(0xFF00C48C),
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                )
              : GestureDetector(
                  onTap: _openReviewSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                    decoration: BoxDecoration(
                      color: c.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, size: 17, color: c.primary),
                        const SizedBox(width: 7),
                        Text(
                          'Rate this trade',
                          style: TextStyle(
                            color: c.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

// ─── Cancelled card ────────────────────────────────────────────────────────────

class _CancelledCard extends StatelessWidget {
  const _CancelledCard({required this.c});
  final AppColor c;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: c.error.withOpacity(0.06),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: c.error.withOpacity(0.2)),
    ),
    child: Column(
      children: [
        Icon(Icons.cancel_rounded, color: c.error, size: 40),
        const SizedBox(height: 12),
        Text(
          'Trade cancelled',
          style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 6),
        Text(
          'Any locked funds have been released back.',
          textAlign: TextAlign.center,
          style: TextStyle(color: c.textSecondary, fontSize: 13),
        ),
      ],
    ),
  );
}

// ─── Bottom actions ────────────────────────────────────────────────────────────

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.c,
    required this.trade,
    required this.isBuy,
    required this.loading,
    required this.onLockCrypto,
    required this.onMarkFiatSent,
    required this.onConfirmFiat,
    required this.onClaimCrypto,
    required this.onCancel,
    required this.onDispute,
    required this.onRefund,
  });
  final AppColor c;
  final TradeModel trade;
  final bool isBuy;
  final bool loading;
  final VoidCallback onLockCrypto;
  final VoidCallback onMarkFiatSent;
  final VoidCallback onConfirmFiat;
  final VoidCallback onClaimCrypto;
  final VoidCallback onCancel;
  final VoidCallback onDispute;
  final VoidCallback onRefund;

  @override
  Widget build(BuildContext context) {
    final status = trade.status;

    // Role-gated primary actions:
    // SELL offer (isBuy=true):  merchant locks → user pays fiat → merchant confirms → user claims
    // BUY  offer (isBuy=false): user locks     → merchant pays  → user confirms    → merchant claims
    final showLockCrypto   = status == TradeStatus.created      && !isBuy;
    final showMarkFiatSent = status == TradeStatus.cryptoLocked &&  isBuy;
    final showConfirmFiat  = status == TradeStatus.fiatSent     && !isBuy;
    final showClaimCrypto  = status == TradeStatus.fiatConfirmed &&  isBuy;

    final showCancel  = (status == TradeStatus.created || status == TradeStatus.cryptoLocked);
    final showDispute = status.isActive && status != TradeStatus.disputed;
    final showRefund  = status == TradeStatus.expired && !isBuy
                        && trade.escrow?.claimableBalanceId != null;

    final hasPrimary = showLockCrypto || showMarkFiatSent ||
                       showConfirmFiat || showClaimCrypto;

    if (!hasPrimary && !showCancel && !showDispute && !showRefund) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: c.background,
        border: Border(top: BorderSide(color: c.border.withOpacity(0.15))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Primary action button
          if (showLockCrypto)
            _ActionButton(
              label: 'Lock Your Crypto',
              icon: Icons.lock_rounded,
              color: const Color(0xFF5B8DEF),
              loading: loading,
              onTap: onLockCrypto,
            ),
          if (showMarkFiatSent)
            _ActionButton(
              label: "I've Sent Payment",
              icon: Icons.send_rounded,
              color: const Color(0xFF5B8DEF),
              loading: loading,
              onTap: onMarkFiatSent,
            ),
          if (showConfirmFiat)
            _ActionButton(
              label: 'Confirm Payment Received',
              icon: Icons.verified_rounded,
              color: const Color(0xFF00C48C),
              loading: loading,
              onTap: onConfirmFiat,
            ),
          if (showClaimCrypto)
            _ActionButton(
              label: 'Claim Your Crypto',
              icon: Icons.account_balance_wallet_rounded,
              color: const Color(0xFF00C48C),
              loading: loading,
              onTap: onClaimCrypto,
            ),
          if (showRefund)
            _ActionButton(
              label: 'Refund Expired Escrow',
              icon: Icons.replay_rounded,
              color: c.warning,
              loading: loading,
              onTap: onRefund,
            ),

          if (hasPrimary || showRefund) const SizedBox(height: 8),

          // Secondary actions row (cancel + dispute)
          if (showCancel || showDispute)
            Row(
              children: [
                if (showCancel)
                  Expanded(
                    child: _ActionButton(
                      label: 'Cancel',
                      icon: Icons.close_rounded,
                      color: c.error,
                      outlined: true,
                      loading: loading,
                      onTap: onCancel,
                    ),
                  ),
                if (showCancel && showDispute) const SizedBox(width: 8),
                if (showDispute)
                  Expanded(
                    child: _ActionButton(
                      label: 'Dispute',
                      icon: Icons.flag_rounded,
                      color: c.error,
                      outlined: true,
                      loading: loading,
                      onTap: onDispute,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.outlined = false,
    this.loading = false,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool outlined;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 50,
        width: double.infinity,
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : (loading ? color.withOpacity(0.5) : color),
          borderRadius: BorderRadius.circular(14),
          border: outlined ? Border.all(color: color.withOpacity(0.6), width: 1.5) : null,
          boxShadow: !outlined && !loading
              ? [BoxShadow(color: color.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4))]
              : [],
        ),
        child: Center(
          child: loading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: outlined ? color : Colors.white,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18, color: outlined ? color : Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        color: outlined ? color : Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─── Confirm bottom sheet ──────────────────────────────────────────────────────

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.c,
    required this.title,
    required this.body,
    required this.confirmLabel,
    this.isDestructive = false,
  });
  final AppColor c;
  final String title;
  final String body;
  final String confirmLabel;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: c.border.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textSecondary, fontSize: 13.5, height: 1.4),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(false),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: c.background,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: c.border.withOpacity(0.2)),
                    ),
                    child: Center(
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(true),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: isDestructive ? c.error : c.primary,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Center(
                      child: Text(
                        confirmLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Shared sub-widgets ────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.c, required this.child});
  final AppColor c;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: c.border.withOpacity(0.15)),
    ),
    child: child,
  );
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.c, required this.icon, required this.label});
  final AppColor c;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 16, color: c.textPrimary),
      const SizedBox(width: 8),
      Text(
        label,
        style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5),
      ),
    ],
  );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.c,
    required this.label,
    required this.value,
    this.copyable = false,
    this.fullCopyValue,
    this.isLast = false,
  });
  final AppColor c;
  final String label;
  final String value;
  final bool copyable;
  final String? fullCopyValue;
  final bool isLast;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: TextStyle(color: c.textSecondary, fontSize: 12.5),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: copyable
                ? () {
                    Clipboard.setData(ClipboardData(text: fullCopyValue ?? value));
                    showFloatingSnackBar(context, message: 'Copied!', type: SnackBarType.success);
                  }
                : null,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                if (copyable) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.copy_rounded, size: 12, color: c.textSecondary.withOpacity(0.5)),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

// ─── Dispute bottom sheet ──────────────────────────────────────────────────────

class _DisputeSheet extends StatefulWidget {
  const _DisputeSheet({required this.c});
  final AppColor c;

  @override
  State<_DisputeSheet> createState() => _DisputeSheetState();
}

class _DisputeSheetState extends State<_DisputeSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: c.border.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Open a Dispute',
            style: TextStyle(
                color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            'Describe the issue. Our support team will review and contact you.',
            style: TextStyle(color: c.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _ctrl,
            maxLines: 4,
            style: TextStyle(color: c.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'e.g. Merchant is not responding...',
              hintStyle: TextStyle(color: c.textSecondary.withOpacity(0.5)),
              filled: true,
              fillColor: c.background,
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: c.border.withOpacity(0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: c.border.withOpacity(0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: c.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(null),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: c.background,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: c.border.withOpacity(0.2)),
                    ),
                    child: Center(
                      child: Text('Cancel',
                          style: TextStyle(
                              color: c.textSecondary, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    final reason = _ctrl.text.trim();
                    if (reason.isEmpty) return;
                    Navigator.of(context).pop(reason);
                  },
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: c.error,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Center(
                      child: Text('Submit',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Proof pick sheet ──────────────────────────────────────────────────────────

class _ProofPickSheet extends StatelessWidget {
  const _ProofPickSheet({required this.c});
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      decoration: BoxDecoration(
          color: c.surface, borderRadius: BorderRadius.circular(24)),
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
                color: c.border.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2)),
          ),
          Text('Attach Payment Proof?',
              style: TextStyle(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16)),
          const SizedBox(height: 8),
          Text('Optionally attach a screenshot of your payment.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 13.5)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(true),
            child: Container(
              height: 50,
              width: double.infinity,
              decoration: BoxDecoration(
                  color: c.primary, borderRadius: BorderRadius.circular(14)),
              child: const Center(
                child: Text('Pick from Gallery',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(false),
            child: Container(
              height: 50,
              width: double.infinity,
              decoration: BoxDecoration(
                color: c.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.border.withOpacity(0.2)),
              ),
              child: Center(
                child: Text('Skip',
                    style: TextStyle(
                        color: c.textSecondary, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Review sheet ──────────────────────────────────────────────────────────────

class _ReviewResult {
  final int rating;
  final String comment;
  const _ReviewResult({required this.rating, required this.comment});
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.c, required this.tradeId});
  final AppColor c;
  final String tradeId;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  int _rating = 5;
  final _commentCtrl = TextEditingController();

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      decoration: BoxDecoration(
          color: c.surface, borderRadius: BorderRadius.circular(24)),
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
                color: c.border.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2)),
          ),
          Text('Rate Your Experience',
              style: TextStyle(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final star = i + 1;
              return GestureDetector(
                onTap: () => setState(() => _rating = star),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Icon(
                    star <= _rating ? Icons.star_rounded : Icons.star_border_rounded,
                    color: star <= _rating
                        ? const Color(0xFFFAC748)
                        : c.textSecondary.withOpacity(0.3),
                    size: 36,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _commentCtrl,
            maxLines: 3,
            style: TextStyle(color: c.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Leave a comment (optional)',
              hintStyle: TextStyle(color: c.textSecondary.withOpacity(0.5)),
              filled: true,
              fillColor: c.background,
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: c.border.withOpacity(0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: c.border.withOpacity(0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: c.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(
                _ReviewResult(rating: _rating, comment: _commentCtrl.text.trim())),
            child: Container(
              height: 50,
              width: double.infinity,
              decoration: BoxDecoration(
                  color: c.primary, borderRadius: BorderRadius.circular(14)),
              child: const Center(
                child: Text('Submit Review',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
