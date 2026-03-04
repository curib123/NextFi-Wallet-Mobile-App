import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/modal/payment_proof_view_modal.dart';
import 'package:next_fi/common/components/modal/trade_confirm_sheet.dart';
import 'package:next_fi/common/components/modal/trade_proof_pick_sheet.dart';
import 'package:next_fi/common/components/modal/trade_review_sheet.dart';
import 'package:next_fi/common/components/modal/upload_dispute_evidence_modal.dart';
import 'package:next_fi/common/components/snackbar/SnackBar.dart';
import 'package:next_fi/features/offers/view/trade_messages_screen.dart';
import 'package:next_fi/reusable_view_model/seed_keypair_vm.dart';
import 'package:next_fi/services/base_url/base_url.dart';
import 'package:next_fi/services/oath2.0/auth_service.dart';
import 'package:next_fi/services/offers/models/offers_models.dart';
import 'package:next_fi/services/reviews/models/reviews_dtos.dart';
import 'package:next_fi/services/reviews/reviews_core_service.dart';
import 'package:next_fi/services/secure_storage/security_storage.dart';
import 'package:next_fi/services/stellar/stellar_wallet_services.dart';
import 'package:next_fi/services/trades/models/trades_models.dart';
import 'package:next_fi/services/trades/trades_core_service.dart';
import 'package:provider/provider.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

// ─── Status accent colors ─────────────────────────────────────────────────────

Color _statusAccent(TradeStatus s, AppColor colors) => switch (s) {
  TradeStatus.created => colors.warning,
  TradeStatus.cryptoLocked => colors.primary,
  TradeStatus.fiatSent => colors.warning,
  TradeStatus.fiatConfirmed => colors.success,
  TradeStatus.completed => colors.success,
  TradeStatus.cancelled => colors.error,
  TradeStatus.disputed => colors.error,
  TradeStatus.expired => colors.textSecondary,
  _ => colors.textSecondary,
};

IconData _statusIcon(TradeStatus s) => switch (s) {
  TradeStatus.created => Icons.hourglass_empty_rounded,
  TradeStatus.cryptoLocked => Icons.lock_clock_rounded,
  TradeStatus.fiatSent => Icons.north_east_rounded,
  TradeStatus.fiatConfirmed => Icons.check_circle_outline_rounded,
  TradeStatus.completed => Icons.check_circle_rounded,
  TradeStatus.cancelled => Icons.cancel_rounded,
  TradeStatus.disputed => Icons.flag_rounded,
  TradeStatus.expired => Icons.timer_off_rounded,
  _ => Icons.help_outline_rounded,
};

String _statusLabel(
  TradeStatus s, {
  required bool isUserEscrowLocker,
  required bool isUserFiatPayer,
  required bool isUserCryptoReceiver,
  required String assetCode,
}) {
  switch (s) {
    case TradeStatus.created:
      return isUserEscrowLocker ? 'Your Action Needed' : 'Waiting to Start';
    case TradeStatus.cryptoLocked:
      return isUserFiatPayer ? 'Send Payment Now' : 'Waiting for Payment';
    case TradeStatus.fiatSent:
      return isUserFiatPayer ? 'Payment Sent' : 'Confirm You Got Paid';
    case TradeStatus.fiatConfirmed:
      return isUserCryptoReceiver
          ? 'Get Your ${assetCode.toUpperCase()}'
          : 'Payment Confirmed';
    case TradeStatus.completed:
      return 'Trade Finished';
    case TradeStatus.cancelled:
      return 'Trade Canceled';
    case TradeStatus.disputed:
      return 'Needs Support Review';
    case TradeStatus.expired:
      return 'Time Ran Out';
    default:
      return 'Unknown Status';
  }
}

String _resolveTradeProofUrl(String raw) {
  final v = raw.trim();
  if (v.isEmpty) return '';
  if (v.startsWith('http://') || v.startsWith('https://')) return v;
  final base = centralized_baseUrl.replaceFirst(RegExp(r'/api/v1/?$'), '');
  if (v.startsWith('/')) return '$base$v';
  return '$base/$v';
}

String _extractTradeProofFileUrl(Map<String, dynamic> row) {
  String read(dynamic value) => value == null ? '' : value.toString().trim();

  for (final key in const [
    'fileUrl',
    'file_url',
    'url',
    'proofUrl',
    'proof_url',
    'imageUrl',
    'image_url',
    'attachmentUrl',
    'attachment_url',
    'location',
    'path',
  ]) {
    final v = read(row[key]);
    if (v.isNotEmpty) return v;
  }

  final nested = row['file'];
  if (nested is Map<String, dynamic>) {
    for (final key in const [
      'url',
      'fileUrl',
      'file_url',
      'location',
      'path',
    ]) {
      final v = read(nested[key]);
      if (v.isNotEmpty) return v;
    }
  }

  return '';
}

// ─── Main screen ──────────────────────────────────────────────────────────────

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
  static String _chatLastSeenKey(String tradeId) =>
      'trade.chat.last_seen.$tradeId';

  late TradeModel _trade;
  String? _currentUserId;
  bool _refreshing = false;
  bool _actionLoading = false;
  String? _actionError;
  bool _isOnline = true;
  bool _lockPendingVerification = false;
  bool _uploadingFiatProof = false;
  bool _proofsLoading = false;
  List<Map<String, dynamic>> _proofs = const [];
  int _unreadMessages = 0;
  bool _hasAutoOpenedProofModal = false;
  double? _activeAssetBalance;
  bool _balanceLoading = false;
  String? _balanceError;
  late final StreamSubscription<List<ConnectivityResult>> _connectivitySub;

  Timer? _countdownTimer;
  Duration _timeLeft = Duration.zero;
  Timer? _pollTimer;

  // ── Role helpers ─────────────────────────────────────────────────────────

  bool get _isUserBuyer =>
      _currentUserId != null && _trade.buyerId == _currentUserId;
  bool get _isUserSeller =>
      _currentUserId != null && _trade.sellerId == _currentUserId;

  bool get _isUserEscrowLocker {
    if (_trade.offerType == TradeOfferType.sell) return _isUserSeller;
    if (_trade.offerType == TradeOfferType.buy) return _isUserBuyer;
    return _isUserSeller;
  }

  bool get _isUserFiatPayer {
    if (_trade.offerType == TradeOfferType.sell) return _isUserBuyer;
    if (_trade.offerType == TradeOfferType.buy) return _isUserSeller;
    return _isUserBuyer;
  }

  bool get _isUserCryptoReceiver {
    if (_trade.offerType == TradeOfferType.sell) return _isUserBuyer;
    if (_trade.offerType == TradeOfferType.buy) return _isUserSeller;
    return _isUserBuyer;
  }

  bool get _isBuyingCrypto => _isUserCryptoReceiver;

  String? get _merchantUserId {
    String read(dynamic v) => v == null ? '' : v.toString().trim();

    final fromWidgetOfferId = read(widget.offer?.sellerId);
    if (fromWidgetOfferId.isNotEmpty) return fromWidgetOfferId;

    final fromWidgetOfferMap = widget.offer?.seller;
    if (fromWidgetOfferMap != null) {
      final nested = read(
        fromWidgetOfferMap['id'] ??
            fromWidgetOfferMap['userId'] ??
            fromWidgetOfferMap['user_id'],
      );
      if (nested.isNotEmpty) return nested;
    }

    final tradeOffer = _trade.offer;
    if (tradeOffer != null) {
      final fromTradeOffer = read(
        tradeOffer['sellerId'] ?? tradeOffer['seller_id'],
      );
      if (fromTradeOffer.isNotEmpty) return fromTradeOffer;
      final tradeSeller = tradeOffer['seller'];
      if (tradeSeller is Map) {
        final nested = read(
          tradeSeller['id'] ?? tradeSeller['userId'] ?? tradeSeller['user_id'],
        );
        if (nested.isNotEmpty) return nested;
      }
    }

    return null;
  }

  bool get _isParticipant => _isUserBuyer || _isUserSeller;

  bool get _canUploadFiatProofFromPanel {
    if (!_isParticipant || !_isUserFiatPayer) return false;
    if (_trade.status == TradeStatus.completed ||
        _trade.status == TradeStatus.cancelled ||
        _trade.status == TradeStatus.expired) {
      return false;
    }
    return _trade.status == TradeStatus.cryptoLocked ||
        _trade.status == TradeStatus.fiatSent ||
        _trade.status == TradeStatus.fiatConfirmed ||
        _trade.status == TradeStatus.disputed;
  }

  bool _isFiatProof(Map<String, dynamic> row) {
    String read(List<String> keys) {
      for (final key in keys) {
        final v = row[key];
        if (v == null) continue;
        final text = v.toString().trim();
        if (text.isNotEmpty) return text;
      }
      return '';
    }

    final type = read(const [
      'type',
      'proofType',
      'proof_type',
      'category',
      'kind',
      'label',
    ]).toUpperCase();
    if (type.contains('FIAT')) return true;
    if (type.contains('CRYPTO')) return false;
    // Backward compatibility for proofs created before type metadata.
    return true;
  }

  bool get _hasFiatProof => _proofs.any(_isFiatProof);

  String? get _disputeId {
    final id = _trade.disputeId?.trim() ?? '';
    return id.isEmpty ? null : id;
  }

  String? _buildDisputeEvidenceNote(TradeProofPickResult config) {
    final parts = <String>[];
    final type = config.type.trim().toUpperCase();
    if (type.isNotEmpty) parts.add('Type: $type');
    final ref = (config.referenceNo ?? '').trim();
    if (ref.isNotEmpty) parts.add('Reference: $ref');
    final tx = (config.txHash ?? '').trim();
    if (tx.isNotEmpty) parts.add('TxHash: $tx');
    if (parts.isEmpty) return null;
    return parts.join(' | ');
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _trade = widget.trade;
    WidgetsBinding.instance.addObserver(this);
    _startConnectivityMonitor();
    _startCountdown();
    _startPolling();
    _loadCurrentUserId();
    unawaited(_loadProofs(silent: true));
    unawaited(_refreshUnreadMessages(silent: true));
    unawaited(_refreshActiveAssetBalance(silent: true));
  }

  Future<void> _loadCurrentUserId() async {
    try {
      final user = await AuthService().currentUser;
      if (mounted) setState(() => _currentUserId = user.id);
      unawaited(_refreshActiveAssetBalance(silent: true));
      unawaited(_refreshUnreadMessages(silent: true));
    } catch (_) {}
  }

  Asset _tradeStellarAsset(StellarWalletServices stellarSvc) {
    final assetCode = _trade.asset.toUpperCase();
    return switch (assetCode) {
      'XLM' => Asset.NATIVE,
      'USDC' => AssetTypeCreditAlphaNum4('USDC', stellarSvc.usdcIssuer),
      _ => throw Exception('Unsupported token: $assetCode'),
    };
  }

  Future<void> _refreshActiveAssetBalance({bool silent = true}) async {
    if (!mounted) return;
    if (!_isUserEscrowLocker || _trade.status != TradeStatus.created) {
      setState(() {
        _activeAssetBalance = null;
        _balanceLoading = false;
        _balanceError = null;
      });
      return;
    }
    setState(() {
      _balanceLoading = true;
      if (!silent) _balanceError = null;
    });
    try {
      final stellarSvc = context.read<StellarWalletServices>();
      final seedVM = context.read<SeedKeypairVM>();
      final kp = await seedVM.deriveKeyPair();
      final balance = await stellarSvc.accountService.getAssetBalance(
        kp.accountId,
        _tradeStellarAsset(stellarSvc),
      );
      if (!mounted) return;
      setState(() {
        _activeAssetBalance = balance;
        _balanceLoading = false;
        _balanceError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _balanceLoading = false;
        _balanceError = e.toString();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub.cancel();
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
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
      if (online && wasOffline && _trade.status.isActive) {
        _refresh(silent: true);
      }
    });
  }

  void _startCountdown() {
    final deadline = _resolveCountdownDeadline();
    if (deadline == null) {
      _countdownTimer?.cancel();
      if (mounted) setState(() => _timeLeft = Duration.zero);
      return;
    }
    _updateTimeLeft(deadline);
  }

  DateTime? _resolveCountdownDeadline() {
    if (_trade.status == TradeStatus.disputed) {
      final disputeStart =
          _trade.updatedAt ??
          _trade.fiatConfirmDueAt ??
          _trade.fiatSentAt ??
          _trade.createdAt;
      if (disputeStart == null) return null;
      return disputeStart.add(const Duration(hours: 24));
    }
    final expires = _trade.expiresAt;
    if (expires != null) return expires;
    final created = _trade.createdAt;
    final window = _trade.paymentWindowMinutes;
    if (created != null && window != null) {
      return created.add(Duration(minutes: window));
    }
    return null;
  }

  void _updateTimeLeft(DateTime deadline) {
    final left = deadline.difference(DateTime.now());
    setState(() => _timeLeft = left.isNegative ? Duration.zero : left);
    if (_timeLeft > Duration.zero) {
      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final updated = deadline.difference(DateTime.now());
        setState(
          () => _timeLeft = updated.isNegative ? Duration.zero : updated,
        );
        if (_timeLeft == Duration.zero) _countdownTimer?.cancel();
      });
    }
  }

  void _startPolling() {
    if (!_trade.status.isActive) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_trade.status.isActive) {
        _refresh(silent: true);
      } else {
        _pollTimer?.cancel();
      }
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
        final hasEscrowId =
            (_trade.escrow?.claimableBalanceId?.trim().isNotEmpty ?? false);
        if (hasEscrowId || _trade.status != TradeStatus.created) {
          _lockPendingVerification = false;
        }
        if (!_trade.status.isActive) _pollTimer?.cancel();
      });
      _startCountdown();
      await _refreshActiveAssetBalance(silent: true);
      await _loadProofs(silent: true);
      await _refreshUnreadMessages(silent: true);
    } catch (_) {
      if (!mounted) return;
      if (!silent) setState(() => _refreshing = false);
    }
  }

  Future<void> _loadProofs({bool silent = false}) async {
    if (_proofsLoading) return;
    if (!silent && mounted) {
      setState(() => _proofsLoading = true);
    } else {
      _proofsLoading = true;
    }
    try {
      final proofs = await _tradesCore.getTradeProofs(_trade.id);
      final merged = List<Map<String, dynamic>>.from(proofs);
      if (_trade.status == TradeStatus.disputed && _disputeId != null) {
        try {
          final evidence = await _tradesCore.getDisputeEvidence(_disputeId!);
          for (final row in evidence) {
            final mapped = Map<String, dynamic>.from(row);
            mapped.putIfAbsent('type', () => 'EVIDENCE');
            merged.add(mapped);
          }
        } catch (_) {
          // Keep trade proofs visible even if dispute evidence list fails.
        }
      }
      merged.sort((a, b) {
        DateTime? parse(Map<String, dynamic> row) {
          final raw =
              row['createdAt'] ??
              row['created_at'] ??
              row['updatedAt'] ??
              row['updated_at'];
          return raw == null ? null : DateTime.tryParse(raw.toString());
        }

        final ad = parse(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = parse(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });
      if (!mounted) return;
      setState(() {
        _proofs = merged;
        _proofsLoading = false;
      });
      _maybeAutoOpenPaymentProofModal();
    } catch (_) {
      if (!mounted) return;
      setState(() => _proofsLoading = false);
    } finally {
      _proofsLoading = false;
    }
  }

  String _firstProofImageUrl(List<Map<String, dynamic>> proofs) {
    for (final row in proofs) {
      final raw = _extractTradeProofFileUrl(row);
      final resolved = _resolveTradeProofUrl(raw);
      if (resolved.isNotEmpty) return resolved;
    }
    return '';
  }

  void _openProofModalFromRow(Map<String, dynamic> row) {
    final imageUrl = _resolveTradeProofUrl(_extractTradeProofFileUrl(row));
    if (imageUrl.isEmpty) return;
    final type = (row['type'] ?? '').toString().trim().toUpperCase();
    final title = type.isEmpty ? 'Payment Proof' : '$type Proof';
    unawaited(
      showPaymentProofViewModal(
        context,
        colors: AppColor.of(context),
        imageUrl: imageUrl,
        title: title,
      ),
    );
  }

  void _openLatestProofModal() {
    if (_proofs.isEmpty || !mounted) return;
    final latestWithImage = _proofs.firstWhere(
      (row) => _resolveTradeProofUrl(_extractTradeProofFileUrl(row)).isNotEmpty,
      orElse: () => const <String, dynamic>{},
    );
    if (latestWithImage.isEmpty) {
      showFloatingSnackBar(
        context,
        message: 'No proof image is available to preview yet.',
        type: SnackBarType.info,
      );
      return;
    }
    _openProofModalFromRow(latestWithImage);
  }

  void _maybeAutoOpenPaymentProofModal() {
    if (_hasAutoOpenedProofModal || !mounted) return;
    final imageUrl = _firstProofImageUrl(_proofs);
    if (imageUrl.isEmpty) return;
    _hasAutoOpenedProofModal = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        showPaymentProofViewModal(
          context,
          colors: AppColor.of(context),
          imageUrl: imageUrl,
          title: 'Payment Proof',
        ),
      );
    });
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _lockCrypto() async {
    if (_lockPendingVerification) {
      showFloatingSnackBar(
        context,
        message:
            'Your lock is still being checked. Please refresh in a few seconds.',
        type: SnackBarType.warning,
      );
      return;
    }
    final ok = await _showConfirm(
      title: 'Lock ${_trade.asset.toUpperCase()} to Start',
      body:
          'You are about to lock ${_trade.asset} for this trade. '
          'It will be released after payment is confirmed. '
          'If time runs out, it comes back to your wallet automatically.',
      confirmLabel: 'Lock Now',
    );
    if (!ok) return;

    _runAction(
      () async {
        await _refresh(silent: true);
        if (!mounted) return;
        final hasEscrowId =
            (_trade.escrow?.claimableBalanceId?.trim().isNotEmpty ?? false);
        if (_trade.status != TradeStatus.created || hasEscrowId) {
          throw Exception(
            'This trade may already be locked. Please refresh and try again.',
          );
        }

        final stellarSvc = context.read<StellarWalletServices>();
        final seedVM = context.read<SeedKeypairVM>();
        final kp = await seedVM.deriveKeyPair();
        final asset = _tradeStellarAsset(stellarSvc);
        final liveBalance = await stellarSvc.accountService.getAssetBalance(
          kp.accountId,
          asset,
        );
        setState(() {
          _activeAssetBalance = liveBalance;
          _balanceError = null;
        });
        if (liveBalance < _trade.cryptoAmount) {
          throw Exception(
            'Not enough balance in your wallet. '
            'Available: ${liveBalance.toStringAsFixed(6)} ${_trade.asset.toUpperCase()}, '
            'Required: ${_trade.cryptoAmount.toStringAsFixed(6)} ${_trade.asset.toUpperCase()}.',
          );
        }

        final recipientAddress = _trade.cryptoReceiverAddress.trim();
        if (recipientAddress.isEmpty) {
          throw Exception(
            'Wallet address is missing. Please refresh and try again.',
          );
        }
        if (!RegExp(r'^G[A-Z2-7]{55}$').hasMatch(recipientAddress)) {
          throw Exception('Wallet address format is not valid.');
        }

        final expiry =
            _trade.expiresAt ?? DateTime.now().add(const Duration(hours: 24));
        final txHash = await stellarSvc.claimableBalanceService
            .createUnconditionalWithExpiry(
              keyPair: kp,
              asset: asset,
              amount: _trade.cryptoAmount,
              recipientId: recipientAddress,
              expiryTime: expiry,
            );

        final cbId = await _resolveClaimableBalanceId(
          stellarSvc: stellarSvc,
          txHash: txHash,
        );

        if (cbId == null || cbId.isEmpty) {
          if (mounted) setState(() => _lockPendingVerification = true);
          throw Exception(
            'Your lock was sent, but it is still updating. Please refresh and try again in a moment.',
          );
        }

        final u = await _tradesCore.lockCrypto(
          _trade.id,
          claimableBalanceId: cbId,
          createTxHash: txHash,
        );
        if (mounted) setState(() => _trade = u);
      },
      successMsg:
          '${_trade.asset.toUpperCase()} locked. The other person has been notified.',
    );
  }

  Future<String?> _resolveClaimableBalanceId({
    required StellarWalletServices stellarSvc,
    required String txHash,
  }) async {
    // Horizon may index transaction effects with a short delay.
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        final effectsPage = await stellarSvc.sdk.effects
            .forTransaction(txHash)
            .limit(200)
            .execute();
        for (final effect in effectsPage.records) {
          if (effect is ClaimableBalanceCreatedEffectResponse) {
            final id = effect.balanceId.trim();
            if (id.isNotEmpty) return id;
          }
        }
      } catch (_) {}
      await Future.delayed(Duration(milliseconds: 800 + (attempt * 400)));
    }
    return null;
  }

  Future<void> _markFiatSent() async {
    final ok = await _showConfirm(
      title: 'Confirm Payment Sent',
      body:
          'Have you already sent the ${_trade.fiatCurrency} payment? '
          'This cannot be undone and notifies the other party.',
      confirmLabel: "Yes, I've paid",
    );
    if (!ok) return;
    _runAction(() async {
      String? uploadedProofUrl;
      final proof = await _showProofPickSheet();
      if (proof != null) {
        uploadedProofUrl = await _tradesCore.uploadProof(
          _trade.id,
          file: proof,
          type: 'FIAT',
        );
      }
      final u = uploadedProofUrl != null && uploadedProofUrl.trim().isNotEmpty
          ? await _tradesCore.markFiatSentWithProof(
              _trade.id,
              proofUrls: [uploadedProofUrl.trim()],
            )
          : await _tradesCore.markFiatSent(_trade.id);
      if (mounted) setState(() => _trade = u);
      await _loadProofs(silent: true);
      if (!mounted) return;
      if (uploadedProofUrl == null || uploadedProofUrl.trim().isEmpty) {
        showFloatingSnackBar(
          context,
          message:
              'Please upload your payment screenshot before this trade can finish.',
          type: SnackBarType.warning,
        );
      }
    }, successMsg: 'Marked as paid. Waiting for confirmation.');
  }

  Future<void> _uploadFiatProofFromPanel() async {
    final canUploadFromPanel = _trade.status == TradeStatus.disputed
        ? _isParticipant
        : _canUploadFiatProofFromPanel;
    if (!canUploadFromPanel || _uploadingFiatProof) return;
    setState(() => _uploadingFiatProof = true);
    try {
      if (_trade.status == TradeStatus.disputed) {
        final config = await showModalBottomSheet<TradeProofPickResult>(
          context: context,
          backgroundColor: AppColor.of(context).surface,
          builder: (_) =>
              UploadDisputeEvidenceModal(colors: AppColor.of(context)),
        );
        if (config == null || !mounted) return;
        final file = await ImagePicker().pickImage(source: config.source);
        if (file == null || !mounted) return;
        String? disputeId = _disputeId;
        if (disputeId == null) {
          await _refresh(silent: true);
          disputeId = _disputeId;
        }
        if (disputeId == null) {
          throw Exception(
            'Dispute ID is missing from trade data. Please refresh. '
            'If it still fails, backend must include dispute.id in trade response.',
          );
        }
        await _tradesCore.uploadDisputeEvidence(
          disputeId,
          file: File(file.path),
          note: _buildDisputeEvidenceNote(config),
        );
      } else {
        final proof = await _showProofPickSheet(forceUpload: true);
        if (proof == null || !mounted) return;
        await _tradesCore.uploadProof(_trade.id, file: proof, type: 'FIAT');
      }
      await _loadProofs(silent: true);
      if (mounted) {
        showFloatingSnackBar(
          context,
          message: _trade.status == TradeStatus.disputed
              ? 'File uploaded'
              : 'Payment screenshot uploaded',
          type: SnackBarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        showFloatingSnackBar(
          context,
          message: 'Could not upload screenshot: $e',
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingFiatProof = false);
    }
  }

  DateTime? _readMessageTime(Map<String, dynamic> row) {
    final raw =
        row['createdAt'] ??
        row['created_at'] ??
        row['updatedAt'] ??
        row['updated_at'];
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  String _readMessageSenderId(Map<String, dynamic> row) {
    String read(dynamic v) => v == null ? '' : v.toString().trim();
    final direct = read(
      row['senderId'] ??
          row['sender_id'] ??
          row['senderUserId'] ??
          row['sender_user_id'] ??
          row['userId'] ??
          row['user_id'] ??
          row['authorId'] ??
          row['author_id'],
    );
    if (direct.isNotEmpty) return direct;
    final sender = row['sender'];
    if (sender is Map) {
      final nested = read(
        sender['id'] ?? sender['userId'] ?? sender['user_id'],
      );
      if (nested.isNotEmpty) return nested;
    }
    return '';
  }

  Future<void> _markTradeChatRead([DateTime? at]) async {
    try {
      await SecurityStorage.save(
        _chatLastSeenKey(_trade.id),
        (at ?? DateTime.now()).toUtc().toIso8601String(),
      );
      if (mounted) setState(() => _unreadMessages = 0);
    } catch (_) {}
  }

  Future<void> _refreshUnreadMessages({bool silent = false}) async {
    if (!_isParticipant || _currentUserId == null || _trade.status.isTerminal) {
      if (mounted && _unreadMessages != 0) {
        setState(() => _unreadMessages = 0);
      }
      return;
    }

    try {
      final rawSeen = await SecurityStorage.read(_chatLastSeenKey(_trade.id));
      final seenAt = rawSeen == null || rawSeen.trim().isEmpty
          ? null
          : DateTime.tryParse(rawSeen.trim())?.toUtc();
      final messages = await _tradesCore.getTradeMessages(_trade.id);
      var unread = 0;
      for (final row in messages) {
        final senderId = _readMessageSenderId(row);
        if (senderId.isEmpty || senderId == _currentUserId) continue;
        final t = _readMessageTime(row)?.toUtc();
        if (t == null) continue;
        if (seenAt == null || t.isAfter(seenAt)) unread++;
      }
      if (!mounted) return;
      setState(() => _unreadMessages = unread);
    } catch (_) {
      if (!silent) {
        // Ignore unread refresh failures silently in polling mode.
      }
    }
  }

  Future<void> _confirmFiat() async {
    final cryptoRecipientLabel = _trade.offerType == TradeOfferType.sell
        ? 'buyer'
        : 'seller';
    final ok = await _showConfirm(
      title: 'Confirm You Got Paid',
      body:
          'Have you received the full ${_trade.fiatCurrency.toUpperCase()} payment? '
          'This will release ${_trade.asset.toUpperCase()} to the $cryptoRecipientLabel.',
      confirmLabel: 'Yes, I got it',
    );
    if (!ok) return;
    _runAction(
      () async {
        final u = await _tradesCore.confirmFiat(_trade.id);
        if (mounted) setState(() => _trade = u);
      },
      successMsg:
          'Payment confirmed. ${_trade.asset.toUpperCase()} is being released.',
    );
  }

  Future<void> _claimCrypto() async {
    final cbId = _trade.escrow?.claimableBalanceId;
    if (cbId == null || cbId.trim().isEmpty) {
      showFloatingSnackBar(
        context,
        message: 'Lock ID not ready yet. Please refresh and try again.',
        type: SnackBarType.error,
      );
      return;
    }
    final ok = await _showConfirm(
      title: 'Receive Your ${_trade.asset.toUpperCase()}',
      body:
          'Receive ${_trade.cryptoAmount.toStringAsFixed(4)} ${_trade.asset} in your wallet.',
      confirmLabel: 'Receive ${_trade.asset.toUpperCase()}',
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
    }, successMsg: '${_trade.asset.toUpperCase()} received in your wallet.');
  }

  Future<void> _refundCrypto() async {
    final cbId = _trade.escrow?.claimableBalanceId;
    if (cbId == null || cbId.trim().isEmpty) {
      showFloatingSnackBar(
        context,
        message: 'Nothing to return right now.',
        type: SnackBarType.error,
      );
      return;
    }
    final ok = await _showConfirm(
      title: 'Return ${_trade.asset.toUpperCase()}',
      body:
          'Time ran out for this trade. Return your '
          '${_trade.cryptoAmount.toStringAsFixed(4)} ${_trade.asset} back to your wallet.',
      confirmLabel: 'Return ${_trade.asset.toUpperCase()}',
    );
    if (!ok) return;
    _runAction(() async {
      final stellarSvc = context.read<StellarWalletServices>();
      final seedVM = context.read<SeedKeypairVM>();
      final kp = await seedVM.deriveKeyPair();
      final refundTx = await stellarSvc.claimableBalanceService
          .claimClaimableBalance(keyPair: kp, balanceId: cbId);
      final u = await _tradesCore.refundCrypto(
        _trade.id,
        refundTxHash: refundTx,
      );
      if (mounted) setState(() => _trade = u);
    }, successMsg: '${_trade.asset.toUpperCase()} returned to your wallet.');
  }

  Future<void> _cancelTrade() async {
    final ok = await _showConfirm(
      title: 'Cancel Trade',
      body:
          'Are you sure? Any locked ${_trade.asset.toUpperCase()} will return to the original wallet automatically.',
      confirmLabel: 'Yes, cancel',
      isDestructive: true,
    );
    if (!ok) return;
    _runAction(() async {
      final u = await _tradesCore.cancelTrade(
        _trade.id,
        reason: 'User cancelled',
      );
      if (mounted) setState(() => _trade = u);
    }, successMsg: 'Trade canceled');
  }

  Future<void> _navigateToMessages() async {
    if (!(_isUserBuyer || _isUserSeller)) {
      showFloatingSnackBar(
        context,
        message: 'Only the two people in this trade can open this chat.',
        type: SnackBarType.error,
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TradeMessagesScreen(trade: _trade)),
    );
    await _markTradeChatRead();
    await _refreshUnreadMessages(silent: true);
  }

  Future<File?> _showProofPickSheet({bool forceUpload = false}) async {
    final pick = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColor.of(context).surface,
      builder: (_) => TradeProofPickSheet(
        colors: AppColor.of(context),
        forceUpload: forceUpload,
      ),
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
    setState(() {
      _actionLoading = true;
      _actionError = null;
    });
    try {
      await action();
      if (mounted) {
        showFloatingSnackBar(
          context,
          message: successMsg,
          type: SnackBarType.success,
        );
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll(
        RegExp(r'TradeApiException\(\d+\): '),
        '',
      );
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
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColor.of(context).surface,
      isScrollControlled: true,
      builder: (_) => TradeConfirmSheet(
        title: title,
        body: body,
        confirmLabel: confirmLabel,
        isDestructive: isDestructive,
        colors: AppColor.of(context),
      ),
    );
    return result ?? false;
  }

  Future<bool> _onWillPop() async {
    final leave = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColor.of(context).surface,
      builder: (_) => TradeConfirmSheet(
        title: 'Leave Trade Room?',
        body: 'Your trade is active. Return any time from Trade History.',
        confirmLabel: 'Leave',
        isDestructive: false,
        colors: AppColor.of(context),
      ),
    );
    return leave ?? false;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final s = _trade.status;

    return PopScope(
      canPop: !_trade.status.isActive,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && _trade.status.isActive) {
          final leave = await _onWillPop();
          if (leave && context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        extendBodyBehindAppBar: true,
        appBar: _buildAppBar(colors),
        body: RefreshIndicator(
          onRefresh: _refresh,
          color: colors.primary,
          backgroundColor: colors.surface,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              12,
              MediaQuery.of(context).padding.top + 66,
              12,
              124,
            ),
            children: [
              if (!_isOnline) ...[
                _ConnectivityBanner(colors: colors),
                const SizedBox(height: 10),
              ],

              _HeroCard(
                trade: _trade,
                isBuyingCrypto: _isBuyingCrypto,
                isUserSeller: _isUserSeller,
                isUserBuyer: _isUserBuyer,
                isUserEscrowLocker: _isUserEscrowLocker,
                isUserFiatPayer: _isUserFiatPayer,
                isUserCryptoReceiver: _isUserCryptoReceiver,
                colors: colors,
              ),
              const SizedBox(height: 8),
              _TimelineCard(
                trade: _trade,
                isUserBuyer: _isUserBuyer,
                showViewProof: _proofs.isNotEmpty,
                onViewProof: _openLatestProofModal,
                colors: colors,
              ),
              const SizedBox(height: 8),

              if (s == TradeStatus.created && _isUserEscrowLocker) ...[
                _EscrowSenderCard(
                  trade: _trade,
                  colors: colors,
                  isCryptoReceiverBuyer:
                      _trade.offerType == TradeOfferType.sell,
                  activeBalance: _activeAssetBalance,
                  balanceLoading: _balanceLoading,
                  balanceError: _balanceError,
                  onRefreshBalance: () =>
                      unawaited(_refreshActiveAssetBalance(silent: false)),
                  onLock: _lockCrypto,
                  loading: _actionLoading,
                ),
                const SizedBox(height: 8),
              ],

              if (s == TradeStatus.created && !_isUserEscrowLocker) ...[
                _WaitingForEscrowCard(colors: colors, trade: _trade),
                const SizedBox(height: 8),
              ],

              if (s == TradeStatus.cryptoLocked && _isUserFiatPayer) ...[
                _PaymentInstructionsCard(trade: _trade, colors: colors),
                const SizedBox(height: 10),
                _PaymentProofCard(
                  colors: colors,
                  hasProof: _hasFiatProof,
                  uploading: _uploadingFiatProof,
                  onUpload: _uploadFiatProofFromPanel,
                ),
                const SizedBox(height: 8),
              ],

              if (s == TradeStatus.fiatSent && _isUserFiatPayer) ...[
                _PaymentProofCard(
                  colors: colors,
                  hasProof: _hasFiatProof,
                  uploading: _uploadingFiatProof,
                  onUpload: _uploadFiatProofFromPanel,
                ),
                const SizedBox(height: 8),
              ],

              if (s == TradeStatus.fiatSent && !_isUserFiatPayer) ...[
                _FiatSentNoticeCard(
                  trade: _trade,
                  colors: colors,
                  isBuyerFiatSender: _trade.offerType == TradeOfferType.sell,
                ),
                const SizedBox(height: 8),
              ],

              if (s == TradeStatus.fiatSent && _isUserFiatPayer) ...[
                _WaitingConfirmationCard(
                  trade: _trade,
                  colors: colors,
                  isSellerVerifier: _trade.offerType == TradeOfferType.sell,
                ),
                const SizedBox(height: 8),
              ],

              if (_actionError != null) ...[
                _ErrorBanner(message: _actionError!, colors: colors),
                const SizedBox(height: 10),
              ],

              if (s == TradeStatus.completed)
                _CompletedCard(
                  trade: _trade,
                  colors: colors,
                  isBuyingCrypto: _isBuyingCrypto,
                  currentUserId: _currentUserId,
                  merchantUserId: _merchantUserId,
                ),
              if (s == TradeStatus.cancelled) _CancelledCard(colors: colors),
              if (s == TradeStatus.disputed) ...[_DisputedCard(colors: colors)],
            ],
          ),
        ),
        bottomNavigationBar: _BottomActions(
          trade: _trade,
          isParticipant: _isUserBuyer || _isUserSeller,
          isUserBuyer: _isUserBuyer,
          isUserSeller: _isUserSeller,
          isUserEscrowLocker: _isUserEscrowLocker,
          isUserFiatPayer: _isUserFiatPayer,
          isUserCryptoReceiver: _isUserCryptoReceiver,
          loading: _actionLoading,
          onLockCrypto: _lockCrypto,
          onMarkFiatSent: _markFiatSent,
          onConfirmFiat: _confirmFiat,
          onClaimCrypto: _claimCrypto,
          onCancel: _cancelTrade,
          onRefund: _refundCrypto,
          onUploadFiatProof: _uploadFiatProofFromPanel,
          onMessages: _navigateToMessages,
          lockPendingVerification: _lockPendingVerification,
          showUploadFiatProof:
              _canUploadFiatProofFromPanel ||
              (_isParticipant && _trade.status == TradeStatus.disputed),
          unreadMessages: _unreadMessages,
          uploadingFiatProof: _uploadingFiatProof,
          colors: colors,
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppColor colors) {
    final showHeaderTimer = _trade.status.isActive && _timeLeft > Duration.zero;
    final timerLabel = _trade.status == TradeStatus.disputed
        ? 'Dispute time'
        : 'Trade time';
    return AppBar(
      backgroundColor: colors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      leadingWidth: 50,
      leading: Padding(
        padding: const EdgeInsets.only(left: 10),
        child: _GlassIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          colors: colors,
          onTap: () => Navigator.maybePop(context),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trade Room',
            style: GoogleFonts.sora(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          Text(
            _trade.id.length > 16
                ? '${_trade.id.substring(0, 12)}…${_trade.id.substring(_trade.id.length - 4)}'
                : _trade.id,
            style: GoogleFonts.sora(fontSize: 10, color: colors.textSecondary),
          ),
        ],
      ),
      actions: [
        if (showHeaderTimer)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _HeaderCountdownChip(
              label: timerLabel,
              value: _formatHeaderCountdown(_timeLeft),
              colors: colors,
            ),
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  String _formatHeaderCountdown(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    if (h > 0) return '${h.toString().padLeft(2, '0')}:$mm:$ss';
    return '$mm:$ss';
  }
}

// ─── Glass icon button ────────────────────────────────────────────────────────

class _HeaderCountdownChip extends StatelessWidget {
  const _HeaderCountdownChip({
    required this.label,
    required this.value,
    required this.colors,
  });

  final String label;
  final String value;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 170),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 14, color: colors.textSecondary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '$label $value',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.sora(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.onTap,
    required this.colors,
  });
  final IconData icon;
  final VoidCallback onTap;
  final AppColor colors;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(11),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, color: colors.textSecondary, size: 17),
    ),
  );
}

// ─── Connectivity banner ──────────────────────────────────────────────────────

class _ConnectivityBanner extends StatelessWidget {
  const _ConnectivityBanner({required this.colors});
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    final amber = AppColor.of(context).warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: amber, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No Connection',
                  style: GoogleFonts.sora(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: amber,
                  ),
                ),
                Text(
                  'Trade is safe. Updates resume when reconnected.',
                  style: GoogleFonts.sora(
                    fontSize: 10.5,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Hero card ────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.trade,
    required this.isBuyingCrypto,
    required this.isUserSeller,
    required this.isUserBuyer,
    required this.isUserEscrowLocker,
    required this.isUserFiatPayer,
    required this.isUserCryptoReceiver,
    required this.colors,
  });
  final TradeModel trade;
  final bool isBuyingCrypto;
  final bool isUserSeller;
  final bool isUserBuyer;
  final bool isUserEscrowLocker;
  final bool isUserFiatPayer;
  final bool isUserCryptoReceiver;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    final accent = _statusAccent(trade.status, colors);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.045),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    _statusIcon(trade.status),
                    color: accent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _statusLabel(
                          trade.status,
                          isUserEscrowLocker: isUserEscrowLocker,
                          isUserFiatPayer: isUserFiatPayer,
                          isUserCryptoReceiver: isUserCryptoReceiver,
                          assetCode: trade.asset,
                        ),
                        style: GoogleFonts.sora(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: trade.id));
                          showFloatingSnackBar(
                            context,
                            message: 'Trade ID copied',
                            type: SnackBarType.success,
                          );
                        },
                        child: Row(
                          children: [
                            Text(
                              'ID: ',
                              style: GoogleFonts.sora(
                                fontSize: 9,
                                color: colors.textSecondary,
                              ),
                            ),
                            Text(
                              trade.id.length > 14
                                  ? '${trade.id.substring(0, 10)}…'
                                  : trade.id,
                              style: GoogleFonts.sora(
                                fontSize: 9.5,
                                color: colors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.copy_all_rounded,
                              size: 11,
                              color: colors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // BUYING/SELLING pill — solid accent
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isBuyingCrypto ? 'BUYING' : 'SELLING',
                    style: GoogleFonts.sora(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColor.of(context).onPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            Divider(color: colors.border.withValues(alpha: 0.8), height: 1),
            const SizedBox(height: 14),

            // Amounts
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isBuyingCrypto ? 'YOU RECEIVE' : 'YOU SEND',
                        style: GoogleFonts.sora(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: colors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            trade.cryptoAmount.toStringAsFixed(4),
                            style: GoogleFonts.sora(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(
                              trade.asset,
                              style: GoogleFonts.sora(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isBuyingCrypto ? 'YOU PAY' : 'YOU RECEIVE',
                      style: GoogleFonts.sora(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: colors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      trade.fiatAmount.toStringAsFixed(2),
                      style: GoogleFonts.sora(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      trade.fiatCurrency.toUpperCase(),
                      style: GoogleFonts.sora(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Countdown card ───────────────────────────────────────────────────────────

class _EscrowSenderCard extends StatelessWidget {
  const _EscrowSenderCard({
    required this.trade,
    required this.colors,
    required this.isCryptoReceiverBuyer,
    required this.activeBalance,
    required this.balanceLoading,
    required this.balanceError,
    required this.onRefreshBalance,
    required this.onLock,
    required this.loading,
  });
  final TradeModel trade;
  final AppColor colors;
  final bool isCryptoReceiverBuyer;
  final double? activeBalance;
  final bool balanceLoading;
  final String? balanceError;
  final VoidCallback onRefreshBalance;
  final VoidCallback onLock;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final accent = colors.primary;
    final hasBalance = activeBalance != null;
    final enoughBalance = hasBalance && activeBalance! >= trade.cryptoAmount;
    final balanceAccent = enoughBalance ? colors.success : colors.error;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(Icons.lock_open_rounded, color: accent, size: 17),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Action Required',
                        style: GoogleFonts.sora(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        'Lock your ${trade.asset.toUpperCase()} to start this trade',
                        style: GoogleFonts.sora(
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'STEP 1',
                    style: GoogleFonts.sora(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColor.of(context).onPrimary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _EscrowStep(
                  num: '1',
                  text:
                      'Lock ${trade.cryptoAmount.toStringAsFixed(4)} ${trade.asset} for this trade',
                  colors: colors,
                  accent: accent,
                ),
                const SizedBox(height: 10),
                _EscrowStep(
                  num: '2',
                  text:
                      'The other party pays ${trade.fiatAmount.toStringAsFixed(2)} ${trade.fiatCurrency.toUpperCase()} to your payment account',
                  colors: colors,
                  accent: accent,
                ),
                const SizedBox(height: 10),
                _EscrowStep(
                  num: '3',
                  text:
                      'Confirm you got paid → ${trade.asset.toUpperCase()} is released to the ${isCryptoReceiverBuyer ? 'buyer' : 'seller'}',
                  colors: colors,
                  accent: accent,
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet_rounded,
                            size: 14,
                            color: colors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Your Active Wallet Balance',
                            style: GoogleFonts.sora(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          if (balanceLoading)
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.primary,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (hasBalance)
                        Text(
                          '${activeBalance!.toStringAsFixed(6)} ${trade.asset.toUpperCase()}',
                          style: GoogleFonts.sora(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: balanceAccent,
                          ),
                        )
                      else if (balanceError != null && balanceError!.isNotEmpty)
                        Text(
                          'Unable to fetch live balance.',
                          style: GoogleFonts.sora(
                            fontSize: 12,
                            color: colors.error,
                          ),
                        )
                      else
                        Text(
                          'Fetching live balance...',
                          style: GoogleFonts.sora(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        'Required: ${trade.cryptoAmount.toStringAsFixed(6)} ${trade.asset.toUpperCase()}',
                        style: GoogleFonts.sora(
                          fontSize: 11.5,
                          color: colors.textSecondary,
                        ),
                      ),
                      if (trade.asset.toUpperCase() == 'XLM') ...[
                        const SizedBox(height: 4),
                        Text(
                          'XLM available balance already excludes reserve.',
                          style: GoogleFonts.sora(
                            fontSize: 10.5,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                      if (hasBalance && !enoughBalance) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Not enough balance to lock this trade.',
                          style: GoogleFonts.sora(
                            fontSize: 11.5,
                            color: colors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (balanceError != null && balanceError!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: balanceLoading ? null : onRefreshBalance,
                          child: Text(
                            'Retry balance sync',
                            style: GoogleFonts.sora(
                              fontSize: 11.5,
                              color: colors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: loading ? null : onLock,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    height: 52,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: loading ? colors.border : accent,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Center(
                      child: loading
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColor.of(context).onPrimary,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.lock_rounded,
                                  color: AppColor.of(context).onPrimary,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Lock ${trade.asset.toUpperCase()} to Start',
                                  style: GoogleFonts.sora(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColor.of(context).onPrimary,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EscrowStep extends StatelessWidget {
  const _EscrowStep({
    required this.num,
    required this.text,
    required this.colors,
    required this.accent,
  });
  final String num;
  final String text;
  final AppColor colors;
  final Color accent;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 22,
        height: 22,
        margin: const EdgeInsets.only(top: 1),
        decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
        child: Center(
          child: Text(
            num,
            style: GoogleFonts.sora(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColor.of(context).onPrimary,
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          text,
          style: GoogleFonts.sora(
            fontSize: 13,
            color: colors.textSecondary,
            height: 1.4,
          ),
        ),
      ),
    ],
  );
}

// ─── Waiting for escrow card ──────────────────────────────────────────────────

class _WaitingForEscrowCard extends StatelessWidget {
  const _WaitingForEscrowCard({required this.colors, required this.trade});
  final AppColor colors;
  final TradeModel trade;

  @override
  Widget build(BuildContext context) {
    final amber = AppColor.of(context).warning;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(Icons.hourglass_empty_rounded, color: amber, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Waiting for Lock',
                  style: GoogleFonts.sora(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'The other person is locking ${trade.cryptoAmount.toStringAsFixed(4)} '
                  '${trade.asset}. Once done, you can send payment.',
                  style: GoogleFonts.sora(
                    fontSize: 12,
                    color: colors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Payment instructions card ────────────────────────────────────────────────

class _PaymentInstructionsCard extends StatelessWidget {
  const _PaymentInstructionsCard({required this.trade, required this.colors});
  final TradeModel trade;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    final blue = AppColor.of(context).primary;
    final payeeAccount = trade.offerType == TradeOfferType.sell
        ? trade.sellerPaymentAccount
        : trade.buyerPaymentAccount;
    final payeeLabel = trade.offerType == TradeOfferType.sell
        ? 'merchant'
        : 'user';
    final accountName = payeeAccount?['accountName']?.toString();
    final accountNo = payeeAccount?['accountNo']?.toString();
    final instructions = payeeAccount?['instructions']?.toString();

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.account_balance_rounded,
                    color: blue,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Send Payment To ${payeeLabel == 'merchant' ? 'Seller' : 'Buyer'}',
                  style: GoogleFonts.sora(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: blue,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'STEP 2',
                    style: GoogleFonts.sora(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: AppColor.of(context).onPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                if (accountName != null)
                  _DataRow(
                    label: 'Account Name',
                    value: accountName,
                    copyable: true,
                    colors: colors,
                  ),
                if (accountNo != null)
                  _DataRow(
                    label: 'Account No.',
                    value: accountNo,
                    copyable: true,
                    mono: true,
                    colors: colors,
                  ),
                if (instructions != null && instructions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: colors.textSecondary,
                          size: 13,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            instructions,
                            style: GoogleFonts.sora(
                              fontSize: 11.5,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (accountName == null && accountNo == null)
                  Text(
                    'Payment details not found. Contact the $payeeLabel via trade chat.',
                    style: GoogleFonts.sora(
                      fontSize: 12,
                      color: colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentProofCard extends StatelessWidget {
  const _PaymentProofCard({
    required this.colors,
    required this.hasProof,
    required this.uploading,
    required this.onUpload,
  });

  final AppColor colors;
  final bool hasProof;
  final bool uploading;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final accent = hasProof ? colors.success : colors.warning;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            hasProof ? Icons.verified_rounded : Icons.upload_file_rounded,
            color: accent,
            size: 17,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasProof
                  ? 'Payment screenshot uploaded. You can upload a new one anytime.'
                  : 'Upload your payment screenshot now. You can still add it later.',
              style: GoogleFonts.sora(
                fontSize: 11.5,
                color: colors.textPrimary,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: uploading ? null : onUpload,
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Center(
                child: uploading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColor.of(context).onPrimary,
                        ),
                      )
                    : Text(
                        hasProof ? 'Re-upload' : 'Upload Proof',
                        style: GoogleFonts.sora(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColor.of(context).onPrimary,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Fiat sent notice card ────────────────────────────────────────────────────

class _FiatSentNoticeCard extends StatelessWidget {
  const _FiatSentNoticeCard({
    required this.trade,
    required this.colors,
    required this.isBuyerFiatSender,
  });
  final TradeModel trade;
  final AppColor colors;
  final bool isBuyerFiatSender;

  @override
  Widget build(BuildContext context) {
    final green = AppColor.of(context).success;
    final red = AppColor.of(context).error;
    final dueAt = trade.fiatConfirmDueAt;
    final bool autoDisputeSoon =
        dueAt != null && dueAt.difference(DateTime.now()).inMinutes < 30;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(Icons.payments_rounded, color: green, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Has Been Sent',
                      style: GoogleFonts.sora(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'The ${isBuyerFiatSender ? 'buyer' : 'seller'} has marked payment as sent. '
                      'Please verify receipt in your payment account and confirm below.',
                      style: GoogleFonts.sora(
                        fontSize: 12,
                        color: colors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (autoDisputeSoon) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Support review will start automatically if not confirmed within '
                      '${dueAt.difference(DateTime.now()).inMinutes} min. '
                      'Check your account and confirm receipt now.',
                      style: GoogleFonts.sora(
                        fontSize: 11.5,
                        color: red,
                        height: 1.4,
                      ),
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

// ─── Waiting for confirmation card ───────────────────────────────────────────

class _WaitingConfirmationCard extends StatelessWidget {
  const _WaitingConfirmationCard({
    required this.trade,
    required this.colors,
    required this.isSellerVerifier,
  });
  final TradeModel trade;
  final AppColor colors;
  final bool isSellerVerifier;

  @override
  Widget build(BuildContext context) {
    final amber = AppColor.of(context).warning;
    final dueAt = trade.fiatConfirmDueAt;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.hourglass_top_rounded,
                  color: amber,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Waiting for Confirmation',
                      style: GoogleFonts.sora(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'The ${isSellerVerifier ? 'seller' : 'buyer'} is checking your payment. After confirmation, your ${trade.asset.toUpperCase()} will be released.',
                      style: GoogleFonts.sora(
                        fontSize: 12,
                        color: colors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (dueAt != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'If this is not confirmed before the deadline, support will review and resolve it.',
                      style: GoogleFonts.sora(
                        fontSize: 11.5,
                        color: colors.textSecondary,
                      ),
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

// ─── Trade details card ───────────────────────────────────────────────────────

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({
    required this.trade,
    required this.isUserBuyer,
    required this.showViewProof,
    required this.onViewProof,
    required this.colors,
  });
  final TradeModel trade;
  final bool isUserBuyer;
  final bool showViewProof;
  final VoidCallback onViewProof;
  final AppColor colors;

  List<(TradeStatus, String, String)> _steps() {
    final asset = trade.asset.toUpperCase();
    final isSellOffer = trade.offerType == TradeOfferType.sell;
    final actingAsBuyer = isUserBuyer;

    final createdDesc = isSellOffer
        ? (actingAsBuyer
              ? 'Waiting for seller to lock $asset'
              : 'Lock your $asset to start')
        : (actingAsBuyer
              ? 'Lock your $asset to start'
              : 'Waiting for buyer to lock $asset');

    final lockedDesc = isSellOffer
        ? (actingAsBuyer
              ? 'Send payment to the seller'
              : 'Waiting for buyer to send payment')
        : (actingAsBuyer
              ? 'Waiting for seller to send payment'
              : 'Send payment to the buyer');

    final fiatSentTitle = (isSellOffer && !actingAsBuyer)
        ? 'Payment Received'
        : 'Payment Sent';
    final fiatSentDesc = isSellOffer
        ? (actingAsBuyer
              ? 'Seller is verifying your payment'
              : 'Confirm you received the payment')
        : (actingAsBuyer
              ? 'Confirm you received the payment'
              : 'Buyer is verifying your payment');

    final fiatConfirmedDesc = isSellOffer
        ? (actingAsBuyer
              ? 'Receive $asset in your wallet'
              : 'Buyer will receive $asset')
        : (actingAsBuyer
              ? 'Seller will receive $asset'
              : 'Receive $asset in your wallet');

    final completedDesc = isSellOffer
        ? (actingAsBuyer
              ? '$asset received in your wallet'
              : '$asset sent to buyer')
        : (actingAsBuyer
              ? '$asset sent to seller'
              : '$asset received in your wallet');

    return [
      (TradeStatus.created, 'Trade Started', createdDesc),
      (TradeStatus.cryptoLocked, '$asset Locked', lockedDesc),
      (TradeStatus.fiatSent, fiatSentTitle, fiatSentDesc),
      (TradeStatus.fiatConfirmed, 'Payment Confirmed', fiatConfirmedDesc),
      (TradeStatus.completed, 'Trade Complete', completedDesc),
    ];
  }

  String _escrowStatusLabel() {
    final status = trade.escrow?.status;
    return switch (status) {
      EscrowStatus.cbCreated => 'LOCKED',
      EscrowStatus.cbClaimed => 'CLAIMED',
      EscrowStatus.cbRefunded => 'REFUNDED',
      EscrowStatus.failed => 'FAILED',
      EscrowStatus.pending => 'PENDING',
      EscrowStatus.unknown => 'PENDING',
      null => 'NOT LOCKED',
    };
  }

  Color _escrowStatusColor() {
    final status = trade.escrow?.status;
    return switch (status) {
      EscrowStatus.cbCreated => colors.success,
      EscrowStatus.cbClaimed => colors.primary,
      EscrowStatus.cbRefunded => colors.warning,
      EscrowStatus.failed => colors.error,
      _ => colors.background,
    };
  }

  int _resolvedProgressIndex(List<TradeStatus> order) {
    if (order.contains(trade.status)) return order.indexOf(trade.status);

    final hasFiatSent = trade.fiatSentAt != null;
    final escrow = trade.escrow;
    final hasClaimTx = (escrow?.claimTxHash?.trim().isNotEmpty ?? false);
    final hasLockedEscrow =
        (escrow?.claimableBalanceId?.trim().isNotEmpty ?? false) ||
        escrow?.status == EscrowStatus.cbCreated ||
        escrow?.status == EscrowStatus.cbClaimed ||
        escrow?.status == EscrowStatus.cbRefunded;

    if (hasClaimTx) return order.indexOf(TradeStatus.fiatConfirmed);
    if (hasFiatSent) return order.indexOf(TradeStatus.fiatSent);
    if (hasLockedEscrow || trade.status == TradeStatus.cryptoLocked) {
      return order.indexOf(TradeStatus.cryptoLocked);
    }
    return order.indexOf(TradeStatus.created);
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps();
    final order = [
      TradeStatus.created,
      TradeStatus.cryptoLocked,
      TradeStatus.fiatSent,
      TradeStatus.fiatConfirmed,
      TradeStatus.completed,
    ];
    final currentIdx = _resolvedProgressIndex(order);
    final isTerminal =
        trade.status == TradeStatus.cancelled ||
        trade.status == TradeStatus.disputed ||
        trade.status == TradeStatus.expired;

    final doneColor = AppColor.of(context).success;
    final activeColor = AppColor.of(context).primary;
    final escrowLabel = _escrowStatusLabel();
    final escrowColor = _escrowStatusColor();
    final isEscrowNeutral =
        trade.escrow == null ||
        trade.escrow!.status == EscrowStatus.pending ||
        trade.escrow!.status == EscrowStatus.unknown;

    return _SectionCard(
      icon: Icons.route_rounded,
      iconColor: colors.textSecondary,
      title: 'Progress',
      colors: colors,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: escrowColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Escrow: $escrowLabel',
                  style: GoogleFonts.sora(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: isEscrowNeutral
                        ? colors.textSecondary
                        : colors.onPrimary,
                  ),
                ),
              ),
              const Spacer(),
              if (showViewProof)
                GestureDetector(
                  onTap: onViewProof,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.image_outlined,
                          size: 14,
                          color: colors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'View Proof',
                          style: GoogleFonts.sora(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        ...List.generate(steps.length, (i) {
          final step = steps[i];
          final stepIdx = order.indexOf(step.$1);
          final isCompleted = trade.status == TradeStatus.completed;
          final isDone = isCompleted || currentIdx > stepIdx;
          final isCurrent = stepIdx == currentIdx && trade.status.isActive;
          final isLast = i == steps.length - 1;

          final dotColor = isTerminal && stepIdx > 0
              ? colors.border
              : isDone
              ? doneColor
              : isCurrent
              ? activeColor
              : colors.border;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  isCurrent
                      ? Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: doneColor,
                          ),
                          child: Center(
                            child: Icon(
                              Icons.circle,
                              color: colors.onPrimary,
                              size: 8,
                            ),
                          ),
                        )
                      : Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDone ? doneColor : colors.background,
                          ),
                          child: isDone
                              ? Icon(
                                  Icons.check_rounded,
                                  color: colors.onPrimary,
                                  size: 14,
                                )
                              : Icon(
                                  Icons.circle_outlined,
                                  color: dotColor,
                                  size: 10,
                                ),
                        ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 36,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: isDone ? doneColor : colors.border,
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 4, bottom: isLast ? 0 : 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.$2,
                        style: GoogleFonts.sora(
                          fontSize: 13.5,
                          fontWeight: isCurrent
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: isDone || isCurrent
                              ? colors.textPrimary
                              : colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        step.$3,
                        style: GoogleFonts.sora(
                          fontSize: 11.5,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }
}

// ─── Section card ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.children,
    required this.colors,
    this.padding,
  });
  final IconData icon;
  final Color iconColor;
  final String title;
  final List<Widget> children;
  final AppColor colors;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.035),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 14),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.sora(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Divider(color: colors.border, height: 1),
          Padding(
            padding:
                padding ??
                const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

// ─── Data row ─────────────────────────────────────────────────────────────────

class _DataRow extends StatefulWidget {
  const _DataRow({
    required this.label,
    required this.value,
    required this.colors,
    this.copyable = false,
    this.mono = false,
  });
  final String label;
  final String value;
  final AppColor colors;
  final bool copyable;
  final bool mono;

  @override
  State<_DataRow> createState() => _DataRowState();
}

class _DataRowState extends State<_DataRow> {
  bool _copied = false;

  void _copy() {
    if (!widget.copyable) return;
    Clipboard.setData(ClipboardData(text: widget.value));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final doneColor = AppColor.of(context).success;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 98,
            child: Text(
              widget.label,
              style: GoogleFonts.sora(
                fontSize: 11.5,
                color: widget.colors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: _copy,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      widget.value,
                      textAlign: TextAlign.right,
                      style: widget.mono
                          ? GoogleFonts.sora(
                              fontSize: 11.5,
                              color: widget.colors.textPrimary,
                              fontWeight: FontWeight.w500,
                            )
                          : GoogleFonts.sora(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: widget.colors.textPrimary,
                            ),
                    ),
                  ),
                  if (widget.copyable) ...[
                    const SizedBox(width: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: _copied ? doneColor : widget.colors.background,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        _copied ? Icons.check_rounded : Icons.copy_rounded,
                        size: 10,
                        color: _copied
                            ? AppColor.of(context).onPrimary
                            : widget.colors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Safety note ──────────────────────────────────────────────────────────────

// ─── Error banner ─────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.colors});
  final String message;
  final AppColor colors;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      color: colors.surface,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Icon(Icons.error_outline_rounded, color: colors.error, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: GoogleFonts.sora(fontSize: 12, color: colors.error),
          ),
        ),
      ],
    ),
  );
}

// ─── Completed card ───────────────────────────────────────────────────────────

class _CompletedCard extends StatefulWidget {
  const _CompletedCard({
    required this.trade,
    required this.colors,
    required this.isBuyingCrypto,
    required this.currentUserId,
    required this.merchantUserId,
  });
  final TradeModel trade;
  final AppColor colors;
  final bool isBuyingCrypto;
  final String? currentUserId;
  final String? merchantUserId;

  @override
  State<_CompletedCard> createState() => _CompletedCardState();
}

class _CompletedCardState extends State<_CompletedCard> {
  bool _reviewSubmitted = false;
  bool _alreadyReviewed = false;
  bool _checkingReview = true;

  bool get _canSubmitReview {
    final me = (widget.currentUserId ?? '').trim();
    final merchant = (widget.merchantUserId ?? '').trim();
    if (me.isEmpty || merchant.isEmpty) return false;
    // Only non-merchant participant can review merchant.
    return me != merchant;
  }

  @override
  void initState() {
    super.initState();
    _loadReviewState();
  }

  @override
  void didUpdateWidget(covariant _CompletedCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trade.id != widget.trade.id ||
        oldWidget.currentUserId != widget.currentUserId ||
        oldWidget.merchantUserId != widget.merchantUserId) {
      _loadReviewState();
    }
  }

  Future<void> _loadReviewState() async {
    if (!_canSubmitReview) {
      if (mounted) {
        setState(() {
          _alreadyReviewed = false;
          _checkingReview = false;
          _reviewSubmitted = false;
        });
      }
      return;
    }
    if (mounted) setState(() => _checkingReview = true);
    final already = await ReviewsCoreService.I.hasReviewedTrade(
      widget.trade.id,
    );
    if (!mounted) return;
    setState(() {
      _alreadyReviewed = already;
      _reviewSubmitted = already;
      _checkingReview = false;
    });
  }

  Future<void> _openReviewSheet() async {
    if (!_canSubmitReview || _alreadyReviewed || _reviewSubmitted) return;
    final result = await showModalBottomSheet<TradeReviewResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColor.of(context).surface,
      builder: (_) => TradeReviewSheet(
        tradeId: widget.trade.id,
        colors: AppColor.of(context),
      ),
    );
    if (result == null) return;
    try {
      await ReviewsCoreService.I.create(
        CreateReviewRequest(
          tradeId: widget.trade.id,
          rating: result.rating,
          comment: result.comment.isNotEmpty ? result.comment : null,
        ),
      );
      if (mounted) {
        setState(() {
          _reviewSubmitted = true;
          _alreadyReviewed = true;
        });
      }
      if (mounted) {
        showFloatingSnackBar(
          context,
          message: 'Review submitted!',
          type: SnackBarType.success,
        );
      }
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('duplicate') ||
          msg.contains('already') ||
          msg.contains('review')) {
        if (mounted) {
          setState(() {
            _reviewSubmitted = true;
            _alreadyReviewed = true;
          });
        }
      }
      if (mounted) {
        showFloatingSnackBar(
          context,
          message: 'Failed: $e',
          type: SnackBarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final green = AppColor.of(context).success;
    final colors = widget.colors;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(shape: BoxShape.circle, color: green),
            child: Icon(
              Icons.check_rounded,
              color: AppColor.of(context).onPrimary,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Trade Completed!',
            style: GoogleFonts.sora(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isBuyingCrypto
                ? '${widget.trade.cryptoAmount.toStringAsFixed(6)} ${widget.trade.asset} released to your wallet'
                : '${widget.trade.fiatAmount.toStringAsFixed(2)} ${widget.trade.fiatCurrency.toUpperCase()} received',
            textAlign: TextAlign.center,
            style: GoogleFonts.sora(fontSize: 13, color: colors.textSecondary),
          ),
          const SizedBox(height: 20),
          _checkingReview
              ? Text(
                  'Checking review status...',
                  style: GoogleFonts.sora(
                    fontSize: 13,
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : !_canSubmitReview
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.visibility_rounded, color: green, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Merchant view: ratings are read-only',
                      style: GoogleFonts.sora(
                        fontSize: 13,
                        color: green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : _reviewSubmitted
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.star_rounded, color: green, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Review submitted — thank you!',
                      style: GoogleFonts.sora(
                        fontSize: 13,
                        color: green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : GestureDetector(
                  onTap: _openReviewSheet,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: colors.background,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.star_rounded, color: green, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Rate This Trade',
                          style: GoogleFonts.sora(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: green,
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

// ─── Cancelled card ───────────────────────────────────────────────────────────

class _CancelledCard extends StatelessWidget {
  const _CancelledCard({required this.colors});
  final AppColor colors;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: colors.surface,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.error,
          ),
          child: Icon(
            Icons.close_rounded,
            color: AppColor.of(context).onPrimary,
            size: 28,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Trade Cancelled',
          style: GoogleFonts.sora(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'All locked funds have been released back.',
          textAlign: TextAlign.center,
          style: GoogleFonts.sora(fontSize: 13, color: colors.textSecondary),
        ),
      ],
    ),
  );
}

// ─── Disputed card ────────────────────────────────────────────────────────────

class _DisputedCard extends StatelessWidget {
  const _DisputedCard({required this.colors});
  final AppColor colors;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: colors.surface,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.error,
          ),
          child: Icon(
            Icons.flag_rounded,
            color: AppColor.of(context).onPrimary,
            size: 28,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Support Is Reviewing',
          style: GoogleFonts.sora(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Our support team is reviewing this trade. We will resolve it within 24 hours.',
          textAlign: TextAlign.center,
          style: GoogleFonts.sora(fontSize: 13, color: colors.textSecondary),
        ),
      ],
    ),
  );
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.trade,
    required this.isParticipant,
    required this.isUserBuyer,
    required this.isUserSeller,
    required this.isUserEscrowLocker,
    required this.isUserFiatPayer,
    required this.isUserCryptoReceiver,
    required this.loading,
    required this.onLockCrypto,
    required this.onMarkFiatSent,
    required this.onConfirmFiat,
    required this.onClaimCrypto,
    required this.onCancel,
    required this.onRefund,
    required this.onUploadFiatProof,
    required this.onMessages,
    required this.lockPendingVerification,
    required this.showUploadFiatProof,
    required this.unreadMessages,
    required this.uploadingFiatProof,
    required this.colors,
  });
  final TradeModel trade;
  final bool isParticipant;
  final bool isUserBuyer;
  final bool isUserSeller;
  final bool isUserEscrowLocker;
  final bool isUserFiatPayer;
  final bool isUserCryptoReceiver;
  final bool loading;
  final VoidCallback onLockCrypto;
  final VoidCallback onMarkFiatSent;
  final VoidCallback onConfirmFiat;
  final VoidCallback onClaimCrypto;
  final VoidCallback onCancel;
  final VoidCallback onRefund;
  final VoidCallback onUploadFiatProof;
  final VoidCallback onMessages;
  final bool lockPendingVerification;
  final bool showUploadFiatProof;
  final int unreadMessages;
  final bool uploadingFiatProof;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    final s = trade.status;
    final escrow = trade.escrow;
    final escrowStatus = escrow?.status;
    final hasEscrowId =
        (escrow?.claimableBalanceId?.trim().isNotEmpty ?? false);
    final escrowFinalized =
        escrowStatus == EscrowStatus.cbClaimed ||
        escrowStatus == EscrowStatus.cbRefunded;
    final canAttemptLock =
        !hasEscrowId ||
        escrowStatus == null ||
        escrowStatus == EscrowStatus.pending ||
        escrowStatus == EscrowStatus.failed ||
        escrowStatus == EscrowStatus.unknown;

    final bool showLock =
        isParticipant &&
        s == TradeStatus.created &&
        isUserEscrowLocker &&
        !lockPendingVerification &&
        canAttemptLock;
    final bool showMarkFiat =
        isParticipant && s == TradeStatus.cryptoLocked && isUserFiatPayer;
    final bool showConfirm =
        isParticipant && s == TradeStatus.fiatSent && !isUserFiatPayer;
    final bool showClaim =
        isParticipant &&
        s == TradeStatus.fiatConfirmed &&
        isUserCryptoReceiver &&
        hasEscrowId &&
        !escrowFinalized;
    final bool showRefund =
        s == TradeStatus.expired &&
        isParticipant &&
        isUserEscrowLocker &&
        hasEscrowId &&
        !escrowFinalized;
    final bool showCancel =
        isParticipant &&
        (s == TradeStatus.created || s == TradeStatus.cryptoLocked);
    final hasPrimary =
        showLock || showMarkFiat || showConfirm || showClaim || showRefund;

    if (!hasPrimary && !showCancel && !s.isActive) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        12,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(color: colors.background),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showLock)
            _ActionBtn(
              label: 'Lock ${trade.asset.toUpperCase()}',
              icon: Icons.lock_rounded,
              accent: colors.primary,
              loading: loading,
              onTap: onLockCrypto,
            ),
          if (showMarkFiat)
            _ActionBtn(
              label: "I've Already Paid",
              icon: Icons.check_circle_outline_rounded,
              accent: colors.primary,
              loading: loading,
              onTap: onMarkFiatSent,
            ),
          if (showConfirm)
            _ActionBtn(
              label: 'Confirm Payment Received',
              icon: Icons.verified_rounded,
              accent: colors.success,
              loading: loading,
              onTap: onConfirmFiat,
            ),
          if (showClaim)
            _ActionBtn(
              label: 'Receive ${trade.asset.toUpperCase()}',
              icon: Icons.account_balance_wallet_rounded,
              accent: colors.success,
              loading: loading,
              onTap: onClaimCrypto,
            ),
          if (showRefund)
            _ActionBtn(
              label: 'Return ${trade.asset.toUpperCase()}',
              icon: Icons.replay_rounded,
              accent: colors.warning,
              loading: loading,
              onTap: onRefund,
            ),
          if (hasPrimary) const SizedBox(height: 10),
          if (showCancel || s.isActive || showUploadFiatProof)
            Row(
              children: [
                if (showCancel)
                  Expanded(
                    child: _ActionBtn(
                      label: 'Cancel',
                      icon: Icons.close_rounded,
                      accent: colors.error,
                      loading: loading,
                      onTap: onCancel,
                      outlined: false,
                      compact: true,
                    ),
                  ),
                if (showCancel && (showUploadFiatProof || s.isActive))
                  const SizedBox(width: 10),
                if (showUploadFiatProof)
                  Expanded(
                    child: _ActionBtn(
                      label: s == TradeStatus.disputed
                          ? 'Upload Evidence'
                          : 'Upload Payment Proof',
                      icon: Icons.upload_file_rounded,
                      accent: colors.primary,
                      loading: uploadingFiatProof,
                      onTap: onUploadFiatProof,
                      outlined: false,
                      compact: true,
                    ),
                  ),
                if (showUploadFiatProof && s.isActive)
                  const SizedBox(width: 10),
                if (s.isActive)
                  Expanded(
                    child: _ActionBtn(
                      label: 'Messages',
                      icon: Icons.chat_bubble_outline_rounded,
                      accent: colors.primary,
                      loading: false,
                      onTap: onMessages,
                      outlined: false,
                      compact: true,
                      badgeCount: unreadMessages,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.accent,
    required this.loading,
    required this.onTap,
    this.outlined = false,
    this.compact = false,
    this.badgeCount = 0,
  });
  final String label;
  final IconData icon;
  final Color accent;
  final bool loading;
  final bool outlined;
  final bool compact;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final h = compact ? 42.0 : 50.0;
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: h,
        width: double.infinity,
        decoration: BoxDecoration(
          color: outlined
              ? AppColor.of(context).surface
              : loading
              ? accent.withValues(alpha: ((128) / 255.0))
              : accent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: outlined
              ? null
              : [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.22),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Center(
          child: loading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: outlined ? accent : AppColor.of(context).onPrimary,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: compact ? 15 : 17,
                      color: outlined ? accent : AppColor.of(context).onPrimary,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      label,
                      style: GoogleFonts.sora(
                        fontSize: compact ? 12 : 13.5,
                        fontWeight: FontWeight.w700,
                        color: outlined
                            ? accent
                            : AppColor.of(context).onPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (badgeCount > 0) ...[
                      const SizedBox(width: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: outlined ? accent : colorsForBadge(context),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          badgeCount > 99 ? '99+' : '$badgeCount',
                          style: GoogleFonts.sora(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColor.of(context).onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Color colorsForBadge(BuildContext context) {
    if (outlined) return accent;
    return AppColor.of(context).error;
  }
}

// ─── Bottom sheet base ────────────────────────────────────────────────────────
