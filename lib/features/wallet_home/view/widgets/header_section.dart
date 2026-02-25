import 'package:flutter/material.dart';
import 'package:next_fi/common/components/button/app_buttons.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'live_counting_balance.dart';

class HeaderSection extends StatefulWidget {
  const HeaderSection({
    super.key,
    required this.colors,
    required this.currencyFmt,
    required this.loadingBalances,
    required this.totalFiat,
    required this.lastBalancesAt,
    required this.onSwap,
    required this.onSend,
    required this.onReceive,
    required this.livePulse,
    required this.incomingStrip,
    this.animateTotal = false,
    this.onP2P,
  });

  final AppColor colors;
  final NumberFormat currencyFmt;
  final bool loadingBalances;
  final double totalFiat;
  final DateTime? lastBalancesAt;
  final VoidCallback onSwap;
  final VoidCallback onSend;
  final VoidCallback onReceive;
  final AnimationController livePulse;
  final Widget incomingStrip;
  final bool animateTotal;
  final VoidCallback? onP2P;

  @override
  State<HeaderSection> createState() => _HeaderSectionState();
}

class _HeaderSectionState extends State<HeaderSection> {
  bool _hideBalance = false;

  double? _lastTotal;
  double? _deltaFiat;
  static const double _epsilon = 0.0001;

  Color get _upColor => widget.colors.success;
  Color get _downColor => widget.colors.error;

  void _onPulseStatus(AnimationStatus status) {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _lastTotal = _safe(widget.totalFiat);
    _deltaFiat = null;
    widget.livePulse.addStatusListener(_onPulseStatus);
  }

  @override
  void didUpdateWidget(covariant HeaderSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.livePulse != widget.livePulse) {
      oldWidget.livePulse.removeStatusListener(_onPulseStatus);
      widget.livePulse.addStatusListener(_onPulseStatus);
    }

    final current = _safe(widget.totalFiat);
    if (_lastTotal == null) {
      _lastTotal = current;
      _deltaFiat = null;
      return;
    }
    final d = current - _lastTotal!;
    if (d.abs() > _epsilon) {
      _deltaFiat = d;
      _lastTotal = current;
    }
  }

  @override
  void dispose() {
    widget.livePulse.removeStatusListener(_onPulseStatus);
    super.dispose();
  }

  double _safe(double v) => v.isFinite ? v : 0.0;

  bool _shouldColorize() {
    if (_hideBalance) return false;
    if (_deltaFiat == null || _deltaFiat!.abs() <= _epsilon) return false;
    return true;
  }

  Color _balanceColor() {
    if (!_shouldColorize()) return widget.colors.textPrimary;
    return _deltaFiat! >= 0 ? _upColor : _downColor;
  }

  Widget _trendIconForDelta() {
    if (!_shouldColorize()) return const SizedBox.shrink();
    final up = _deltaFiat! >= 0;
    return Icon(
      up ? LucideIcons.trendingUp : LucideIcons.trendingDown,
      size: 18,
      color: up ? _upColor : _downColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _safe(widget.totalFiat);
    final hasDelta = _deltaFiat != null && !_hideBalance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: BoxDecoration(
            color: widget.colors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: widget.colors.border, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'TOTAL BALANCE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: widget.colors.textSecondary,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () =>
                              setState(() => _hideBalance = !_hideBalance),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              _hideBalance
                                  ? LucideIcons.eyeOff
                                  : LucideIcons.eye,
                              size: 16,
                              color: widget.colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _trendIconForDelta(),
                        if (_shouldColorize()) const SizedBox(width: 8),
                        Expanded(
                          child: LiveCountingBalance(
                            animate: widget.animateTotal,
                            hidden: _hideBalance,
                            targetValue: total,
                            fmt: widget.currencyFmt,
                            baseColor: _balanceColor(),
                            upColor: _upColor,
                            downColor: _downColor,
                            loading: widget.loadingBalances,
                            pulse: widget.livePulse,
                            showTrendIcon: false,
                            forceBaseColor: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.lastBalancesAt == null
                                ? 'Not synced yet'
                                : 'Updated ${DateFormat.Hm().format(widget.lastBalancesAt!.toLocal())}',
                            style: TextStyle(
                              color: widget.colors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                        if (hasDelta)
                          _DeltaChipFiat(
                            key: ValueKey(
                              '${_deltaFiat!.sign}_${_lastTotal?.toStringAsFixed(2)}',
                            ),
                            amount: _deltaFiat!,
                            fmt: widget.currencyFmt,
                            upColor: _upColor,
                            downColor: _downColor,
                            active: true,
                            neutralColor: widget.colors.textSecondary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 40,
                child: AppFilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: widget.colors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: widget.onSwap,
                  icon: const Icon(LucideIcons.scanLine, size: 18),
                  label: const Text(
                    'Scanner',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _ActionTile(
                colors: widget.colors,
                icon: LucideIcons.send,
                label: 'Send',
                onTap: widget.onSend,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionTile(
                colors: widget.colors,
                icon: LucideIcons.download,
                label: 'Receive',
                onTap: widget.onReceive,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionTile(
                colors: widget.colors,
                icon: LucideIcons.store,
                label: 'P2P',
                onTap: widget.onP2P ?? () => debugPrint('P2P'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        widget.incomingStrip,
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.colors,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final AppColor colors;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: colors.primary,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colors.primary, width: 1),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: Colors.white, size: 22),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}

class _DeltaChipFiat extends StatelessWidget {
  const _DeltaChipFiat({
    super.key,
    required this.amount,
    required this.fmt,
    required this.upColor,
    required this.downColor,
    required this.active,
    required this.neutralColor,
  });

  final double amount;
  final NumberFormat fmt;
  final Color upColor;
  final Color downColor;
  final bool active;
  final Color neutralColor;

  @override
  Widget build(BuildContext context) {
    final up = amount >= 0;
    final color = active ? (up ? upColor : downColor) : neutralColor;
    final icon = up ? LucideIcons.trendingUp : LucideIcons.trendingDown;
    final sign = up ? '+' : '-';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.black
            : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            '$sign${fmt.format(amount.abs())}',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.15,
            ),
          ),
        ],
      ),
    );
  }
}
