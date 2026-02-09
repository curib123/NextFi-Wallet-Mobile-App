import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/button/CustomButton.dart';
import 'package:next_fi/features/swap/view/widgets/info_row.dart';
import 'package:next_fi/features/swap/view_model/swap_vm.dart';

/// Shows a live-updating Market confirmation sheet that LISTENS to SwapVM.
/// Returns the *current* minOutPreFee (double) if the user confirms; null if cancelled.
Future<double?> showConfirmMarketSheet(
    BuildContext context, {
      required NumberFormat fmt,
    }) async {
  final colors = AppColor.of(context);

  // Prime fee stream if needed
  final vm = context.read<SwapVM>();
  if (!vm.hasFeeEstimates) {
    await vm.refreshBalances();
  }

  return await showModalBottomSheet<double?>(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetCtx) => _ConfirmMarketSheet(fmt: fmt),
  );
}

/// Shows a live-updating Limit order confirmation sheet.
/// Returns true if confirmed; null/false if cancelled.
Future<bool?> showConfirmLimitSheet(
    BuildContext context, {
      required NumberFormat fmt,
      required double price,
    }) async {
  return await showModalBottomSheet<bool?>(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetCtx) => _ConfirmLimitSheet(fmt: fmt, price: price),
  );
}

/// Shows a live-updating Schedule confirmation sheet.
/// Returns true if confirmed; null/false if cancelled.
Future<bool?> showConfirmScheduleSheet(
    BuildContext context, {
      required NumberFormat fmt,
      required DateTime? start,
      required DateTime? end,
    }) async {
  return await showModalBottomSheet<bool?>(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetCtx) =>
        _ConfirmScheduleSheet(fmt: fmt, start: start, end: end),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// Market Swap Confirmation Sheet
// ═══════════════════════════════════════════════════════════════════════════

class _ConfirmMarketSheet extends StatefulWidget {
  const _ConfirmMarketSheet({required this.fmt});
  final NumberFormat fmt;

  @override
  State<_ConfirmMarketSheet> createState() => _ConfirmMarketSheetState();
}

class _ConfirmMarketSheetState extends State<_ConfirmMarketSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _close([double? result]) async {
    await _animController.reverse();
    if (!mounted) return;
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final vmLive = context.watch<SwapVM>();
    final sLive = vmLive.state;

    final estOutLive = sLive.estReceive;
    final minOutPreFeeLive = vmLive.currentMinOutPreFee ??
        (estOutLive != null ? estOutLive * (1 - vmLive.slippagePct) : null);
    final minAfterFeesLive =
        vmLive.currentMinOutAfterFees ?? minOutPreFeeLive ?? 0.0;

    final isXlmToUsdc = sLive.isXlmToUsdc;
    final fromSymbol = isXlmToUsdc ? 'XLM' : 'USDC';
    final toSymbol = isXlmToUsdc ? 'USDC' : 'XLM';

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  _buildHandle(colors),
                  const SizedBox(height: 8),

                  // Header
                  _buildHeader(
                    colors,
                    icon: LucideIcons.arrowLeftRight,
                    title: 'Confirm Swap',
                    subtitle: 'Review your transaction',
                  ),
                  const SizedBox(height: 20),

                  // Swap visualization
                  _buildSwapVisualization(
                    colors,
                    from: '${widget.fmt.format(vmLive.amount)} $fromSymbol',
                    to: estOutLive != null
                        ? '${widget.fmt.format(estOutLive)} $toSymbol'
                        : 'Calculating...',
                  ),
                  const SizedBox(height: 20),

                  // Details
                  _buildDetailsCard(
                    colors,
                    children: [
                      _buildDetailRow(
                        colors,
                        label: 'Slippage Tolerance',
                        value: _fmtPct(vmLive.slippagePct),
                        icon: LucideIcons.zap,
                      ),
                      _buildDivider(colors),
                      _buildDetailRow(
                        colors,
                        label: 'Minimum Received',
                        value:
                        '${widget.fmt.format(minAfterFeesLive)} $toSymbol',
                        icon: LucideIcons.shield,
                        highlight: true,
                      ),
                      _buildDivider(colors),
                      _buildDetailRow(
                        colors,
                        label: 'Network Fee',
                        value: vmLive.hasFeeEstimates
                            ? '≈ ${widget.fmt.format(vmLive.estCombinedFeeXlm)} XLM'
                            : 'Calculating...',
                        icon: LucideIcons.coins,
                        subtitle: sLive.needsTrustline
                            ? 'Includes trustline setup'
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          type: ButtonType.outlined,
                          icon: LucideIcons.x,
                          text: "Cancel",
                          onPressed: () => _close(null),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: CustomButton(
                          icon: LucideIcons.checkCircle2,
                          text: "Confirm Swap",
                          onPressed: () => _close(minOutPreFeeLive ?? 0.0),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Limit Order Confirmation Sheet
// ═══════════════════════════════════════════════════════════════════════════

class _ConfirmLimitSheet extends StatefulWidget {
  const _ConfirmLimitSheet({
    required this.fmt,
    required this.price,
  });

  final NumberFormat fmt;
  final double price;

  @override
  State<_ConfirmLimitSheet> createState() => _ConfirmLimitSheetState();
}

class _ConfirmLimitSheetState extends State<_ConfirmLimitSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _close([bool? result]) async {
    await _animController.reverse();
    if (!mounted) return;
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final vmLive = context.watch<SwapVM>();
    final isXlmToUsdc = vmLive.state.isXlmToUsdc;
    final side = isXlmToUsdc ? 'Sell XLM' : 'Buy XLM';
    final fromSymbol = isXlmToUsdc ? 'XLM' : 'USDC';

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHandle(colors),
                  const SizedBox(height: 8),

                  _buildHeader(
                    colors,
                    icon: LucideIcons.target,
                    title: 'Place Limit Order',
                    subtitle: 'Set your target price',
                  ),
                  const SizedBox(height: 20),

                  // Order type badge
                  _buildOrderTypeBadge(
                    colors,
                    isXlmToUsdc ? 'SELL ORDER' : 'BUY ORDER',
                    isXlmToUsdc ? colors.error : colors.success,
                  ),
                  const SizedBox(height: 20),

                  _buildDetailsCard(
                    colors,
                    children: [
                      _buildDetailRow(
                        colors,
                        label: 'Amount',
                        value:
                        '${widget.fmt.format(vmLive.amount)} $fromSymbol',
                        icon: LucideIcons.coins,
                      ),
                      _buildDivider(colors),
                      _buildDetailRow(
                        colors,
                        label: 'Limit Price',
                        value: '${widget.fmt.format(widget.price)} USDC per XLM',
                        icon: LucideIcons.trendingUp,
                        highlight: true,
                      ),
                      _buildDivider(colors),
                      _buildDetailRow(
                        colors,
                        label: 'Order Type',
                        value: 'Good-Till-Cancel',
                        icon: LucideIcons.clock,
                        subtitle: 'Order stays active until filled or cancelled',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          type: ButtonType.outlined,
                          icon: LucideIcons.x,
                          text: "Cancel",
                          onPressed: () => _close(false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: CustomButton(
                          icon: LucideIcons.checkCircle2,
                          text: "Place Order",
                          onPressed: () => _close(true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Schedule Confirmation Sheet
// ═══════════════════════════════════════════════════════════════════════════

class _ConfirmScheduleSheet extends StatefulWidget {
  const _ConfirmScheduleSheet({
    required this.fmt,
    required this.start,
    required this.end,
  });

  final NumberFormat fmt;
  final DateTime? start;
  final DateTime? end;

  @override
  State<_ConfirmScheduleSheet> createState() => _ConfirmScheduleSheetState();
}

class _ConfirmScheduleSheetState extends State<_ConfirmScheduleSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _close([bool? result]) async {
    await _animController.reverse();
    if (!mounted) return;
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final vmLive = context.watch<SwapVM>();
    final isXlmToUsdc = vmLive.state.isXlmToUsdc;
    final fromSymbol = isXlmToUsdc ? 'XLM' : 'USDC';

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHandle(colors),
                  const SizedBox(height: 8),

                  _buildHeader(
                    colors,
                    icon: LucideIcons.calendar,
                    title: 'Schedule Swap',
                    subtitle: 'Execute during time window',
                  ),
                  const SizedBox(height: 20),

                  // Time window visualization
                  _buildTimeWindow(
                    colors,
                    start: widget.start,
                    end: widget.end,
                  ),
                  const SizedBox(height: 20),

                  _buildDetailsCard(
                    colors,
                    children: [
                      _buildDetailRow(
                        colors,
                        label: 'Amount',
                        value:
                        '${widget.fmt.format(vmLive.amount)} $fromSymbol',
                        icon: LucideIcons.coins,
                      ),
                      _buildDivider(colors),
                      _buildDetailRow(
                        colors,
                        label: 'Execution',
                        value: 'Market Price',
                        icon: LucideIcons.zap,
                        subtitle: 'Best available price during window',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          type: ButtonType.outlined,
                          icon: LucideIcons.x,
                          text: "Cancel",
                          onPressed: () => _close(false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: CustomButton(
                          icon: LucideIcons.checkCircle2,
                          text: "Schedule",
                          onPressed: () => _close(true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Reusable UI Components
// ═══════════════════════════════════════════════════════════════════════════

Widget _buildHandle(AppColor colors) {
  return Container(
    width: 40,
    height: 4,
    decoration: BoxDecoration(
      color: colors.border.withOpacity(0.5),
      borderRadius: BorderRadius.circular(100),
    ),
  );
}

Widget _buildHeader(
    AppColor colors, {
      required IconData icon,
      required String title,
      required String subtitle,
    }) {
  return Row(
    children: [
      Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: colors.primaryGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: colors.primary.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

Widget _buildSwapVisualization(
    AppColor colors, {
      required String from,
      required String to,
    }) {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: colors.primaryGradient,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: colors.primary.withOpacity(0.2),
        width: 1,
      ),
    ),
    child: Column(
      children: [
        _buildAmountBox(colors, from, colors.primary),
        const SizedBox(height: 12),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: colors.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: colors.primary.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Icon(
            LucideIcons.arrowDown,
            size: 16,
            color: colors.primary,
          ),
        ),
        const SizedBox(height: 12),
        _buildAmountBox(colors, to, colors.success),
      ],
    ),
  );
}

Widget _buildAmountBox(AppColor colors, String text, Color accentColor) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: accentColor.withOpacity(0.2),
        width: 1,
      ),
    ),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: colors.textPrimary,
        letterSpacing: -0.2,
      ),
    ),
  );
}

Widget _buildDetailsCard(AppColor colors, {required List<Widget> children}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: colors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: colors.border.withOpacity(0.3),
        width: 1,
      ),
    ),
    child: Column(children: children),
  );
}

Widget _buildDetailRow(
    AppColor colors, {
      required String label,
      required String value,
      required IconData icon,
      String? subtitle,
      bool highlight = false,
    }) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: highlight
                ? colors.primary.withOpacity(0.1)
                : colors.border.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: highlight ? colors.primary : colors.textSecondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: colors.textSecondary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.textSecondary.withOpacity(0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: highlight ? colors.primary : colors.textPrimary,
          ),
        ),
      ],
    ),
  );
}

Widget _buildDivider(AppColor colors) {
  return Divider(
    color: colors.border.withOpacity(0.2),
    height: 1,
  );
}

Widget _buildOrderTypeBadge(AppColor colors, String text, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: color.withOpacity(0.3),
        width: 1,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          LucideIcons.trendingUp,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
      ],
    ),
  );
}

Widget _buildTimeWindow(
    AppColor colors, {
      required DateTime? start,
      required DateTime? end,
    }) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: colors.primaryGradient,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: colors.primary.withOpacity(0.2),
        width: 1,
      ),
    ),
    child: Row(
      children: [
        Expanded(
          child: _buildTimeBox(colors, 'Start', start),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Icon(
            LucideIcons.arrowRight,
            size: 20,
            color: colors.primary,
          ),
        ),
        Expanded(
          child: _buildTimeBox(colors, 'End', end),
        ),
      ],
    ),
  );
}

Widget _buildTimeBox(AppColor colors, String label, DateTime? time) {
  return Column(
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: colors.textSecondary,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        _fmtDateTimeCompact(time),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: colors.textPrimary,
        ),
      ),
    ],
  );
}

// ══════════════════════════════════════════════════════════════════════════
// Helpers
// ══════════════════════════════════════════════════════════════════════════

String _fmtPct(double frac) {
  final p = frac * 100;
  return (p % 1 == 0) ? '${p.toStringAsFixed(0)}%' : '${p.toStringAsFixed(1)}%';
}

String _fmtDateTimeLocal(DateTime? dt) {
  if (dt == null) return '—';
  final local = dt.toLocal();
  final two = (int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}

String _fmtDateTimeCompact(DateTime? dt) {
  if (dt == null) return '—';
  final local = dt.toLocal();
  final two = (int n) => n.toString().padLeft(2, '0');
  return '${two(local.month)}/${two(local.day)}\n${two(local.hour)}:${two(local.minute)}';
}