import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/core/widgets/alert/app_alert.dart';
import 'package:next_fi/core/widgets/drawer/app_drawer_button.dart';
import 'package:next_fi/core/widgets/drawer/app_drawer.dart';

import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/app/config/app_providers.dart';
import 'package:next_fi/core/widgets/button/custom_button.dart';
import 'package:next_fi/core/widgets/loader/page_loader.dart';
import 'package:next_fi/core/widgets/asset/asset_logo.dart';
import 'package:next_fi/core/widgets/modal/confirm_swap_sheet.dart';

import 'package:next_fi/features/swap/data/models/swap_mode.dart';
import 'package:next_fi/features/swap/presentation/widgets/section_card.dart';
import 'package:next_fi/features/swap/presentation/widgets/percent_chips_row.dart';
import 'package:next_fi/features/swap/presentation/widgets/error_card.dart';
import 'package:next_fi/features/swap/presentation/viewmodels/swap_vm.dart';

class SwapScreen extends ConsumerStatefulWidget {
  const SwapScreen({super.key});

  @override
  ConsumerState<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends ConsumerState<SwapScreen>
    with SingleTickerProviderStateMixin {
  final _fmt = NumberFormat('#,##0.######');
  final _fromCtl = TextEditingController();
  final _toCtl = TextEditingController();

  final RegExp _partialRe = RegExp(r'^\d{0,12}([.]\d{0,7})?$');

  bool _booted = false;
  bool _syncingFrom = false;
  bool _syncingTo = false;
  double? _lastPct;

  late final AnimationController _flipCtl;
  late final Animation<double> _flipAnim;

  @override
  void initState() {
    super.initState();
    _flipCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _flipAnim = CurvedAnimation(parent: _flipCtl, curve: Curves.easeInOut);
    _fromCtl.addListener(_onFromChanged);
    _toCtl.addListener(_onToChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_booted) return;
    _booted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final vm = ref.read(swapVmProvider);
      await vm.start();
      if (vm.mode != AmountMode.from) await vm.setAmountMode(AmountMode.from);
      _syncBoth(vm);
    });
  }

  @override
  void dispose() {
    _fromCtl.removeListener(_onFromChanged);
    _toCtl.removeListener(_onToChanged);
    _fromCtl.dispose();
    _toCtl.dispose();
    _flipCtl.dispose();
    super.dispose();
  }

  Future<void> _onFromChanged() async {
    if (_syncingFrom) return;
    final vm = ref.read(swapVmProvider);
    if (vm.mode != AmountMode.from) await vm.setAmountMode(AmountMode.from);

    var raw = _fromCtl.text;
    if (raw == '.') {
      _setField(_fromCtl, '0.', isFrom: true);
      return;
    }

    _lastPct = null;
    await vm.onAmountChanged(raw);

    final accepted = vm.amount;
    final typed = double.tryParse(raw.replaceAll(',', '').trim()) ?? 0.0;
    if (typed > 0 && (accepted - typed).abs() > 1e-9) {
      _setField(_fromCtl, _tight(accepted), isFrom: true);
    }

    if (_partialRe.hasMatch(raw)) {
      _syncTo(vm);
    } else {
      _syncBoth(vm);
    }
    if (mounted) setState(() {});
  }

  Future<void> _onToChanged() async {
    if (_syncingTo) return;
    final vm = ref.read(swapVmProvider);
    if (vm.mode != AmountMode.to) await vm.setAmountMode(AmountMode.to);

    var raw = _toCtl.text;
    if (raw == '.') {
      _setField(_toCtl, '0.', isFrom: false);
      return;
    }

    _lastPct = null;
    await vm.onAmountChanged(raw);

    if (_partialRe.hasMatch(raw)) {
      _syncFrom(vm);
    } else {
      _syncBoth(vm);
    }
    if (mounted) setState(() {});
  }

  void _setField(
    TextEditingController ctl,
    String text, {
    required bool isFrom,
  }) {
    if (isFrom) {
      _syncingFrom = true;
    } else {
      _syncingTo = true;
    }
    try {
      ctl.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    } finally {
      if (isFrom) {
        _syncingFrom = false;
      } else {
        _syncingTo = false;
      }
    }
  }

  void _syncFrom(SwapVM vm) {
    _syncingFrom = true;
    try {
      final t = vm.amount <= 0 ? '' : _tight(vm.amount);
      _fromCtl.value = TextEditingValue(
        text: t,
        selection: TextSelection.collapsed(offset: t.length),
      );
    } finally {
      _syncingFrom = false;
    }
  }

  void _syncTo(SwapVM vm) {
    _syncingTo = true;
    try {
      final est = vm.state.estReceive;
      final t = (est == null || est <= 0) ? '' : _tight(est);
      _toCtl.value = TextEditingValue(
        text: t,
        selection: TextSelection.collapsed(offset: t.length),
      );
    } finally {
      _syncingTo = false;
    }
  }

  void _syncBoth(SwapVM vm) {
    _syncingFrom = true;
    _syncingTo = true;
    try {
      final fromT = vm.amount <= 0 ? '' : _tight(vm.amount);
      final est = vm.state.estReceive;
      final toT = (est == null || est <= 0) ? '' : _tight(est);
      _fromCtl.value = TextEditingValue(
        text: fromT,
        selection: TextSelection.collapsed(offset: fromT.length),
      );
      _toCtl.value = TextEditingValue(
        text: toT,
        selection: TextSelection.collapsed(offset: toT.length),
      );
    } finally {
      _syncingFrom = false;
      _syncingTo = false;
    }
    if (mounted) setState(() {});
  }

  String _tight(double v, {int decimals = 7}) {
    final s = v.toStringAsFixed(decimals);
    return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
  }

  String _fmtPct(double pct) =>
      pct % 1 == 0 ? pct.toStringAsFixed(0) : pct.toStringAsFixed(1);

  Future<void> _flip(SwapVM vm) async {
    HapticFeedback.lightImpact();
    _flipCtl.forward(from: 0);
    await vm.flipDirectionAndRequote();
    if (vm.mode != AmountMode.from) await vm.setAmountMode(AmountMode.from);
    _lastPct = null;
    _syncBoth(vm);
  }

  Future<void> _pickAsset(SwapVM vm, {required bool selectingFrom}) async {
    final c = AppColor.of(context);
    final selectedId = selectingFrom ? vm.fromAsset.id : vm.toAsset.id;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final asset in vm.swappableAssets)
              ListTile(
                leading: AssetLogo(keyOrSymbol: asset.symbol, size: 20),
                title: Text(asset.symbol.toUpperCase()),
                subtitle: Text(asset.name),
                trailing: asset.id == selectedId
                    ? Icon(LucideIcons.check, color: c.primary, size: 18)
                    : null,
                onTap: () => Navigator.of(ctx).pop(asset.id),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final asset = vm.swappableAssets.firstWhere((a) => a.id == picked);
    if (selectingFrom) {
      await vm.selectFromAsset(asset);
    } else {
      await vm.selectToAsset(asset);
    }
    _lastPct = null;
    _syncBoth(vm);
  }

  Future<void> _applyPct(SwapVM vm, double p) async {
    HapticFeedback.selectionClick();
    if (vm.mode != AmountMode.from) await vm.setAmountMode(AmountMode.from);
    await vm.applyPercent(p);
    _lastPct = p;
    _syncBoth(vm);
  }

  Future<void> _confirmMarket(SwapVM vm) async {
    await vm.onAmountChanged(
      vm.mode == AmountMode.from ? _fromCtl.text : _toCtl.text,
    );
    if (!mounted) return;

    if (!vm.hasAmount) return;

    if (!vm.canSwap) {
      showAppAlert(
        context,
        type: AppAlertType.warning,
        title: 'Insufficient balance',
        subtitle:
            'Your available ${vm.fromSymbol} '
            'is not enough for this swap.',
        primaryText: 'OK',
      );
      return;
    }

    if ((vm.state.estReceive ?? 0) <= 0) {
      showAppAlert(
        context,
        type: AppAlertType.error,
        title: 'No price quote',
        subtitle: 'A live quote is not available. Please try again.',
        primaryText: 'OK',
      );
      return;
    }

    if (!mounted) return;
    final minOut = await showConfirmMarketSheet(context, fmt: _fmt);
    if (minOut != null) await _execute(vm, vm.amount, minOut);
  }

  Future<void> _execute(SwapVM vm, double amount, double minOut) async {
    final ctl = showAppAlert(
      context,
      type: AppAlertType.loading,
      title: 'Submitting swap...',
      subtitle: 'This usually takes a few seconds.',
      primaryText: 'Hide',
      barrierDismissible: false,
    );

    try {
      final tx = await vm.executeSwap(amount: amount, minOut: minOut);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ctl.update(
        AppAlertType.success,
        title: 'Swap submitted',
        subtitle: vm.lastTrustlineActionMessage == null
            ? 'Transaction ID:\n$tx'
            : 'Transaction ID:\n$tx\n\n${vm.lastTrustlineActionMessage}',
        primaryText: 'OK',
        onPrimary: ctl.close,
      );
      await vm.setAmount(0);
      _lastPct = null;
      _syncBoth(vm);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      ctl.update(
        AppAlertType.error,
        title: 'Swap failed',
        subtitle: msg.length > 400 ? '${msg.substring(0, 400)}...' : msg,
        primaryText: 'Dismiss',
        onPrimary: ctl.close,
      );
    }
  }

  Future<void> _showSlippagePicker(SwapVM vm) async {
    final c = AppColor.of(context);
    double tempPct = vm.slippagePctPercent;

    await showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4,
                width: 36,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: c.border.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  Icon(
                    LucideIcons.slidersHorizontal,
                    size: 18,
                    color: c.textPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Slippage Tolerance',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: c.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_fmtPct(tempPct)}%',
                      style: TextStyle(
                        color: c.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: c.primary,
                  inactiveTrackColor: c.border.withValues(alpha: 0.3),
                  thumbColor: c.primary,
                  overlayColor: c.primary.withValues(alpha: 0.12),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: tempPct.clamp(
                    SwapVM.slippageMinPct,
                    SwapVM.slippageMaxPct,
                  ),
                  min: SwapVM.slippageMinPct,
                  max: SwapVM.slippageMaxPct,
                  divisions:
                      ((SwapVM.slippageMaxPct - SwapVM.slippageMinPct) / 0.1)
                          .round(),
                  label: '${_fmtPct(tempPct)}%',
                  onChanged: (v) => set(() => tempPct = v),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      type: ButtonType.outlined,
                      text: 'Cancel',
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: CustomButton(
                      type: ButtonType.filled,
                      text: 'Apply',
                      onPressed: () {
                        vm.setSlippagePctPercent(tempPct);
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(swapVmProvider);
    final s = vm.state;
    final c = AppColor.of(context);

    final fromSymbol = vm.fromSymbol;
    final toSymbol = vm.toSymbol;

    final priceLine = (vm.amount > 0 && (s.estReceive ?? 0) > 0)
        ? '1 $fromSymbol = ${_tight(s.estReceive! / vm.amount)} $toSymbol'
        : '-';

    final minOut = vm.currentMinOut;
    final minReceiveText = (minOut != null && minOut > 0)
        ? '${_tight(minOut)} $toSymbol (min.)'
        : null;

    final balanceStr = '${_fmt.format(vm.fromBalance)} $fromSymbol';

    return Scaffold(
      backgroundColor: c.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: c.background,
        leadingWidth: 60,
        leading: Builder(
          builder: (context) => Padding(
            padding: const EdgeInsets.only(left: 12),
            child: AppDrawerButton(
              colors: c,
              onTap: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ),
        title: Text(
          'Swap',
          style: TextStyle(fontWeight: FontWeight.w700, color: c.textPrimary),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(LucideIcons.refreshCcw, color: c.textPrimary),
            onPressed: () async {
              HapticFeedback.selectionClick();
              await vm.refreshBalances();
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
      body: _buildBody(
        vm,
        s,
        c,
        fromSymbol,
        toSymbol,
        priceLine,
        minReceiveText,
        balanceStr,
      ),
      bottomNavigationBar: _buildBottomBar(vm, s, c),
    );
  }

  Widget _buildBody(
    SwapVM vm,
    dynamic s,
    AppColor c,
    String fromSymbol,
    String toSymbol,
    String priceLine,
    String? minReceiveText,
    String balanceStr,
  ) {
    if (s.loading && s.accountId == null) return const PageLoader();
    if (s.error != null && s.error!.isNotEmpty) {
      return ErrorCard(
        message: s.error!,
        onRetry: () async {
          await vm.start();
          if (mounted) setState(() {});
        },
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        _buildExchangeCard(
          vm,
          c,
          fromSymbol,
          toSymbol,
          balanceStr,
          minReceiveText,
        ),
        const SizedBox(height: 12),
        _buildPriceRow(vm, c, priceLine),
        const SizedBox(height: 18),
        _buildTrustlineCard(vm, c),
        const SizedBox(height: 18),
        SectionCard(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: PercentChipsRow(activePct: _lastPct, onPick: (p) => _applyPct(vm, p)),
        ),
      ],
    );
  }

  Widget _buildExchangeCard(
    SwapVM vm,
    AppColor c,
    String fromSymbol,
    String toSymbol,
    String balanceStr,
    String? minReceiveText,
  ) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SectionCard(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 18),
          child: Column(
            children: [
              _AmountTile(
                symbol: fromSymbol,
                controller: _fromCtl,
                hint: '0.0',
                balanceText: balanceStr,
                onMax: () => _applyPct(vm, 1.0),
                onAssetTap: () => _pickAsset(vm, selectingFrom: true),
              ),
              const SizedBox(height: 20),
              _AmountTile(
                symbol: toSymbol,
                controller: _toCtl,
                hint: '0.0',
                onAssetTap: () => _pickAsset(vm, selectingFrom: false),
              ),
              if (minReceiveText != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      minReceiveText,
                      style: TextStyle(color: c.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        Positioned.fill(
          child: Align(
            alignment: Alignment.center,
            child: AnimatedBuilder(
              animation: _flipAnim,
              builder: (_, child) => Transform.rotate(
                angle: _flipAnim.value * math.pi,
                child: child,
              ),
              child: GestureDetector(
                onTap: () => _flip(vm),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border.all(color: c.border.withValues(alpha: 0.5)),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: c.textPrimary.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    LucideIcons.arrowUpDown,
                    size: 18,
                    color: c.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRow(SwapVM vm, AppColor c, String priceLine) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
      child: Row(
        children: [
          Icon(LucideIcons.trendingUp, size: 16, color: c.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              priceLine,
              style: TextStyle(color: c.textSecondary, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _showSlippagePicker(vm),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: c.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.slidersHorizontal,
                    size: 13,
                    color: c.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_fmtPct(vm.slippagePctPercent)}%',
                    style: TextStyle(
                      color: c.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustlineCard(SwapVM vm, AppColor c) {
    final showDestination = vm.showDestinationTrustlineSection;
    final showSourceRemoval = vm.showSourceTrustlineRemovalSection;
    if (!showDestination && !showSourceRemoval) {
      return const SizedBox.shrink();
    }

    final destinationTone =
        vm.destinationHasTrustline || vm.autoAddDestinationTrustline
        ? c.success
        : c.warning;

    return Container(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: c.border.withValues(alpha: 0.55)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showDestination) ...[
            _TrustlineToggleTile(
              colors: c,
              title: vm.destinationHasTrustline
                  ? '${vm.toSymbol} trustline is active'
                  : '${vm.toSymbol} trustline is missing',
              subtitle: vm.destinationTrustlineHint,
              value: vm.destinationHasTrustline || vm.autoAddDestinationTrustline,
              enabled: !vm.destinationHasTrustline,
              activeLabel: vm.destinationHasTrustline ? 'Active' : 'Auto-add',
              inactiveLabel: 'Off',
              onChanged: vm.destinationHasTrustline
                  ? null
                  : vm.setAutoAddDestinationTrustline,
              tone: destinationTone,
            ),
          ],
          if (showDestination && showSourceRemoval)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: c.border.withValues(alpha: 0.3)),
            ),
          if (showSourceRemoval) ...[
            if (!showDestination) const SizedBox(height: 12),
            _TrustlineToggleTile(
              colors: c,
              title: 'Remove ${vm.fromSymbol} trustline after swap',
              subtitle:
                  vm.sourceTrustlineRemovalHint ??
                  'Optional trustline cleanup after the swap.',
              value: vm.removeSourceTrustlineAfterSwap,
              enabled: true,
              activeLabel: 'Remove',
              inactiveLabel: 'Keep',
              onChanged: vm.setRemoveSourceTrustlineAfterSwap,
              tone: vm.removeSourceTrustlineAfterSwap ? c.warning : c.textSecondary,
            ),
          ],
          if (vm.trustlineValidationMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: c.warning.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(LucideIcons.alertTriangle, size: 15, color: c.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      vm.trustlineValidationMessage!,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget? _buildBottomBar(SwapVM vm, dynamic s, AppColor c) {
    if ((s.loading && s.accountId == null) ||
        (s.error != null && s.error!.isNotEmpty)) {
      return null;
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: CustomButton(
          text: 'Swap ${vm.fromSymbol} to ${vm.toSymbol}',
          icon: LucideIcons.arrowRightLeft,
          type: vm.hasAmount ? ButtonType.filled : ButtonType.disabled,
          onPressed: !vm.hasAmount
              ? () {}
              : vm.canSwap
              ? () => _confirmMarket(vm)
              : () {
                  HapticFeedback.selectionClick();
                  final trustlineMessage = vm.trustlineValidationMessage;
                  showAppAlert(
                    context,
                    type: trustlineMessage != null
                        ? AppAlertType.info
                        : AppAlertType.warning,
                    title: trustlineMessage != null
                        ? 'Trustline setup required'
                        : 'Insufficient balance',
                    subtitle: trustlineMessage ??
                        'Your available ${vm.fromSymbol} is not enough for this swap.',
                    primaryText: 'OK',
                  );
                },
        ),
      ),
    );
  }
}

class _TrustlineToggleTile extends StatelessWidget {
  const _TrustlineToggleTile({
    required this.colors,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.activeLabel,
    required this.inactiveLabel,
    required this.onChanged,
    required this.tone,
  });

  final AppColor colors;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final String activeLabel;
  final String inactiveLabel;
  final ValueChanged<bool>? onChanged;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12.2,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Switch.adaptive(
                value: value,
                onChanged: enabled ? onChanged : null,
                activeColor: tone,
              ),
              Text(
                value ? activeLabel : inactiveLabel,
                style: TextStyle(
                  color: value ? tone : colors.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AmountTile extends StatelessWidget {
  const _AmountTile({
    required this.symbol,
    required this.controller,
    this.hint = '0.0',
    this.onAssetTap,
    this.balanceText,
    this.onMax,
  });

  final String symbol;
  final TextEditingController controller;
  final String hint;
  final VoidCallback? onAssetTap;
  final String? balanceText;
  final VoidCallback? onMax;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);

    return Column(
      children: [
        Row(
          children: [
            if (balanceText != null) ...[
              const Spacer(),
              Text(
                balanceText!,
                style: TextStyle(
                  fontSize: 12,
                  color: c.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (onMax != null) ...[
                const SizedBox(width: 6),
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: onMax,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: c.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'MAX',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: c.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
        if (balanceText != null) const SizedBox(height: 8),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: c.border.withValues(alpha: 0.55)),
            ),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: onAssetTap,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: c.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AssetLogo(keyOrSymbol: symbol, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        symbol,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        LucideIcons.chevronsUpDown,
                        size: 14,
                        color: c.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              Expanded(
                child: TextField(
                  controller: controller,
                  readOnly: false,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle: TextStyle(
                      color: c.textSecondary.withValues(alpha: 0.5),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
