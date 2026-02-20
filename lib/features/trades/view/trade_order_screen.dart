import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/button/app_buttons.dart';
import 'package:next_fi/features/trades/view/trade_template_screen.dart';
import 'package:next_fi/services/disputes/disputes_core_service.dart';
import 'package:next_fi/services/disputes/models/disputes_dtos.dart';
import 'package:next_fi/services/offers/models/offers_models.dart';
import 'package:next_fi/services/oath2.0/auth_service.dart';
import 'package:next_fi/services/reviews/models/reviews_dtos.dart';
import 'package:next_fi/services/reviews/reviews_core_service.dart';
import 'package:next_fi/services/secure_storage/token_storage.dart';
import 'package:next_fi/services/trades/models/trades_models.dart';
import 'package:next_fi/services/trades/realtime/trade_chat_socket_service.dart';
import 'package:next_fi/services/trades/trades_core_service.dart';

class TradeOrderScreen extends StatefulWidget {
  const TradeOrderScreen({
    super.key,
    required this.tradeId,
    required this.asSeller,
    required this.mode,
  });

  final String tradeId;
  final bool asSeller;
  final TradeTemplateMode mode;

  @override
  State<TradeOrderScreen> createState() => _TradeOrderScreenState();
}

class _TradeOrderScreenState extends State<TradeOrderScreen>
    with SingleTickerProviderStateMixin {
  final _trades = TradesCoreService.I;
  final _disputes = DisputesCoreService.I;
  final _reviews = ReviewsCoreService.I;
  final _auth = AuthService();
  final _picker = ImagePicker();
  final _msgCtrl = TextEditingController();
  final _chatScroll = ScrollController();
  final _money = NumberFormat.currency(symbol: '', decimalDigits: 2);

  TradeModel? _trade;
  String? _currentUserId;
  bool _loading = true;
  bool _busy = false;
  bool _sending = false;
  String? _error;
  Duration _remaining = Duration.zero;
  Timer? _refreshTimer;
  Timer? _tickTimer;
  TradeChatSocketService? _chatSocket;
  StreamSubscription<TradeChatSocketStatus>? _chatStatusSub;
  StreamSubscription<TradeMessageModel>? _chatMessageSub;
  StreamSubscription<String>? _chatErrorSub;
  List<TradeMessageModel> _chatMessages = const [];
  TradeChatSocketStatus _chatStatus = const TradeChatSocketStatus(
    connecting: false,
    connected: false,
    joined: false,
  );
  String? _chatError;
  final Map<String, String> _idempotencyKeys = <String, String>{};

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tickTimer?.cancel();
    _disposeChatSocket();
    _msgCtrl.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final user = await _auth.currentUser;
      _currentUserId = user.id;
    } catch (_) {}
    await _initChatSocket();
    await _loadTrade(showLoader: true);
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _loadTrade(showLoader: false),
    );
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _recomputeRemaining();
    });
  }

  Future<void> _loadTrade({required bool showLoader}) async {
    if (showLoader) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final trade = widget.asSeller
          ? await _trades.getSellerTradeById(widget.tradeId)
          : await _trades.getMyTradeById(widget.tradeId);
      if (!mounted) return;
      final prevCount = _chatMessages.length;
      final mergedMessages = _mergeMessages(_chatMessages, trade.messages);
      setState(() {
        _trade = trade;
        _chatMessages = mergedMessages;
        _loading = false;
      });
      _recomputeRemaining();
      if (mergedMessages.length > prevCount) {
        _scrollChatToBottom();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _recomputeRemaining() {
    final trade = _trade;
    if (trade == null) return;
    final deadline = trade.paymentDeadline;
    if (deadline == null) {
      if (_remaining != Duration.zero && mounted) {
        setState(() => _remaining = Duration.zero);
      }
      return;
    }
    final next = deadline.difference(DateTime.now().toUtc());
    final normalized = next.isNegative ? Duration.zero : next;
    if (!mounted) return;
    if (normalized != _remaining) {
      setState(() => _remaining = normalized);
    }
  }

  Future<void> _markPaid() async {
    if (_busy || _trade == null) return;
    setState(() => _busy = true);
    try {
      await _trades.markPaid(
        _trade!.id,
        idempotencyKey: _idempotencyKey('mark-paid'),
      );
      await _loadTrade(showLoader: false);
      _showSnack('Trade marked as paid.');
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelTrade() async {
    if (_busy || _trade == null) return;
    final reason = await _promptText(
      title: 'Cancel Trade',
      hint: 'Reason (optional)',
      confirm: 'Cancel trade',
    );
    if (reason == null) return;
    final txHash = await _promptText(
      title: 'Refund Tx Hash',
      hint: 'Optional in virtual mode, required in stellar mode',
      confirm: 'Continue',
    );
    if (txHash == null) return;

    setState(() => _busy = true);
    try {
      if (widget.asSeller) {
        await _trades.cancelSellerTrade(
          _trade!.id,
          idempotencyKey: _idempotencyKey('seller-cancel'),
          txHash: txHash.trim().isEmpty ? null : txHash.trim(),
          reason: reason.trim(),
        );
      } else {
        await _trades.cancelMyTrade(
          _trade!.id,
          idempotencyKey: _idempotencyKey('buyer-cancel'),
          txHash: txHash.trim().isEmpty ? null : txHash.trim(),
          reason: reason.trim(),
        );
      }
      await _loadTrade(showLoader: false);
      _showSnack('Trade cancelled.');
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _releaseTrade() async {
    if (_busy || _trade == null) return;
    final ok = await _confirm(
      title: 'Release Escrow?',
      message:
          'Only release if payment is fully received in your account. This action is final and cannot be undone.',
      confirmLabel: 'Release',
      isDestructive: false,
    );
    if (ok != true) return;
    final txHash = await _promptText(
      title: 'Release Tx Hash',
      hint: 'Required in stellar mode',
      confirm: 'Continue',
    );
    if (txHash == null) return;

    setState(() => _busy = true);
    try {
      await _trades.releaseSellerTrade(
        _trade!.id,
        idempotencyKey: _idempotencyKey('release'),
        txHash: txHash.trim().isEmpty ? null : txHash.trim(),
      );
      await _loadTrade(showLoader: false);
      _showSnack('Escrow released successfully.');
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadProof() async {
    final trade = _trade;
    if (_busy || trade == null) return;
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      imageQuality: 88,
    );
    if (picked == null) return;
    final note = await _promptText(
      title: 'Payment Proof Note',
      hint: 'Optional note',
      confirm: 'Upload',
    );
    if (note == null) return;

    setState(() => _busy = true);
    try {
      await _trades.uploadPaymentProof(
        trade.id,
        image: File(picked.path),
        note: note.trim().isEmpty ? null : note.trim(),
      );
      await _loadTrade(showLoader: false);
      _showSnack('Payment proof uploaded.');
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openDispute() async {
    final trade = _trade;
    if (_busy || trade == null) return;
    final reason = await _promptText(
      title: 'Open Dispute',
      hint: 'Reason for dispute',
      confirm: 'Open dispute',
      minLength: 6,
    );
    if (reason == null) return;

    setState(() => _busy = true);
    try {
      final dispute = await _disputes.openDispute(
        OpenDisputeRequest(tradeId: trade.id, reason: reason.trim()),
      );
      _showSnack('Dispute opened.');

      final attach = await _confirm(
        title: 'Upload Evidence',
        message: 'Do you want to attach screenshot/image evidence now?',
        confirmLabel: 'Attach image',
      );
      if (attach == true) {
        final picked = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 2000,
          imageQuality: 88,
        );
        if (picked != null) {
          await _disputes.uploadEvidence(
            dispute.id,
            image: File(picked.path),
            note: 'Uploaded from trade chat flow',
          );
          _showSnack('Dispute evidence uploaded.');
        }
      }
      await _loadTrade(showLoader: false);
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitReview() async {
    final trade = _trade;
    if (_busy || trade == null) return;
    final input = await _promptReviewInput();
    if (input == null) return;

    setState(() => _busy = true);
    try {
      final req = CreateReviewRequest(
        tradeId: trade.id,
        rating: input.$1,
        comment: input.$2,
      );
      if (widget.asSeller) {
        await _reviews.createReviewAsSeller(req);
      } else {
        await _reviews.createReviewAsBuyer(req);
      }
      _showSnack('Review submitted.');
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendMessage() async {
    if (_sending) return;
    final msg = _msgCtrl.text.trim();
    if (msg.isEmpty) return;
    setState(() => _sending = true);
    try {
      final sent = _chatSocket?.sendMessage(msg) ?? false;
      if (!sent) {
        _showSnack(_chatError ?? 'Realtime chat is reconnecting. Please wait.');
        return;
      }
      _msgCtrl.clear();
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _initChatSocket() async {
    _disposeChatSocket();
    final socket = TradeChatSocketService(
      tradeId: widget.tradeId,
      tokenProvider: () async => TokenStorage().accessToken,
    );
    _chatSocket = socket;
    _chatStatusSub = socket.statusStream.listen((status) {
      if (!mounted) return;
      setState(() {
        _chatStatus = status;
        if (status.ready) {
          _chatError = null;
        }
      });
      if (status.connected && !status.joined) {
        socket.retryJoin();
      }
    });
    _chatMessageSub = socket.messagesStream.listen((message) {
      if (!mounted) return;
      setState(() {
        _chatMessages = _mergeMessages(_chatMessages, [message]);
      });
      _scrollChatToBottom();
    });
    _chatErrorSub = socket.errorsStream.listen((error) {
      if (!mounted) return;
      setState(() {
        _chatError = error;
      });
    });

    await socket.connect();
  }

  void _disposeChatSocket() {
    _chatStatusSub?.cancel();
    _chatStatusSub = null;
    _chatMessageSub?.cancel();
    _chatMessageSub = null;
    _chatErrorSub?.cancel();
    _chatErrorSub = null;
    _chatSocket?.dispose();
    _chatSocket = null;
  }

  List<TradeMessageModel> _mergeMessages(
    List<TradeMessageModel> current,
    List<TradeMessageModel> incoming,
  ) {
    final map = <String, TradeMessageModel>{};
    var fallbackIndex = 0;

    String keyFor(TradeMessageModel msg) {
      final id = msg.id.trim();
      if (id.isNotEmpty) return 'id:$id';
      final ts = msg.createdAt?.toUtc().toIso8601String() ?? '$fallbackIndex';
      fallbackIndex += 1;
      return 'tmp:${msg.senderId}|${msg.message}|$ts';
    }

    for (final msg in current) {
      map[keyFor(msg)] = msg;
    }
    for (final msg in incoming) {
      map[keyFor(msg)] = msg;
    }

    final merged = map.values.toList();
    merged.sort(
      (a, b) => (a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
    );
    return merged;
  }

  Future<String?> _promptText({
    required String title,
    required String hint,
    required String confirm,
    int minLength = 0,
  }) async {
    final ctrl = TextEditingController();
    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final c = AppColor.of(context);
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.border.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: hint,
                    filled: true,
                    fillColor: c.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: BorderSide(color: c.border.withOpacity(0.24)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: BorderSide(color: c.border.withOpacity(0.24)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: BorderSide(
                        color: c.primary.withOpacity(0.5),
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: AppOutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(null),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: c.textPrimary,
                          side: BorderSide(color: c.border.withOpacity(0.4)),
                          minimumSize: const Size.fromHeight(44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppElevatedButton(
                        onPressed: () {
                          final text = ctrl.text.trim();
                          if (text.length < minLength && minLength > 0) return;
                          Navigator.of(ctx).pop(text);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(44),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(confirm),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    ctrl.dispose();
    return value;
  }

  Future<(int, String?)?> _promptReviewInput() async {
    int rating = 5;
    final ctrl = TextEditingController();
    final result = await showModalBottomSheet<(int, String?)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final c = AppColor.of(context);
        return StatefulBuilder(
          builder: (ctx2, setLocal) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: c.border.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Leave a Review',
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Help others know about this merchant.',
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Rating',
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: List.generate(5, (i) {
                        return GestureDetector(
                          onTap: () => setLocal(() => rating = i + 1),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(
                              i < rating
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: i < rating ? Colors.amber : c.border,
                              size: 32,
                            ),
                          ),
                        );
                      }),
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: ctrl,
                      autofocus: true,
                      minLines: 2,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Comment (optional)',
                        filled: true,
                        fillColor: c.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: BorderSide(
                            color: c.border.withOpacity(0.24),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: BorderSide(
                            color: c.border.withOpacity(0.24),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: BorderSide(
                            color: c.primary.withOpacity(0.5),
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: AppOutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(null),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: c.textPrimary,
                              side: BorderSide(
                                color: c.border.withOpacity(0.4),
                              ),
                              minimumSize: const Size.fromHeight(44),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Back'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppElevatedButton(
                            onPressed: () => Navigator.of(ctx).pop(
                              (rating, ctrl.text.trim()),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: c.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(44),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Submit Review'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    ctrl.dispose();
    return result;
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool isDestructive = false,
  }) {
    final c = AppColor.of(context);
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: c.border.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: AppOutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.textPrimary,
                      side: BorderSide(color: c.border.withOpacity(0.4)),
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDestructive ? c.error : c.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(44),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _statusLabel(TradeStatus status, String raw) {
    switch (status) {
      case TradeStatus.created:
        return 'Created';
      case TradeStatus.awaitingPayment:
        return 'Awaiting Payment';
      case TradeStatus.paid:
        return 'Paid';
      case TradeStatus.released:
        return 'Released';
      case TradeStatus.cancelled:
        return 'Cancelled';
      case TradeStatus.disputed:
        return 'Disputed';
      case TradeStatus.expired:
        return 'Expired';
      case TradeStatus.refunded:
        return 'Refunded';
      case TradeStatus.unknown:
        return raw;
    }
  }

  String _escrowStateLabel(TradeEscrowState state) {
    switch (state) {
      case TradeEscrowState.unfunded:
        return 'UNFUNDED';
      case TradeEscrowState.funded:
        return 'FUNDED';
      case TradeEscrowState.released:
        return 'RELEASED';
      case TradeEscrowState.refunded:
        return 'REFUNDED';
      case TradeEscrowState.unknown:
        return 'UNKNOWN';
    }
  }

  ({String title, String message, IconData icon, Color color}) _nextActionHint(
    AppColor c,
    TradeModel trade,
  ) {
    if (widget.asSeller) {
      if (trade.status == TradeStatus.paid) {
        return (
          title: 'Action required',
          message:
              'Buyer marked paid. Verify funds in your payment account, then release escrow.',
          icon: Icons.verified_rounded,
          color: c.success,
        );
      }
      if (trade.status == TradeStatus.awaitingPayment ||
          trade.status == TradeStatus.created) {
        return (
          title: 'Waiting for buyer payment',
          message:
              'Keep chat active and monitor payment proof uploads before taking action.',
          icon: Icons.hourglass_bottom_rounded,
          color: c.warning,
        );
      }
    } else {
      if (trade.isOpenForBuyerPayment) {
        return (
          title: 'Action required',
          message:
              'Send fiat payment using seller account details, then tap Mark Paid and upload proof.',
          icon: Icons.payments_outlined,
          color: c.primary,
        );
      }
      if (trade.status == TradeStatus.paid) {
        return (
          title: 'Waiting for release',
          message:
              'Seller is expected to release escrow once payment is confirmed.',
          icon: Icons.lock_clock_outlined,
          color: c.warning,
        );
      }
    }

    if (trade.status == TradeStatus.released) {
      return (
        title: 'Trade completed',
        message: 'Escrow released successfully. You can now leave a review.',
        icon: Icons.check_circle_rounded,
        color: c.success,
      );
    }
    if (trade.status == TradeStatus.cancelled) {
      return (
        title: 'Trade cancelled',
        message: 'Review escrow tracking below for refund details.',
        icon: Icons.cancel_outlined,
        color: c.textSecondary,
      );
    }
    if (trade.status == TradeStatus.disputed) {
      return (
        title: 'Dispute in progress',
        message:
            'Keep all communication and evidence inside this trade chat and proof flows.',
        icon: Icons.gavel_rounded,
        color: c.error,
      );
    }
    return (
      title: 'Order active',
      message:
          'Follow the guided flow in this screen only. External chats are not protected.',
      icon: Icons.shield_rounded,
      color: c.primary,
    );
  }

  Color _statusColor(AppColor c, TradeStatus status) {
    switch (status) {
      case TradeStatus.paid:
      case TradeStatus.awaitingPayment:
      case TradeStatus.created:
        return c.warning;
      case TradeStatus.released:
        return c.success;
      case TradeStatus.disputed:
        return c.error;
      case TradeStatus.cancelled:
      case TradeStatus.expired:
      case TradeStatus.refunded:
      case TradeStatus.unknown:
        return c.textSecondary;
    }
  }

  String _formatRemaining(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _idempotencyKey(String action) {
    final existing = _idempotencyKeys[action];
    if (existing != null) return existing;
    final millis = DateTime.now().toUtc().millisecondsSinceEpoch;
    final randomPart = math.Random().nextInt(1 << 32).toRadixString(16);
    final tradePart = widget.tradeId.length > 12
        ? widget.tradeId.substring(0, 12)
        : widget.tradeId;
    final key = '$action-$tradePart-$millis-$randomPart';
    _idempotencyKeys[action] = key;
    return key;
  }

  void _scrollChatToBottom() {
    if (!_chatScroll.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScroll.hasClients) return;
      _chatScroll.animateTo(
        _chatScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  String _chatStatusText() {
    if (_chatStatus.ready) return 'Realtime connected to secure trade room.';
    if (_chatStatus.connecting) return 'Connecting to secure trade chat...';
    if (_chatStatus.connected && !_chatStatus.joined) {
      return 'Connected. Joining trade room...';
    }
    return 'Realtime chat reconnecting. You can still refresh order data.';
  }

  Color _chatStatusColor(AppColor c) {
    if (_chatStatus.ready) return c.success;
    if (_chatStatus.connecting) return c.warning;
    if (_chatStatus.connected) return c.warning;
    return c.error;
  }

  String _partyPrimaryLabel(
    TradePartyLite? party, {
    required String fallbackId,
  }) {
    if (party != null) {
      final display = party.displayName?.trim() ?? '';
      if (display.isNotEmpty) return display;
      final name = party.name.trim();
      if (name.isNotEmpty) return name;
      final username = party.username?.trim() ?? '';
      if (username.isNotEmpty) return '@$username';
      final email = party.email.trim();
      if (email.isNotEmpty) return email;
    }
    return fallbackId.isNotEmpty ? fallbackId : 'Counterparty';
  }

  String _partySecondaryLabel(TradePartyLite? party) {
    if (party == null) return '';
    final username = party.username?.trim() ?? '';
    final email = party.email.trim();
    if (username.isNotEmpty && email.isNotEmpty) return '@$username | $email';
    if (username.isNotEmpty) return '@$username';
    if (email.isNotEmpty) return email;
    return '';
  }

  String _counterpartyTitle(TradeModel trade) {
    final me = _currentUserId?.trim() ?? '';
    final counterpart = trade.counterpartyFor(_currentUserId);
    final fallback = trade.sellerId == me ? trade.buyerId : trade.sellerId;
    return _partyPrimaryLabel(counterpart, fallbackId: fallback);
  }

  String _counterpartySubtitle(TradeModel trade) {
    return _partySecondaryLabel(trade.counterpartyFor(_currentUserId));
  }

  String _senderLabel(TradeModel trade, TradeMessageModel message) {
    if ((_currentUserId?.trim() ?? '').isNotEmpty &&
        message.senderId == _currentUserId) {
      return 'You';
    }
    final party = trade.partyForUserId(message.senderId);
    return _partyPrimaryLabel(party, fallbackId: message.senderId);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final trade = _trade;
    if (_loading) {
      return Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(backgroundColor: c.background, elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(backgroundColor: c.background, elevation: 0),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, color: c.error, size: 24),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.textSecondary, fontSize: 12.8),
                ),
                const SizedBox(height: 10),
                AppOutlinedButton(
                  onPressed: () => _loadTrade(showLoader: true),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (trade == null) {
      return Scaffold(
        backgroundColor: c.background,
        body: const SizedBox.shrink(),
      );
    }

    final statusColor = _statusColor(c, trade.status);
    final canMarkPaid = !widget.asSeller && trade.isOpenForBuyerPayment;
    final canRelease = widget.asSeller && trade.status == TradeStatus.paid;
    final canCancel =
        !trade.isFinalStatus && trade.status != TradeStatus.released;
    final canReview = trade.status == TradeStatus.released;
    final nextHint = _nextActionHint(c, trade);
    final counterpartyTitle = _counterpartyTitle(trade);
    final counterpartySubtitle = _counterpartySubtitle(trade);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          backgroundColor: c.background,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleSpacing: 20,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trade ${trade.id.length > 8 ? trade.id.substring(0, 8) : trade.id}',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.35,
                ),
              ),
              Text(
                counterpartySubtitle.trim().isNotEmpty
                    ? '$counterpartyTitle | $counterpartySubtitle'
                    : counterpartyTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 11.7,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
          leading: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: c.textPrimary,
                size: 18,
              ),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          bottom: TabBar(
            indicatorColor: c.primary,
            labelColor: c.textPrimary,
            unselectedLabelColor: c.textSecondary,
            labelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
            ),
            tabs: const [
              Tab(text: 'Order'),
              Tab(text: 'Live Chat'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: c.border.withOpacity(0.25)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              _statusLabel(trade.status, trade.statusRaw),
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 11.6,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            LucideIcons.clock3,
                            size: 14,
                            color: c.textSecondary.withOpacity(0.8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatRemaining(_remaining),
                            style: TextStyle(
                              color: c.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Live order timer and status updates are active.',
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 12.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: trade.paymentWindow <= 0
                              ? 0
                              : (_remaining.inSeconds /
                                        (trade.paymentWindow * 60))
                                    .clamp(0.0, 1.0)
                                    .toDouble(),
                          minHeight: 6,
                          backgroundColor: c.border.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: c.success.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.success.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: c.success.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.verified_user_rounded,
                              color: c.success,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Claimable Balance Protection',
                            style: TextStyle(
                              color: c.success,
                              fontWeight: FontWeight.w700,
                              fontSize: 13.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        trade.claimableBalanceId == null
                            ? 'Escrow protection is enabled. Never settle outside this screen.'
                            : 'Escrow ID: ${trade.claimableBalanceId}',
                        style: TextStyle(color: c.textPrimary, fontSize: 12.2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: nextHint.color.withOpacity(0.09),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: nextHint.color.withOpacity(0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: nextHint.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          nextHint.icon,
                          color: nextHint.color,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nextHint.title,
                              style: TextStyle(
                                color: nextHint.color,
                                fontWeight: FontWeight.w700,
                                fontSize: 13.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              nextHint.message,
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 12.2,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'ORDER DETAILS',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.border.withOpacity(0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trade Summary',
                        style: TextStyle(
                          color: c.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _SummaryRow(
                        c: c,
                        label: 'Asset',
                        value:
                            '${offerAssetToApi(trade.asset)} / ${trade.fiatCurrency}',
                      ),
                      _SummaryRow(
                        c: c,
                        label: 'Amount',
                        value:
                            '${_money.format(trade.amount)} ${trade.fiatCurrency}',
                      ),
                      if (trade.price != null)
                        _SummaryRow(
                          c: c,
                          label: 'Price',
                          value:
                              '${_money.format(trade.price)} ${trade.fiatCurrency}',
                        ),
                      if (trade.fiatAmount != null)
                        _SummaryRow(
                          c: c,
                          label: 'Fiat total',
                          value:
                              '${_money.format(trade.fiatAmount)} ${trade.fiatCurrency}',
                        ),
                      _SummaryRow(
                        c: c,
                        label: 'Escrow state',
                        value: _escrowStateLabel(trade.escrowState),
                      ),
                      if (trade.paymentDueAt != null)
                        _SummaryRow(
                          c: c,
                          label: 'Pay by',
                          value: DateFormat(
                            'MMM d, HH:mm',
                          ).format(trade.paymentDueAt!.toLocal()),
                        ),
                      if (trade.releaseDueAt != null)
                        _SummaryRow(
                          c: c,
                          label: 'Release by',
                          value: DateFormat(
                            'MMM d, HH:mm',
                          ).format(trade.releaseDueAt!.toLocal()),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.border.withOpacity(0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment Accounts',
                        style: TextStyle(
                          color: c.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _SummaryRow(
                        c: c,
                        label: 'Seller',
                        value:
                            '${trade.sellerPaymentAccount?.paymentMethod?.name ?? 'Method'} | ${trade.sellerPaymentAccount?.accountName ?? 'N/A'}',
                      ),
                      _SummaryRow(
                        c: c,
                        label: 'Buyer',
                        value:
                            '${trade.buyerPaymentAccount?.paymentMethod?.name ?? 'Method'} | ${trade.buyerPaymentAccount?.accountName ?? 'N/A'}',
                      ),
                      if (trade.sellerWallet?.publicAddress.trim().isNotEmpty ??
                          false)
                        _SummaryRow(
                          c: c,
                          label: 'Seller wallet',
                          value: trade.sellerWallet!.publicAddress.trim(),
                        ),
                      if (trade.buyerWallet?.publicAddress.trim().isNotEmpty ??
                          false)
                        _SummaryRow(
                          c: c,
                          label: 'Buyer wallet',
                          value: trade.buyerWallet!.publicAddress.trim(),
                        ),
                    ],
                  ),
                ),
                if (trade.note != null && trade.note!.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: c.border.withOpacity(0.25)),
                    ),
                    child: Text(
                      trade.note!,
                      style: TextStyle(color: c.textPrimary, fontSize: 12.4),
                    ),
                  ),
                ],
                if (trade.proofs.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: c.border.withOpacity(0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment Proof',
                          style: TextStyle(
                            color: c.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...trade.proofs.map(
                          (p) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              p.imageUrl ?? p.note ?? 'Proof uploaded',
                              style: TextStyle(
                                color: c.textSecondary,
                                fontSize: 12.1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                _EscrowTrackingCard(c: c, trade: trade),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                  decoration: BoxDecoration(
                    color: c.warning.withOpacity(0.09),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.warning.withOpacity(0.25)),
                  ),
                  child: Text(
                    'Safety reminder: only follow actions inside this screen. Never move to private chats or external links.',
                    style: TextStyle(color: c.textPrimary, fontSize: 12.2),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (canMarkPaid)
                      AppElevatedButton.icon(
                        onPressed: _busy ? null : _markPaid,
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Mark Paid'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(140, 44),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                      ),
                    if (canRelease)
                      AppElevatedButton.icon(
                        onPressed: _busy ? null : _releaseTrade,
                        icon: const Icon(Icons.verified_rounded, size: 16),
                        label: const Text('Release'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.success,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(140, 44),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                      ),
                    if (!widget.asSeller)
                      AppOutlinedButton.icon(
                        onPressed: _busy ? null : _uploadProof,
                        icon: const Icon(Icons.upload_file_rounded, size: 16),
                        label: const Text('Upload Proof'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: c.textPrimary,
                          side: BorderSide(color: c.border.withOpacity(0.5)),
                          minimumSize: const Size(140, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                      ),
                    if (canCancel)
                      AppTextButton.icon(
                        onPressed: _busy ? null : _cancelTrade,
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('Cancel Trade'),
                        style: TextButton.styleFrom(
                          foregroundColor: c.error,
                          backgroundColor: c.error.withOpacity(0.08),
                          minimumSize: const Size(140, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                      ),
                    if (!trade.isFinalStatus ||
                        trade.status == TradeStatus.disputed)
                      AppTextButton.icon(
                        onPressed: _busy ? null : _openDispute,
                        icon: const Icon(
                          Icons.report_problem_outlined,
                          size: 16,
                        ),
                        label: const Text('Open Dispute'),
                        style: TextButton.styleFrom(
                          foregroundColor: c.warning,
                          backgroundColor: c.warning.withOpacity(0.1),
                          minimumSize: const Size(140, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                      ),
                    if (canReview)
                      AppTextButton.icon(
                        onPressed: _busy ? null : _submitReview,
                        icon: const Icon(Icons.star_border_rounded, size: 16),
                        label: const Text('Review'),
                        style: TextButton.styleFrom(
                          foregroundColor: c.primary,
                          backgroundColor: c.primary.withOpacity(0.09),
                          minimumSize: const Size(120, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            Column(
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: _chatStatusColor(c).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _chatStatusColor(c).withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: _chatStatusColor(c).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: _chatStatusColor(c),
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _chatStatusText(),
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 12.2,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_chatError != null &&
                          _chatError!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _chatError!,
                          style: TextStyle(color: c.error, fontSize: 11.2),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: _chatScroll,
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                    itemCount: _chatMessages.length,
                    itemBuilder: (_, i) {
                      final m = _chatMessages[i];
                      final mine =
                          _currentUserId != null &&
                          m.senderId == _currentUserId;
                      final senderLabel = _senderLabel(trade, m);
                      return Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.fromLTRB(11, 8, 11, 8),
                          constraints: const BoxConstraints(maxWidth: 280),
                          decoration: BoxDecoration(
                            color: mine ? c.primary : c.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: mine
                                ? null
                                : Border.all(color: c.border.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!mine) ...[
                                Text(
                                  senderLabel,
                                  style: TextStyle(
                                    color: c.textSecondary,
                                    fontSize: 10.4,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                              ],
                              Text(
                                m.message,
                                style: TextStyle(
                                  color: mine ? Colors.white : c.textPrimary,
                                  fontSize: 12.8,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                m.createdAt == null
                                    ? ''
                                    : DateFormat(
                                        'MMM d, HH:mm',
                                      ).format(m.createdAt!.toLocal()),
                                style: TextStyle(
                                  color: mine
                                      ? Colors.white.withOpacity(0.75)
                                      : c.textSecondary,
                                  fontSize: 10.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border(
                      top: BorderSide(color: c.border.withOpacity(0.25)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _msgCtrl,
                          enabled: _chatStatus.ready,
                          minLines: 1,
                          maxLines: 4,
                          onSubmitted: (_) => _sendMessage(),
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            filled: true,
                            fillColor: c.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AppElevatedButton(
                        onPressed: (_sending || !_chatStatus.ready)
                            ? null
                            : _sendMessage,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(48, 46),
                          backgroundColor: c.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _sending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 18),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.c,
    required this.label,
    required this.value,
  });

  final AppColor c;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 12.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EscrowTrackingCard extends StatelessWidget {
  const _EscrowTrackingCard({required this.c, required this.trade});

  final AppColor c;
  final TradeModel trade;

  Color _escrowColor() {
    switch (trade.escrowState) {
      case TradeEscrowState.funded:
        return c.warning;
      case TradeEscrowState.released:
        return c.success;
      case TradeEscrowState.refunded:
        return c.textSecondary;
      case TradeEscrowState.unfunded:
      case TradeEscrowState.unknown:
        return c.textSecondary;
    }
  }

  String _escrowLabel() {
    switch (trade.escrowState) {
      case TradeEscrowState.funded:
        return 'FUNDED';
      case TradeEscrowState.released:
        return 'RELEASED';
      case TradeEscrowState.refunded:
        return 'REFUNDED';
      case TradeEscrowState.unfunded:
        return 'UNFUNDED';
      case TradeEscrowState.unknown:
        return 'UNKNOWN';
    }
  }

  String _shortHash(String hash) {
    if (hash.length <= 20) return hash;
    return '${hash.substring(0, 10)}...${hash.substring(hash.length - 10)}';
  }

  @override
  Widget build(BuildContext context) {
    final claimId = trade.claimableBalanceId;
    final escrowColor = _escrowColor();
    final fmt = DateFormat('MMM d, HH:mm');

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Escrow Tracking',
                style: TextStyle(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: escrowColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _escrowLabel(),
                  style: TextStyle(
                    color: escrowColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (claimId != null && claimId.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 13,
                  color: c.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _shortHash(claimId),
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 11.8,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: claimId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Claimable balance ID copied.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.copy_rounded,
                      size: 14,
                      color: c.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ] else ...[
            Row(
              children: [
                Icon(
                  Icons.hourglass_empty_rounded,
                  size: 13,
                  color: c.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Escrow ID pending backend assignment',
                  style: TextStyle(color: c.textSecondary, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          if (trade.escrowFundedAt != null)
            _EscrowTimestamp(
              c: c,
              icon: Icons.lock_rounded,
              label: 'Funded',
              time: fmt.format(trade.escrowFundedAt!.toLocal()),
              color: c.warning,
            ),
          if (trade.escrowReleasedAt != null)
            _EscrowTimestamp(
              c: c,
              icon: Icons.check_circle_rounded,
              label: 'Released',
              time: fmt.format(trade.escrowReleasedAt!.toLocal()),
              color: c.success,
            ),
          if (trade.escrowRefundedAt != null)
            _EscrowTimestamp(
              c: c,
              icon: Icons.refresh_rounded,
              label: 'Refunded',
              time: fmt.format(trade.escrowRefundedAt!.toLocal()),
              color: c.textSecondary,
            ),
          if (trade.escrowExpiryAt != null &&
              trade.escrowState == TradeEscrowState.funded)
            _EscrowTimestamp(
              c: c,
              icon: Icons.timer_outlined,
              label: 'Escrow expires',
              time: fmt.format(trade.escrowExpiryAt!.toLocal()),
              color: c.error,
            ),
          if ((trade.fundedTxHash ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            _TxHashRow(
              c: c,
              label: 'Fund tx',
              hash: trade.fundedTxHash!,
            ),
          ],
          if ((trade.releasedTxHash ?? '').trim().isNotEmpty)
            _TxHashRow(
              c: c,
              label: 'Release tx',
              hash: trade.releasedTxHash!,
            ),
          if ((trade.refundTxHash ?? '').trim().isNotEmpty)
            _TxHashRow(c: c, label: 'Refund tx', hash: trade.refundTxHash!),
        ],
      ),
    );
  }
}

class _EscrowTimestamp extends StatelessWidget {
  const _EscrowTimestamp({
    required this.c,
    required this.icon,
    required this.label,
    required this.time,
    required this.color,
  });

  final AppColor c;
  final IconData icon;
  final String label;
  final String time;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            time,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _TxHashRow extends StatelessWidget {
  const _TxHashRow({
    required this.c,
    required this.label,
    required this.hash,
  });

  final AppColor c;
  final String label;
  final String hash;

  String _short(String h) {
    if (h.length <= 20) return h;
    return '${h.substring(0, 8)}...${h.substring(h.length - 8)}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _short(hash),
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 11.5,
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: hash));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Transaction hash copied.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.copy_rounded, size: 13, color: c.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
