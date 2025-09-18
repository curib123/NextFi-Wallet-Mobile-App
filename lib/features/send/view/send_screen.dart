import 'dart:convert' show utf8; // for memo byte counting
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/common/components/modal/recipient_upsert_sheet.dart';
import 'package:next_fi/features/send/model/send_token.dart';
import 'package:next_fi/features/send/view_model/send_vm.dart';
import 'package:provider/provider.dart';

import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/common/components/Input/modern_input.dart';
import 'package:next_fi/common/components/snackbar/SnackBar.dart';
import 'package:next_fi/common/components/alert/AppAlert.dart';
import 'package:next_fi/features/transactions/view/widgets/asset_logo.dart';
import 'package:next_fi/features/wallet_home/view_model/recipient_address_vm.dart';
import 'package:next_fi/features/scanner/view/scanner_screen.dart';
// Address book picker
import 'package:next_fi/features/wallet_home/view/widgets/recipient_list_widget.dart';
import 'package:next_fi/features/wallet_home/model/recipient_address_model.dart';

import 'widgets/page_loader.dart';
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

  // NEW: optional memo
  final _memoCtl = TextEditingController();
  int _memoBytes = 0;

  final _numFmt = NumberFormat('#,##0.######');

  bool _booted = false;
  bool _scannerOpenedOnce = false; // guard to avoid double auto-open

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

    // NEW: memo listener (keep byte-accurate count)
    _memoCtl.addListener(() {
      _memoBytes = utf8.encode(_memoCtl.text).length;
      setState(() {});
    });

    // Auto-open scanner if requested and there is no prefilled address (only once)
    if (widget.autoOpenScanner && !_scannerOpenedOnce) {
      final hasPrefill = (widget.prefillAddress ?? '').trim().isNotEmpty || _toCtl.text.trim().isNotEmpty;
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
    return (v >= 0 ? (v * scale).floor() / scale : (v * scale).ceil() / scale).toDouble();
  }

  String _fmtAmount(double v, {int decimals = 7}) {
    final s = v.toStringAsFixed(decimals);
    return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
  }

  double _calcMaxTyped(SendVM vm) {
    if (vm.isXlm) {
      final fees = (vm.txFeeXlm ?? 0) + (vm.estNetworkFeeXlm ?? 0);
      final raw = (vm.senderBalanceToken - fees);
      return _floorTo(raw > 0 ? raw : 0, 7);
    }
    return _floorTo(vm.senderBalanceToken, 7);
  }

  void _applyPercent(SendVM vm, double percent) {
    final base = vm.isXlm ? _calcMaxTyped(vm) : vm.senderBalanceToken;
    final v = _floorTo(base * percent, 7);
    HapticFeedback.selectionClick();
    _amtCtl.text = _fmtAmount(v);
    _amtCtl.selection = TextSelection.fromPosition(TextPosition(offset: _amtCtl.text.length));
  }

  String? _currentMemoOrNull() {
    final t = _memoCtl.text.trim();
    if (t.isEmpty) return null;
    final bytes = utf8.encode(t);
    if (bytes.length > 28) return null; // blocked by validator anyway
    return t;
  }

  Future<void> _confirmAndSend(SendVM vm) async {
    final tokenStr = vm.isXlm ? 'XLM' : 'USDC';
    final recipientGets = vm.isXlm ? vm.recipientWillReceiveXlmFromBudget : vm.typedAmount;

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
          extraLabel: vm.isXlm ? 'Total budget (deducted)' : 'XLM required for fees',
          extraValue: vm.isXlm
              ? '${_numFmt.format(vm.typedAmount)} XLM'
              : '${(vm.needsXlmForFeesIfUsdcSend).toStringAsFixed(7)} XLM',
          // If you want to show the memo inside the review sheet,
          // add a memoText param in SlimReviewSheet and pass _currentMemoOrNull().
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
      ctl.update(AppAlertType.error, title: 'Send failed', subtitle: '$e', primaryText: 'Close');
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Scanner + Address book integration
  // ────────────────────────────────────────────────────────────────────────────

  Future<void> _openScanner() async {
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus(); // hide keyboard
    await Future.delayed(const Duration(milliseconds: 60)); // let UI settle

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
      final cut = after.split(RegExp(r'[\#/]')).first; // strip # or /
      final qIdx = cut.indexOf('?');
      final path = qIdx == -1 ? cut : cut.substring(0, qIdx);
      if (_looksLikeStellarPk(path)) addr = path;

      if (qIdx != -1) {
        final query = cut.substring(qIdx + 1);
        try {
          final params = Uri.splitQueryString(query, encoding: utf8);
          memoText = params['memo'];
          memoType = params['memo_type']?.toLowerCase();
        } catch (_) {/* ignore bad query */}
      }
    } else {
      // Fallback: find first G... base32 public key length 56
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

    // Only accept TEXT memos here
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
    _toCtl.selection = TextSelection.fromPosition(TextPosition(offset: _toCtl.text.length));
    context.read<SendVM>().setRecipient(addr);
  }

  // open recipients list and populate on select
  Future<void> _openRecipientsPicker() async {
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();

    final picked = await Navigator.push<RecipientAddressModel>(
      context,
      MaterialPageRoute(
        builder: (innerCtx) => RecipientListWidget(
          colors: AppColor.of(innerCtx),
          // Selection mode → pop with the chosen model
          onSelect: (r) => Navigator.of(innerCtx).pop(r),
          fromAddress: widget.address, // optional; not used in selection mode
        ),
      ),
    );

    if (!mounted || picked == null) return;

    final vm = context.read<SendVM>();
    final addr = (picked.address).trim();

    _toCtl.text = addr;
    _toCtl.selection = TextSelection.fromPosition(TextPosition(offset: _toCtl.text.length));

    // Use VM helper so UI can show a friendly label + re-check trustlines
    vm.pickRecipient(addr, displayName: picked.name);
  }

  /// Accepts raw G... public keys or `stellar:G...` URIs (optional query like ?memo=).
  String? _parseStellarAddress(String input) {
    final s = input.trim();

    // Handle stellar: URI
    final uriIdx = s.toLowerCase().indexOf('stellar:');
    if (uriIdx != -1) {
      final after = s.substring(uriIdx + 'stellar:'.length);
      final cut = after.split(RegExp(r'[\?\#/]')).first;
      if (_looksLikeStellarPk(cut)) return cut;
    }

    // Fallback: find first G... base32 public key length 56
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
    final recipientGets = vm.isXlm ? vm.recipientWillReceiveXlmFromBudget : vm.typedAmount;

    final typedAddr = _toCtl.text.trim();
    final saved = (!recipients.loading && typedAddr.isNotEmpty) ? recipients.byAddress(typedAddr) : null;

    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
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
              final ok = await showRecipientUpsertSheet(context, initial: saved);
              if (ok == true && mounted) setState(() {});
            },
          ),
          const SizedBox(height: 8),
        ] else if (typedAddr.isNotEmpty) ...[
          RecipientAddTemplate(
            address: typedAddr,
            onAdd: () async {
              final ok = await showRecipientUpsertSheet(context);
              if (ok == true && mounted) setState(() {});
            },
          ),
          const SizedBox(height: 8),
        ],

        Form(
          key: _form,
          child: Column(
            children: [
              // ───────── Recipient with address book + Scanner suffix ─────────
              TextFormField(
                controller: _toCtl,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                textInputAction: TextInputAction.next,
                decoration: modernInput(
                  context,
                  placeholder: 'Recipient Address',
                  prefix: Icon(LucideIcons.contact, color: AppColor.of(context).primary),
                ).copyWith(
                  helperText: context.read<SendVM>().recipientLabel == null
                      ? null
                      : 'To: ${context.read<SendVM>().recipientLabel}',
                  helperStyle: TextStyle(color: AppColor.of(context).textSecondary),
                  // THREE actions: clear (when not empty) + address book + scan
                  suffixIcon: SizedBox(
                    width: _toCtl.text.trim().isNotEmpty ? 144 : 100,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (_toCtl.text.trim().isNotEmpty)
                          IconButton(
                            tooltip: 'Clear',
                            onPressed: () {
                              _toCtl.clear();
                              final vm = context.read<SendVM>();
                              vm.clearPrefillName();
                              vm.setRecipient('');
                            },
                            icon: const Icon(LucideIcons.x),
                          ),
                        IconButton(
                          tooltip: 'Choose from contacts',
                          onPressed: _openRecipientsPicker,
                          icon: const Icon(LucideIcons.contact), // or LucideIcons.users
                        ),
                        IconButton(
                          tooltip: 'Scan QR',
                          onPressed: _openScanner,
                          icon: const Icon(LucideIcons.scanLine),
                        ),
                      ],
                    ),
                  ),
                ),
                validator: (_) =>
                vm.blockingReason == null || !vm.blockingReason!.contains('Stellar')
                    ? null
                    : 'Enter a valid Stellar address',
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
              ),
              const SizedBox(height: 6),
              const TrustlineHint(),
              const SizedBox(height: 10),

              // ───────── Amount ─────────
              TextFormField(
                controller: _amtCtl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,7}$'))],
                decoration: modernInput(
                  context,
                  placeholder: vm.isXlm ? 'Amount (XLM)' : 'Amount (USDC)',
                  prefix: Padding(
                    padding: const EdgeInsets.all(8),
                    child: AssetLogo(asset: tokenStr, size: 18),
                  ),
                ),
                validator: (_) => vm.blockingReason,
              ),
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
                  prefix: Icon(LucideIcons.stickyNote, color: AppColor.of(context).primary),
                ).copyWith(
                  // Byte-accurate counter (28 bytes max for Stellar TEXT memo)
                  counterText: '$_memoBytes / 28 bytes',
                  helperText: 'Some exchanges require a memo. '
                      'Example: 123456 or "Invoice #123". If unsure, leave blank.',
                  helperStyle: TextStyle(color: AppColor.of(context).textSecondary),
                  suffixIcon: (_memoCtl.text.isEmpty)
                      ? null
                      : IconButton(
                    tooltip: 'Clear memo',
                    onPressed: () => _memoCtl.clear(),
                    icon: const Icon(LucideIcons.x),
                  ),
                ),
                // NOTE: Stellar TEXT memos are limited to 28 BYTES, not characters.
                validator: (_) {
                  final bytes = utf8.encode(_memoCtl.text);
                  return (bytes.length <= 28) ? null : 'Memo too long (max 28 bytes)';
                },
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        SlimPreviewCard(
          isXLM: vm.isXlm,
          token: tokenStr,
          recipientGets: recipientGets,
          estNetworkFeeXlm: vm.estNetworkFeeXlm ?? 0,
          txFeeXlm: vm.txFeeXlm ?? 0,
          totalBudgetXlm: vm.isXlm ? vm.totalDeductXlmIfXlmSend : null,
          needsXlmForFeesIfUsdc: vm.isXlm ? null : vm.needsXlmForFeesIfUsdcSend,
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
            AssetLogo(asset: tokenStr, size: 18),
            const SizedBox(width: 8),
            Text('Send $tokenStr', style: TextStyle(fontWeight: FontWeight.w700, color: c.textPrimary)),
          ],
        ),
      ),
      body: vm.loading
          ? const PageLoader()
          : vm.error != null
          ? ErrorCard(message: vm.error!)
          : RefreshIndicator(onRefresh: _refresh, color: c.primary, displacement: 24, child: list),
      bottomNavigationBar: (vm.loading || vm.error != null)
          ? null
          : AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: BoxDecoration(
              color: c.surface,
              border: Border(top: BorderSide(color: c.primary.withOpacity(0.10))),
              boxShadow: [BoxShadow(blurRadius: 12, offset: const Offset(0, -4), color: Colors.black.withOpacity(0.04))],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (!_form.currentState!.validate()) return;
                  final reason = vm.blockingReason;
                  if (reason != null) {
                    HapticFeedback.selectionClick();
                    showFloatingSnackBar(context, message: reason, type: SnackBarType.error);
                    return;
                  }
                  await _confirmAndSend(vm);
                },
                icon: const Icon(LucideIcons.send, color: Colors.white, size: 18),
                label: Text('Send $tokenStr', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
