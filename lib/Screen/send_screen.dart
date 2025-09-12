// lib/Screen/SendScreen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:next_fi/Components/modern_input.dart';
import 'package:next_fi/Components/SnackBar.dart';
import 'package:next_fi/Components/AppAlert.dart';
import 'package:next_fi/Screen/SwapScreenWidgets/swap_widgets.dart';
import 'package:next_fi/Provider/SendProvider.dart';
import 'package:next_fi/Provider/RecipientAddressProvider.dart';
import 'package:next_fi/Components/recipient_upsert_sheet.dart';
import 'package:next_fi/Helper/AppColor.dart';

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
  final _numFmt = NumberFormat('#,##0.######');

  bool _booted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_booted) return;

    final p = context.read<SendProvider>();
    p.configure(
      token: widget.token.toUpperCase() == 'XLM' ? SendToken.xlm : SendToken.usdc,
      senderAddress: widget.address,
      senderBalanceToken: widget.balance,
      prefillTo: widget.prefillAddress,
      prefillName: widget.prefillName,
    );

    _toCtl.text = (widget.prefillAddress ?? '');
    _amtCtl.addListener(() {
      final v = double.tryParse(_amtCtl.text.trim()) ?? 0;
      p.setTypedAmount(v);
      setState(() {});
    });
    _toCtl.addListener(() {
      p.setRecipient(_toCtl.text);
      setState(() {}); // refresh badge/template as the user types
    });

    _booted = true;
  }

  @override
  void dispose() {
    _toCtl.dispose();
    _amtCtl.dispose();
    super.dispose();
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  Future<void> _refresh(BuildContext context) async {
    // lighter refresh: keep session, refresh fees & re-check trustline
    final p = context.read<SendProvider>();
    await p.refreshFees();
    p.setRecipient(_toCtl.text.trim());
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

  double _calcMaxTyped(SendProvider p) {
    // For XLM: max spendable = balance - (txFee + networkFee)
    if (p.isXlm) {
      final fees = (p.txFeeXlm ?? 0) + (p.estNetworkFeeXlm ?? 0);
      final raw = (p.senderBalanceToken - fees);
      return _floorTo(raw > 0 ? raw : 0, 7);
    }
    // For USDC: use full balance
    return _floorTo(p.senderBalanceToken, 7);
  }

  void _applyPercent(SendProvider p, double percent) {
    final base = p.isXlm ? _calcMaxTyped(p) : p.senderBalanceToken;
    final v = _floorTo(base * percent, 7);
    HapticFeedback.selectionClick();
    _amtCtl.text = _fmtAmount(v);
    _amtCtl.selection = TextSelection.fromPosition(TextPosition(offset: _amtCtl.text.length));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final p = context.watch<SendProvider>();
    final recipients = context.watch<RecipientAddressProvider>();

    final tokenStr = p.token == SendToken.xlm ? 'XLM' : 'USDC';
    final isXLM = p.isXlm;

    final recipientGets = isXLM ? p.recipientWillReceiveXlmFromBudget : p.typedAmount;
    final netFee = p.estNetworkFeeXlm ?? 0;
    final txFee = p.txFeeXlm ?? 0;

    // Resolve current typed address
    final typedAddr = _toCtl.text.trim();
    final saved = (!recipients.loading && typedAddr.isNotEmpty)
        ? recipients.byAddress(typedAddr)
        : null;

    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 120), // leave space for bottom button
      children: [
        _BalanceLine(token: tokenStr, balance: p.senderBalanceToken),
        const SizedBox(height: 12),

        // Recipient name / template above input
        if (recipients.loading) ...[
          _RecipientLoadingLine(),
          const SizedBox(height: 8),
        ] else if (typedAddr.isNotEmpty && saved != null) ...[
          _RecipientBadge(
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
          _RecipientAddTemplate(
            address: typedAddr,
            onAdd: () async {
              final ok = await showRecipientUpsertSheet(context);
              if (ok == true && mounted) setState(() {});
            },
          ),
          const SizedBox(height: 8),
        ],

        // Form
        Form(
          key: _form,
          child: Column(
            children: [
              // Recipient input
              TextFormField(
                controller: _toCtl,
                decoration: modernInput(
                  context,
                  placeholder: 'Recipient Address',
                  prefix: Icon(LucideIcons.contact, color: AppColor.of(context).primary),
                ),
                validator: (_) => p.blockingReason == null || !p.blockingReason!.contains('Stellar')
                    ? null
                    : 'Enter a valid Stellar address',
              ),

              // NEW: tiny trustline hint for USDC
              const SizedBox(height: 6),
              _TrustlineHint(),
              const SizedBox(height: 10),

              // Amount (no MAX)
              TextFormField(
                controller: _amtCtl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,7}$')),
                ],
                decoration: modernInput(
                  context,
                  placeholder: p.isXlm ? 'Amount (XLM)' : 'Amount (USDC)',
                  prefix: Padding(
                    padding: const EdgeInsets.all(8),
                    child: AssetLogo(asset: tokenStr, size: 18),
                  ),
                ),
                validator: (_) => p.blockingReason == null ? null : p.blockingReason,
              ),

              // Percentage chips (10 / 25 / 50 / 75 / 100)
              const SizedBox(height: 10),
              _PercentChipsRow(
                onPick: (pct) => _applyPercent(p, pct),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Slim preview
        _SlimPreviewCard(
          isXLM: isXLM,
          token: tokenStr,
          recipientGets: recipientGets,
          estNetworkFeeXlm: netFee,
          txFeeXlm: txFee,
          totalBudgetXlm: isXLM ? p.totalDeductXlmIfXlmSend : null,
          needsXlmForFeesIfUsdc: isXLM ? null : p.needsXlmForFeesIfUsdcSend,
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
      body: p.loading
          ? const _PageLoader()
          : p.error != null
          ? _ErrorCard(message: p.error!)
      // ↓ Pull-to-refresh wrapper
          : RefreshIndicator(
        onRefresh: () => _refresh(context),
        color: c.primary,
        displacement: 24,
        child: list,
      ),

      // Pinned bottom Send button
      bottomNavigationBar: (p.loading || p.error != null)
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
                  final reason = p.blockingReason;
                  if (reason != null) {
                    HapticFeedback.selectionClick();
                    showFloatingSnackBar(context, message: reason, type: SnackBarType.error);
                    return;
                  }
                  await _confirmAndSend(context, p);
                },
                icon: const Icon(LucideIcons.send, color: Colors.white, size: 18),
                label: Text('Send $tokenStr',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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

  Future<void> _confirmAndSend(BuildContext context, SendProvider p) async {
    final tokenStr = p.isXlm ? 'XLM' : 'USDC';
    final recipientGets = p.isXlm ? p.recipientWillReceiveXlmFromBudget : p.typedAmount;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _FlatSheet(
          maxHeightFactor: 0.50,
          child: _SlimReviewSheet(
            tokenStr: tokenStr,
            sender: p.senderAddress,
            to: p.to,
            recipientGets: _numFmt.format(recipientGets),
            txFeeXlm: (p.txFeeXlm ?? 0).toStringAsFixed(7),
            netFeeXlm: (p.estNetworkFeeXlm ?? 0).toStringAsFixed(7),
            extraLabel: p.isXlm ? 'Total budget (deducted)' : 'XLM required for fees',
            extraValue: p.isXlm
                ? '${_numFmt.format(p.typedAmount)} XLM'
                : '${(p.needsXlmForFeesIfUsdcSend).toStringAsFixed(7)} XLM',
            onCancel: () => Navigator.pop(context),
            onConfirm: () async {
              Navigator.pop(context);
              await _doSend(context, p);
            },
          ),
        );
      },
    );
  }

  Future<void> _doSend(BuildContext context, SendProvider p) async {
    late final AppAlertController ctl;
    ctl = showAppAlert(
      context,
      type: AppAlertType.loading,
      title: 'Submitting…',
      subtitle: 'Broadcasting your transaction to the network.',
      primaryText: 'Hide',
    );
    try {
      final txid = await p.submit();
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
    } catch (e) {
      ctl.update(AppAlertType.error, title: 'Send failed', subtitle: '$e', primaryText: 'Close');
    }
  }
}

/* ───────────────────── Recipient UI helpers ───────────────────── */

class _RecipientLoadingLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Container(
      height: 18,
      decoration: BoxDecoration(
        color: c.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class _RecipientBadge extends StatelessWidget {
  const _RecipientBadge({
    required this.name,
    required this.colorValue,
    required this.address,
    required this.onEdit,
  });

  final String name;
  final int colorValue;
  final String address;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final color = Color(colorValue);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(LucideIcons.edit, size: 16),
            label: const Text('Edit'),
            style: TextButton.styleFrom(
              foregroundColor: color,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipientAddTemplate extends StatelessWidget {
  const _RecipientAddTemplate({required this.address, required this.onAdd});
  final String address;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: c.primary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.primary.withOpacity(0.12), style: BorderStyle.solid),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.userPlus, size: 18, color: c.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No saved name for this address',
                    style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.textSecondary, fontFamily: 'monospace', fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onAdd,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              side: BorderSide(color: c.primary.withOpacity(0.35)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              foregroundColor: c.primary,
            ),
            child: const Text('Add', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

/* ───────────────────── Chips + Preview + Misc ───────────────────── */

class _PercentChipsRow extends StatelessWidget {
  const _PercentChipsRow({required this.onPick});
  final void Function(double pct) onPick;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);

    Widget chip(String label, double pct) => InkWell(
      onTap: () => onPick(pct),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: c.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.primary.withOpacity(0.18)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: c.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          chip('10%', 0.10),
          chip('25%', 0.25),
          chip('50%', 0.50),
          chip('75%', 0.75),
          chip('100%', 1.00),
        ],
      ),
    );
  }
}

/* ───────────────────── Bottom sheet + review (unchanged) ─────────────────── */

class _FlatSheet extends StatelessWidget {
  const _FlatSheet({required this.child, this.maxHeightFactor = 0.92});
  final Widget child;
  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final h = MediaQuery.of(context).size.height;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: c.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          elevation: 0,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: h * maxHeightFactor),
            child: SafeArea(top: false, child: child),
          ),
        ),
      ),
    );
  }
}

class _SlimReviewSheet extends StatelessWidget {
  const _SlimReviewSheet({
    required this.tokenStr,
    required this.sender,
    required this.to,
    required this.recipientGets,
    required this.txFeeXlm,
    required this.netFeeXlm,
    required this.extraLabel,
    required this.extraValue,
    required this.onCancel,
    required this.onConfirm,
  });

  final String tokenStr;
  final String sender;
  final String to;
  final String recipientGets;
  final String txFeeXlm;
  final String netFeeXlm;
  final String extraLabel;
  final String extraValue;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);

    Widget _grabber() => Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(top: 8, bottom: 6),
        decoration: BoxDecoration(
          color: c.primary.withOpacity(0.18),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );

    Widget _header() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Text(
            'Review',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: c.textPrimary,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: c.primary.withOpacity(0.07),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: c.primary.withOpacity(0.14)),
            ),
            child: Row(
              children: [
                AssetLogo(asset: tokenStr, size: 14),
                const SizedBox(width: 6),
                Text(
                  tokenStr,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    Widget _summaryPill() => Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: c.primary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.primary.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.badgeDollarSign, size: 16, color: c.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Recipient receives',
                style: TextStyle(color: c.textSecondary, fontSize: 12),
              ),
            ),
            Text(
              '$recipientGets $tokenStr',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: c.textPrimary,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      ),
    );

    TableRow _kv(String k, String v, {bool mono = false}) => TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            k,
            style: TextStyle(color: c.textSecondary, fontSize: 12),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: SelectableText(
            v,
            textAlign: TextAlign.right,
            maxLines: 2,
            style: TextStyle(
              color: c.textPrimary,
              fontWeight: FontWeight.w800,
              fontFamily: mono ? 'monospace' : null,
              fontSize: 13,
              height: 1.15,
            ),
          ),
        ),
      ],
    );

    Widget _specCard({required List<TableRow> rows}) => Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.primary.withOpacity(0.10)),
        ),
        child: Table(
          columnWidths: const {
            0: IntrinsicColumnWidth(),
            1: FlexColumnWidth(),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: rows,
        ),
      ),
    );

    Widget _actions() => Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                foregroundColor: c.primary,
              ),
              child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onConfirm,
              icon: const Icon(LucideIcons.check, size: 18, color: Colors.white),
              label: const Text('Confirm'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                backgroundColor: c.primary,
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );

    return Column(
      children: [
        _grabber(),
        _header(),
        _summaryPill(),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _specCard(rows: [
                _kv('From', sender, mono: true),
                _kv('To', to, mono: true),
              ]),
              _specCard(rows: [
                _kv('Transaction fee', '$txFeeXlm XLM'),
                _kv('Network fee (est.)', '$netFeeXlm XLM'),
                _kv(extraLabel, extraValue),
              ]),
            ],
          ),
        ),
        _actions(),
      ],
    );
  }
}

/* ───────────────────── Small shared widgets ───────────────────── */

class _PageLoader extends StatelessWidget {
  const _PageLoader();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.only(top: 60),
      child: SizedBox(height: 26, width: 26, child: CircularProgressIndicator(strokeWidth: 2)),
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});
  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.error.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.error.withOpacity(0.2)),
        ),
        child: Text(message, style: TextStyle(color: c.error)),
      ),
    );
  }
}

class _BalanceLine extends StatelessWidget {
  final String token;
  final double balance;
  const _BalanceLine({required this.token, required this.balance});
  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Row(
      children: [
        AssetLogo(asset: token, size: 16),
        const SizedBox(width: 8),
        Text('Balance: ', style: TextStyle(color: c.textSecondary)),
        Text(
          '$token ${balance.toStringAsFixed(balance >= 100 ? 2 : 4)}',
          style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

/* ───────────────────── Slim Preview Card (no "profit" text) ───────────────── */

class _SlimPreviewCard extends StatelessWidget {
  final bool isXLM;
  final String token;
  final double recipientGets;
  final double estNetworkFeeXlm;
  final double txFeeXlm;
  final double? totalBudgetXlm; // for XLM sends
  final double? needsXlmForFeesIfUsdc; // for USDC sends

  const _SlimPreviewCard({
    required this.isXLM,
    required this.token,
    required this.recipientGets,
    required this.estNetworkFeeXlm,
    required this.txFeeXlm,
    required this.totalBudgetXlm,
    required this.needsXlmForFeesIfUsdc,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);

    Widget tinyRow(String k, String v) => Row(
      children: [
        Expanded(child: Text(k, style: TextStyle(color: c.textSecondary, fontSize: 12))),
        const SizedBox(width: 6),
        Text(v, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.primary.withOpacity(0.10)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(LucideIcons.info, size: 14, color: c.textSecondary),
              const SizedBox(width: 6),
              Text('Preview', style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
              const Spacer(),
              Row(
                children: [
                  AssetLogo(asset: token, size: 14),
                  const SizedBox(width: 6),
                  Text(token, style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w700, fontSize: 11.5)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          tinyRow('Recipient receives', '${recipientGets.toStringAsFixed(6)} $token'),
          const SizedBox(height: 4),
          tinyRow('Transaction fee', '${txFeeXlm.toStringAsFixed(7)} XLM'),
          tinyRow('Network fee (est.)', '${estNetworkFeeXlm.toStringAsFixed(7)} XLM'),
          if (isXLM && (totalBudgetXlm ?? 0) > 0) ...[
            const SizedBox(height: 4),
            tinyRow('Total budget (deducted)', '${(totalBudgetXlm!).toStringAsFixed(6)} XLM'),
          ],
          if (!isXLM) ...[
            const SizedBox(height: 4),
            tinyRow('XLM required for fees', '${(needsXlmForFeesIfUsdc ?? 0).toStringAsFixed(7)} XLM'),
          ],
        ],
      ),
    );
  }
}

/* ───────────────────── NEW: USDC Trustline hint ───────────────────── */

class _TrustlineHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final p = context.watch<SendProvider>();
    if (p.isXlm) return const SizedBox.shrink(); // not needed for XLM
    if (p.to.trim().isEmpty) return const SizedBox.shrink();

    if (p.checking) {
      return Row(
        children: [
          SizedBox(
            height: 14,
            width: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: c.primary),
          ),
          const SizedBox(width: 8),
          Text('Checking USDC trustline…', style: TextStyle(color: c.textSecondary, fontSize: 12)),
        ],
      );
    }

    if (p.destHasUsdcTL == false) {
      return Row(
        children: [
          Icon(LucideIcons.alertTriangle, size: 14, color: c.error),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'This address has no USDC trustline.',
              style: TextStyle(color: c.error, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    if (p.destHasUsdcTL == true) {
      return Row(
        children: [
          Icon(LucideIcons.checkCircle, size: 14, color: c.success),
          const SizedBox(width: 6),
          Text('USDC trustline detected', style: TextStyle(color: c.textSecondary, fontSize: 12)),
        ],
      );
    }

    return const SizedBox.shrink(); // unknown / not checked
  }
}
