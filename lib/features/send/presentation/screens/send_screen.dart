import 'dart:convert' show utf8;
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:next_fi/core/widgets/button/app_buttons.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/core/widgets/asset/asset_logo.dart';
import 'package:next_fi/core/widgets/loader/page_loader.dart';
import 'package:next_fi/core/widgets/modal/recipient_upsert_sheet.dart';
import 'package:next_fi/core/widgets/snackbar/snack_bar.dart';
import 'package:next_fi/core/widgets/alert/app_alert.dart';

import 'package:next_fi/features/contact/data/models/recipient_address_model.dart';
import 'package:next_fi/features/wallet_home/presentation/widgets/recipient_list_widget.dart';
import 'package:next_fi/features/scanner/presentation/screens/scanner_screen.dart';
import 'package:next_fi/features/contact/presentation/viewmodels/contact_list_notifier.dart';
import 'package:next_fi/features/send/presentation/viewmodels/send_controller.dart';
import 'package:next_fi/features/send/presentation/viewmodels/send_state.dart';

class _ST {
  final bool isDark;

  final Color cardBg;
  final Color inputBg;
  final Color chipBg;
  final Color chipBorder;

  final Color primaryTint;
  final Color primaryTintBorder;
  final Color primaryMuted;

  final Color successTint;
  final Color successBorder;
  final Color successText;
  final Color errorTint;
  final Color errorBorder;
  final Color warningTint;
  final Color warningBorder;

  final Color labelColor;
  final Color metaColor;
  final Color monoColor;
  final Color dividerColor;

  const _ST._({
    required this.isDark,
    required this.cardBg,
    required this.inputBg,
    required this.chipBg,
    required this.chipBorder,
    required this.primaryTint,
    required this.primaryTintBorder,
    required this.primaryMuted,
    required this.successTint,
    required this.successBorder,
    required this.successText,
    required this.errorTint,
    required this.errorBorder,
    required this.warningTint,
    required this.warningBorder,
    required this.labelColor,
    required this.metaColor,
    required this.monoColor,
    required this.dividerColor,
  });

  static _ST of(BuildContext context) {
    final c = AppColor.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return _ST._(
      isDark: dark,
      cardBg: dark ? c.surface : c.onPrimary,
      inputBg: c.background,
      chipBg: c.background,
      chipBorder: c.border,
      primaryTint: c.background,
      primaryTintBorder: c.border,
      primaryMuted: c.primary,
      successTint: c.background,
      successBorder: c.border,
      successText: c.success,
      errorTint: c.background,
      errorBorder: c.border,
      warningTint: c.background,
      warningBorder: c.border,
      labelColor: c.textSecondary,
      metaColor: c.textSecondary,
      monoColor: c.textSecondary,
      dividerColor: c.border,
    );
  }
}

class SendScreen extends ConsumerStatefulWidget {
  final String address;
  final String assetId;
  final double balance;
  final bool autoOpenScanner;
  final String? prefillAddress;
  final String? prefillName;
  final Future<void> Function()? onTransactionCompleted;

  const SendScreen({
    super.key,
    required this.address,
    required this.assetId,
    required this.balance,
    this.autoOpenScanner = false,
    this.prefillAddress,
    this.prefillName,
    this.onTransactionCompleted,
  });

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen> {
  final _toCtl = TextEditingController();
  final _amtCtl = TextEditingController();
  final _memoCtl = TextEditingController();

  int _memoBytes = 0;
  double? _lastPct;
  final _numFmt = NumberFormat('#,##0.######');

  bool _booted = false;
  bool _scannerOpenedOnce = false;

  SendControllerArgs get _args => SendControllerArgs(
    address: widget.address,
    assetId: widget.assetId,
    balance: widget.balance,
    prefillAddress: widget.prefillAddress,
    prefillName: widget.prefillName,
  );

  @override
  void initState() {
    super.initState();
    if (_booted) return;

    _toCtl.text = widget.prefillAddress ?? '';

    _amtCtl.addListener(() {
      final v = double.tryParse(_amtCtl.text.trim()) ?? 0;
      ref.read(sendControllerProvider(_args).notifier).setTypedAmount(v);
      _lastPct = null;
      setState(() {});
    });

    _toCtl.addListener(() {
      ref
          .read(sendControllerProvider(_args).notifier)
          .onRecipientInputChanged(_toCtl.text);
    });

    _memoCtl.addListener(() {
      _memoBytes = utf8.encode(_memoCtl.text).length;
      ref.read(sendControllerProvider(_args).notifier).setMemo(_memoCtl.text);
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(contactListProvider.notifier).ensureLoaded();
    });
    _booted = true;
  }

  @override
  void dispose() {
    _toCtl.dispose();
    _amtCtl.dispose();
    _memoCtl.dispose();
    super.dispose();
  }

  void _applyFederationSuggestion(String value) {
    _toCtl.text = value;
    _toCtl.selection = TextSelection.fromPosition(
      TextPosition(offset: _toCtl.text.length),
    );
  }

  Future<void> _refresh() async {
    await ref.read(sendControllerProvider(_args).notifier).refreshFees();
    await ref
        .read(sendControllerProvider(_args).notifier)
        .onRecipientInputChanged(_toCtl.text);
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

  void _applyPercent(SendState vm, double percent) {
    HapticFeedback.selectionClick();
    double targetAmount;
    if (percent >= 0.999) {
      targetAmount = vm.isXlm
          ? (vm.senderBalanceToken - vm.networkFee).clamp(0, double.infinity)
          : vm.senderBalanceToken;
    } else {
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

  String _shortenAddress(String addr) {
    if (addr.length <= 16) return addr;
    return '${addr.substring(0, 6)}...${addr.substring(addr.length - 6)}';
  }

  Future<void> _confirmAndSend(SendState vm) async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColor.of(context).surface,
      builder: (_) => _ReviewSheet(
        args: _args,
        recipientName: vm.resolvedRecipient?.name,
        onTransactionCompleted: widget.onTransactionCompleted,
      ),
    );
    if (sent == true && mounted) {
      _amtCtl.clear();
      _memoCtl.clear();
      setState(() => _lastPct = null);
    }
  }

  Future<void> _openScanner() async {
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    final navigator = Navigator.of(context);
    await Future.delayed(const Duration(milliseconds: 60));
    if (!mounted) return;

    final raw = await navigator.push(
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
        try {
          final params = Uri.splitQueryString(
            cut.substring(qIdx + 1),
            encoding: utf8,
          );
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
      } else if (mounted) {
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
    if (mounted) {
      ref
          .read(sendControllerProvider(_args).notifier)
          .applyPickedRecipient(addr);
    }
  }

  Future<void> _openRecipientsPicker() async {
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    final picked = await Navigator.push<RecipientAddressModel>(
      context,
      MaterialPageRoute(
        builder: (innerCtx) => RecipientListWidget(
          colors: AppColor.of(innerCtx),
          showAppBar: true,
          onSelect: (r) => Navigator.of(innerCtx).pop(r),
          fromAddress: widget.address,
        ),
      ),
    );
    if (!mounted || picked == null) return;
    final addr = picked.address.trim();
    _toCtl.text = addr;
    _toCtl.selection = TextSelection.fromPosition(
      TextPosition(offset: addr.length),
    );
    ref
        .read(sendControllerProvider(_args).notifier)
        .applyPickedRecipient(addr, displayName: picked.name);
  }

  bool _looksLikeStellarPk(String value) =>
      RegExp(r'^G[A-Z2-7]{55}$').hasMatch(value);

  String? _parseStellarAddress(String input) {
    final s = input.trim();
    final uriIdx = s.toLowerCase().indexOf('stellar:');
    if (uriIdx != -1) {
      final after = s.substring(uriIdx + 'stellar:'.length);
      final cut = after.split(RegExp(r'[?#/]')).first;
      if (_looksLikeStellarPk(cut)) return cut;
    }
    final m = RegExp(r'\bG[A-Z2-7]{55}\b').firstMatch(s);
    return m?.group(0);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final t = _ST.of(context);
    final vm = ref.watch(sendControllerProvider(_args));
    final tokenStr = vm.assetSymbol;

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
            _buildHeader(c, t, tokenStr),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                color: c.primary,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    const SizedBox(height: 20),
                    _buildAmountCard(c, t, vm, tokenStr),
                    const SizedBox(height: 12),
                    _buildRecipientCard(c, t, vm),
                    if (!vm.isXlm) ...[
                      const SizedBox(height: 10),
                      _buildTrustlineStatus(c, t, vm),
                    ],
                    const SizedBox(height: 12),
                    _buildMemoCard(c, t),
                    if (vm.typedAmount > 0) ...[
                      const SizedBox(height: 12),
                      _buildBreakdownCard(c, t, vm, tokenStr),
                    ],
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildActionBar(c, t, vm),
    );
  }

  Widget _buildHeader(AppColor c, _ST t, String tokenStr) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 6, 20, 10),
      decoration: BoxDecoration(
        color: c.background,
        border: Border(bottom: BorderSide(color: t.dividerColor, width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(LucideIcons.arrowLeft, color: c.textPrimary, size: 21),
            splashRadius: 22,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Send',
                  style: TextStyle(
                    color: t.labelColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tokenStr,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          AssetLogo(keyOrSymbol: tokenStr, size: 34),
        ],
      ),
    );
  }

  Widget _buildAmountCard(AppColor c, _ST t, SendState vm, String tokenStr) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.chipBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SectionLabel('Amount'),
              const Spacer(),
              Icon(LucideIcons.wallet, size: 13, color: t.labelColor),
              const SizedBox(width: 5),
              Text(
                'Spendable: ${_fmtAmount(vm.senderBalanceToken, decimals: vm.isXlm ? 4 : 2)} $tokenStr',
                style: TextStyle(
                  color: t.labelColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

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
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                    letterSpacing: -2,
                    height: 1.05,
                  ),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(
                      color: t.metaColor,
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -2,
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tokenStr,
                    style: TextStyle(
                      color: t.labelColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _MaxButton(t: t, c: c, onTap: () => _applyPercent(vm, 1.0)),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),
          _buildDivider(t),
          const SizedBox(height: 14),

          _buildPctChips(c, t, vm),
        ],
      ),
    );
  }

  Widget _buildPctChips(AppColor c, _ST t, SendState vm) {
    const presets = [('25%', 0.25), ('50%', 0.50), ('75%', 0.75)];
    return Row(
      children: [
        for (int i = 0; i < presets.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _buildPctChip(
              c,
              t,
              label: presets[i].$1,
              pct: presets[i].$2,
              vm: vm,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPctChip(
    AppColor c,
    _ST t, {
    required String label,
    required double pct,
    required SendState vm,
  }) {
    final active = _lastPct != null && (_lastPct! - pct).abs() < 0.001;
    return GestureDetector(
      onTap: () => _applyPercent(vm, pct),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? t.primaryTint : t.chipBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? t.primaryTintBorder : t.chipBorder,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: active ? c.primary : t.labelColor,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecipientCard(AppColor c, _ST t, SendState vm) {
    final addr = vm.recipientInput.trim();
    final resolvedAccountId = vm.resolvedFederation?.accountId.trim();
    final hasValidAddr =
        _looksLikeStellarPk(addr) ||
        (addr.contains('*') &&
            resolvedAccountId != null &&
            _looksLikeStellarPk(resolvedAccountId));
    final hasFederationInput = addr.contains('*');
    final recipientLookupAddress = _looksLikeStellarPk(addr)
        ? addr
        : (resolvedAccountId ?? addr);
    final isLoading = vm.recipientLoading || vm.federationLoading;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.chipBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SectionLabel('Send to'),
              const Spacer(),
              _IconPill(
                icon: LucideIcons.qrCode,
                t: t,
                c: c,
                onTap: _openScanner,
                tooltip: 'Scan QR',
              ),
              const SizedBox(width: 8),
              _IconPill(
                icon: LucideIcons.contact2,
                t: t,
                c: c,
                onTap: _openRecipientsPicker,
                tooltip: 'Contacts',
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (isLoading)
            _RecipientLoadingLine(t: t, c: c)
          else if (hasValidAddr && vm.resolvedRecipient != null)
            _RecipientBadge(
              name: vm.resolvedRecipient!.name,
              address: vm.resolvedRecipient!.address,
              colorValue: vm.resolvedRecipient!.color,
              t: t,
              c: c,
              onEdit: () async {
                final ok = await showRecipientUpsertSheet(
                  context,
                  initial: vm.resolvedRecipient,
                );
                if (ok == true && mounted) {
                  await ref.read(contactListProvider.notifier).refresh();
                  await ref
                      .read(sendControllerProvider(_args).notifier)
                      .onRecipientInputChanged(_toCtl.text.trim());
                }
              },
            )
          else if (hasValidAddr && vm.resolvedRecipient == null)
            _RecipientAddTemplate(
              address: recipientLookupAddress,
              t: t,
              c: c,
              onAdd: () async {
                final saved = await showRecipientUpsertSheet(
                  context,
                  address: recipientLookupAddress,
                );
                if (saved == true && mounted) {
                  await ref.read(contactListProvider.notifier).refresh();
                  await ref
                      .read(sendControllerProvider(_args).notifier)
                      .onRecipientInputChanged(recipientLookupAddress);
                }
              },
            )
          else
            _buildAddressInput(c, t, addr, vm),

          if (vm.federationSuggestions.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildFederationSuggestions(c, t, vm),
          ],
          if (hasFederationInput) ...[
            const SizedBox(height: 10),
            _buildFederationStatus(c, t, vm),
          ],
        ],
      ),
    );
  }

  Widget _buildAddressInput(AppColor c, _ST t, String addr, SendState vm) {
    return Container(
      decoration: BoxDecoration(
        color: t.inputBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: _toCtl,
        textInputAction: TextInputAction.next,
        keyboardType: TextInputType.multiline,
        minLines: 1,
        maxLines: null,
        style: TextStyle(
          fontSize: 15.5,
          fontWeight: FontWeight.w500,
          color: c.textPrimary,
          letterSpacing: -0.2,
          fontFeatures: const [ui.FontFeature.tabularFigures()],
        ),
        decoration: InputDecoration(
          hintText: 'Paste G... address or alias*${vm.federationDomain}',
          hintMaxLines: 1,
          hintStyle: TextStyle(
            color: t.metaColor,
            fontSize: 14,
            letterSpacing: -0.2,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 15, right: 10),
            child: Icon(LucideIcons.wallet, color: t.labelColor, size: 17),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0),
          suffixIcon: addr.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: IconButton(
                    onPressed: () {
                      _toCtl.clear();
                      ref
                          .read(sendControllerProvider(_args).notifier)
                          .onRecipientInputChanged('');
                    },
                    icon: Icon(LucideIcons.x, size: 16, color: t.labelColor),
                    splashRadius: 18,
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 19,
          ),
        ),
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
      ),
    );
  }

  Widget _buildFederationSuggestions(AppColor c, _ST t, SendState vm) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: vm.federationSuggestions
          .map(
            (s) => GestureDetector(
              onTap: () => _applyFederationSuggestion(s),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width - 80,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: t.primaryTint,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: t.primaryTintBorder, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.atSign, size: 13, color: c.primary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          s,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildFederationStatus(AppColor c, _ST t, SendState vm) {
    if (vm.federationLoading) {
      return _StatusBanner(
        t: t,
        c: c,
        icon: null,
        title: 'Resolving federation address...',
        color: c.primary,
        tint: t.primaryTint,
        border: t.primaryTintBorder,
        showSpinner: true,
      );
    }
    if (vm.federationError != null) {
      return _StatusBanner(
        t: t,
        c: c,
        icon: LucideIcons.alertCircle,
        title: vm.federationError!,
        color: c.error,
        tint: t.errorTint,
        border: t.errorBorder,
      );
    }
    final resolved = vm.resolvedFederation;
    if (resolved != null && resolved.accountId.trim().isNotEmpty) {
      return _StatusBanner(
        t: t,
        c: c,
        icon: LucideIcons.checkCircle2,
        title: 'Resolved - ${_shortenAddress(resolved.accountId)}',
        subtitle: resolved.stellarAddress,
        color: t.successText,
        tint: t.successTint,
        border: t.successBorder,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildTrustlineStatus(AppColor c, _ST t, SendState vm) {
    if (vm.destinationAddress.trim().isEmpty) return const SizedBox.shrink();
    if (vm.checking) {
      return _StatusBanner(
        t: t,
        c: c,
        icon: null,
        title: 'Verifying trustline...',
        color: c.primary,
        tint: t.primaryTint,
        border: t.primaryTintBorder,
        showSpinner: true,
      );
    }
    if (vm.destinationHasTrustline == false) {
      return _StatusBanner(
        t: t,
        c: c,
        icon: LucideIcons.alertCircle,
        title: 'Cannot receive ${vm.assetSymbol}',
        subtitle: 'Recipient needs to add a ${vm.assetSymbol} trustline first',
        color: c.error,
        tint: t.errorTint,
        border: t.errorBorder,
      );
    }
    if (vm.destinationHasTrustline == true) {
      return _StatusBanner(
        t: t,
        c: c,
        icon: LucideIcons.checkCircle2,
        title: 'Ready to receive ${vm.assetSymbol}',
        color: t.successText,
        tint: t.successTint,
        border: t.successBorder,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildMemoCard(AppColor c, _ST t) {
    final hasError = _memoBytes > 28;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasError ? c.error : t.chipBorder,
          width: hasError ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SectionLabel('Memo'),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: t.chipBg,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  'OPTIONAL',
                  style: TextStyle(
                    color: t.metaColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '$_memoBytes / 28',
                style: TextStyle(
                  color: hasError ? c.error : t.metaColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _memoCtl,
            minLines: 2,
            maxLines: 3,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w500,
              color: c.textPrimary,
              letterSpacing: -0.2,
            ),
            decoration: InputDecoration(
              hintText: 'Add a note (e.g. invoice ref, exchange tag)',
              hintStyle: TextStyle(
                color: t.metaColor,
                fontSize: 14,
                letterSpacing: -0.2,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              isDense: false,
            ),
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
          ),
          if (hasError) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(LucideIcons.alertCircle, size: 13, color: c.error),
                const SizedBox(width: 6),
                Text(
                  'Memo exceeds 28 bytes - shorten it',
                  style: TextStyle(
                    color: c.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBreakdownCard(AppColor c, _ST t, SendState vm, String tokenStr) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.chipBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('Summary'),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: t.primaryTint,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: t.primaryTintBorder, width: 1),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.arrowUpRight, size: 15, color: c.primary),
                const SizedBox(width: 10),
                Text(
                  'Recipient receives',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_numFmt.format(vm.recipientWillReceive)} $tokenStr',
                  style: TextStyle(
                    color: c.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          _buildDivider(t),
          const SizedBox(height: 12),

          _BreakdownRow(
            icon: LucideIcons.zap,
            label: 'Network fee',
            value: '${(vm.estNetworkFeeXlm ?? 0).toStringAsFixed(7)} XLM',
            t: t,
            c: c,
          ),

          if (vm.isXlm && vm.totalDeductFromBalance > 0) ...[
            const SizedBox(height: 8),
            _BreakdownRow(
              icon: LucideIcons.minusCircle,
              label: 'Total deducted',
              value: '${_numFmt.format(vm.totalDeductFromBalance)} XLM',
              t: t,
              c: c,
            ),
          ],
          const SizedBox(height: 8),
          _BreakdownRow(
            icon: LucideIcons.wallet,
            label: 'Remaining',
            value: '${_fmtAmount(vm.remainingExpendable)} $tokenStr',
            t: t,
            c: c,
            muted: true,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(_ST t) => Container(height: 1, color: t.dividerColor);

  Widget _buildActionBar(AppColor c, _ST t, SendState vm) {
    final canSubmit = vm.blockingReason == null && _memoBytes <= 28;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.chipBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: c.textPrimary.withValues(alpha: t.isDark ? 0.20 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 54,
          child: AppElevatedButton(
            onPressed: canSubmit
                ? () async {
                    HapticFeedback.mediumImpact();
                    await _confirmAndSend(vm);
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canSubmit ? c.primary : t.chipBg,
              foregroundColor: canSubmit
                  ? AppColor.of(context).onPrimary
                  : t.labelColor,
              disabledBackgroundColor: t.chipBg,
              disabledForegroundColor: t.labelColor,
              elevation: 0,
              shadowColor: AppColor.of(context).surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(canSubmit ? LucideIcons.send : LucideIcons.lock, size: 18),
                const SizedBox(width: 10),
                Text(
                  canSubmit ? 'Review & Send' : 'Complete all fields',
                  style: const TextStyle(
                    fontSize: 15.5,
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = _ST.of(context);
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: t.labelColor,
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.9,
        height: 1,
      ),
    );
  }
}

class _MaxButton extends StatelessWidget {
  const _MaxButton({required this.t, required this.c, required this.onTap});
  final _ST t;
  final AppColor c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: t.primaryTint,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: t.primaryTintBorder, width: 1),
        ),
        child: Text(
          'MAX',
          style: TextStyle(
            color: c.primary,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

class _IconPill extends StatelessWidget {
  const _IconPill({
    required this.icon,
    required this.t,
    required this.c,
    required this.onTap,
    required this.tooltip,
  });
  final IconData icon;
  final _ST t;
  final AppColor c;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: t.chipBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: t.chipBorder, width: 1),
        ),
        child: Icon(icon, size: 17, color: t.primaryMuted),
      ),
    );
  }
}

class _RecipientBadge extends StatelessWidget {
  const _RecipientBadge({
    required this.name,
    required this.address,
    required this.colorValue,
    required this.t,
    required this.c,
    required this.onEdit,
  });
  final String name;
  final String address;
  final int colorValue;
  final _ST t;
  final AppColor c;
  final VoidCallback onEdit;

  String _short(String addr) => addr.length <= 16
      ? addr
      : '${addr.substring(0, 6)}...${addr.substring(addr.length - 6)}';

  Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

  @override
  Widget build(BuildContext context) {
    final brand = Color(colorValue);
    final base = t.isDark ? c.surface : c.onPrimary;
    final bgCol = _mix(base, brand, t.isDark ? 0.13 : 0.09);
    final borderCol = _mix(base, brand, t.isDark ? 0.25 : 0.20);
    final avatarBg = _mix(base, brand, t.isDark ? 0.22 : 0.16);
    final editBg = _mix(t.isDark ? c.surface : c.background, brand, 0.14);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgCol,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderCol, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: avatarBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: brand,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    letterSpacing: -0.4,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _short(address),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: TextStyle(
                    color: t.monoColor,
                    fontSize: 11.5,
                    letterSpacing: 0.3,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onEdit,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: editBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderCol, width: 1),
              ),
              child: Center(
                child: Icon(LucideIcons.pencil, size: 14, color: brand),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipientAddTemplate extends StatelessWidget {
  const _RecipientAddTemplate({
    required this.address,
    required this.t,
    required this.c,
    required this.onAdd,
  });
  final String address;
  final _ST t;
  final AppColor c;
  final VoidCallback onAdd;

  String _short(String addr) => addr.length <= 16
      ? addr
      : '${addr.substring(0, 6)}...${addr.substring(addr.length - 6)}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: t.inputBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.chipBorder, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: t.primaryTint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                LucideIcons.userPlus,
                size: 17,
                color: t.primaryMuted,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Save to contacts',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _short(address),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: TextStyle(
                    color: t.monoColor,
                    fontSize: 11.5,
                    letterSpacing: 0.3,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onAdd,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: t.primaryTint,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: t.primaryTintBorder, width: 1),
              ),
              child: Text(
                'Save',
                style: TextStyle(
                  color: c.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipientLoadingLine extends StatelessWidget {
  const _RecipientLoadingLine({required this.t, required this.c});
  final _ST t;
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: t.inputBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.chipBorder, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 17,
            height: 17,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: t.primaryMuted,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Looking up address...',
            style: TextStyle(
              color: t.labelColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.t,
    required this.c,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.color,
    required this.tint,
    required this.border,
    this.showSpinner = false,
  });
  final _ST t;
  final AppColor c;
  final IconData? icon;
  final String title;
  final String? subtitle;
  final Color color;
  final Color tint;
  final Color border;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showSpinner)
            SizedBox(
              height: 17,
              width: 17,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: color),
            )
          else if (icon != null)
            Icon(icon, size: 17, color: color),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: color,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
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
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.t,
    required this.c,
    this.muted = false,
  });
  final IconData icon;
  final String label;
  final String value;
  final _ST t;
  final AppColor c;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: muted ? t.metaColor : t.labelColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: muted ? t.metaColor : t.labelColor,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: muted ? t.labelColor : c.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _ReviewSheet extends ConsumerStatefulWidget {
  final SendControllerArgs args;
  final String? recipientName;
  final Future<void> Function()? onTransactionCompleted;
  const _ReviewSheet({
    required this.args,
    this.recipientName,
    this.onTransactionCompleted,
  });

  @override
  ConsumerState<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<_ReviewSheet> {
  String _short(String addr) => addr.length <= 16
      ? addr
      : '${addr.substring(0, 8)}...${addr.substring(addr.length - 8)}';

  Future<void> _confirm(BuildContext ctx) async {
    if (ref.read(sendControllerProvider(widget.args)).submitting) return;
    final rootContext = Navigator.of(ctx, rootNavigator: true).context;
    try {
      final txHash = await ref
          .read(sendControllerProvider(widget.args).notifier)
          .submit();
      if (!ctx.mounted) return;
      await widget.onTransactionCompleted?.call();
      if (!ctx.mounted) return;
      Navigator.pop(ctx, true);
      if (!rootContext.mounted) return;
      showAppAlert(
        rootContext,
        type: AppAlertType.success,
        title: 'Transaction Sent',
        subtitle: 'Broadcast successfully',
        primaryText: 'Copy TxID',
        onPrimary: () async => Clipboard.setData(ClipboardData(text: txHash)),
      );
    } catch (e) {
      if (!ctx.mounted) return;
      showAppAlert(
        ctx,
        type: AppAlertType.error,
        title: 'Transaction Failed',
        subtitle: e.toString(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final t = _ST.of(context);
    final vm = ref.watch(sendControllerProvider(widget.args));
    final tokenStr = vm.assetSymbol;
    final numFmt = NumberFormat('#,##0.######');

    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: c.textPrimary.withValues(alpha: t.isDark ? 0.24 : 0.10),
              blurRadius: 40,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 3,
                margin: const EdgeInsets.only(top: 12, bottom: 22),
                decoration: BoxDecoration(
                  color: t.chipBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CONFIRM',
                          style: TextStyle(
                            color: t.labelColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Transaction',
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    AssetLogo(keyOrSymbol: tokenStr, size: 30),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  decoration: BoxDecoration(
                    color: t.primaryTint,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: t.primaryTintBorder, width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SENDING',
                            style: TextStyle(
                              color: t.labelColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            numFmt.format(vm.recipientWillReceive),
                            style: TextStyle(
                              color: c.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 38,
                              letterSpacing: -1.8,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          tokenStr,
                          style: TextStyle(
                            color: t.primaryMuted,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    _ReviewSection(
                      t: t,
                      c: c,
                      children: [
                        _ReviewRow(
                          t: t,
                          c: c,
                          label: 'From',
                          value: _short(vm.senderAddress),
                          icon: LucideIcons.userCircle,
                        ),
                        Container(
                          height: 1,
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          color: t.dividerColor,
                        ),
                        _ReviewRow(
                          t: t,
                          c: c,
                          label: widget.recipientName != null
                              ? 'To | ${widget.recipientName}'
                              : 'To',
                          value: _short(vm.destinationAddress),
                          icon: LucideIcons.target,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _ReviewSection(
                      t: t,
                      c: c,
                      children: [
                        _ReviewRow(
                          t: t,
                          c: c,
                          label: 'Network fee',
                          value:
                              '${(vm.estNetworkFeeXlm ?? 0).toStringAsFixed(7)} XLM',
                          icon: LucideIcons.zap,
                        ),
                        if (vm.isXlm) ...[
                          Container(
                            height: 1,
                            margin: const EdgeInsets.symmetric(vertical: 10),
                            color: t.dividerColor,
                          ),
                          _ReviewRow(
                            t: t,
                            c: c,
                            label: 'Total deducted',
                            value:
                                '${numFmt.format(vm.totalDeductFromBalance)} XLM',
                            icon: LucideIcons.minusCircle,
                          ),
                        ],
                        Container(
                          height: 1,
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          color: t.dividerColor,
                        ),
                        _ReviewRow(
                          t: t,
                          c: c,
                          label: 'Remaining after send',
                          value:
                              '${numFmt.format(vm.remainingExpendable)} $tokenStr',
                          icon: LucideIcons.wallet,
                          muted: true,
                        ),
                      ],
                    ),
                    if (vm.memo.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _ReviewSection(
                        t: t,
                        c: c,
                        children: [
                          _ReviewRow(
                            t: t,
                            c: c,
                            label: 'Memo',
                            value: vm.memo,
                            icon: LucideIcons.messageSquare,
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: AppOutlinedButton(
                        onPressed: vm.submitting
                            ? null
                            : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: BorderSide(color: t.chipBorder, width: 1.5),
                          foregroundColor: c.textSecondary,
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: AppElevatedButton(
                        onPressed: vm.submitting
                            ? null
                            : () => _confirm(context),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          backgroundColor: c.primary,
                          foregroundColor: AppColor.of(context).onPrimary,
                          disabledBackgroundColor: t.chipBg,
                          elevation: 0,
                        ),
                        child: vm.submitting
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    height: 17,
                                    width: 17,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: AppColor.of(context).onPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Sending...',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14.5,
                                      letterSpacing: -0.2,
                                      color: AppColor.of(context).onPrimary,
                                    ),
                                  ),
                                ],
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(LucideIcons.checkCircle, size: 17),
                                  SizedBox(width: 10),
                                  Text(
                                    'Confirm Send',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14.5,
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
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({
    required this.t,
    required this.c,
    required this.children,
  });
  final _ST t;
  final AppColor c;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: t.inputBg,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: t.chipBorder, width: 1),
      ),
      child: Column(children: children),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.t,
    required this.c,
    required this.label,
    required this.value,
    required this.icon,
    this.muted = false,
  });
  final _ST t;
  final AppColor c;
  final String label;
  final String value;
  final IconData icon;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: muted ? t.metaColor : t.labelColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: t.metaColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                value,
                style: TextStyle(
                  color: muted ? t.labelColor : c.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
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

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) =>
      const PageLoader(label: 'Loading wallet...');
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final t = _ST.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: t.errorTint,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: t.errorBorder, width: 1),
              ),
              child: Center(
                child: Icon(
                  LucideIcons.alertTriangle,
                  size: 28,
                  color: c.error,
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Unable to Load',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: t.labelColor,
                fontSize: 13.5,
                height: 1.55,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 26),
            AppElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(LucideIcons.refreshCw, size: 17),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                backgroundColor: c.primary,
                foregroundColor: AppColor.of(context).onPrimary,
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
