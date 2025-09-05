import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Components/CustomButton.dart';

import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Components/SnackBar.dart';
import 'package:next_fi/Services/tron/tron_wallet_service.dart';
import 'stake_widgets.dart';
import 'package:next_fi/Components/confirm_action_sheet.dart'; // your provided sheet file path

enum _Res { ENERGY, BANDWIDTH }
extension on _Res {
  String get label => this == _Res.ENERGY ? 'ENERGY' : 'BANDWIDTH';
  IconData get icon => this == _Res.ENERGY ? LucideIcons.zap : LucideIcons.activity;
}

class StakeV2StakeScreen extends StatefulWidget {
  const StakeV2StakeScreen({
    super.key,
    required this.tron,
    required this.pk,
    required this.address,
    required this.spendableSun,
  });

  final TronWalletService tron;
  final Uint8List pk;
  final String address;
  final int spendableSun;

  @override
  State<StakeV2StakeScreen> createState() => _StakeV2StakeScreenState();
}

class _StakeV2StakeScreenState extends State<StakeV2StakeScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _nf = NumberFormat('#,##0.######');
  final _amountCtrl = TextEditingController();
  bool _performing = false;

  String _fmtTrx(int sun) => _nf.format(sun / 1e6);

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this)..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _applyPct(double pct) {
    final sun = (widget.spendableSun * pct).floor();
    _amountCtrl.text = _nf.format(sun / 1e6);
    setState(() {});
  }

  String _estimateText() {
    final amtTrx = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    final sun = (amtTrx * 1e6).round();
    if (sun <= 0) return '—';
    if (_tab.index == 0) {
      final energyUnits = (sun / 420).floor();
      return 'Est. ENERGY/day (recharges over ~24h): ~$energyUnits';
    } else {
      final bytes = (sun / 1000).floor();
      return 'Est. BANDWIDTH/day (bytes): ~$bytes';
    }
  }

  Future<void> _stake() async {
    final colors = AppColor.of(context);
    final res = _tab.index == 0 ? _Res.ENERGY : _Res.BANDWIDTH;
    final amtTrx = double.tryParse(_amountCtrl.text.trim());
    if (amtTrx == null || amtTrx <= 0) {
      showFloatingSnackBar(context, message: 'Enter a valid amount.', type: SnackBarType.error);
      return;
    }
    final sun = (amtTrx * 1e6).round();
    if (sun < 1_000_000) {
      showFloatingSnackBar(context, message: 'Minimum is 1.0 TRX.', type: SnackBarType.error);
      return;
    }
    if (sun > widget.spendableSun) {
      showFloatingSnackBar(context, message: 'Insufficient TRX. Available ${_fmtTrx(widget.spendableSun)}.', type: SnackBarType.error);
      return;
    }

    final ok = await showConfirmActionSheet(
      context,
      title: 'Stake ${_fmtTrx(sun)} TRX for ${res.label}?',
      message: res == _Res.ENERGY
          ? 'Your TRX will be locked. ENERGY helps reduce TRC-20 fees (like USDT transfers).'
          : 'Your TRX will be locked. BANDWIDTH helps reduce basic TRX transfer fees.',
      confirmLabel: 'Stake',
      icon: res.icon,
    );
    if (!ok) return;

    setState(() => _performing = true);
    try {
      final tx = await widget.tron.freezeBalanceV2(
        privateKey: widget.pk,
        amountSun: sun,
        resource: res.label,
      );
      showFloatingSnackBar(context, message: 'Staked! tx: ${tx.length > 10 ? '${tx.substring(0,6)}…${tx.substring(tx.length-4)}' : tx}', type: SnackBarType.success);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      showFloatingSnackBar(context, message: e.toString(), type: SnackBarType.error);
    } finally {
      if (mounted) setState(() => _performing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stake'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'ENERGY', icon: Icon(LucideIcons.zap)),
            Tab(text: 'BANDWIDTH', icon: Icon(LucideIcons.activity)),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: CustomButton(
            text: 'Stake',
            icon: LucideIcons.lock,
            onPressed: _performing ? () {} : _stake,
            type: _performing ? ButtonType.disabled : ButtonType.filled,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          SectionCard(
            title: 'Stake amount',
            subtitle: 'Choose how much TRX to lock. You can later start an Unstake and withdraw after ~14 days.',
            leading: LucideIcons.coins,
            leadingColor: colors.primary,
            children: [
              Row(
                children: [
                  Text('Spendable', style: TextStyle(color: colors.textSecondary, fontSize: 12.5)),
                  const Spacer(),
                  Text(_fmtTrx(widget.spendableSun), style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: 'e.g., 50',
                  prefixIcon: const Icon(LucideIcons.coins),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _pctChip('25%', () => _applyPct(.25)),
                _pctChip('50%', () => _applyPct(.50)),
                _pctChip('75%', () => _applyPct(.75)),
                _pctChip('MAX', () => _applyPct(1.0)),
              ]),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(_tab.index == 0 ? LucideIcons.zap : LucideIcons.activity, size: 18, color: colors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _estimateText() == '—'
                          ? (_tab.index == 0
                          ? 'ENERGY replenishes roughly over a day. Good for TRC-20 (USDT) operations.'
                          : 'BANDWIDTH replenishes over time. Good for basic TRX transfers.')
                          : _estimateText(),
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pctChip(String text, VoidCallback onTap) => ChoiceChip(
    label: Text(text),
    selected: false,
    onSelected: (_) => onTap(),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
  );
}
