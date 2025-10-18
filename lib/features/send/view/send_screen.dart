import 'dart:convert' show utf8; // for memo byte counting
import 'dart:math' as math;
import 'dart:ui' as ui; // for FontFeature.tabularFigures
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/asset/asset_logo.dart';
import 'package:next_fi/common/components/loader/page_loader.dart';
import 'package:next_fi/common/components/modal/recipient_upsert_sheet.dart';
import 'package:next_fi/common/components/Input/modern_input.dart';
import 'package:next_fi/common/components/snackbar/SnackBar.dart';
import 'package:next_fi/common/components/alert/AppAlert.dart';

import 'package:next_fi/features/send/model/send_token.dart';
import 'package:next_fi/features/send/view_model/send_vm.dart';

import 'package:next_fi/features/wallet_home/view_model/recipient_address_vm.dart';
import 'package:next_fi/features/wallet_home/model/recipient_address_model.dart';
import 'package:next_fi/features/wallet_home/view/widgets/recipient_list_widget.dart';
import 'package:next_fi/features/scanner/view/scanner_screen.dart';

import 'widgets/error_card.dart';
import 'widgets/balance_line.dart';
import 'widgets/recipient_loading_line.dart';
import 'widgets/recipient_badge.dart';
import 'widgets/recipient_add_template.dart';
import 'widgets/percent_chips_row.dart';
import 'widgets/trustline_hint.dart';
import 'widgets/slim_preview_card.dart';
import 'widgets/flat_sheet.dart';
import 'widgets/slim_review_sheet.dart';

class SendScreen extends StatefulWidget {
  final String address;
  final String token; // 'XLM' or 'USDC'
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

  // Optional memo (TEXT; 28-byte limit)
  final _memoCtl = TextEditingController();
  int _memoBytes = 0;

  final _numFmt = NumberFormat('#,##0.######');

  bool _booted = false;
  bool _scannerOpenedOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_booted) return;

    final vm = context.read<SendVM>();
    vm.configure(
      token: widget.token.toUpperCase() == 'XLM' ? SendToken.xlm : SendToken.usdc,
      senderAddress: widget.address,
      senderBalanceToken: widget.balance,
      prefillTo: widget.prefillAddress,
      prefillName: widget.prefillName,
    );

    _toCtl.text = (widget.prefillAddress ?? '');
    _amtCtl.addListener(() {
      final v = double.tryParse(_amtCtl.text.trim()) ?? 0;
      vm.setTypedAmount(v);
      setState(() {});
    });
    _toCtl.addListener(() {
      vm.setRecipient(_toCtl.text.trim());
      setState(() {});
    });
    _memoCtl.addListener(() {
      _memoBytes = utf8.encode(_memoCtl.text).length;
      setState(() {});
    });

    if (widget.autoOpenScanner && !_scannerOpenedOnce) {
      final hasPrefill = (widget.prefillAddress ?? '').trim().isNotEmpty ||
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

  // ────────────────────────────────────────────────────────────────────────────
  // Helpers
  // ────────────────────────────────────────────────────────────────────────────

  Future<void> _refresh() async {
    final vm = context.read<SendVM>();
    await vm.refreshFees();
    vm.setRecipient(_toCtl.text.trim());
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

  /// Percent chips:
  /// - USDC send: base = full USDC balance (as before).
  /// - XLM send: 100% keeps 1 XLM if sender has USDC trustline; other % = full balance * pct.
  void _applyPercent(SendVM vm, double percent) {
    double base = vm.senderBalanceToken;

    if (vm.isXlm && percent == 1.0 && vm.selfHasUsdcTrustline) {
      if (base > 1.0) {
        base = base - 1.0;
      } else {
        base = 0.0;
      }
      showFloatingSnackBar(
        context,
        message: 'Kept 1 XLM for network fees so USDC stays usable.',
        type: SnackBarType.info,
      );
    } else {
      base = base * percent;
    }

    final v = _floorTo(base, 7);
    HapticFeedback.selectionClick();
    _amtCtl.text = _fmtAmount(v);
    _amtCtl.selection =
        TextSelection.fromPosition(TextPosition(offset: _amtCtl.text.length));
  }

  String? _currentMemoOrNull() {
    final t = _memoCtl.text.trim();
    if (t.isEmpty) return null;
    final bytes = utf8.encode(t);
    if (bytes.length > 28) return null;
    return t;
  }

  Future<void> _confirmAndSend(SendVM vm) async {
    final tokenStr = vm.isXlm ? 'XLM' : 'USDC';
    final recipientGets =
    vm.isXlm ? vm.recipientWillReceiveXlmFromBudget : vm.typedAmount;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FlatSheet(
        maxHeightFactor: 0.50,
        child: SlimReviewSheet(
          tokenStr: tokenStr,
          sender: vm.senderAddress,
          to: vm.to,
          recipientGets: _numFmt.format(recipientGets),
          txFeeXlm: (vm.txFeeXlm ?? 0).toStringAsFixed(7),
          netFeeXlm: (vm.estNetworkFeeXlm ?? 0).toStringAsFixed(7),
          extraLabel: vm.isXlm ? 'Total deducted' : 'XLM required for fees',
          extraValue: vm.isXlm
              ? '${_numFmt.format(vm.typedAmount)} XLM'
              : '${(vm.needsXlmForFeesIfUsdcSend).toStringAsFixed(7)} XLM',
          onCancel: () => Navigator.pop(context),
          onConfirm: () async {
            Navigator.pop(context);
            await _doSend(vm);
          },
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
    } catch (e) {
      ctl.update(
        AppAlertType.error,
        title: 'Send failed',
        subtitle: '$e',
        primaryText: 'Close',
      );
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Scanner + Contacts
  // ────────────────────────────────────────────────────────────────────────────

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
        showFloatingSnackBar(
          context,
          message: 'QR memo type "$memoType" not supported (only TEXT).',
          type: SnackBarType.warning,
        );
      }
    }

    _toCtl.text = addr;
    _toCtl.selection =
        TextSelection.fromPosition(TextPosition(offset: _toCtl.text.length));
    context.read<SendVM>().setRecipient(addr);
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
    _toCtl.selection =
        TextSelection.fromPosition(TextPosition(offset: _toCtl.text.length));

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

  bool _looksLikeStellarPk(String x) => RegExp(r'^G[A-Z2-7]{55}$').hasMatch(x);

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final vm = context.watch<SendVM>();
    final recipients = context.watch<RecipientAddressVM>();

    final tokenStr = vm.isXlm ? 'XLM' : 'USDC';
    final recipientGets =
    vm.isXlm ? vm.recipientWillReceiveXlmFromBudget : vm.typedAmount;

    final typedAddr = _toCtl.text.trim();
    final saved = (!recipients.loading && typedAddr.isNotEmpty)
        ? recipients.byAddress(typedAddr)
        : null;

    final list = ListView(
      physics:
      const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
      children: [
        BalanceLine(token: tokenStr, balance: vm.senderBalanceToken),
        const SizedBox(height: 12),

        if (recipients.loading) ...[
          const RecipientLoadingLine(),
          const SizedBox(height: 8),
        ] else if (typedAddr.isNotEmpty && saved != null) ...[
          RecipientBadge(
            name: saved.name,
            colorValue: saved.color,
            address: saved.address,
            onEdit: () async {
              final ok =
              await showRecipientUpsertSheet(context, initial: saved);
              if (ok == true && mounted) setState(() {});
            },
          ),
          const SizedBox(height: 8),
        ] else if (typedAddr.isNotEmpty) ...[
          RecipientAddTemplate(
            address: typedAddr,
            onAdd: () async {
              final ok =
              await showRecipientUpsertSheet(context, address: typedAddr);
              if (ok == true && mounted) setState(() {});
            },
          ),
          const SizedBox(height: 8),
        ],

        Form(
          key: _form,
          child: Column(
            children: [
              // ───────── Recipient (show full; wrap unlimited lines; selectable)
              TextFormField(
                controller: _toCtl,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                textInputAction: TextInputAction.newline, // allow multi-line
                keyboardType: TextInputType.multiline,    // enable wrapping
                enableInteractiveSelection: true,         // select/copy long keys
                style: const TextStyle(
                  fontSize: 12.0,
                  height: 1.2,
                  letterSpacing: 0.15,
                  fontFeatures: [ui.FontFeature.tabularFigures()],
                ),
                minLines: 1,
                maxLines: null,   // allow unlimited wrapping (show full length)
                decoration: modernInput(
                  context,
                  placeholder: 'Recipient Address (G… 56 chars)',
                  prefix: Icon(LucideIcons.contact, color: c.primary, size: 18),
                ).copyWith(
                  // make field compact
                  isDense: true,
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),

                  // tighten icon areas
                  prefixIconConstraints:
                  const BoxConstraints(minWidth: 28, minHeight: 28),
                  // don't force suffix width; let it hug its content
                  suffixIconConstraints:
                  const BoxConstraints(minHeight: 28),

                  helperText:
                  vm.recipientLabel == null ? null : 'To: ${vm.recipientLabel}',
                  helperStyle: TextStyle(color: c.textSecondary, fontSize: 12),

                  // COMPACT 3-ACTION SUFFIX (Clear · Contacts · Scan)
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min, // hug buttons tightly
                    children: [
                      if (_toCtl.text.trim().isNotEmpty)
                        IconButton(
                          tooltip: 'Clear',
                          onPressed: () {
                            _toCtl.clear();
                            final vm = context.read<SendVM>();
                            vm.clearPrefillName();
                            vm.setRecipient('');
                            setState(() {});
                          },
                          icon: const Icon(LucideIcons.x),
                          iconSize: 16,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(
                              minWidth: 28, minHeight: 28),
                          visualDensity:
                          const VisualDensity(horizontal: -4, vertical: -4),
                        ),
                      IconButton(
                        tooltip: 'Choose from contacts',
                        onPressed: _openRecipientsPicker,
                        icon: const Icon(LucideIcons.contact),
                        iconSize: 16,
                        padding: const EdgeInsets.all(4),
                        constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                        visualDensity:
                        const VisualDensity(horizontal: -4, vertical: -4),
                      ),
                      IconButton(
                        tooltip: 'Scan QR',
                        onPressed: _openScanner,
                        icon: const Icon(LucideIcons.scanLine),
                        iconSize: 16,
                        padding: const EdgeInsets.all(4),
                        constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                        visualDensity:
                        const VisualDensity(horizontal: -4, vertical: -4),
                      ),
                    ],
                  ),
                ),
                validator: (_) => vm.blockingReason,
                onChanged: (_) => setState(() {}), // update suffix immediately
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
              ),
              const SizedBox(height: 6),
              const TrustlineHint(),
              const SizedBox(height: 10),

              // ───────── Amount ─────────
              TextFormField(
                controller: _amtCtl,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,7}$')),
                ],
                decoration: modernInput(
                  context,
                  placeholder: vm.isXlm ? 'Amount (XLM)' : 'Amount (USDC)',
                  prefix: Padding(
                    padding: const EdgeInsets.all(8),
                    child: AssetLogo(keyOrSymbol: tokenStr, size: 18),
                  ),
                ).copyWith(
                  isDense: true,
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                validator: (_) => vm.blockingReason,
              ),

              // Tiny tip (only when it matters)
              if (vm.isXlm && vm.selfHasUsdcTrustline) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(LucideIcons.info, size: 14, color: c.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Tip: If you choose 100%, we’ll keep 1 XLM so USDC stays usable (fees need XLM).',
                        style: TextStyle(fontSize: 12, color: c.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 10),
              PercentChipsRow(onPick: (pct) => _applyPercent(vm, pct)),

              // ───────── Memo (optional) ─────────
              const SizedBox(height: 12),
              TextFormField(
                controller: _memoCtl,
                textInputAction: TextInputAction.done,
                decoration: modernInput(
                  context,
                  placeholder: 'Memo (optional)',
                  prefix: Icon(LucideIcons.stickyNote, color: c.primary),
                ).copyWith(
                  isDense: true,
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  counterText: '$_memoBytes / 28 bytes',
                  helperText:
                  'Some exchanges require a memo. If unsure, leave blank.',
                  helperStyle: TextStyle(color: c.textSecondary, fontSize: 12),
                  suffixIcon: (_memoCtl.text.isEmpty)
                      ? null
                      : IconButton(
                    tooltip: 'Clear memo',
                    onPressed: () => _memoCtl.clear(),
                    icon: const Icon(LucideIcons.x),
                  ),
                ),
                validator: (_) {
                  final bytes = utf8.encode(_memoCtl.text);
                  return (bytes.length <= 28)
                      ? null
                      : 'Memo too long (max 28 bytes)';
                },
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ───────── Preview ─────────
        SlimPreviewCard(
          isXLM: vm.isXlm,
          token: tokenStr,
          recipientGets: recipientGets,
          estNetworkFeeXlm: vm.estNetworkFeeXlm ?? 0,
          txFeeXlm: vm.txFeeXlm ?? 0,
          totalBudgetXlm: vm.isXlm ? vm.totalDeductXlmIfXlmSend : null,
          needsXlmForFeesIfUsdc:
          vm.isXlm ? null : vm.needsXlmForFeesIfUsdcSend,
        ),
      ],
    );

    return Scaffold(
      backgroundColor: c.surface,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AssetLogo(size: 18, keyOrSymbol: tokenStr),
            const SizedBox(width: 8),
            Text('Send $tokenStr',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: c.textPrimary)),
          ],
        ),
      ),
      body: vm.loading
          ? const PageLoader(size: 36)
          : vm.error != null
          ? ErrorCard(message: vm.error!)
          : RefreshIndicator(
        onRefresh: _refresh,
        color: c.primary,
        displacement: 24,
        child: list,
      ),
      bottomNavigationBar: (vm.loading || vm.error != null)
          ? null
          : AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        padding:
        EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: BoxDecoration(
              color: c.surface,
              border: Border(
                top: BorderSide(color: c.primary.withOpacity(0.10)),
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                  color: Colors.black.withOpacity(0.04),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (!_form.currentState!.validate()) return;
                  final reason = vm.blockingReason;
                  if (reason != null) {
                    HapticFeedback.selectionClick();
                    showFloatingSnackBar(context,
                        message: reason, type: SnackBarType.error);
                    return;
                  }
                  await _confirmAndSend(vm);
                },
                icon: const Icon(LucideIcons.send,
                    color: Colors.white, size: 18),
                label: const Text(
                  'Send',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
