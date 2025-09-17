import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/AppColor.dart';
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

  /// If false, the total is shown immediately (no counting animation).
  final bool animateTotal;

  @override
  State<HeaderSection> createState() => _HeaderSectionState();
}

class _HeaderSectionState extends State<HeaderSection> {
  bool _hideBalance = false;

  // Track last total & fiat delta
  double? _lastTotal;
  double? _deltaFiat;
  static const double _epsilon = 0.0001;

  // Use your theme colors (as requested)
  Color get _upColor => widget.colors.success;
  Color get _downColor => widget.colors.error;

  void _onPulseStatus(AnimationStatus status) {
    if (mounted) setState(() {}); // refresh when counting starts/stops
  }

  @override
  void initState() {
    super.initState();
    _lastTotal = _safe(widget.totalFiat);
    _deltaFiat = null; // first draw: no pill
    widget.livePulse.addStatusListener(_onPulseStatus);
  }

  @override
  void didUpdateWidget(covariant HeaderSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Rewire pulse listener if controller instance changed
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

  // Colorize whenever there's a real delta (and not hidden).
  bool _shouldColorize() {
    if (_hideBalance) return false;
    if (_deltaFiat == null || _deltaFiat!.abs() <= _epsilon) return false;
    return true;
  }

  Color _balanceColor() {
    if (!_shouldColorize()) return widget.colors.textPrimary;
    return _deltaFiat! >= 0 ? _upColor : _downColor;
  }

  Color _swapButtonColor() {
    if (_shouldColorize()) return _deltaFiat! >= 0 ? _upColor : _downColor;
    return widget.colors.primary;
  }

  // Slight background tint based on delta
  List<Color> _cardGradient() {
    final base = widget.colors.surface;
    if (!_shouldColorize()) return [base, base];
    final tone = _deltaFiat! >= 0 ? _upColor : _downColor;
    return [base, tone.withOpacity(0.06)];
  }

  // Up/Down icon beside the balance text
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Card
        AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(18),
          margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
          decoration: BoxDecoration(
            color: widget.colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.colors.primary.withOpacity(0.10),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.16),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: Balance & meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Label + eye
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Total Balance',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: widget.colors.textSecondary,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkResponse(
                          onTap: () => setState(() => _hideBalance = !_hideBalance),
                          borderRadius: BorderRadius.circular(10),
                          child: Icon(
                            _hideBalance ? LucideIcons.eyeOff : LucideIcons.eye,
                            color: widget.colors.textSecondary,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Balance row: our own ↑/↓ icon + the number
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      tween: Tween(begin: 1.0, end: (_deltaFiat == null) ? 1.0 : 1.02),
                      builder: (context, scale, child) {
                        return Transform.scale(
                          scale: scale,
                          alignment: Alignment.centerLeft,
                          child: child,
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _trendIconForDelta(),
                          if (_shouldColorize()) const SizedBox(width: 6),
                          // LiveCountingBalance with forced baseColor & no internal icon
                          LiveCountingBalance(
                            animate: widget.animateTotal,
                            hidden: _hideBalance,
                            targetValue: total,
                            fmt: widget.currencyFmt,
                            baseColor: _balanceColor(), // ← driven by our delta
                            upColor: _upColor,
                            downColor: _downColor,
                            loading: widget.loadingBalances,
                            pulse: widget.livePulse,
                            showTrendIcon: false,     // ← we show our own icon
                            forceBaseColor: true,     // ← lock color to baseColor
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Meta row: delta pill
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.12, 0.0),
                                end: Offset.zero,
                              ).animate(anim),
                              child: child,
                            ),
                          ),
                          child: (_deltaFiat != null && !_hideBalance)
                              ? _DeltaChipFiat(
                            key: ValueKey('${_deltaFiat!.sign}_${_lastTotal?.toStringAsFixed(2)}'),
                            amount: _deltaFiat!,
                            fmt: widget.currencyFmt,
                            upColor: _upColor,
                            downColor: _downColor,
                            active: true, // always colorize when we show it
                            neutralColor: widget.colors.textSecondary,
                          )
                              : const SizedBox.shrink(key: ValueKey('empty')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Right: primary action
              SizedBox(
                height: 40,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _swapButtonColor(),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 1,
                  ),
                  onPressed: widget.onSwap,
                  icon: const Icon(LucideIcons.shuffle, size: 20),
                  label: const Text(
                    'Swap',
                    style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.2),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Quick actions
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ActionTile(
                colors: widget.colors,
                icon: LucideIcons.send,
                label: 'Send',
                onTap: widget.onSend,
              ),
              _ActionTile(
                colors: widget.colors,
                icon: LucideIcons.download,
                label: 'Receive',
                onTap: widget.onReceive,
              ),
              _ActionTile(
                colors: widget.colors,
                icon: LucideIcons.wallet,
                label: 'Deposit',
                onTap: () => debugPrint('Deposit'),
              ),
              _ActionTile(
                colors: widget.colors,
                icon: LucideIcons.upload,
                label: 'Withdraw',
                onTap: () => debugPrint('Withdraw'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
        widget.incomingStrip,
      ],
    );
  }
}

// ────────────────── Quick Action Tile ──────────────────
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
    final bg = colors.primary.withOpacity(0.10);
    final border = colors.primary.withOpacity(0.14);
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            margin: const EdgeInsets.symmetric(vertical: 10),
            child: Icon(icon, color: colors.primary, size: 30),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 0.15,
          ),
        ),
      ],
    );
  }
}

// ────────────────── Delta pill (no words; symbols only) ──────────────────
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

  /// If false, show neutral colors (no up/down tint).
  final bool active;

  /// Neutral color to use when not active.
  final Color neutralColor;

  @override
  Widget build(BuildContext context) {
    final up = amount >= 0;
    final color = active ? (up ? upColor : downColor) : neutralColor;
    final icon = up ? LucideIcons.trendingUp : LucideIcons.trendingDown;
    final sign = up ? '+' : '−'; // true minus

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          '$sign${fmt.format(amount.abs())}',
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}
