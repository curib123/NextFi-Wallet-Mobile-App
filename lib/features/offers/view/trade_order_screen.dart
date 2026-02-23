import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/snackbar/SnackBar.dart';
import 'package:next_fi/services/offers/models/offers_dtos.dart';
import 'package:next_fi/services/offers/models/offers_models.dart';
import 'package:next_fi/services/trades/models/trades_models.dart';
import 'package:next_fi/services/trades/trades_core_service.dart';

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

              // ── Payment instructions (for buyer, if escrow funded) ────
              if (isBuy && _trade.status == TradeStatus.escrowFunded) ...[
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
          onMarkFiatSent: _markFiatSent,
          onConfirmFiat: _confirmFiat,
          onCancel: _cancelTrade,
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

  static const _labels = {
    TradeStatus.pending: ('Waiting for escrow', Icons.hourglass_empty_rounded, Color(0xFFFAA040)),
    TradeStatus.escrowFunded: ('Ready to pay', Icons.lock_clock_rounded, Color(0xFF5B8DEF)),
    TradeStatus.fiatSent: ('Payment sent – awaiting confirmation', Icons.pending_rounded, Color(0xFFFAA040)),
    TradeStatus.completed: ('Trade completed', Icons.check_circle_rounded, Color(0xFF00C48C)),
    TradeStatus.cancelled: ('Trade cancelled', Icons.cancel_rounded, Color(0xFFFF5C72)),
    TradeStatus.disputed: ('Under dispute', Icons.report_rounded, Color(0xFFFF5C72)),
    TradeStatus.unknown: ('Unknown status', Icons.help_outline_rounded, Color(0xFF9CA3AF)),
  };

  @override
  Widget build(BuildContext context) {
    final info = _labels[trade.status] ??
        ('Unknown', Icons.help_outline_rounded, const Color(0xFF9CA3AF));
    final label = info.$1;
    final icon = info.$2;
    final color = info.$3;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
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
    final statusColor = switch (escrow.status?.toUpperCase()) {
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
                    escrow.status!.toUpperCase(),
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

  @override
  Widget build(BuildContext context) {
    final steps = isBuy
        ? [
            (TradeStatus.pending, 'Trade opened', 'Waiting for crypto escrow to be set up'),
            (TradeStatus.escrowFunded, 'Escrow funded', 'Crypto is locked — send your fiat payment'),
            (TradeStatus.fiatSent, 'Payment sent', 'Waiting for merchant to confirm receipt'),
            (TradeStatus.completed, 'Completed', 'Crypto has been released to your wallet'),
          ]
        : [
            (TradeStatus.pending, 'Trade opened', 'Waiting for escrow to be funded'),
            (TradeStatus.escrowFunded, 'Escrow funded', 'Buyer will send fiat payment'),
            (TradeStatus.fiatSent, 'Payment received', 'Confirm you received the fiat'),
            (TradeStatus.completed, 'Completed', 'Fiat confirmed — crypto released'),
          ];

    final statusOrder = [
      TradeStatus.pending,
      TradeStatus.escrowFunded,
      TradeStatus.fiatSent,
      TradeStatus.completed,
    ];

    final currentIdx = statusOrder.indexOf(status);

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

            final isDone = currentIdx > stepIdx ||
                status == TradeStatus.completed;
            final isCurrent = stepIdx == currentIdx && status.isActive;
            final isSkipped = status == TradeStatus.cancelled ||
                status == TradeStatus.disputed;

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

class _CompletedCard extends StatelessWidget {
  const _CompletedCard({required this.c, required this.trade});
  final AppColor c;
  final TradeModel trade;

  @override
  Widget build(BuildContext context) => Container(
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
      ],
    ),
  );
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
    required this.onMarkFiatSent,
    required this.onConfirmFiat,
    required this.onCancel,
  });
  final AppColor c;
  final TradeModel trade;
  final bool isBuy;
  final bool loading;
  final VoidCallback onMarkFiatSent;
  final VoidCallback onConfirmFiat;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    if (trade.status.isTerminal) return const SizedBox.shrink();

    final showMarkFiatSent = isBuy && trade.status == TradeStatus.escrowFunded;
    final showConfirmFiat = !isBuy && trade.status == TradeStatus.fiatSent;
    final showCancel = trade.status == TradeStatus.pending ||
        trade.status == TradeStatus.escrowFunded;

    if (!showMarkFiatSent && !showConfirmFiat && !showCancel) {
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
          if (showMarkFiatSent)
            _ActionButton(
              label: "I've sent the payment",
              icon: Icons.check_rounded,
              color: const Color(0xFF5B8DEF),
              loading: loading,
              onTap: onMarkFiatSent,
            ),
          if (showConfirmFiat)
            _ActionButton(
              label: 'Confirm fiat received',
              icon: Icons.verified_rounded,
              color: const Color(0xFF00C48C),
              loading: loading,
              onTap: onConfirmFiat,
            ),
          if (showMarkFiatSent || showConfirmFiat) const SizedBox(height: 8),
          if (showCancel)
            _ActionButton(
              label: 'Cancel trade',
              icon: Icons.close_rounded,
              color: c.error,
              outlined: true,
              loading: loading && !showMarkFiatSent && !showConfirmFiat,
              onTap: onCancel,
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
