import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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

// ─── Design tokens ────────────────────────────────────────────────────────────

class _T {
  // Background layers
  static const bg        = Color(0xFF070C18);
  static const surface   = Color(0xFF0D1626);
  static const card      = Color(0xFF111D30);
  static const cardHover = Color(0xFF152138);

  // Brand palette
  static const blue      = Color(0xFF4F8EF7);
  static const blueDim   = Color(0x1A4F8EF7);
  static const green     = Color(0xFF1DC99A);
  static const greenDim  = Color(0x1A1DC99A);
  static const amber     = Color(0xFFF5A623);
  static const amberDim  = Color(0x1AF5A623);
  static const red       = Color(0xFFF06060);
  static const redDim    = Color(0x1AF06060);
  static const grey      = Color(0xFF6B7A99);

  // Text
  static const t1 = Color(0xFFEEF2FF);
  static const t2 = Color(0xFF7B8DB0);
  static const t3 = Color(0xFF3D4F6E);

  // Borders
  static const border  = Color(0x12FFFFFF);
  static const border2 = Color(0x08FFFFFF);

  // Spacing
  static const double r4  = 4;
  static const double r8  = 8;
  static const double r12 = 12;
  static const double r16 = 16;
  static const double r20 = 20;
  static const double r24 = 24;
  static const double r28 = 28;
  static const double r32 = 32;

  // Typography
  static TextStyle display(double size, {FontWeight w = FontWeight.w800}) =>
      GoogleFonts.sora(fontSize: size, fontWeight: w, color: t1, letterSpacing: -0.6);

  static TextStyle mono(double size, {FontWeight w = FontWeight.w500, Color? color}) =>
      GoogleFonts.jetBrainsMono(fontSize: size, fontWeight: w, color: color ?? t1);

  static TextStyle body(double size, {FontWeight w = FontWeight.w400, Color? color}) =>
      GoogleFonts.sora(fontSize: size, fontWeight: w, color: color ?? t2);

  static TextStyle label({Color? color}) =>
      GoogleFonts.sora(fontSize: 10, fontWeight: FontWeight.w700,
          color: color ?? t3, letterSpacing: 1.0);
}

// ─── Status helpers ───────────────────────────────────────────────────────────

Color _statusColor(TradeStatus s) => switch (s) {
  TradeStatus.created        => _T.amber,
  TradeStatus.cryptoLocked   => _T.blue,
  TradeStatus.fiatSent       => _T.amber,
  TradeStatus.fiatConfirmed  => _T.green,
  TradeStatus.completed      => _T.green,
  TradeStatus.cancelled      => _T.red,
  TradeStatus.disputed       => _T.red,
  TradeStatus.expired        => _T.grey,
  _                          => _T.grey,
};

Color _statusDimColor(TradeStatus s) => switch (s) {
  TradeStatus.created        => _T.amberDim,
  TradeStatus.cryptoLocked   => _T.blueDim,
  TradeStatus.fiatSent       => _T.amberDim,
  TradeStatus.fiatConfirmed  => _T.greenDim,
  TradeStatus.completed      => _T.greenDim,
  TradeStatus.cancelled      => _T.redDim,
  TradeStatus.disputed       => _T.redDim,
  _                          => const Color(0x14FFFFFF),
};

String _statusLabel(TradeStatus s, bool isBuy) => switch (s) {
  TradeStatus.created        => 'Awaiting Escrow',
  TradeStatus.cryptoLocked   => isBuy ? 'Ready to Pay' : 'Awaiting Payment',
  TradeStatus.fiatSent       => isBuy ? 'Payment Sent' : 'Payment Received',
  TradeStatus.fiatConfirmed  => 'Payment Confirmed',
  TradeStatus.completed      => 'Trade Completed',
  TradeStatus.cancelled      => 'Trade Cancelled',
  TradeStatus.disputed       => 'Under Dispute',
  TradeStatus.expired        => 'Trade Expired',
  _                          => 'Unknown',
};

IconData _statusIcon(TradeStatus s) => switch (s) {
  TradeStatus.created        => Icons.hourglass_empty_rounded,
  TradeStatus.cryptoLocked   => Icons.lock_clock_rounded,
  TradeStatus.fiatSent       => Icons.north_east_rounded,
  TradeStatus.fiatConfirmed  => Icons.check_circle_outline_rounded,
  TradeStatus.completed      => Icons.check_circle_rounded,
  TradeStatus.cancelled      => Icons.cancel_rounded,
  TradeStatus.disputed       => Icons.flag_rounded,
  TradeStatus.expired        => Icons.timer_off_rounded,
  _                          => Icons.help_outline_rounded,
};

// ─── Main screen ─────────────────────────────────────────────────────────────

class TradeOrderScreen extends StatefulWidget {
  const TradeOrderScreen({super.key, required this.trade, this.offer});
  final TradeModel trade;
  final OfferModel? offer;

  @override
  State<TradeOrderScreen> createState() => _TradeOrderScreenState();
}

class _TradeOrderScreenState extends State<TradeOrderScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final _tradesCore = TradesCoreService.I;

  late TradeModel _trade;
  bool _refreshing = false;
  bool _actionLoading = false;
  String? _actionError;
  bool _isOnline = true;
  late final StreamSubscription<List<ConnectivityResult>> _connectivitySub;

  Timer? _countdownTimer;
  Duration _timeLeft = Duration.zero;
  Timer? _pollTimer;

  // Pulse animation for active dot
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _trade = widget.trade;
    WidgetsBinding.instance.addObserver(this);
    _startConnectivityMonitor();
    _startCountdown();
    _startPolling();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub.cancel();
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _trade.status.isActive) {
      _refresh(silent: true);
    }
  }

  void _startConnectivityMonitor() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (!mounted) return;
      final wasOffline = !_isOnline;
      setState(() => _isOnline = online);
      if (online && wasOffline && _trade.status.isActive) _refresh(silent: true);
    });
  }

  void _startCountdown() {
    final expires = _trade.expiresAt;
    if (expires == null) {
      final created = _trade.createdAt;
      final window = _trade.paymentWindowMinutes;
      if (created != null && window != null) {
        _updateTimeLeft(created.add(Duration(minutes: window)));
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

  void _startPolling() {
    if (!_trade.status.isActive) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_trade.status.isActive) _refresh(silent: true);
      else _pollTimer?.cancel();
    });
  }

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

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _markFiatSent() async {
    final ok = await _showConfirm(
      title: 'Confirm Payment Sent',
      body: 'Have you sent the fiat payment? This cannot be undone.',
      confirmLabel: 'Yes, I Sent It',
    );
    if (!ok) return;
    _runAction(() async {
      final proof = await _showProofPickSheet();
      if (proof != null) await _tradesCore.uploadProof(_trade.id, file: proof, type: 'FIAT');
      final u = await _tradesCore.markFiatSent(_trade.id);
      if (mounted) setState(() => _trade = u);
    }, successMsg: 'Payment marked as sent');
  }

  Future<void> _confirmFiat() async {
    final ok = await _showConfirm(
      title: 'Confirm Payment Received',
      body: 'Have you received the fiat payment from the buyer?',
      confirmLabel: 'Yes, I Received It',
    );
    if (!ok) return;
    _runAction(() async {
      final u = await _tradesCore.confirmFiat(_trade.id);
      if (mounted) setState(() => _trade = u);
    }, successMsg: 'Trade completed');
  }

  Future<void> _cancelTrade() async {
    final ok = await _showConfirm(
      title: 'Cancel Trade',
      body: 'Are you sure? The escrow will be released back to the seller.',
      confirmLabel: 'Cancel Trade',
      isDestructive: true,
    );
    if (!ok) return;
    _runAction(() async {
      final u = await _tradesCore.cancelTrade(_trade.id, reason: 'User cancelled');
      if (mounted) setState(() => _trade = u);
    }, successMsg: 'Trade cancelled');
  }

  Future<void> _lockCrypto() async {
    final ok = await _showConfirm(
      title: 'Lock Crypto in Escrow',
      body: 'Your crypto will be locked in a Stellar Claimable Balance until payment is confirmed.',
      confirmLabel: 'Lock Crypto',
    );
    if (!ok) return;
    _runAction(() async {
      final stellarSvc = context.read<StellarWalletServices>();
      final seedVM = context.read<SeedKeypairVM>();
      final kp = await seedVM.deriveKeyPair();
      final asset = _trade.asset.toUpperCase() == 'XLM'
          ? Asset.NATIVE
          : AssetTypeCreditAlphaNum4('USDC', stellarSvc.usdcIssuer);
      final merchantAddress = (_trade.offer?['seller']?['walletAddress'] ??
          _trade.offer?['seller']?['stellarAddress'] ?? '').toString();
      if (merchantAddress.isEmpty) throw Exception('Merchant address unavailable.');
      final expiry = _trade.expiresAt ?? DateTime.now().add(const Duration(hours: 24));
      final txHash = await stellarSvc.claimableBalanceService.createUnconditionalWithExpiry(
        keyPair: kp, asset: asset, amount: _trade.cryptoAmount,
        recipientId: merchantAddress, expiryTime: expiry,
      );
      final ops = await stellarSvc.sdk.operations.forTransaction(txHash).execute();
      final cbOp = ops.records.whereType<CreateClaimableBalanceOperationResponse>().firstOrNull;
      final cbId = cbOp?.claimants;
      if (cbId == null) throw Exception('Could not retrieve Claimable Balance ID.');
      final u = await _tradesCore.lockCrypto(_trade.id,
          claimableBalanceId: cbId.toString(), createTxHash: txHash);
      if (mounted) setState(() => _trade = u);
    }, successMsg: 'Crypto locked in escrow');
  }

  Future<void> _claimCrypto() async {
    final cbId = _trade.escrow?.claimableBalanceId;
    if (cbId == null) {
      showFloatingSnackBar(context, message: 'Escrow ID not available. Refresh.', type: SnackBarType.error);
      return;
    }
    final ok = await _showConfirm(
      title: 'Claim Your Crypto',
      body: 'Claim ${_trade.cryptoAmount.toStringAsFixed(4)} ${_trade.asset} to your wallet.',
      confirmLabel: 'Claim Crypto',
    );
    if (!ok) return;
    _runAction(() async {
      final stellarSvc = context.read<StellarWalletServices>();
      final seedVM = context.read<SeedKeypairVM>();
      final kp = await seedVM.deriveKeyPair();
      final claimTx = await stellarSvc.claimableBalanceService
          .claimClaimableBalance(keyPair: kp, balanceId: cbId);
      final u = await _tradesCore.claimCrypto(_trade.id, claimTxHash: claimTx);
      if (mounted) setState(() => _trade = u);
    }, successMsg: 'Crypto claimed to your wallet');
  }

  Future<void> _refundCrypto() async {
    final cbId = _trade.escrow?.claimableBalanceId;
    if (cbId == null) {
      showFloatingSnackBar(context, message: 'No escrow to refund.', type: SnackBarType.error);
      return;
    }
    final ok = await _showConfirm(
      title: 'Refund Escrow',
      body: 'The trade has expired. Reclaim your crypto back to your wallet.',
      confirmLabel: 'Refund',
    );
    if (!ok) return;
    _runAction(() async {
      final stellarSvc = context.read<StellarWalletServices>();
      final seedVM = context.read<SeedKeypairVM>();
      final kp = await seedVM.deriveKeyPair();
      final refundTx = await stellarSvc.claimableBalanceService
          .claimClaimableBalance(keyPair: kp, balanceId: cbId);
      final u = await _tradesCore.refundCrypto(_trade.id, refundTxHash: refundTx);
      if (mounted) setState(() => _trade = u);
    }, successMsg: 'Crypto refunded to your wallet');
  }

  Future<void> _openDispute() async {
    final reason = await showModalBottomSheet<String>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _DisputeSheet(),
    );
    if (reason == null || reason.isEmpty) return;
    _runAction(() async {
      final u = await _tradesCore.openDispute(_trade.id, reason: reason);
      if (mounted) setState(() => _trade = u);
    }, successMsg: 'Dispute opened. Support will contact you.');
  }

  Future<File?> _showProofPickSheet() async {
    final pick = await showModalBottomSheet<bool>(
      context: context, backgroundColor: Colors.transparent,
      builder: (_) => _ProofPickSheet(),
    );
    if (pick != true) return null;
    final result = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (result == null) return null;
    return File(result.path);
  }

  Future<void> _runAction(Future<void> Function() action, {required String successMsg}) async {
    setState(() { _actionLoading = true; _actionError = null; });
    try {
      await action();
      if (mounted) showFloatingSnackBar(context, message: successMsg, type: SnackBarType.success);
    } catch (e) {
      if (!mounted) return;
      String msg = e.toString().replaceAll(RegExp(r'TradeApiException\(\d+\): '), '');
      setState(() => _actionError = msg);
      showFloatingSnackBar(context, message: msg, type: SnackBarType.error);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<bool> _showConfirm({
    required String title, required String body,
    required String confirmLabel, bool isDestructive = false,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => _ConfirmSheet(title: title, body: body,
          confirmLabel: confirmLabel, isDestructive: isDestructive),
    );
    return result ?? false;
  }

  Future<bool> _onWillPop() async {
    final leave = await showModalBottomSheet<bool>(
      context: context, backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmSheet(
        title: 'Leave Trade Room?',
        body: 'Your trade is active. Return any time from Trade History.',
        confirmLabel: 'Leave', isDestructive: false,
      ),
    );
    return leave ?? false;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final bool isBuy = offer != null ? offer.type == OfferType.sell : true;

    return PopScope(
      canPop: !_trade.status.isActive,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && _trade.status.isActive) {
          final leave = await _onWillPop();
          if (leave && context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: _T.bg,
        extendBodyBehindAppBar: true,
        appBar: _buildAppBar(),
        body: Stack(
          children: [
            // Ambient background glow
            Positioned(
              top: -80, right: -60,
              child: Container(
                width: 280, height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    _statusColor(_trade.status).withOpacity(0.12),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
            RefreshIndicator(
              onRefresh: _refresh,
              color: _T.blue,
              backgroundColor: _T.card,
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 72, 16, 130),
                children: [
                  if (!_isOnline) _ConnectivityBanner(),
                  _HeroCard(trade: _trade, isBuy: isBuy),
                  const SizedBox(height: 12),
                  if (_trade.status.isActive && _timeLeft > Duration.zero) ...[
                    _CountdownCard(timeLeft: _timeLeft),
                    const SizedBox(height: 12),
                  ],
                  if (isBuy && _trade.status == TradeStatus.cryptoLocked)
                    _PaymentInstructionsCard(trade: _trade),
                  if (isBuy && _trade.status == TradeStatus.cryptoLocked)
                    const SizedBox(height: 12),
                  _TradeDetailsCard(trade: _trade, isBuy: isBuy),
                  const SizedBox(height: 12),
                  if (_trade.escrow != null) ...[
                    _EscrowCard(escrow: _trade.escrow!),
                    const SizedBox(height: 12),
                  ],
                  _TimelineCard(
                      trade: _trade, isBuy: isBuy, pulseAnim: _pulseAnim),
                  const SizedBox(height: 12),
                  if (_actionError != null) ...[
                    _ErrorBanner(message: _actionError!),
                    const SizedBox(height: 10),
                  ],
                  if (_trade.status.isActive) _SafetyNote(),
                  if (_trade.status == TradeStatus.completed)
                    _CompletedCard(trade: _trade),
                  if (_trade.status == TradeStatus.cancelled) _CancelledCard(),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: _BottomActions(
          trade: _trade, isBuy: isBuy, loading: _actionLoading,
          onLockCrypto: _lockCrypto, onMarkFiatSent: _markFiatSent,
          onConfirmFiat: _confirmFiat, onClaimCrypto: _claimCrypto,
          onCancel: _cancelTrade, onDispute: _openDispute, onRefund: _refundCrypto,
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leadingWidth: 56,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: _GlassButton(
          icon: Icons.arrow_back_ios_new_rounded,
          size: 18,
          onTap: () => Navigator.maybePop(context),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Trade Room', style: _T.display(17, w: FontWeight.w800)),
          Text(_trade.id, style: _T.mono(10, color: _T.t3)),
        ],
      ),
      actions: [
        if (_refreshing)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: _T.blue),
            ),
          )
        else if (_trade.status.isActive)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _GlassButton(
              icon: Icons.refresh_rounded, size: 18,
              onTap: _refresh,
            ),
          ),
      ],
    );
  }
}

// ─── Glass icon button ────────────────────────────────────────────────────────

class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.icon, required this.onTap, this.size = 20});
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: const Color(0x0DFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _T.border),
      ),
      child: Icon(icon, color: _T.t2, size: size),
    ),
  );
}

// ─── Connectivity banner ──────────────────────────────────────────────────────

class _ConnectivityBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      color: _T.amberDim,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _T.amber.withOpacity(0.25)),
    ),
    child: Row(children: [
      Icon(Icons.wifi_off_rounded, color: _T.amber, size: 16),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('No Connection', style: _T.body(12, w: FontWeight.w700, color: _T.amber)),
        Text('Your trade is safe. Updates resume when reconnected.',
            style: _T.body(11, color: _T.amber.withOpacity(0.75))),
      ])),
    ]),
  );
}

// ─── Hero card ────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.trade, required this.isBuy});
  final TradeModel trade;
  final bool isBuy;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(trade.status);
    final dimColor = _statusDimColor(trade.status);

    return Container(
      decoration: BoxDecoration(
        color: _T.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.2)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.08), _T.card],
        ),
      ),
      child: Stack(children: [
        // Decorative circle
        Positioned(right: -30, top: -30,
          child: Container(width: 140, height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [color.withOpacity(0.10), Colors.transparent]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Status row
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: dimColor, borderRadius: BorderRadius.circular(13)),
                child: Icon(_statusIcon(trade.status), color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_statusLabel(trade.status, isBuy),
                    style: _T.display(15, w: FontWeight.w700)),
                const SizedBox(height: 3),
                Row(children: [
                  Text('ID: ', style: _T.body(11, color: _T.t3)),
                  Text(trade.id.length > 16
                      ? '${trade.id.substring(0, 12)}…${trade.id.substring(trade.id.length - 4)}'
                      : trade.id,
                      style: _T.mono(11, color: _T.t3)),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: trade.id));
                      showFloatingSnackBar(context, message: 'Trade ID copied', type: SnackBarType.success);
                    },
                    child: Icon(Icons.copy_all_rounded, size: 13, color: _T.t3),
                  ),
                ]),
              ])),
              // Status chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: dimColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text(
                  isBuy ? 'BUYING' : 'SELLING',
                  style: _T.label(color: color),
                ),
              ),
            ]),

            const SizedBox(height: 20),
            Container(height: 1, color: _T.border2),
            const SizedBox(height: 20),

            // Amount display
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isBuy ? 'YOU RECEIVE' : 'YOU SEND', style: _T.label()),
                const SizedBox(height: 6),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(
                    trade.cryptoAmount.toStringAsFixed(4),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 32, fontWeight: FontWeight.w700,
                      color: _T.t1, letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(trade.asset,
                        style: _T.mono(14, color: _T.t2, w: FontWeight.w600)),
                  ),
                ]),
              ])),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(isBuy ? 'YOU PAY' : 'YOU RECEIVE', style: _T.label()),
                const SizedBox(height: 6),
                Text(
                  '${trade.fiatAmount.toStringAsFixed(2)}',
                  style: _T.display(22, w: FontWeight.w700),
                ),
                Text(trade.fiatCurrency, style: _T.body(12, color: _T.t2, w: FontWeight.w600)),
              ]),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// ─── Countdown card ───────────────────────────────────────────────────────────

class _CountdownCard extends StatelessWidget {
  const _CountdownCard({required this.timeLeft});
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
    final urgent = timeLeft.inMinutes < 5;
    final color = urgent ? _T.red : _T.amber;
    final dimColor = urgent ? _T.redDim : _T.amberDim;
    final totalSecs = 30 * 60.0;
    final progress = (timeLeft.inSeconds / totalSecs).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _T.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        // Circular progress
        SizedBox(
          width: 52, height: 52,
          child: CustomPaint(
            painter: _RingPainter(progress: progress, color: color),
            child: Center(
              child: Icon(Icons.timer_rounded, color: color, size: 22),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Payment Window', style: _T.label()),
          const SizedBox(height: 4),
          Text(
            urgent ? 'Act fast — time is running out!' : 'Send payment before the timer ends',
            style: _T.body(12, color: _T.t2),
          ),
        ])),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: dimColor, borderRadius: BorderRadius.circular(10)),
          child: Text(
            _fmt(timeLeft),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 16, fontWeight: FontWeight.w700, color: color,
            ),
          ),
        ),
      ]),
    );
  }
}

// Ring painter for countdown
class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = (size.width / 2) - 3;
    final bgPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), r, bgPaint);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

// ─── Payment instructions card ────────────────────────────────────────────────

class _PaymentInstructionsCard extends StatelessWidget {
  const _PaymentInstructionsCard({required this.trade});
  final TradeModel trade;

  @override
  Widget build(BuildContext context) {
    final spa = trade.sellerPaymentAccount;
    final accountName = spa?['accountName']?.toString();
    final accountNo = spa?['accountNo']?.toString();
    final instructions = spa?['instructions']?.toString();

    return Container(
      decoration: BoxDecoration(
        color: _T.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _T.blue.withOpacity(0.25)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_T.blueDim, _T.card],
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: _T.blue.withOpacity(0.12))),
          ),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: _T.blueDim, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.account_balance_rounded, color: _T.blue, size: 16),
            ),
            const SizedBox(width: 10),
            Text('Send Payment To', style: _T.body(13, w: FontWeight.w700, color: _T.t1)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _T.blueDim, borderRadius: BorderRadius.circular(6)),
              child: Text('STEP 1', style: _T.label(color: _T.blue)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            if (accountName != null)
              _DataRow(label: 'Account Name', value: accountName, copyable: true),
            if (accountNo != null)
              _DataRow(label: 'Account No.', value: accountNo, copyable: true, mono: true),
            if (instructions != null && instructions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _T.surface, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _T.border),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.info_outline_rounded, color: _T.t3, size: 14),
                  const SizedBox(width: 8),
                  Expanded(child: Text(instructions, style: _T.body(12, color: _T.t2))),
                ]),
              ),
            ],
            if (accountName == null && accountNo == null)
              Text('Contact the merchant via trade chat for payment details.',
                  style: _T.body(12, color: _T.t2)),
          ]),
        ),
      ]),
    );
  }
}

// ─── Trade details card ───────────────────────────────────────────────────────

class _TradeDetailsCard extends StatelessWidget {
  const _TradeDetailsCard({required this.trade, required this.isBuy});
  final TradeModel trade;
  final bool isBuy;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.receipt_long_rounded,
      iconColor: _T.blue,
      title: 'Trade Details',
      children: [
        _DataRow(label: 'Asset', value: trade.asset),
        _DataRow(label: 'Currency', value: trade.fiatCurrency),
        _DataRow(
          label: isBuy ? 'You Pay' : 'You Receive',
          value: '${trade.fiatAmount.toStringAsFixed(2)} ${trade.fiatCurrency}',
          highlight: true,
        ),
        _DataRow(
          label: isBuy ? 'You Receive' : 'You Send',
          value: '${trade.cryptoAmount.toStringAsFixed(6)} ${trade.asset}',
          highlight: true, mono: true,
        ),
        _DataRow(
          label: isBuy ? 'To Address' : 'From Address',
          value: trade.cryptoReceiverAddress.length > 20
              ? '${trade.cryptoReceiverAddress.substring(0, 14)}…'
              : trade.cryptoReceiverAddress,
          copyable: true,
          fullCopyValue: trade.cryptoReceiverAddress,
          mono: true,
        ),
        if (trade.cryptoReceiverMemo != null)
          _DataRow(
            label: 'Memo / Tag',
            value: trade.cryptoReceiverMemo!,
            copyable: true, mono: true,
          ),
      ],
    );
  }
}

// ─── Escrow card ──────────────────────────────────────────────────────────────

class _EscrowCard extends StatelessWidget {
  const _EscrowCard({required this.escrow});
  final TradeEscrowModel escrow;

  @override
  Widget build(BuildContext context) {
    final statusStr = escrow.status?.toString() ?? '';
    final statusColor = switch (statusStr) {
      'FUNDED' || 'ACTIVE' => _T.green,
      'RELEASED'           => _T.blue,
      'CANCELLED'          => _T.red,
      'FAILED'             => _T.red,
      _                    => _T.amber,
    };

    return _SectionCard(
      icon: Icons.lock_rounded,
      iconColor: statusColor,
      title: 'Stellar Escrow',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: statusColor.withOpacity(0.3)),
        ),
        child: Text(statusStr, style: _T.label(color: statusColor)),
      ),
      children: [
        if (escrow.claimableBalanceId != null)
          _DataRow(
            label: 'Balance ID',
            value: '${escrow.claimableBalanceId!.substring(0, 10)}…'
                '${escrow.claimableBalanceId!.substring(escrow.claimableBalanceId!.length - 8)}',
            copyable: true,
            fullCopyValue: escrow.claimableBalanceId,
            mono: true,
          ),
        if (escrow.txHash != null)
          _DataRow(
            label: 'Tx Hash',
            value: '${escrow.txHash!.substring(0, 10)}…'
                '${escrow.txHash!.substring(escrow.txHash!.length - 8)}',
            copyable: true,
            fullCopyValue: escrow.txHash,
            mono: true,
          ),
      ],
    );
  }
}

// ─── Timeline card ────────────────────────────────────────────────────────────

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({
    required this.trade, required this.isBuy, required this.pulseAnim,
  });
  final TradeModel trade;
  final bool isBuy;
  final Animation<double> pulseAnim;

  List<(TradeStatus, String, String)> _steps() => isBuy ? [
    (TradeStatus.created,        'Trade Created',       'Merchant is locking crypto in escrow'),
    (TradeStatus.cryptoLocked,   'Escrow Funded',       'Send your fiat payment to the merchant'),
    (TradeStatus.fiatSent,       'Payment Sent',        'Merchant is confirming receipt'),
    (TradeStatus.fiatConfirmed,  'Payment Confirmed',   'Claim your crypto to your wallet'),
    (TradeStatus.completed,      'Completed',           'Crypto delivered to your wallet'),
  ] : [
    (TradeStatus.created,        'Trade Created',       'Lock your crypto to start the trade'),
    (TradeStatus.cryptoLocked,   'Escrow Funded',       'Buyer will send fiat payment'),
    (TradeStatus.fiatSent,       'Payment Received',    'Confirm you received the payment'),
    (TradeStatus.fiatConfirmed,  'Payment Confirmed',   'Buyer will claim crypto from escrow'),
    (TradeStatus.completed,      'Completed',           'Crypto released to buyer'),
  ];

  @override
  Widget build(BuildContext context) {
    final steps = _steps();
    final order = [
      TradeStatus.created, TradeStatus.cryptoLocked,
      TradeStatus.fiatSent, TradeStatus.fiatConfirmed, TradeStatus.completed,
    ];
    final currentIdx = order.contains(trade.status) ? order.indexOf(trade.status) : -1;
    final isTerminal = trade.status == TradeStatus.cancelled
        || trade.status == TradeStatus.disputed
        || trade.status == TradeStatus.expired;

    return _SectionCard(
      icon: Icons.route_rounded,
      iconColor: _T.t2,
      title: 'Progress',
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      children: List.generate(steps.length, (i) {
        final step = steps[i];
        final stepIdx = order.indexOf(step.$1);
        final isCompleted = trade.status == TradeStatus.completed;
        final isDone = isCompleted || currentIdx > stepIdx;
        final isCurrent = stepIdx == currentIdx && trade.status.isActive;
        final isLast = i == steps.length - 1;

        final dotColor = isTerminal && stepIdx > 0
            ? _T.t3
            : isDone ? _T.green : isCurrent ? _T.blue : _T.t3;

        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Spine
          Column(children: [
            isCurrent
                ? AnimatedBuilder(
              animation: pulseAnim,
              builder: (_, __) => Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _T.blue.withOpacity(0.15),
                  border: Border.all(color: _T.blue, width: 2),
                  boxShadow: [BoxShadow(
                    color: _T.blue.withOpacity(pulseAnim.value * 0.4),
                    blurRadius: 12, spreadRadius: 2,
                  )],
                ),
                child: const Center(
                  child: Icon(Icons.circle, color: _T.blue, size: 8),
                ),
              ),
            )
                : Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor.withOpacity(isDone ? 0.15 : 0.06),
                border: Border.all(color: dotColor, width: isDone ? 2 : 1.5),
              ),
              child: isDone
                  ? const Icon(Icons.check_rounded, color: _T.green, size: 14)
                  : Icon(Icons.circle_outlined, color: dotColor, size: 10),
            ),
            if (!isLast)
              Container(
                width: 2, height: 36,
                margin: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(1),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDone
                        ? [_T.green.withOpacity(0.5), _T.green.withOpacity(0.15)]
                        : [_T.border, _T.border2],
                  ),
                ),
              ),
          ]),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 4, bottom: isLast ? 0 : 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(step.$2, style: _T.body(13.5,
                    w: isCurrent ? FontWeight.w700 : FontWeight.w600,
                    color: isDone || isCurrent ? _T.t1 : _T.t3)),
                const SizedBox(height: 2),
                Text(step.$3, style: _T.body(11.5, color: _T.t3)),
              ]),
            ),
          ),
        ]);
      }),
    );
  }
}

// ─── Section card (shared) ────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.children,
    this.trailing,
    this.padding,
  });
  final IconData icon;
  final Color iconColor;
  final String title;
  final List<Widget> children;
  final Widget? trailing;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _T.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _T.border),
      ),
      child: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 11),
          child: Row(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: iconColor, size: 15),
            ),
            const SizedBox(width: 10),
            Text(title, style: _T.body(12, w: FontWeight.w700, color: _T.t2)),
            const Spacer(),
            if (trailing != null) trailing!,
          ]),
        ),
        Container(height: 1, color: _T.border2),
        Padding(
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(children: children),
        ),
      ]),
    );
  }
}

// ─── Data row ─────────────────────────────────────────────────────────────────

class _DataRow extends StatefulWidget {
  const _DataRow({
    required this.label,
    required this.value,
    this.copyable = false,
    this.fullCopyValue,
    this.mono = false,
    this.highlight = false,
  });
  final String label;
  final String value;
  final bool copyable;
  final String? fullCopyValue;
  final bool mono;
  final bool highlight;

  @override
  State<_DataRow> createState() => _DataRowState();
}

class _DataRowState extends State<_DataRow> {
  bool _copied = false;

  void _copy() {
    if (!widget.copyable) return;
    Clipboard.setData(ClipboardData(text: widget.fullCopyValue ?? widget.value));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        SizedBox(
          width: 110,
          child: Text(widget.label, style: _T.body(12, color: _T.t3)),
        ),
        Expanded(child: GestureDetector(
          onTap: _copy,
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Flexible(child: Text(
              widget.value,
              textAlign: TextAlign.right,
              style: widget.mono
                  ? _T.mono(12, color: widget.highlight ? _T.t1 : _T.t1, w: FontWeight.w500)
                  : _T.body(12.5, w: FontWeight.w600, color: _T.t1),
            )),
            if (widget.copyable) ...[
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: _copied ? _T.greenDim : const Color(0x0DFFFFFF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _copied ? _T.green.withOpacity(0.3) : _T.border,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    _copied ? Icons.check_rounded : Icons.copy_rounded,
                    size: 11,
                    color: _copied ? _T.green : _T.t3,
                  ),
                ]),
              ),
            ],
          ]),
        )),
      ]),
    );
  }
}

// ─── Safety note ─────────────────────────────────────────────────────────────

class _SafetyNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      color: _T.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _T.border),
    ),
    child: Row(children: [
      const Icon(Icons.shield_outlined, size: 15, color: _T.t3),
      const SizedBox(width: 10),
      Expanded(child: Text(
        'Trade remains active if you leave. Return from Trade History.',
        style: _T.body(11.5, color: _T.t3),
      )),
    ]),
  );
}

// ─── Error banner ─────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      color: _T.redDim,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _T.red.withOpacity(0.25)),
    ),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded, color: _T.red, size: 16),
      const SizedBox(width: 10),
      Expanded(child: Text(message, style: _T.body(12, color: _T.red))),
    ]),
  );
}

// ─── Completed card ───────────────────────────────────────────────────────────

class _CompletedCard extends StatefulWidget {
  const _CompletedCard({required this.trade});
  final TradeModel trade;

  @override
  State<_CompletedCard> createState() => _CompletedCardState();
}

class _CompletedCardState extends State<_CompletedCard> {
  bool _reviewSubmitted = false;

  Future<void> _openReviewSheet() async {
    final result = await showModalBottomSheet<_ReviewResult>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _ReviewSheet(tradeId: widget.trade.id),
    );
    if (result == null) return;
    try {
      await ReviewsCoreService.I.create(CreateReviewRequest(
        tradeId: widget.trade.id, rating: result.rating,
        comment: result.comment.isNotEmpty ? result.comment : null,
      ));
      if (mounted) setState(() => _reviewSubmitted = true);
      if (mounted) showFloatingSnackBar(context, message: 'Review submitted!', type: SnackBarType.success);
    } catch (e) {
      if (mounted) showFloatingSnackBar(context, message: 'Failed: $e', type: SnackBarType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trade = widget.trade;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _T.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _T.green.withOpacity(0.25)),
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [_T.greenDim, _T.card],
        ),
      ),
      child: Column(children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(shape: BoxShape.circle, color: _T.greenDim),
          child: const Icon(Icons.check_rounded, color: _T.green, size: 32),
        ),
        const SizedBox(height: 16),
        Text('Trade Completed!', style: _T.display(20)),
        const SizedBox(height: 8),
        Text(
          '${trade.cryptoAmount.toStringAsFixed(6)} ${trade.asset} released to your wallet',
          textAlign: TextAlign.center,
          style: _T.body(13, color: _T.t2),
        ),
        const SizedBox(height: 20),
        _reviewSubmitted
            ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.star_rounded, color: _T.green, size: 18),
          const SizedBox(width: 8),
          Text('Review submitted — thank you!', style: _T.body(13, color: _T.green, w: FontWeight.w600)),
        ])
            : GestureDetector(
          onTap: _openReviewSheet,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: _T.greenDim,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _T.green.withOpacity(0.3)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.star_rounded, color: _T.green, size: 18),
              const SizedBox(width: 8),
              Text('Rate This Trade', style: _T.body(14, w: FontWeight.w700, color: _T.green)),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ─── Cancelled card ───────────────────────────────────────────────────────────

class _CancelledCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: _T.card,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: _T.red.withOpacity(0.2)),
    ),
    child: Column(children: [
      Container(
        width: 56, height: 56,
        decoration: BoxDecoration(shape: BoxShape.circle, color: _T.redDim),
        child: const Icon(Icons.close_rounded, color: _T.red, size: 28),
      ),
      const SizedBox(height: 14),
      Text('Trade Cancelled', style: _T.display(18, w: FontWeight.w700)),
      const SizedBox(height: 6),
      Text('All locked funds have been released back.',
          textAlign: TextAlign.center, style: _T.body(13, color: _T.t2)),
    ]),
  );
}

// ─── Bottom actions ───────────────────────────────────────────────────────────

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.trade, required this.isBuy, required this.loading,
    required this.onLockCrypto, required this.onMarkFiatSent,
    required this.onConfirmFiat, required this.onClaimCrypto,
    required this.onCancel, required this.onDispute, required this.onRefund,
  });
  final TradeModel trade;
  final bool isBuy;
  final bool loading;
  final VoidCallback onLockCrypto, onMarkFiatSent, onConfirmFiat,
      onClaimCrypto, onCancel, onDispute, onRefund;

  @override
  Widget build(BuildContext context) {
    final s = trade.status;
    final showLockCrypto   = s == TradeStatus.created       && !isBuy;
    final showMarkFiatSent = s == TradeStatus.cryptoLocked  &&  isBuy;
    final showConfirmFiat  = s == TradeStatus.fiatSent      && !isBuy;
    final showClaimCrypto  = s == TradeStatus.fiatConfirmed &&  isBuy;
    final showCancel  = s == TradeStatus.created || s == TradeStatus.cryptoLocked;
    final showDispute = s.isActive && s != TradeStatus.disputed;
    final showRefund  = s == TradeStatus.expired && !isBuy && trade.escrow?.claimableBalanceId != null;
    final hasPrimary  = showLockCrypto || showMarkFiatSent || showConfirmFiat || showClaimCrypto;

    if (!hasPrimary && !showCancel && !showDispute && !showRefund) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.fromLTRB(16, 14, 16, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: _T.bg.withOpacity(0.95),
        border: Border(top: BorderSide(color: _T.border)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (showLockCrypto)
          _ActionBtn(label: 'Lock Crypto in Escrow', icon: Icons.lock_rounded,
              color: _T.blue, loading: loading, onTap: onLockCrypto),
        if (showMarkFiatSent)
          _ActionBtn(label: "I've Sent the Payment", icon: Icons.north_east_rounded,
              color: _T.blue, loading: loading, onTap: onMarkFiatSent),
        if (showConfirmFiat)
          _ActionBtn(label: 'Confirm Payment Received', icon: Icons.verified_rounded,
              color: _T.green, loading: loading, onTap: onConfirmFiat),
        if (showClaimCrypto)
          _ActionBtn(label: 'Claim Your Crypto', icon: Icons.account_balance_wallet_rounded,
              color: _T.green, loading: loading, onTap: onClaimCrypto),
        if (showRefund)
          _ActionBtn(label: 'Refund Expired Escrow', icon: Icons.replay_rounded,
              color: _T.amber, loading: loading, onTap: onRefund),
        if (hasPrimary || showRefund) const SizedBox(height: 10),
        if (showCancel || showDispute)
          Row(children: [
            if (showCancel)
              Expanded(child: _ActionBtn(label: 'Cancel', icon: Icons.close_rounded,
                  color: _T.red, loading: loading, onTap: onCancel, outlined: true, compact: true)),
            if (showCancel && showDispute) const SizedBox(width: 10),
            if (showDispute)
              Expanded(child: _ActionBtn(label: 'Dispute', icon: Icons.flag_rounded,
                  color: _T.red, loading: loading, onTap: onDispute, outlined: true, compact: true)),
          ]),
      ]),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.label, required this.icon, required this.color,
    required this.loading, required this.onTap,
    this.outlined = false, this.compact = false,
  });
  final String label;
  final IconData icon;
  final Color color;
  final bool loading, outlined, compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final h = compact ? 46.0 : 54.0;
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: h,
        width: double.infinity,
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : color.withOpacity(loading ? 0.5 : 1.0),
          borderRadius: BorderRadius.circular(16),
          border: outlined ? Border.all(color: color.withOpacity(0.5), width: 1.5) : null,
          boxShadow: !outlined && !loading
              ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))]
              : [],
        ),
        child: Center(
          child: loading
              ? SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2,
                  color: outlined ? color : Colors.white))
              : Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: compact ? 16 : 18, color: outlined ? color : Colors.white),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.sora(
              fontSize: compact ? 13 : 14.5,
              fontWeight: FontWeight.w700,
              color: outlined ? color : Colors.white,
              letterSpacing: -0.2,
            )),
          ]),
        ),
      ),
    );
  }
}

// ─── Shared bottom sheet base ─────────────────────────────────────────────────

class _SheetBase extends StatelessWidget {
  const _SheetBase({required this.child, this.fullScroll = false});
  final Widget child;
  final bool fullScroll;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      decoration: BoxDecoration(color: _T.card, borderRadius: BorderRadius.circular(28)),
      padding: EdgeInsets.fromLTRB(
        20, 16, 20,
        (fullScroll ? MediaQuery.of(context).viewInsets.bottom : MediaQuery.of(context).padding.bottom) + 24,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 36, height: 4, margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(color: _T.border, borderRadius: BorderRadius.circular(2)),
        ),
        child,
      ]),
    );
  }
}

// ─── Confirm sheet ────────────────────────────────────────────────────────────

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.title, required this.body,
    required this.confirmLabel, this.isDestructive = false,
  });
  final String title, body, confirmLabel;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final actionColor = isDestructive ? _T.red : _T.blue;
    return _SheetBase(child: Column(children: [
      Text(title, textAlign: TextAlign.center, style: _T.display(17, w: FontWeight.w800)),
      const SizedBox(height: 10),
      Text(body, textAlign: TextAlign.center, style: _T.body(13.5, color: _T.t2)),
      const SizedBox(height: 28),
      Row(children: [
        Expanded(child: GestureDetector(
          onTap: () => Navigator.pop(context, false),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0x0DFFFFFF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _T.border),
            ),
            child: Center(child: Text('Cancel', style: _T.body(14, w: FontWeight.w600, color: _T.t2))),
          ),
        )),
        const SizedBox(width: 10),
        Expanded(child: GestureDetector(
          onTap: () => Navigator.pop(context, true),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: actionColor,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: actionColor.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 6))],
            ),
            child: Center(child: Text(confirmLabel, style: GoogleFonts.sora(
                fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))),
          ),
        )),
      ]),
    ]));
  }
}

// ─── Dispute sheet ────────────────────────────────────────────────────────────

class _DisputeSheet extends StatefulWidget {
  @override
  State<_DisputeSheet> createState() => _DisputeSheetState();
}

class _DisputeSheetState extends State<_DisputeSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return _SheetBase(fullScroll: true, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 36, height: 36,
            decoration: BoxDecoration(color: _T.redDim, borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.flag_rounded, color: _T.red, size: 18)),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Open a Dispute', style: _T.display(16, w: FontWeight.w800)),
          Text('Support will review within 24h', style: _T.body(11.5, color: _T.t3)),
        ]),
      ]),
      const SizedBox(height: 18),
      TextField(
        controller: _ctrl,
        maxLines: 4,
        style: _T.body(14, color: _T.t1),
        cursorColor: _T.blue,
        decoration: InputDecoration(
          hintText: 'Describe the issue (e.g. Merchant not responding)…',
          hintStyle: _T.body(13.5, color: _T.t3),
          filled: true, fillColor: _T.surface,
          contentPadding: const EdgeInsets.all(16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _T.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _T.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _T.blue, width: 1.5),
          ),
        ),
      ),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: GestureDetector(
          onTap: () => Navigator.pop(context, null),
          child: Container(height: 50,
            decoration: BoxDecoration(
              color: const Color(0x0DFFFFFF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _T.border),
            ),
            child: Center(child: Text('Cancel', style: _T.body(14, w: FontWeight.w600, color: _T.t2))),
          ),
        )),
        const SizedBox(width: 10),
        Expanded(child: GestureDetector(
          onTap: () {
            final r = _ctrl.text.trim();
            if (r.isEmpty) return;
            Navigator.pop(context, r);
          },
          child: Container(height: 50,
            decoration: BoxDecoration(
              color: _T.red, borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: _T.red.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Center(child: Text('Submit', style: GoogleFonts.sora(
                fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))),
          ),
        )),
      ]),
    ]));
  }
}

// ─── Proof pick sheet ─────────────────────────────────────────────────────────

class _ProofPickSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _SheetBase(child: Column(children: [
      const Icon(Icons.image_rounded, color: _T.blue, size: 36),
      const SizedBox(height: 14),
      Text('Attach Payment Proof?', style: _T.display(16, w: FontWeight.w800)),
      const SizedBox(height: 6),
      Text('Optionally add a screenshot of your payment confirmation.',
          textAlign: TextAlign.center, style: _T.body(13, color: _T.t2)),
      const SizedBox(height: 24),
      GestureDetector(
        onTap: () => Navigator.pop(context, true),
        child: Container(height: 52, width: double.infinity,
          decoration: BoxDecoration(
            color: _T.blue, borderRadius: BorderRadius.circular(15),
            boxShadow: [BoxShadow(color: _T.blue.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 6))],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.photo_library_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Choose from Gallery', style: GoogleFonts.sora(
                fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
          ]),
        ),
      ),
      const SizedBox(height: 10),
      GestureDetector(
        onTap: () => Navigator.pop(context, false),
        child: Container(height: 48, width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0x0DFFFFFF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _T.border),
          ),
          child: Center(child: Text('Skip for Now', style: _T.body(14, w: FontWeight.w600, color: _T.t2))),
        ),
      ),
    ]));
  }
}

// ─── Review sheet ─────────────────────────────────────────────────────────────

class _ReviewResult {
  final int rating;
  final String comment;
  const _ReviewResult({required this.rating, required this.comment});
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.tradeId});
  final String tradeId;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  int _rating = 5;
  final _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return _SheetBase(fullScroll: true, child: Column(children: [
      Text('Rate Your Experience', style: _T.display(17, w: FontWeight.w800)),
      const SizedBox(height: 6),
      Text('How was the trade?', style: _T.body(13, color: _T.t2)),
      const SizedBox(height: 20),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) {
        final star = i + 1;
        return GestureDetector(
          onTap: () => setState(() => _rating = star),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              star <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
              color: star <= _rating ? const Color(0xFFFBBC04) : _T.t3,
              size: star <= _rating ? 40 : 34,
            ),
          ),
        );
      })),
      const SizedBox(height: 18),
      TextField(
        controller: _ctrl, maxLines: 3,
        style: _T.body(14, color: _T.t1),
        cursorColor: _T.blue,
        decoration: InputDecoration(
          hintText: 'Leave a comment (optional)…',
          hintStyle: _T.body(13.5, color: _T.t3),
          filled: true, fillColor: _T.surface,
          contentPadding: const EdgeInsets.all(16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _T.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _T.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _T.blue, width: 1.5),
          ),
        ),
      ),
      const SizedBox(height: 18),
      GestureDetector(
        onTap: () => Navigator.pop(context, _ReviewResult(rating: _rating, comment: _ctrl.text.trim())),
        child: Container(height: 52, width: double.infinity,
          decoration: BoxDecoration(
            color: _T.blue, borderRadius: BorderRadius.circular(15),
            boxShadow: [BoxShadow(color: _T.blue.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 6))],
          ),
          child: Center(child: Text('Submit Review', style: GoogleFonts.sora(
              fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.white))),
        ),
      ),
    ]));
  }
}