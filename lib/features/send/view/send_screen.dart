// lib/features/send/view/send_screen.dart
import 'dart:convert' show utf8;
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/asset/asset_logo.dart';
import 'package:next_fi/common/components/modal/recipient_upsert_sheet.dart';
import 'package:next_fi/common/components/snackbar/SnackBar.dart';
import 'package:next_fi/common/components/alert/AppAlert.dart';

import 'package:next_fi/features/send/model/send_token.dart';
import 'package:next_fi/features/send/view_model/send_vm.dart';
import 'package:next_fi/features/wallet_home/view_model/recipient_address_vm.dart';
import 'package:next_fi/features/wallet_home/model/recipient_address_model.dart';
import 'package:next_fi/features/wallet_home/view/widgets/recipient_list_widget.dart';
import 'package:next_fi/features/scanner/view/scanner_screen.dart';

class SendScreen extends StatefulWidget {
  final String address;
  final String token;
  final double balance;
  final bool autoOpenScanner;
  final String? prefillAddress;
  final String? prefillName;

  const SendScreen({
    super.key,
    required this.address,
    required this.token,
    required this.balance,
    this.autoOpenScanner = false,
    this.prefillAddress,
    this.prefillName,
  });

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final _form = GlobalKey<FormState>();
  final _toCtl = TextEditingController();
  final _amtCtl = TextEditingController();
  final _memoCtl = TextEditingController();

  int _memoBytes = 0;
  double? _lastPct;

  final _numFmt = NumberFormat('#,##0.######');

  bool _booted = false;
  bool _scannerOpenedOnce = false;

  bool _recipientLoading = false;
  RecipientAddressModel? _resolvedRecipient;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_booted) return;

    final vm = context.read<SendVM>();
    vm.configure(
      token: widget.token.toUpperCase() == 'XLM'
          ? SendToken.xlm
          : SendToken.usdc,
      senderAddress: widget.address,
      senderBalanceToken: widget.balance,
      prefillTo: widget.prefillAddress,
      prefillName: widget.prefillName,
    );

    _toCtl.text = widget.prefillAddress ?? '';

    if (widget.prefillAddress != null) {
      _lookupRecipient(widget.prefillAddress!);
    }

    _amtCtl.addListener(() {
      final v = double.tryParse(_amtCtl.text.trim()) ?? 0;
      vm.setTypedAmount(v);
      _lastPct = null;
      setState(() {});
    });

    _toCtl.addListener(() {
      vm.setRecipient(_toCtl.text.trim());
      _onRecipientChanged();
    });

    _memoCtl.addListener(() {
      _memoBytes = utf8.encode(_memoCtl.text).length;
      setState(() {});
    });

    if (widget.autoOpenScanner && !_scannerOpenedOnce) {
      final hasPrefill =
          (widget.prefillAddress ?? '').trim().isNotEmpty ||
              _toCtl.text.trim().isNotEmpty;
      if (!hasPrefill) {
        _scannerOpenedOnce = true;
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _openScanner());
      }
    }

    _booted = true;
  }

  @override
  void dispose() {
    _toCtl.dispose();
    _amtCtl.dispose();
    _memoCtl.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Recipient lookup
  // ──────────────────────────────────────────────────────────────────────────

  bool _looksLikeStellarPk(String x) =>
      RegExp(r'^G[A-Z2-7]{55}$').hasMatch(x);

  void _onRecipientChanged() {
    final addr = _toCtl.text.trim();

    if (!_looksLikeStellarPk(addr)) {
      if (_resolvedRecipient != null || _recipientLoading) {
        setState(() {
          _resolvedRecipient = null;
          _recipientLoading = false;
        });
      }
      return;
    }

    _lookupRecipient(addr);
  }

  Future<void> _lookupRecipient(String address) async {
    setState(() {
      _recipientLoading = true;
      _resolvedRecipient = null;
    });

    try {
      final recipientVM = context.read<RecipientAddressVM>();
      await recipientVM.ready;
      final match = recipientVM.byAddress(address);

      if (mounted) {
        setState(() {
          _resolvedRecipient = match;
          _recipientLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _recipientLoading = false);
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _refresh() async {
    final vm = context.read<SendVM>();
    await vm.refreshFees();
    vm.setRecipient(_toCtl.text.trim());
    await Future.delayed(const Duration(milliseconds: 250));
  }

  double _floorTo(double v, int dec) {
    final scale = math.pow(10, dec);
    return (v >= 0
        ? (v * scale).floor() / scale
        : (v * scale).ceil() / scale)
        .toDouble();
  }

  String _fmtAmount(double v, {int decimals = 7}) {
    final s = v.toStringAsFixed(decimals);
    return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
  }

  void _applyPercent(SendVM vm, double percent) {
    HapticFeedback.selectionClick();

    double targetAmount;
    if (percent >= 0.999) { // MAX button (1.0)
      if (vm.isXlm) {
        // For XLM: deduct network fee
        final fee = vm.networkFee;
        targetAmount = (vm.senderBalanceToken - fee).clamp(0, double.infinity);
      } else {
        // For USDC: use full balance
        targetAmount = vm.senderBalanceToken;
      }
    } else {
      // For percentage buttons: simple percentage
      targetAmount = vm.senderBalanceToken * percent;
    }

    final v = _floorTo(targetAmount, 7);
    _amtCtl.text = _fmtAmount(v);
    _amtCtl.selection = TextSelection.fromPosition(
        TextPosition(offset: _amtCtl.text.length));
    _lastPct = percent;
    setState(() {});
  }

  String? _currentMemoOrNull() {
    final t = _memoCtl.text.trim();
    if (t.isEmpty) return null;
    final bytes = utf8.encode(t);
    if (bytes.length > 28) return null;
    return t;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Send flow
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _confirmAndSend(SendVM vm) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: vm,
        child: _ReviewSheet(
          memo: _memoCtl.text.trim(),
          recipientName: _resolvedRecipient?.name,
        ),
      ),
    );
  }

  Future<void> _doSend(SendVM vm) async {
    late final AppAlertController ctl;
    ctl = showAppAlert(
      context,
      type: AppAlertType.loading,
      title: 'Submitting…',
      subtitle: 'Broadcasting your transaction to the network.',
      primaryText: 'Hide',
    );
    try {
      final txid = await vm.submit(memo: _currentMemoOrNull());
      if (!mounted) return;
      ctl.update(
        AppAlertType.success,
        title: 'Submitted',
        subtitle: txid,
        primaryText: 'Copy TxID',
        onPrimary: () async {
          await Clipboard.setData(ClipboardData(text: txid));
          ctl.close();
        },
      );
      _amtCtl.clear();
      _memoCtl.clear();
      _lastPct = null;
    } catch (e) {
      if (!mounted) return;
      ctl.update(
        AppAlertType.error,
        title: 'Send failed',
        subtitle: '$e',
        primaryText: 'Close',
      );
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Scanner + Contacts
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _openScanner() async {
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 60));

    final raw = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (!mounted || raw is! String) return;

    String? addr;
    String? memoText;
    String? memoType;

    final s = raw.trim();
    final schemeIdx = s.toLowerCase().indexOf('stellar:');
    if (schemeIdx != -1) {
      final after = s.substring(schemeIdx + 'stellar:'.length);
      final cut = after.split(RegExp(r'[#/]')).first;
      final qIdx = cut.indexOf('?');
      final path = qIdx == -1 ? cut : cut.substring(0, qIdx);
      if (_looksLikeStellarPk(path)) addr = path;

      if (qIdx != -1) {
        final query = cut.substring(qIdx + 1);
        try {
          final params = Uri.splitQueryString(query, encoding: utf8);
          memoText = params['memo'];
          memoType = params['memo_type']?.toLowerCase();
        } catch (_) {}
      }
    } else {
      addr = _parseStellarAddress(s);
    }

    if (addr == null) {
      if (!mounted) return;
      showFloatingSnackBar(
        context,
        message: 'No valid Stellar address found',
        type: SnackBarType.warning,
      );
      return;
    }

    if (memoText != null && memoText.trim().isNotEmpty) {
      if (memoType == null || memoType == 'text') {
        _memoCtl.text = memoText;
      } else {
        if (!mounted) return;
        showFloatingSnackBar(
          context,
          message: 'QR memo type "$memoType" not supported (only TEXT).',
          type: SnackBarType.warning,
        );
      }
    }

    _toCtl.text = addr;
    _toCtl.selection = TextSelection.fromPosition(
        TextPosition(offset: _toCtl.text.length));
    if (mounted) context.read<SendVM>().setRecipient(addr);
  }

  Future<void> _openRecipientsPicker() async {
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();

    final picked = await Navigator.push<RecipientAddressModel>(
      context,
      MaterialPageRoute(
        builder: (innerCtx) => RecipientListWidget(
          colors: AppColor.of(innerCtx),
          onSelect: (r) => Navigator.of(innerCtx).pop(r),
          fromAddress: widget.address,
        ),
      ),
    );

    if (!mounted || picked == null) return;

    final vm = context.read<SendVM>();
    final addr = picked.address.trim();

    _toCtl.text = addr;
    _toCtl.selection = TextSelection.fromPosition(
        TextPosition(offset: _toCtl.text.length));

    vm.pickRecipient(addr, displayName: picked.name);
  }

  String? _parseStellarAddress(String input) {
    final s = input.trim();
    final uriIdx = s.toLowerCase().indexOf('stellar:');
    if (uriIdx != -1) {
      final after = s.substring(uriIdx + 'stellar:'.length);
      final cut = after.split(RegExp(r'[?#/]')).first;
      if (_looksLikeStellarPk(cut)) return cut;
    }
    final reg = RegExp(r'\bG[A-Z2-7]{55}\b');
    final m = reg.firstMatch(s);
    if (m != null) return m.group(0);
    return null;
  }

  String _shortenAddress(String addr) {
    if (addr.length <= 16) return addr;
    return '${addr.substring(0, 6)}…${addr.substring(addr.length - 6)}';
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final vm = context.watch<SendVM>();
    final tokenStr = vm.isXlm ? 'XLM' : 'USDC';

    if (vm.loading) {
      return Scaffold(
        backgroundColor: c.background,
        body: const _LoadingState(),
      );
    }

    if (vm.error != null) {
      return Scaffold(
        backgroundColor: c.background,
        body: _ErrorState(message: vm.error!, onRetry: _refresh),
      );
    }

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(c, tokenStr),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                color: c.primary,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  children: [
                    _buildRecipientSection(c, vm),
                    const SizedBox(height: 32),
                    _buildAmountSection(c, vm, tokenStr),
                    if (!vm.isXlm) ...[
                      const SizedBox(height: 28),
                      _buildTrustlineHint(c, vm),
                    ],
                    const SizedBox(height: 28),
                    _buildMemoSection(c),
                    const SizedBox(height: 32),
                    _buildTransactionPreview(c, vm, tokenStr),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(c, vm),
    );
  }

  Widget _buildHeader(AppColor c, String tokenStr) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 24, 16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(LucideIcons.arrowLeft, color: c.textPrimary, size: 24),
            splashRadius: 24,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Send $tokenStr',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.8,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Transfer crypto to any Stellar address',
                  style: TextStyle(
                    color: c.textSecondary.withOpacity(0.65),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
          AssetLogo(keyOrSymbol: tokenStr, size: 36),
        ],
      ),
    );
  }

  Widget _buildRecipientSection(AppColor c, SendVM vm) {
    final addr = _toCtl.text.trim();
    final hasValidAddr = _looksLikeStellarPk(addr);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: c.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(LucideIcons.send, size: 16, color: c.primary),
            ),
            const SizedBox(width: 12),
            Text(
              'Send to',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_recipientLoading)
          _buildLoadingLine(c)
        else if (hasValidAddr && _resolvedRecipient != null)
          _buildRecipientBadge(c, _resolvedRecipient!)
        else if (hasValidAddr && _resolvedRecipient == null)
            _buildRecipientAddTemplate(c, addr)
          else
            _buildRecipientInput(c, addr, isDark),
      ],
    );
  }

  Widget _buildLoadingLine(AppColor c) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: isDark ? c.surface.withOpacity(0.5) : c.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: c.border.withOpacity(0.12),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.15)
                : c.border.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Center(
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: c.primary.withOpacity(0.6),
          ),
        ),
      ),
    );
  }

  Widget _buildRecipientBadge(AppColor c, RecipientAddressModel recipient) {
    final color = Color(recipient.color);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(isDark ? 0.1 : 0.08),
            color.withOpacity(isDark ? 0.05 : 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withOpacity(isDark ? 0.2 : 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : color.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.1)
                : color.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 1),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(0.25),
                  color.withOpacity(0.12),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                recipient.name.isNotEmpty
                    ? recipient.name[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipient.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _shortenAddress(recipient.address),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textSecondary.withOpacity(0.7),
                    fontFamily: 'monospace',
                    fontSize: 12,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () async {
              final ok = await showRecipientUpsertSheet(
                context,
                initial: _resolvedRecipient,
              );
              if (ok == true && mounted) _lookupRecipient(_toCtl.text.trim());
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.pencil, size: 14, color: color),
                  const SizedBox(width: 6),
                  Text(
                    'Edit',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: -0.2,
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

  Widget _buildRecipientAddTemplate(AppColor c, String addr) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.primary.withOpacity(isDark ? 0.08 : 0.06),
            c.primary.withOpacity(isDark ? 0.04 : 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: c.primary.withOpacity(isDark ? 0.15 : 0.12),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.15)
                : c.primary.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 3),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(LucideIcons.userPlus, size: 18, color: c.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New address',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _shortenAddress(addr),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textSecondary.withOpacity(0.7),
                    fontFamily: 'monospace',
                    fontSize: 12,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () async {
              final saved = await showRecipientUpsertSheet(context, address: addr);
              if (saved == true && mounted) _lookupRecipient(addr);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: c.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Save',
                style: TextStyle(
                  color: c.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientInput(AppColor c, String addr, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? c.surface.withOpacity(0.5) : c.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? c.border.withOpacity(0.12) : c.border.withOpacity(0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.1)
                : c.border.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: TextField(
        controller: _toCtl,
        textInputAction: TextInputAction.next,
        keyboardType: TextInputType.multiline,
        minLines: 1,
        maxLines: null,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: c.textPrimary,
          letterSpacing: -0.3,
          fontFeatures: const [ui.FontFeature.tabularFigures()],
        ),
        decoration: InputDecoration(
          hintText: 'Enter Stellar address (G…)',
          hintStyle: TextStyle(
            color: c.textSecondary.withOpacity(0.4),
            fontSize: 14,
            letterSpacing: -0.2,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 18, right: 12),
            child: Icon(LucideIcons.user, color: c.textSecondary.withOpacity(0.5), size: 20),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0),
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: _openScanner,
                  icon: Icon(LucideIcons.qrCode, size: 20, color: c.primary.withOpacity(0.8)),
                  splashRadius: 20,
                  tooltip: 'Scan QR',
                ),
                IconButton(
                  onPressed: _openRecipientsPicker,
                  icon: Icon(LucideIcons.contact, size: 20, color: c.primary.withOpacity(0.8)),
                  splashRadius: 20,
                  tooltip: 'Contacts',
                ),
                if (addr.isNotEmpty)
                  IconButton(
                    onPressed: () {
                      _toCtl.clear();
                      setState(() => _resolvedRecipient = null);
                      context.read<SendVM>().setRecipient('');
                    },
                    icon: Icon(LucideIcons.x, size: 18, color: c.textSecondary.withOpacity(0.5)),
                    splashRadius: 20,
                  ),
              ],
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        ),
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
      ),
    );
  }

  Widget _buildAmountSection(AppColor c, SendVM vm, String tokenStr) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: c.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(LucideIcons.coins, size: 16, color: c.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Amount',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            Text(
              '${vm.senderBalanceToken.toStringAsFixed(vm.isXlm ? 4 : 2)} $tokenStr',
              style: TextStyle(
                color: c.textSecondary.withOpacity(0.7),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: isDark ? c.surface.withOpacity(0.5) : c.surface.withOpacity(0.7),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? c.border.withOpacity(0.12) : c.border.withOpacity(0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.12)
                    : c.border.withOpacity(0.07),
                blurRadius: 12,
                offset: const Offset(0, 3),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 18, right: 14),
                child: AssetLogo(keyOrSymbol: tokenStr, size: 32),
              ),
              Expanded(
                child: TextField(
                  controller: _amtCtl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,7}$')),
                  ],
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                    letterSpacing: -0.8,
                    height: 1.2,
                  ),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: TextStyle(
                      color: c.textSecondary.withOpacity(0.25),
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 20),
                  ),
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: GestureDetector(
                  onTap: () => _applyPercent(vm, 1.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          c.primary.withOpacity(isDark ? 0.2 : 0.15),
                          c.primary.withOpacity(isDark ? 0.12 : 0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: c.primary.withOpacity(isDark ? 0.25 : 0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? c.primary.withOpacity(0.2)
                              : c.primary.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Text(
                      'MAX',
                      style: TextStyle(
                        color: c.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Percent chips
        _buildPercentChips(c, vm),
      ],
    );
  }

  Widget _buildPercentChips(AppColor c, SendVM vm) {
    final presets = [
      ('25%', 0.25),
      ('50%', 0.50),
      ('75%', 0.75),
    ];

    return Row(
      children: [
        for (int i = 0; i < presets.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _buildPercentChip(
              c,
              label: presets[i].$1,
              pct: presets[i].$2,
              isActive: _lastPct != null &&
                  (_lastPct! - presets[i].$2).abs() < 0.001,
              onTap: () => _applyPercent(vm, presets[i].$2),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPercentChip(
      AppColor c, {
        required String label,
        required double pct,
        required bool isActive,
        required VoidCallback onTap,
      }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? c.primary.withOpacity(0.12)
              : (isDark ? c.surface.withOpacity(0.5) : c.surface.withOpacity(0.7)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? c.primary.withOpacity(0.3)
                : c.border.withOpacity(isDark ? 0.12 : 0.15),
            width: 1,
          ),
          boxShadow: isActive
              ? [
            BoxShadow(
              color: isDark
                  ? c.primary.withOpacity(0.15)
                  : c.primary.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
              spreadRadius: 0,
            ),
          ]
              : [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.08)
                  : c.border.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 1),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? c.primary : c.textSecondary,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
              fontSize: 13,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrustlineHint(AppColor c, SendVM vm) {
    if (vm.to.trim().isEmpty) return const SizedBox.shrink();

    if (vm.checking) {
      return _buildHintContainer(
        c,
        gradient: [
          c.primary.withOpacity(0.08),
          c.primary.withOpacity(0.04),
        ],
        borderColor: c.primary.withOpacity(0.15),
        child: Row(
          children: [
            SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: c.primary.withOpacity(0.6),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Verifying USDC trustline…',
                style: TextStyle(
                  color: c.textSecondary.withOpacity(0.8),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (vm.destHasUsdcTL == false) {
      return _buildHintContainer(
        c,
        gradient: [
          c.error.withOpacity(0.1),
          c.error.withOpacity(0.05),
        ],
        borderColor: c.error.withOpacity(0.2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: c.error.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(LucideIcons.alertTriangle, size: 16, color: c.error),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No USDC Trustline',
                    style: TextStyle(
                      color: c.error,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'This address cannot receive USDC. The recipient needs to add a USDC trustline first.',
                    style: TextStyle(
                      color: c.error.withOpacity(0.85),
                      fontSize: 12,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (vm.destHasUsdcTL == true) {
      return _buildHintContainer(
        c,
        gradient: [
          c.success.withOpacity(0.1),
          c.success.withOpacity(0.05),
        ],
        borderColor: c.success.withOpacity(0.2),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: c.success.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(LucideIcons.checkCircle2, size: 16, color: c.success),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trustline Verified',
                    style: TextStyle(
                      color: c.success,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'This address can receive USDC',
                    style: TextStyle(
                      color: c.textSecondary.withOpacity(0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildHintContainer(
      AppColor c, {
        required List<Color> gradient,
        required Color borderColor,
        required Widget child,
      }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: 0.95 + (0.05 * value),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradient,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: borderColor,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(0.15)
                        : borderColor.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }

  Widget _buildMemoSection(AppColor c) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: c.textSecondary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(LucideIcons.messageSquare, size: 16, color: c.textSecondary.withOpacity(0.7)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Memo (optional)',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            Text(
              '$_memoBytes / 28',
              style: TextStyle(
                color: _memoBytes > 28 ? c.error : c.textSecondary.withOpacity(0.6),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: isDark ? c.surface.withOpacity(0.5) : c.surface.withOpacity(0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _memoBytes > 28
                  ? c.error.withOpacity(0.3)
                  : (isDark ? c.border.withOpacity(0.12) : c.border.withOpacity(0.15)),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.1)
                    : c.border.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 2),
                spreadRadius: 0,
              ),
            ],
          ),
          child: TextField(
            controller: _memoCtl,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: c.textPrimary,
              letterSpacing: -0.2,
            ),
            decoration: InputDecoration(
              hintText: 'Add a note (e.g., for exchanges)',
              hintStyle: TextStyle(
                color: c.textSecondary.withOpacity(0.4),
                fontSize: 14,
                letterSpacing: -0.2,
              ),
              suffixIcon: _memoCtl.text.isEmpty
                  ? null
                  : IconButton(
                onPressed: () => _memoCtl.clear(),
                icon: Icon(LucideIcons.x, size: 18, color: c.textSecondary.withOpacity(0.5)),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            ),
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
          ),
        ),
        if (_memoBytes > 28) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'Memo exceeds 28 bytes limit',
              style: TextStyle(
                color: c.error,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTransactionPreview(AppColor c, SendVM vm, String tokenStr) {
    if (vm.typedAmount <= 0) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.fileText, size: 16, color: c.textSecondary.withOpacity(0.7)),
            const SizedBox(width: 10),
            Text(
              'Transaction Summary',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? c.surface.withOpacity(0.5) : c.surface.withOpacity(0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? c.border.withOpacity(0.12) : c.border.withOpacity(0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.15)
                    : c.border.withOpacity(0.08),
                blurRadius: 14,
                offset: const Offset(0, 3),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            children: [
              // Recipient receives
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: c.primary.withOpacity(0.15),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? c.primary.withOpacity(0.12)
                          : c.primary.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.arrowUpRight, size: 16, color: c.primary),
                    const SizedBox(width: 10),
                    Text(
                      'Recipient receives',
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_numFmt.format(vm.recipientWillReceive)} $tokenStr',
                      style: TextStyle(
                        color: c.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Network fee
              _buildDetailRow(
                c,
                icon: LucideIcons.coins,
                label: 'Network fee',
                value: '${(vm.estNetworkFeeXlm ?? 0).toStringAsFixed(7)} XLM',
              ),
              if (vm.isXlm && vm.totalDeductFromBalance > 0) ...[
                const SizedBox(height: 10),
                _buildDetailRow(
                  c,
                  icon: LucideIcons.minusCircle,
                  label: 'Total deducted',
                  value: '${_numFmt.format(vm.totalDeductFromBalance)} XLM',
                ),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Divider(
                  color: c.border.withOpacity(0.2),
                  height: 1,
                ),
              ),
              _buildDetailRow(
                c,
                icon: LucideIcons.wallet,
                label: 'Remaining balance',
                value: '${_fmtAmount(vm.remainingExpendable)} $tokenStr',
                isMuted: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(
      AppColor c, {
        required IconData icon,
        required String label,
        required String value,
        bool isMuted = false,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 15,
            color: isMuted
                ? c.textSecondary.withOpacity(0.4)
                : c.textSecondary.withOpacity(0.6),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: c.textSecondary.withOpacity(isMuted ? 0.5 : 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.2,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isMuted ? c.textSecondary : c.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(AppColor c, SendVM vm) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canSubmit = vm.blockingReason == null && _memoBytes <= 28;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      decoration: BoxDecoration(
        color: c.background,
        border: Border(
          top: BorderSide(
            color: isDark ? c.border.withOpacity(0.12) : c.border.withOpacity(0.1),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : c.border.withOpacity(0.12),
            blurRadius: isDark ? 32 : 24,
            offset: const Offset(0, -6),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.15)
                : c.border.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 58,
          child: ElevatedButton(
            onPressed: canSubmit
                ? () async {
              HapticFeedback.mediumImpact();
              await _confirmAndSend(vm);
            }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canSubmit ? c.primary : c.primary.withOpacity(0.5),
              foregroundColor: Colors.white,
              disabledBackgroundColor: c.surface,
              disabledForegroundColor: c.textSecondary.withOpacity(0.4),
              elevation: canSubmit ? 4 : 0,
              shadowColor: canSubmit
                  ? c.primary.withOpacity(isDark ? 0.3 : 0.2)
                  : Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  canSubmit ? LucideIcons.send : LucideIcons.lock,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  canSubmit ? 'Review & Send' : 'Complete all fields',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// REVIEW SHEET
// ============================================================================

class _ReviewSheet extends StatefulWidget {
  final String memo;
  final String? recipientName;

  const _ReviewSheet({
    required this.memo,
    this.recipientName,
  });

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  bool _sending = false;

  Future<void> _confirm(SendVM vm, BuildContext ctx) async {
    if (_sending) return;

    setState(() => _sending = true);

    try {
      final memo = widget.memo.isEmpty ? null : widget.memo;
      final txHash = await vm.submit(memo: memo);

      if (!mounted) return;

      Navigator.pop(context);

      if (!ctx.mounted) return;

      showAppAlert(
        ctx,
        type: AppAlertType.success,
        title: 'Transaction Sent',
        subtitle: 'Your transaction has been broadcast successfully',
        primaryText: 'Copy TxID',
        onPrimary: () async {
          await Clipboard.setData(ClipboardData(text: txHash));
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);

      showAppAlert(
        context,
        type: AppAlertType.error,
        title: 'Transaction Failed',
        subtitle: e.toString(),
      );
    }
  }

  String _shortenAddress(String addr) {
    if (addr.length <= 16) return addr;
    return '${addr.substring(0, 8)}…${addr.substring(addr.length - 8)}';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final vm = context.watch<SendVM>();
    final tokenStr = vm.isXlm ? 'XLM' : 'USDC';
    final numFmt = NumberFormat('#,##0.######');

    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Material(
        color: c.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 14, bottom: 24),
                decoration: BoxDecoration(
                  color: c.border.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: c.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(LucideIcons.fileCheck, size: 18, color: c.primary),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Review Transaction',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        color: c.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Spacer(),
                    AssetLogo(keyOrSymbol: tokenStr, size: 24),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Amount highlight
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        c.primary.withOpacity(0.1),
                        c.primary.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: c.primary.withOpacity(0.2),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: c.primary.withOpacity(0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: c.primary.withOpacity(0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(LucideIcons.arrowUpRight, size: 16, color: c.primary),
                          const SizedBox(width: 10),
                          Text(
                            'Recipient receives',
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            numFmt.format(vm.recipientWillReceive),
                            style: TextStyle(
                              color: c.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 32,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            tokenStr,
                            style: TextStyle(
                              color: c.primary.withOpacity(0.7),
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Details
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    _buildDetailCard(
                      c,
                      children: [
                        _buildDetailRow(
                          c,
                          icon: LucideIcons.userCircle,
                          label: 'From',
                          value: _shortenAddress(vm.senderAddress),
                          mono: true,
                        ),
                        Divider(height: 24, color: c.border.withOpacity(0.2)),
                        _buildDetailRow(
                          c,
                          icon: LucideIcons.target,
                          label: widget.recipientName != null ? 'To (${widget.recipientName})' : 'To',
                          value: _shortenAddress(vm.to),
                          mono: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildDetailCard(
                      c,
                      children: [
                        _buildDetailRow(
                          c,
                          icon: LucideIcons.coins,
                          label: 'Network fee',
                          value: '${(vm.estNetworkFeeXlm ?? 0).toStringAsFixed(7)} XLM',
                        ),
                        if (vm.isXlm) ...[
                          Divider(height: 24, color: c.border.withOpacity(0.2)),
                          _buildDetailRow(
                            c,
                            icon: LucideIcons.minusCircle,
                            label: 'Total deducted',
                            value: '${numFmt.format(vm.totalDeductFromBalance)} XLM',
                          ),
                        ],
                        Divider(height: 24, color: c.border.withOpacity(0.2)),
                        _buildDetailRow(
                          c,
                          icon: LucideIcons.wallet,
                          label: 'Remaining',
                          value: '${numFmt.format(vm.remainingExpendable)} $tokenStr',
                          muted: true,
                        ),
                      ],
                    ),
                    if (widget.memo.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _buildDetailCard(
                        c,
                        children: [
                          _buildDetailRow(
                            c,
                            icon: LucideIcons.messageSquare,
                            label: 'Memo',
                            value: widget.memo,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _sending ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: BorderSide(
                            color: c.border.withOpacity(0.4),
                            width: 1.5,
                          ),
                          foregroundColor: c.textSecondary,
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _sending ? null : () => _confirm(vm, context),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          backgroundColor: _sending ? c.primary.withOpacity(0.7) : c.primary,
                          foregroundColor: Colors.white,
                          elevation: _sending ? 0 : 4,
                          shadowColor: _sending
                              ? Colors.transparent
                              : c.primary.withOpacity(0.3),
                        ),
                        child: _sending
                            ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Sending…',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        )
                            : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(LucideIcons.checkCircle, size: 18),
                            const SizedBox(width: 12),
                            const Text(
                              'Confirm Send',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard(AppColor c, {required List<Widget> children}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? c.surface.withOpacity(0.5) : c.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? c.border.withOpacity(0.15) : c.border.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.12)
                : c.border.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDetailRow(
      AppColor c, {
        required IconData icon,
        required String label,
        required String value,
        bool mono = false,
        bool muted = false,
      }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: muted
              ? c.textSecondary.withOpacity(0.5)
              : c.textSecondary.withOpacity(0.65),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: c.textSecondary.withOpacity(muted ? 0.5 : 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 5),
              SelectableText(
                value,
                maxLines: 2,
                style: TextStyle(
                  color: muted ? c.textSecondary : c.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontFamily: mono ? 'monospace' : null,
                  fontSize: mono ? 12 : 13,
                  letterSpacing: mono ? 0 : -0.2,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// LOADING STATE
// ============================================================================

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 32,
            width: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: c.primary.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading wallet…',
            style: TextStyle(
              color: c.textSecondary.withOpacity(0.6),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ERROR STATE
// ============================================================================

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(0.2)
                        : c.error.withOpacity(0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Icon(LucideIcons.alertTriangle, size: 32, color: c.error),
            ),
            const SizedBox(height: 20),
            Text(
              'Unable to Load Wallet',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textSecondary.withOpacity(0.7),
                fontSize: 14,
                height: 1.5,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                backgroundColor: c.primary,
                foregroundColor: Colors.white,
                elevation: 3,
                shadowColor: c.primary.withOpacity(0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}