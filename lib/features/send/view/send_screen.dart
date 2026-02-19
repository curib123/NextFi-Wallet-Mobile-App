// lib/features/send/view/send_screen.dart
import 'dart:convert' show utf8;
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:next_fi/common/components/button/app_buttons.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/asset/asset_logo.dart';
import 'package:next_fi/common/components/loader/page_loader.dart';
import 'package:next_fi/common/components/modal/recipient_upsert_sheet.dart';
import 'package:next_fi/common/components/snackbar/SnackBar.dart';
import 'package:next_fi/common/components/alert/AppAlert.dart';

import 'package:next_fi/features/send/model/send_token.dart';
import 'package:next_fi/features/send/view_model/send_vm.dart';
import 'package:next_fi/features/wallet_home/view_model/recipient_address_vm.dart';
import 'package:next_fi/features/wallet_home/model/recipient_address_model.dart';
import 'package:next_fi/features/wallet_home/view/widgets/recipient_list_widget.dart';
import 'package:next_fi/features/scanner/view/scanner_screen.dart';
import 'package:next_fi/services/federation_address/federation_address_core_service.dart';
import 'package:next_fi/services/federation_address/models/federation_address_models.dart';

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
  bool _federationLoading = false;
  FederationResolveResponse? _resolvedFederation;
  String? _federationError;
  int _federationResolveSeq = 0;
  String _federationDomain = FederationAddressCoreService.defaultDomain;
  List<String> _federationSuggestions = const [];

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
      _onRecipientChanged();
    });

    _loadFederationDomain();

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
        WidgetsBinding.instance.addPostFrameCallback((_) => _openScanner());
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

  bool _looksLikeStellarPk(String x) => RegExp(r'^G[A-Z2-7]{55}$').hasMatch(x);
  bool _looksLikeFederation(String x) =>
      RegExp(r'^[^*\s]+\*[^*\s]+$').hasMatch(x);
  bool _looksLikeFederationAliasInput(String x) =>
      RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(x);

  void _onRecipientChanged() {
    final vm = context.read<SendVM>();
    final input = _toCtl.text.trim();

    if (input.isEmpty) {
      vm.setRecipient('');
      setState(() {
        _resolvedRecipient = null;
        _recipientLoading = false;
        _resolvedFederation = null;
        _federationError = null;
        _federationLoading = false;
        _federationSuggestions = const [];
      });
      return;
    }

    if (_looksLikeStellarPk(input)) {
      vm.setRecipient(input);
      setState(() {
        _resolvedFederation = null;
        _federationError = null;
        _federationLoading = false;
        _federationSuggestions = const [];
      });
      _lookupRecipient(input);
      return;
    }

    if (_looksLikeFederation(input)) {
      vm.setRecipient('');
      setState(() {
        _resolvedRecipient = null;
        _federationSuggestions = const [];
      });
      _resolveFederation(input);
      return;
    }

    _updateFederationSuggestions(input);
    vm.setRecipient(input);
    setState(() {
      _resolvedRecipient = null;
      _recipientLoading = false;
      _resolvedFederation = null;
      _federationError = null;
      _federationLoading = false;
    });
  }

  Future<void> _resolveFederation(String federationAddress) async {
    final vm = context.read<SendVM>();
    final requestId = ++_federationResolveSeq;

    setState(() {
      _federationLoading = true;
      _federationError = null;
      _resolvedFederation = null;
      _recipientLoading = true;
      _resolvedRecipient = null;
    });

    try {
      final resolved = await FederationAddressCoreService.I.resolveByName(
        federationAddress,
        domain: _federationDomain,
      );
      if (!mounted || requestId != _federationResolveSeq) return;

      final accountId = resolved.accountId.trim();
      if (accountId.isEmpty || !_looksLikeStellarPk(accountId)) {
        throw StateError('Resolved federation has no valid Stellar account id');
      }

      vm.setRecipient(accountId);
      setState(() {
        _resolvedFederation = resolved;
        _federationLoading = false;
      });
      await _lookupRecipient(accountId);
    } catch (e) {
      if (!mounted || requestId != _federationResolveSeq) return;
      vm.setRecipient('');
      setState(() {
        _federationLoading = false;
        _recipientLoading = false;
        _resolvedFederation = null;
        _federationError = 'Federation not found or unavailable.';
      });
    }
  }

  Future<void> _loadFederationDomain() async {
    if (!mounted) return;
    setState(
      () => _federationDomain = FederationAddressCoreService.defaultDomain,
    );
    _updateFederationSuggestions(_toCtl.text.trim());
  }

  void _updateFederationSuggestions(String input) {
    final domain = _federationDomain.trim();
    if (domain.isEmpty ||
        input.isEmpty ||
        input.contains('*') ||
        !_looksLikeFederationAliasInput(input)) {
      if (_federationSuggestions.isNotEmpty) {
        setState(() => _federationSuggestions = const []);
      }
      return;
    }

    final candidate = '${input.toLowerCase()}*$domain';
    if (_federationSuggestions.length == 1 &&
        _federationSuggestions.first == candidate) {
      return;
    }
    setState(() => _federationSuggestions = [candidate]);
  }

  void _applyFederationSuggestion(String value) {
    _toCtl.text = value;
    _toCtl.selection = TextSelection.fromPosition(
      TextPosition(offset: _toCtl.text.length),
    );
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
    await context.read<SendVM>().refreshFees();
    _onRecipientChanged();
    await Future.delayed(const Duration(milliseconds: 250));
  }

  double _floorTo(double v, int dec) {
    final scale = math.pow(10, dec);
    return (v >= 0 ? (v * scale).floor() / scale : (v * scale).ceil() / scale)
        .toDouble();
  }

  String _fmtAmount(double v, {int decimals = 7}) {
    final s = v.toStringAsFixed(decimals);
    return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
  }

  void _applyPercent(SendVM vm, double percent) {
    HapticFeedback.selectionClick();

    double targetAmount;
    if (percent >= 0.999) {
      // MAX button (1.0)
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
      TextPosition(offset: _amtCtl.text.length),
    );
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
      TextPosition(offset: _toCtl.text.length),
    );
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
      TextPosition(offset: _toCtl.text.length),
    );

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
            _buildModernHeader(c, tokenStr),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                color: c.primary,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    const SizedBox(height: 24),
                    _buildAmountCard(c, vm, tokenStr),
                    const SizedBox(height: 20),
                    _buildRecipientCard(c, vm),
                    if (!vm.isXlm) ...[
                      const SizedBox(height: 16),
                      _buildTrustlineStatus(c, vm),
                    ],
                    const SizedBox(height: 16),
                    _buildMemoCard(c),
                    if (vm.typedAmount > 0) ...[
                      const SizedBox(height: 24),
                      _buildTransactionBreakdown(c, vm, tokenStr),
                    ],
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildFloatingActionBar(c, vm),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // MODERN HEADER - Minimalist, clean app bar
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildModernHeader(AppColor c, String tokenStr) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 12),
      decoration: BoxDecoration(
        color: c.background,
        border: Border(
          bottom: BorderSide(color: c.border.withOpacity(0.06), width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(LucideIcons.arrowLeft, color: c.textPrimary, size: 22),
            splashRadius: 22,
          ),
          const SizedBox(width: 8),
          Text(
            'Send $tokenStr',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          AssetLogo(keyOrSymbol: tokenStr, size: 32),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // AMOUNT CARD - Hero section with large input and quick actions
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildAmountCard(AppColor c, SendVM vm, String tokenStr) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? c.surface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: c.border.withOpacity(isDark ? 0.08 : 0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.1)
                : Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 1),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label + Balance
          Row(
            children: [
              Text(
                'Amount',
                style: TextStyle(
                  color: c.textSecondary.withOpacity(0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  height: 1,
                ),
              ),
              const Spacer(),
              Icon(
                LucideIcons.wallet,
                size: 14,
                color: c.textSecondary.withOpacity(0.5),
              ),
              const SizedBox(width: 6),
              Text(
                '${_fmtAmount(vm.senderBalanceToken, decimals: vm.isXlm ? 4 : 2)} $tokenStr',
                style: TextStyle(
                  color: c.textSecondary.withOpacity(0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Large amount input
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: _amtCtl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,7}$'),
                    ),
                  ],
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                    letterSpacing: -1.5,
                    height: 1.1,
                  ),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(
                      color: c.textSecondary.withOpacity(0.2),
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.5,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    tokenStr,
                    style: TextStyle(
                      color: c.textSecondary.withOpacity(0.6),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _applyPercent(vm, 1.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: c.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: c.primary.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'MAX',
                        style: TextStyle(
                          color: c.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Quick amount chips
          _buildQuickAmountChips(c, vm),
        ],
      ),
    );
  }

  Widget _buildQuickAmountChips(AppColor c, SendVM vm) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final presets = [('25%', 0.25), ('50%', 0.50), ('75%', 0.75)];

    return Row(
      children: [
        for (int i = 0; i < presets.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => _applyPercent(vm, presets[i].$2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color:
                      (_lastPct != null &&
                          (_lastPct! - presets[i].$2).abs() < 0.001)
                      ? c.primary.withOpacity(0.1)
                      : (isDark ? c.background : c.surface.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color:
                        (_lastPct != null &&
                            (_lastPct! - presets[i].$2).abs() < 0.001)
                        ? c.primary.withOpacity(0.3)
                        : c.border.withOpacity(isDark ? 0.1 : 0.15),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    presets[i].$1,
                    style: TextStyle(
                      color:
                          (_lastPct != null &&
                              (_lastPct! - presets[i].$2).abs() < 0.001)
                          ? c.primary
                          : c.textSecondary.withOpacity(0.7),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // RECIPIENT CARD - Clean address input with contact integration
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildRecipientCard(AppColor c, SendVM vm) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final addr = _toCtl.text.trim();
    final resolvedAccountId = _resolvedFederation?.accountId.trim();
    final hasValidAddr =
        _looksLikeStellarPk(addr) ||
        (_looksLikeFederation(addr) &&
            resolvedAccountId != null &&
            _looksLikeStellarPk(resolvedAccountId));
    final hasFederationInput = _looksLikeFederation(addr);
    final recipientLookupAddress = _looksLikeStellarPk(addr)
        ? addr
        : (resolvedAccountId ?? addr);
    final isLoadingRecipient = _recipientLoading || _federationLoading;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? c.surface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: c.border.withOpacity(isDark ? 0.08 : 0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Send to',
                style: TextStyle(
                  color: c.textSecondary.withOpacity(0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              // Quick action buttons
              _buildQuickActionButton(
                c,
                icon: LucideIcons.qrCode,
                onTap: _openScanner,
              ),
              const SizedBox(width: 8),
              _buildQuickActionButton(
                c,
                icon: LucideIcons.users,
                onTap: _openRecipientsPicker,
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (isLoadingRecipient)
            _buildRecipientLoadingState(c)
          else if (hasValidAddr && _resolvedRecipient != null)
            _buildSavedRecipientChip(c, _resolvedRecipient!)
          else if (hasValidAddr && _resolvedRecipient == null)
            _buildNewRecipientChip(c, recipientLookupAddress)
          else
            _buildRecipientInputField(c, addr, isDark),
          if (_federationSuggestions.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildFederationSuggestions(c),
          ],
          if (hasFederationInput) ...[
            const SizedBox(height: 10),
            _buildFederationStatus(c),
          ],
        ],
      ),
    );
  }

  Widget _buildFederationSuggestions(AppColor c) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _federationSuggestions
          .map(
            (s) => ActionChip(
              avatar: Icon(LucideIcons.atSign, size: 14, color: c.primary),
              label: Text(s),
              labelStyle: TextStyle(
                color: c.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
              side: BorderSide(color: c.primary.withOpacity(0.35)),
              backgroundColor: c.primary.withOpacity(0.08),
              onPressed: () => _applyFederationSuggestion(s),
            ),
          )
          .toList(),
    );
  }

  Widget _buildFederationStatus(AppColor c) {
    if (_federationLoading) {
      return _buildStatusBanner(
        c,
        icon: null,
        title: 'Resolving federation address...',
        color: c.primary,
        showSpinner: true,
      );
    }

    if (_federationError != null) {
      return _buildStatusBanner(
        c,
        icon: LucideIcons.alertCircle,
        title: _federationError!,
        color: c.error,
      );
    }

    final resolved = _resolvedFederation;
    if (resolved != null && resolved.accountId.trim().isNotEmpty) {
      return _buildStatusBanner(
        c,
        icon: LucideIcons.checkCircle2,
        title: 'Resolved to ${_shortenAddress(resolved.accountId)}',
        subtitle: resolved.stellarAddress,
        color: c.success,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildQuickActionButton(
    AppColor c, {
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? c.background : c.surface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: c.border.withOpacity(isDark ? 0.1 : 0.15),
            width: 1,
          ),
        ),
        child: Icon(icon, size: 18, color: c.primary.withOpacity(0.8)),
      ),
    );
  }

  Widget _buildRecipientLoadingState(AppColor c) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: c.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.primary.withOpacity(0.1), width: 1),
      ),
      child: Center(
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: c.primary.withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildSavedRecipientChip(AppColor c, RecipientAddressModel recipient) {
    final color = Color(recipient.color);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(isDark ? 0.2 : 0.15),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                recipient.name.isNotEmpty
                    ? recipient.name[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name & Address
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
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _shortenAddress(recipient.address),
                  style: TextStyle(
                    color: c.textSecondary.withOpacity(0.6),
                    fontFamily: 'monospace',
                    fontSize: 12,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Edit button
          GestureDetector(
            onTap: () async {
              final ok = await showRecipientUpsertSheet(
                context,
                initial: _resolvedRecipient,
              );
              if (ok == true && mounted) _lookupRecipient(_toCtl.text.trim());
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(LucideIcons.pencil, size: 16, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewRecipientChip(AppColor c, String addr) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? c.background : c.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: c.border.withOpacity(isDark ? 0.12 : 0.2),
          width: 1.5,
          style: BorderStyle.solid,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: c.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              LucideIcons.userPlus,
              size: 18,
              color: c.primary.withOpacity(0.7),
            ),
          ),
          const SizedBox(width: 12),
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
                const SizedBox(height: 3),
                Text(
                  _shortenAddress(addr),
                  style: TextStyle(
                    color: c.textSecondary.withOpacity(0.6),
                    fontFamily: 'monospace',
                    fontSize: 12,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              final saved = await showRecipientUpsertSheet(
                context,
                address: addr,
              );
              if (saved == true && mounted) _lookupRecipient(addr);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: c.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
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

  Widget _buildRecipientInputField(AppColor c, String addr, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? c.background : c.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: c.border.withOpacity(isDark ? 0.12 : 0.2),
          width: 1.5,
        ),
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
          hintText: 'Paste G... or alias*$_federationDomain',
          hintStyle: TextStyle(
            color: c.textSecondary.withOpacity(0.4),
            fontSize: 14,
            letterSpacing: -0.2,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Icon(
              LucideIcons.wallet,
              color: c.textSecondary.withOpacity(0.5),
              size: 18,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0),
          suffixIcon: addr.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    onPressed: () {
                      _toCtl.clear();
                      setState(() => _resolvedRecipient = null);
                      context.read<SendVM>().setRecipient('');
                    },
                    icon: Icon(
                      LucideIcons.x,
                      size: 18,
                      color: c.textSecondary.withOpacity(0.5),
                    ),
                    splashRadius: 20,
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // TRUSTLINE STATUS - Inline verification banner
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildTrustlineStatus(AppColor c, SendVM vm) {
    if (vm.to.trim().isEmpty) return const SizedBox.shrink();

    if (vm.checking) {
      return _buildStatusBanner(
        c,
        icon: null,
        title: 'Verifying trustline…',
        color: c.primary,
        showSpinner: true,
      );
    }

    if (vm.destHasUsdcTL == false) {
      return _buildStatusBanner(
        c,
        icon: LucideIcons.alertCircle,
        title: 'Cannot receive USDC',
        subtitle: 'Recipient needs to add USDC trustline',
        color: c.error,
      );
    }

    if (vm.destHasUsdcTL == true) {
      return _buildStatusBanner(
        c,
        icon: LucideIcons.checkCircle2,
        title: 'Ready to receive USDC',
        color: c.success,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildStatusBanner(
    AppColor c, {
    IconData? icon,
    required String title,
    String? subtitle,
    required Color color,
    bool showSpinner = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(isDark ? 0.2 : 0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          if (showSpinner)
            SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: color.withOpacity(0.7),
              ),
            )
          else if (icon != null)
            Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: color.withOpacity(0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // MEMO CARD - Optional note field
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildMemoCard(AppColor c) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasError = _memoBytes > 28;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? c.surface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: hasError
              ? c.error.withOpacity(0.3)
              : c.border.withOpacity(isDark ? 0.08 : 0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Memo',
                style: TextStyle(
                  color: c.textSecondary.withOpacity(0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: c.textSecondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'OPTIONAL',
                  style: TextStyle(
                    color: c.textSecondary.withOpacity(0.5),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '$_memoBytes / 28',
                style: TextStyle(
                  color: hasError ? c.error : c.textSecondary.withOpacity(0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
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
                color: c.textSecondary.withOpacity(0.35),
                fontSize: 14,
                letterSpacing: -0.2,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
          ),
          if (hasError) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(LucideIcons.alertCircle, size: 14, color: c.error),
                const SizedBox(width: 6),
                Text(
                  'Memo exceeds 28 bytes',
                  style: TextStyle(
                    color: c.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // TRANSACTION BREAKDOWN - Fee summary
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildTransactionBreakdown(AppColor c, SendVM vm, String tokenStr) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? c.surface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: c.border.withOpacity(isDark ? 0.08 : 0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.15)
                : Colors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 3),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transaction summary',
            style: TextStyle(
              color: c.textSecondary.withOpacity(0.7),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 16),

          // Recipient receives
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.primary.withOpacity(0.15), width: 1),
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.arrowUpRight,
                  size: 16,
                  color: c.primary.withOpacity(0.7),
                ),
                const SizedBox(width: 10),
                Text(
                  'Recipient receives',
                  style: TextStyle(
                    color: c.textSecondary.withOpacity(0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
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

          const SizedBox(height: 12),

          // Network fee
          _buildFeeRow(
            c,
            label: 'Network fee',
            value: '${(vm.estNetworkFeeXlm ?? 0).toStringAsFixed(7)} XLM',
            icon: LucideIcons.zap,
          ),

          if (vm.isXlm && vm.totalDeductFromBalance > 0) ...[
            const SizedBox(height: 8),
            _buildFeeRow(
              c,
              label: 'Total deducted',
              value: '${_numFmt.format(vm.totalDeductFromBalance)} XLM',
              icon: LucideIcons.minusCircle,
            ),
          ],

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: c.border.withOpacity(0.15), height: 1),
          ),

          _buildFeeRow(
            c,
            label: 'Remaining balance',
            value: '${_fmtAmount(vm.remainingExpendable)} $tokenStr',
            icon: LucideIcons.wallet,
            muted: true,
          ),
        ],
      ),
    );
  }

  Widget _buildFeeRow(
    AppColor c, {
    required String label,
    required String value,
    required IconData icon,
    bool muted = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 15,
            color: muted
                ? c.textSecondary.withOpacity(0.4)
                : c.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: c.textSecondary.withOpacity(muted ? 0.5 : 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: muted ? c.textSecondary : c.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // FLOATING ACTION BAR - Modern bottom CTA
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildFloatingActionBar(AppColor c, SendVM vm) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canSubmit = vm.blockingReason == null && _memoBytes <= 28;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? c.surface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: c.border.withOpacity(isDark ? 0.1 : 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.4)
                : Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, -4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, -2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: AppElevatedButton(
            onPressed: canSubmit
                ? () async {
                    HapticFeedback.mediumImpact();
                    await _confirmAndSend(vm);
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canSubmit ? c.primary : c.surface,
              foregroundColor: canSubmit
                  ? Colors.white
                  : c.textSecondary.withOpacity(0.4),
              disabledBackgroundColor: c.surface,
              disabledForegroundColor: c.textSecondary.withOpacity(0.4),
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(canSubmit ? LucideIcons.send : LucideIcons.lock, size: 20),
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
// REVIEW SHEET - Redesigned confirmation modal
// ============================================================================

class _ReviewSheet extends StatefulWidget {
  final String memo;
  final String? recipientName;

  const _ReviewSheet({required this.memo, this.recipientName});

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? c.surface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 40,
              offset: const Offset(0, -8),
              spreadRadius: 0,
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                  color: c.border.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Text(
                      'Confirm transaction',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                        color: c.textPrimary,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const Spacer(),
                    AssetLogo(keyOrSymbol: tokenStr, size: 28),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Amount hero
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        c.primary.withOpacity(0.12),
                        c.primary.withOpacity(0.06),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: c.primary.withOpacity(0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Sending',
                        style: TextStyle(
                          color: c.textSecondary.withOpacity(0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            numFmt.format(vm.recipientWillReceive),
                            style: TextStyle(
                              color: c.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 36,
                              letterSpacing: -1.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            tokenStr,
                            style: TextStyle(
                              color: c.primary.withOpacity(0.7),
                              fontWeight: FontWeight.w600,
                              fontSize: 20,
                              letterSpacing: -0.5,
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
                    _buildReviewSection(
                      c,
                      children: [
                        _buildReviewRow(
                          c,
                          label: 'From',
                          value: _shortenAddress(vm.senderAddress),
                          icon: LucideIcons.userCircle,
                        ),
                        const SizedBox(height: 14),
                        _buildReviewRow(
                          c,
                          label: widget.recipientName != null
                              ? 'To (${widget.recipientName})'
                              : 'To',
                          value: _shortenAddress(vm.to),
                          icon: LucideIcons.target,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildReviewSection(
                      c,
                      children: [
                        _buildReviewRow(
                          c,
                          label: 'Network fee',
                          value:
                              '${(vm.estNetworkFeeXlm ?? 0).toStringAsFixed(7)} XLM',
                          icon: LucideIcons.zap,
                        ),
                        if (vm.isXlm) ...[
                          const SizedBox(height: 14),
                          _buildReviewRow(
                            c,
                            label: 'Total deducted',
                            value:
                                '${numFmt.format(vm.totalDeductFromBalance)} XLM',
                            icon: LucideIcons.minusCircle,
                          ),
                        ],
                        const SizedBox(height: 14),
                        _buildReviewRow(
                          c,
                          label: 'Remaining',
                          value:
                              '${numFmt.format(vm.remainingExpendable)} $tokenStr',
                          icon: LucideIcons.wallet,
                          muted: true,
                        ),
                      ],
                    ),
                    if (widget.memo.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildReviewSection(
                        c,
                        children: [
                          _buildReviewRow(
                            c,
                            label: 'Memo',
                            value: widget.memo,
                            icon: LucideIcons.messageSquare,
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
                      child: AppOutlinedButton(
                        onPressed: _sending
                            ? null
                            : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: BorderSide(
                            color: c.border.withOpacity(0.3),
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
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: AppElevatedButton(
                        onPressed: _sending
                            ? null
                            : () => _confirm(vm, context),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          backgroundColor: _sending
                              ? c.primary.withOpacity(0.7)
                              : c.primary,
                          foregroundColor: Colors.white,
                          elevation: _sending ? 0 : 2,
                          shadowColor: c.primary.withOpacity(0.3),
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
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(LucideIcons.checkCircle, size: 18),
                                  SizedBox(width: 12),
                                  Text(
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

  Widget _buildReviewSection(AppColor c, {required List<Widget> children}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? c.background : c.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: c.border.withOpacity(isDark ? 0.1 : 0.15),
          width: 1,
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildReviewRow(
    AppColor c, {
    required String label,
    required String value,
    required IconData icon,
    bool muted = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: muted
              ? c.textSecondary.withOpacity(0.4)
              : c.textSecondary.withOpacity(0.6),
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
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                value,
                style: TextStyle(
                  color: muted ? c.textSecondary : c.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  letterSpacing: -0.2,
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
    return const PageLoader(label: 'Loading wallet...');
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
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: c.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(0.2)
                        : c.error.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Icon(LucideIcons.alertTriangle, size: 40, color: c.error),
            ),
            const SizedBox(height: 24),
            Text(
              'Unable to Load',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 20,
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
            const SizedBox(height: 28),
            AppElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(LucideIcons.refreshCw, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                backgroundColor: c.primary,
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: c.primary.withOpacity(0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
