import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:next_fi/Components/AppAlert.dart';
import 'package:next_fi/Components/SnackBar.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Provider/SwapProvider.dart';

import 'SwapScreenWidgets/swap_widgets.dart';

class SwapScreen extends StatefulWidget {
  const SwapScreen({super.key});
  @override
  State<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends State<SwapScreen> {
  final _amountCtl = TextEditingController();
  final _fmt = NumberFormat('#,##0.######');

  static const double _slippage = 0.01; // 1%
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _amountCtl.addListener(() {
      final p = context.read<SwapProvider>();
      final amt = double.tryParse(_amountCtl.text.trim()) ?? 0;
      // live quote as user types
      p.updateQuote(amt);
      setState(() {}); // only for enabling/disabling button text etc.
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SwapProvider>().start();
    });
    _started = true;
  }

  @override
  void dispose() {
    _amountCtl.dispose();
    super.dispose();
  }

  void _useMax(SwapProvider p) {
    final max = p.availableFrom;
    _amountCtl.text = max <= 0 ? '' : max.toStringAsFixed(6);
    HapticFeedback.selectionClick();
  }

  Future<void> _flipDir(SwapProvider p) async {
    HapticFeedback.lightImpact();
    await p.setDir(
      p.isXlmToUsdc ? SwapDir.usdcToXlm : SwapDir.xlmToUsdc,
    );
    // re-clamp & re-quote
    final amt = double.tryParse(_amountCtl.text.trim());
    if (amt != null) {
      final cap = p.availableFrom;
      if (amt > cap && cap > 0) {
        _amountCtl.text = cap.toStringAsFixed(6);
      }
      await p.updateQuote(double.tryParse(_amountCtl.text.trim()) ?? 0);
    }
  }

  Future<void> _confirmAndSwap(SwapProvider p) async {
    final amount = double.tryParse(_amountCtl.text.trim()) ?? 0;
    if (amount <= 0) {
      showFloatingSnackBar(context, message: 'Enter amount', type: SnackBarType.error);
      return;
    }
    if (!p.hasEnough(amount)) {
      showFloatingSnackBar(context, message: 'Insufficient balance', type: SnackBarType.error);
      return;
    }

    // Ensure fee is fresh
    await p.updateFeeEstimate();

    // Ensure we have a current quote to compute minOut
    double? est = p.estReceive;
    est ??= await p.updateQuote(amount);
    if (est == null) {
      showFloatingSnackBar(
        context,
        message: 'No price quote available on mainnet. Try a slightly different amount.',
        type: SnackBarType.error,
      );
      return;
    }
    final minOut = est * (1 - _slippage);

    final colors = AppColor.of(context);
    await showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.primary.withOpacity(0.25),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 10),
            Text('Confirm Swap',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: colors.textPrimary)),
            const SizedBox(height: 12),
            _InfoRow('From', '${_fmt.format(amount)} ${p.isXlmToUsdc ? 'XLM' : 'USDC'}'),
            _InfoRow('To (est.)', '${_fmt.format(est)} ${p.isXlmToUsdc ? 'USDC' : 'XLM'}'),
            _InfoRow('Slippage', '1%'),
            _InfoRow('Min receive', '${_fmt.format(minOut)} ${p.isXlmToUsdc ? 'USDC' : 'XLM'}'),
            _InfoRow(
              'Network fee',
              p.feeXlm == null
                  ? '—'
                  : '≈ ${_fmt.format(p.feeXlm!)} XLM${p.needsTrustline ? ' (incl. trustline)' : ''}',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colors.primary.withOpacity(0.35)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Cancel', style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _doSwap(p, amount, minOut);
                    },
                    icon: const Icon(LucideIcons.check, size: 18, color: Colors.white),
                    label: const Text('Swap now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _doSwap(SwapProvider p, double amount, double minOut) async {

    // Submitting alert
    late final AppAlertController submittingCtl;
    submittingCtl = showAppAlert(
      context,
      type: AppAlertType.info,
      title: 'Submitting swap…',
      subtitle: p.isXlmToUsdc
          ? 'Swapping ${_fmt.format(amount)} XLM → at least ${_fmt.format(minOut)} USDC'
          : 'Swapping ${_fmt.format(amount)} USDC → at least ${_fmt.format(minOut)} XLM',
      primaryText: 'Hide',
      barrierDismissible: true,
      onPrimary: () => submittingCtl.close(),
    );

    try {
      final txid = await p.executeSwap(amount: amount, minOut: minOut);

      if (!mounted) return;
      submittingCtl.close();
      HapticFeedback.mediumImpact();

      // Success alert with “Copy TxID”
      late final AppAlertController okCtl;
      okCtl = showAppAlert(
        context,
        type: AppAlertType.success,
        title: 'Swap submitted',
        subtitle: txid,
        primaryText: 'Copy TxID',
        onPrimary: () async {
          await Clipboard.setData(ClipboardData(text: txid));
          okCtl.close();
        },
      );

      _amountCtl.clear();
    } catch (e) {
      if (!mounted) return;
      submittingCtl.close();

      final msg = e.toString();
      showAppAlert(
        context,
        type: AppAlertType.error,
        title: 'Swap failed',
        subtitle: msg.length > 220 ? '${msg.substring(0, 220)}…' : msg,
        primaryText: 'OK',
        onPrimary: () {},
        barrierDismissible: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final p = context.watch<SwapProvider>();

    final loadingFirst = p.loading && p.accountId == null;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Swap'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(LucideIcons.refreshCcw),
            onPressed: p.refreshBalances,
          ),
        ],
      ),
      body: loadingFirst
          ? const _PageLoader()
          : p.error != null
          ? _ErrorCard(message: p.error!)
          : Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BalanceRow(xlm: p.xlmBal, usdc: p.usdcBal),
            const SizedBox(height: 10),
            _DirectionSwitcher(
              isXlmToUsdc: p.isXlmToUsdc,
              onFlip: () => _flipDir(p),
            ),
            const SizedBox(height: 10),
            _AmountField(
              label: 'You send (${p.isXlmToUsdc ? 'XLM' : 'USDC'})',
              controller: _amountCtl,
              onUseMax: () => _useMax(p),
            ),
            if (p.isXlmToUsdc) ...[
              const SizedBox(height: 6),
              const _HintBox(
                text:
                'We keep 1 XLM for fees & account reserve. “MAX” uses only your spendable amount.',
              ),
            ],
            const SizedBox(height: 10),
            _TinyInfoRow(
              icon: LucideIcons.badgeDollarSign,
              text: p.estReceive == null
                  ? 'Estimating receive on mainnet…'
                  : 'Est. receive: ${_fmt.format(p.estReceive!)} ${p.isXlmToUsdc ? 'USDC' : 'XLM'} · Slippage: 1%'
                  '${p.feeXlm == null ? '' : ' · Fee≈ ${_fmt.format(p.feeXlm!)} XLM${p.needsTrustline ? ' (incl. trustline)' : ''}'}',
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () {
                final amt = double.tryParse(_amountCtl.text.trim()) ?? 0;
                if (!p.hasEnough(amt)) {
                  HapticFeedback.selectionClick();
                }
                _confirmAndSwap(p);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(LucideIcons.arrowRightLeft),
              label: Text(p.isXlmToUsdc ? 'Swap XLM → USDC' : 'Swap USDC → XLM'),
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------------- Small UI bits (unchanged) ---------------- */

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

class _BalanceRow extends StatelessWidget {
  final double xlm, usdc;
  const _BalanceRow({required this.xlm, required this.usdc});
  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    String _num(double v) => v.toStringAsFixed(v >= 100 ? 2 : 4);

    Widget chip(String assetKey, String value) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.primary.withOpacity(0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ✅ token logos
          AssetLogo(asset: assetKey, size: 16),
          const SizedBox(width: 6),
          Text('$assetKey: ', style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
          Text(value, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
        ],
      ),
    );

    return Row(
      children: [
        Expanded(child: chip('XLM', _num(xlm))),
        const SizedBox(width: 8),
        Expanded(child: chip('USDC', _num(usdc))),
      ],
    );
  }
}

class _DirectionSwitcher extends StatelessWidget {
  final bool isXlmToUsdc;
  final VoidCallback onFlip;
  const _DirectionSwitcher({required this.isXlmToUsdc, required this.onFlip});
  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: c.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.primary.withOpacity(0.14)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegBtn(
              active: isXlmToUsdc,
              label: 'XLM → USDC',
              onTap: () {
                if (!isXlmToUsdc) onFlip();
              },
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _SegBtn(
              active: !isXlmToUsdc,
              label: 'USDC → XLM',
              onTap: () {
                if (isXlmToUsdc) onFlip();
              },
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onFlip,
            icon: Icon(LucideIcons.arrowUpDown, color: c.primary),
            tooltip: 'Flip',
          ),
        ],
      ),
    );
  }
}

class _SegBtn extends StatelessWidget {
  final bool active;
  final String label;
  final VoidCallback onTap;
  const _SegBtn({required this.active, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? c.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(color: active ? Colors.white : c.textPrimary, fontWeight: FontWeight.w700, fontSize: 12.5),
        ),
      ),
    );
  }
}

class _AmountField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final VoidCallback onUseMax;
  const _AmountField({required this.label, required this.controller, required this.onUseMax});
  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,7}$'))],
                decoration: InputDecoration(
                  hintText: '0.0',
                  filled: true,
                  fillColor: c.primary.withOpacity(0.05),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: c.primary.withOpacity(0.15)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: c.primary, width: 1.2),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: onUseMax,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: c.primary.withOpacity(0.35)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                minimumSize: const Size(52, 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('MAX', style: TextStyle(color: c.primary, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ],
    );
  }
}

class _TinyInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _TinyInfoRow({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: c.textSecondary),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(color: c.textSecondary, fontSize: 12.5))),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
          const Spacer(),
          Text(value, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _HintBox extends StatelessWidget {
  final String text;
  const _HintBox({required this.text});
  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.primary.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.info, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, color: c.textSecondary))),
        ],
      ),
    );
  }
}
