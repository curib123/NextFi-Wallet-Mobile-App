// lib/features/claimable/view/claimable_create_screen.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/asset/asset_logo.dart';
import 'package:next_fi/common/components/alert/AppAlert.dart';
import 'package:next_fi/common/components/snackbar/SnackBar.dart';
import 'package:next_fi/common/components/modal/recipient_upsert_sheet.dart';

import 'package:next_fi/features/claimable/model/claimable_item.dart';
import 'package:next_fi/features/claimable/view_model/claimable_vm.dart';
import 'package:next_fi/features/wallet_home/view_model/recipient_address_vm.dart';
import 'package:next_fi/features/wallet_home/model/recipient_address_model.dart';
import 'package:next_fi/features/wallet_home/view/widgets/recipient_list_widget.dart';
import 'package:next_fi/features/scanner/view/scanner_screen.dart';

// ── Recipient sub-widgets ───────────────────────────────────────────────────
import 'package:next_fi/features/send/view/widgets/recipient_badge.dart';
import 'package:next_fi/features/send/view/widgets/recipient_add_template.dart';
import 'package:next_fi/features/send/view/widgets/recipient_loading_line.dart';

class ClaimableCreateScreen extends StatefulWidget {
  /// The asset symbol pre-selected from the token chooser on the list screen.
  final String initialAsset;

  const ClaimableCreateScreen({
    super.key,
    this.initialAsset = 'XLM',
  });

  @override
  State<ClaimableCreateScreen> createState() => _ClaimableCreateScreenState();
}

class _ClaimableCreateScreenState extends State<ClaimableCreateScreen>
    with SingleTickerProviderStateMixin {
  final _form = GlobalKey<FormState>();
  final _recipientCtl = TextEditingController();
  final _amountCtl = TextEditingController();

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  /// Selected asset symbol — initialized from widget.initialAsset
  late String _selectedAsset;

  ClaimableMode _mode = ClaimableMode.unconditional;

  DateTime? _unlockDate;
  TimeOfDay? _unlockTime;

  bool _hasExpiry = false;
  DateTime? _expiryDate;
  TimeOfDay? _expiryTime;

  bool _submitting = false;

  bool _recipientLoading = false;
  RecipientAddressModel? _resolvedRecipient;

  static final _dateFmt = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    _selectedAsset = widget.initialAsset;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();

    _recipientCtl.addListener(_onRecipientChanged);
  }

  @override
  void dispose() {
    _recipientCtl.removeListener(_onRecipientChanged);
    _animController.dispose();
    _recipientCtl.dispose();
    _amountCtl.dispose();
    super.dispose();
  }

  // ── Balance access ─────────────────────────────────────────────────────

  double get _currentBal {
    final vm = context.watch<ClaimableVM>();
    return vm.getBalanceForSymbol(_selectedAsset);
  }

  bool _looksLikeStellarPk(String x) =>
      RegExp(r'^G[A-Z2-7]{55}$').hasMatch(x);

  // ── Recipient resolution ──────────────────────────────────────────────

  void _onRecipientChanged() {
    final addr = _recipientCtl.text.trim();

    if (!_looksLikeStellarPk(addr)) {
      if (_resolvedRecipient != null || _recipientLoading) {
        setState(() {
          _resolvedRecipient = null;
          _recipientLoading = false;
        });
      }
      return;
    }

    _lookupRecipient(addr);
  }

  Future<void> _lookupRecipient(String address) async {
    setState(() {
      _recipientLoading = true;
      _resolvedRecipient = null;
    });

    try {
      final recipientVM = context.read<RecipientAddressVM>();
      await recipientVM.ready;
      final match = recipientVM.byAddress(address);

      if (mounted) {
        setState(() {
          _resolvedRecipient = match;
          _recipientLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _recipientLoading = false);
      }
    }
  }

  // ── Unlock pickers ─────────────────────────────────────────────────────

  Future<void> _pickUnlockDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _unlockDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (date != null && mounted) setState(() => _unlockDate = date);
  }

  Future<void> _pickUnlockTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _unlockTime ?? TimeOfDay.now(),
    );
    if (time != null && mounted) setState(() => _unlockTime = time);
  }

  DateTime? get _combinedUnlockDateTime {
    if (_unlockDate == null) return null;
    final t = _unlockTime ?? const TimeOfDay(hour: 0, minute: 0);
    return DateTime(_unlockDate!.year, _unlockDate!.month, _unlockDate!.day, t.hour, t.minute);
  }

  // ── Expiry pickers ─────────────────────────────────────────────────────

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final earliest = _mode == ClaimableMode.timeLocked && _unlockDate != null
        ? _unlockDate!.add(const Duration(days: 1))
        : now.add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? earliest,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (date != null && mounted) setState(() => _expiryDate = date);
  }

  Future<void> _pickExpiryTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _expiryTime ?? TimeOfDay.now(),
    );
    if (time != null && mounted) setState(() => _expiryTime = time);
  }

  DateTime? get _combinedExpiryDateTime {
    if (_expiryDate == null) return null;
    final t = _expiryTime ?? const TimeOfDay(hour: 23, minute: 59);
    return DateTime(_expiryDate!.year, _expiryDate!.month, _expiryDate!.day, t.hour, t.minute);
  }

  // ── Validation ─────────────────────────────────────────────────────────

  String? _validate() {
    final addr = _recipientCtl.text.trim();
    if (!_looksLikeStellarPk(addr)) return 'Enter a valid Stellar address (G…)';

    final amt = double.tryParse(_amountCtl.text.trim()) ?? 0;
    if (amt <= 0) return 'Enter a valid amount';

    final vm = context.read<ClaimableVM>();
    if (!vm.hasSufficientBalance(_selectedAsset, amt)) {
      return 'Insufficient $_selectedAsset balance';
    }

    if (_mode == ClaimableMode.timeLocked) {
      final dt = _combinedUnlockDateTime;
      if (dt == null) return 'Pick an unlock date';
      if (dt.isBefore(DateTime.now())) return 'Unlock time must be in the future';
    }

    if (_hasExpiry) {
      final exp = _combinedExpiryDateTime;
      if (exp == null) return 'Pick an expiration date';
      if (exp.isBefore(DateTime.now())) return 'Expiration must be in the future';
      if (_mode == ClaimableMode.timeLocked) {
        final unlock = _combinedUnlockDateTime;
        if (unlock != null && exp.isBefore(unlock)) {
          return 'Expiration must be after unlock time';
        }
      }
    }
    return null;
  }

  Future<void> _saveRecipientIfNeeded(String address) async {
    if (!mounted) return;
    final recipientVM = context.read<RecipientAddressVM>();
    await recipientVM.ready;
    final existing = recipientVM.byAddress(address);
    if (existing != null) return;

    final saved = await showRecipientUpsertSheet(context, address: address);
    if (saved == true && mounted) {
      showFloatingSnackBar(context, message: 'Recipient saved', type: SnackBarType.info);
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final reason = _validate();
    if (reason != null) {
      showFloatingSnackBar(context, message: reason, type: SnackBarType.warning);
      return;
    }

    setState(() => _submitting = true);
    HapticFeedback.mediumImpact();

    final vm = context.read<ClaimableVM>();
    final addr = _recipientCtl.text.trim();
    final amt = double.parse(_amountCtl.text.trim());

    late final AppAlertController ctl;
    ctl = showAppAlert(
      context,
      type: AppAlertType.loading,
      title: 'Creating claimable balance…',
      subtitle: 'Broadcasting transaction.',
      primaryText: 'Hide',
    );

    try {
      String txHash;

      if (_mode == ClaimableMode.unconditional && !_hasExpiry) {
        txHash = await vm.createUnconditional(
          assetSymbol: _selectedAsset, amount: amt, recipientId: addr,
        );
      } else if (_mode == ClaimableMode.unconditional && _hasExpiry) {
        txHash = await vm.createUnconditionalWithExpiry(
          assetSymbol: _selectedAsset, amount: amt, recipientId: addr,
          expiryTime: _combinedExpiryDateTime!,
        );
      } else if (_mode == ClaimableMode.timeLocked && !_hasExpiry) {
        txHash = await vm.createTimeLocked(
          assetSymbol: _selectedAsset, amount: amt, recipientId: addr,
          unlockTime: _combinedUnlockDateTime!,
        );
      } else {
        txHash = await vm.createTimeLockedWithExpiry(
          assetSymbol: _selectedAsset, amount: amt, recipientId: addr,
          unlockTime: _combinedUnlockDateTime!, expiryTime: _combinedExpiryDateTime!,
        );
      }

      if (!mounted) return;
      HapticFeedback.heavyImpact();

      ctl.update(
        AppAlertType.success,
        title: 'Created successfully',
        subtitle: 'Transaction: $txHash',
        primaryText: 'Copy TxID',
        onPrimary: () async {
          await Clipboard.setData(ClipboardData(text: txHash));
          ctl.close();
        },
      );

      await _saveRecipientIfNeeded(addr);

      _amountCtl.clear();
      _recipientCtl.clear();
      setState(() {
        _unlockDate = null;
        _unlockTime = null;
        _expiryDate = null;
        _expiryTime = null;
        _hasExpiry = false;
        _resolvedRecipient = null;
      });
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.vibrate();
      ctl.update(AppAlertType.error, title: 'Failed to create', subtitle: '$e',
          primaryText: 'Dismiss', onPrimary: ctl.close);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _selectRecipient() async {
    final c = AppColor.of(context);
    final selected = await Navigator.push<RecipientAddressModel>(
      context,
      MaterialPageRoute(
        builder: (context) => RecipientListWidget(
          colors: c,
          onSelect: (recipient) => Navigator.pop(context, recipient),
        ),
      ),
    );
    if (selected != null && mounted) {
      _recipientCtl.text = selected.address;
      setState(() => _resolvedRecipient = selected);
    }
  }

  Future<void> _scanQR() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (result != null && mounted) {
      _recipientCtl.text = result.trim();
      setState(() {});
    }
  }

  void _editRecipient() {
    _recipientCtl.clear();
    setState(() => _resolvedRecipient = null);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Create Claimable Balance',
          style: TextStyle(
            fontWeight: FontWeight.w700, color: c.textPrimary,
            fontSize: 20, letterSpacing: -0.5,
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            _buildBalanceCard(c),
            const SizedBox(height: 16),
            _buildModeToggle(c),
            const SizedBox(height: 20),
            Form(
              key: _form,
              child: Column(
                children: [
                  _buildRecipientSection(c),
                  const SizedBox(height: 16),
                  _buildAmountField(c),
                  if (_mode == ClaimableMode.timeLocked) ...[
                    const SizedBox(height: 20),
                    _buildUnlockPicker(c),
                  ],
                  const SizedBox(height: 20),
                  _buildExpirySection(c),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildInfoCard(c),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(c),
    );
  }

  // ── Balance card (shows pre-selected asset) ────────────────────────────

  Widget _buildBalanceCard(AppColor c) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [c.primary.withOpacity(0.08), c.primary.withOpacity(0.04)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.primary.withOpacity(0.15), width: 1.5),
        boxShadow: [
          BoxShadow(color: c.primary.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [c.primary.withOpacity(0.15), c.primary.withOpacity(0.08)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: AssetLogo(keyOrSymbol: _selectedAsset, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_selectedAsset Balance',
                  style: TextStyle(
                    color: c.textSecondary, fontSize: 12,
                    fontWeight: FontWeight.w600, letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_currentBal.toStringAsFixed(_currentBal >= 100 ? 2 : 4)} $_selectedAsset',
                  style: TextStyle(
                    color: c.textPrimary, fontWeight: FontWeight.w900,
                    fontSize: 18, letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [c.primary.withOpacity(0.12), c.primary.withOpacity(0.06)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.primary.withOpacity(0.2), width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AssetLogo(keyOrSymbol: _selectedAsset, size: 18),
                const SizedBox(width: 6),
                Text(_selectedAsset, style: TextStyle(
                  color: c.primary, fontWeight: FontWeight.w800, fontSize: 13,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Mode toggle ────────────────────────────────────────────────────────

  Widget _buildModeToggle(AppColor c) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.surface.withOpacity(0.8), c.surface.withOpacity(0.6)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border.withOpacity(0.15), width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(child: _modeChip(c, 'Instant', ClaimableMode.unconditional, LucideIcons.zap)),
          const SizedBox(width: 6),
          Expanded(child: _modeChip(c, 'Time-locked', ClaimableMode.timeLocked, LucideIcons.clock)),
        ],
      ),
    );
  }

  Widget _modeChip(AppColor c, String label, ClaimableMode mode, IconData icon) {
    final active = _mode == mode;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _mode = mode);
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: active
                ? LinearGradient(colors: [c.primary.withOpacity(0.15), c.primary.withOpacity(0.08)])
                : null,
            borderRadius: BorderRadius.circular(14),
            border: active ? Border.all(color: c.primary.withOpacity(0.25), width: 1.5) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: active ? c.primary : c.textSecondary),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(
                color: active ? c.primary : c.textPrimary,
                fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: -0.1,
              )),
            ],
          ),
        ),
      ),
    );
  }

  // ── Recipient section ──────────────────────────────────────────────────

  Widget _buildRecipientSection(AppColor c) {
    final addr = _recipientCtl.text.trim();
    final hasValidAddr = _looksLikeStellarPk(addr);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            children: [
              Icon(LucideIcons.userCheck, size: 15, color: c.primary),
              const SizedBox(width: 8),
              Text('Recipient', style: TextStyle(
                color: c.textPrimary, fontWeight: FontWeight.w800,
                fontSize: 15, letterSpacing: -0.2,
              )),
            ],
          ),
        ),
        if (_recipientLoading)
          const RecipientLoadingLine()
        else if (hasValidAddr && _resolvedRecipient != null)
          RecipientBadge(
            name: _resolvedRecipient!.name,
            colorValue: _resolvedRecipient!.color,
            address: _shortenAddress(addr),
            onEdit: _editRecipient,
          )
        else if (hasValidAddr && _resolvedRecipient == null)
            RecipientAddTemplate(
              address: _shortenAddress(addr),
              onAdd: () async {
                final saved = await showRecipientUpsertSheet(context, address: addr);
                if (saved == true && mounted) _lookupRecipient(addr);
              },
            )
          else
            _buildRecipientField(c),
      ],
    );
  }

  String _shortenAddress(String addr) {
    if (addr.length <= 16) return addr;
    return '${addr.substring(0, 6)}…${addr.substring(addr.length - 6)}';
  }

  Widget _buildRecipientField(AppColor c) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.surface.withOpacity(0.95), c.surface.withOpacity(0.85)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border.withOpacity(0.15), width: 1.5),
      ),
      child: TextFormField(
        controller: _recipientCtl,
        textInputAction: TextInputAction.next,
        keyboardType: TextInputType.multiline,
        minLines: 1,
        maxLines: null,
        style: const TextStyle(
          fontSize: 13, height: 1.3, letterSpacing: 0.1,
          fontWeight: FontWeight.w500,
          fontFeatures: [ui.FontFeature.tabularFigures()],
        ),
        decoration: InputDecoration(
          hintText: 'Recipient Address (G… 56 chars)',
          hintStyle: TextStyle(color: c.textSecondary.withOpacity(0.5), fontSize: 13),
          prefixIcon: Container(
            padding: const EdgeInsets.all(12),
            child: Icon(LucideIcons.wallet, color: c.primary, size: 20),
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: _scanQR,
                icon: Icon(LucideIcons.qrCode, size: 18, color: c.primary),
                tooltip: 'Scan QR code',
              ),
              IconButton(
                onPressed: _selectRecipient,
                icon: Icon(LucideIcons.contact, size: 18, color: c.primary),
                tooltip: 'Select recipient',
              ),
              if (_recipientCtl.text.trim().isNotEmpty)
                IconButton(
                  onPressed: () {
                    _recipientCtl.clear();
                    setState(() => _resolvedRecipient = null);
                  },
                  icon: Icon(LucideIcons.x, size: 16, color: c.textSecondary),
                ),
            ],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        validator: (_) {
          final a = _recipientCtl.text.trim();
          if (a.isEmpty) return 'Required';
          if (!_looksLikeStellarPk(a)) return 'Invalid Stellar address';
          return null;
        },
        onChanged: (_) => setState(() {}),
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
      ),
    );
  }

  // ── Amount field ───────────────────────────────────────────────────────

  Widget _buildAmountField(AppColor c) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.surface.withOpacity(0.95), c.surface.withOpacity(0.85)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border.withOpacity(0.15), width: 1.5),
      ),
      child: TextFormField(
        controller: _amountCtl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,7}$')),
        ],
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        decoration: InputDecoration(
          hintText: 'Amount ($_selectedAsset)',
          hintStyle: TextStyle(color: c.textSecondary.withOpacity(0.5), fontSize: 15),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: AssetLogo(keyOrSymbol: _selectedAsset, size: 24),
          ),
          suffixIcon: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                final v = _currentBal;
                _amountCtl.text = v > 0
                    ? v.toStringAsFixed(7).replaceFirst(RegExp(r'\.?0+$'), '')
                    : '';
                _amountCtl.selection = TextSelection.fromPosition(
                  TextPosition(offset: _amountCtl.text.length),
                );
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [c.primary.withOpacity(0.12), c.primary.withOpacity(0.06)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('MAX', style: TextStyle(
                  color: c.primary, fontWeight: FontWeight.w900,
                  fontSize: 12, letterSpacing: 0.5,
                )),
              ),
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
        validator: (_) {
          final amt = double.tryParse(_amountCtl.text.trim()) ?? 0;
          if (amt <= 0) return 'Enter amount';
          final vm = context.read<ClaimableVM>();
          if (!vm.hasSufficientBalance(_selectedAsset, amt)) return 'Insufficient balance';
          return null;
        },
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
      ),
    );
  }

  // ── Unlock picker (time-locked mode) ───────────────────────────────────

  Widget _buildUnlockPicker(AppColor c) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.surface.withOpacity(0.95), c.surface.withOpacity(0.85)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border.withOpacity(0.15), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [c.primary.withOpacity(0.15), c.primary.withOpacity(0.08)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(LucideIcons.calendarClock, size: 18, color: c.primary),
              ),
              const SizedBox(width: 12),
              Text('Unlock Schedule', style: TextStyle(
                color: c.textPrimary, fontWeight: FontWeight.w800,
                fontSize: 15, letterSpacing: -0.2,
              )),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _pickerButton(c,
                icon: LucideIcons.calendar,
                label: _unlockDate != null ? _dateFmt.format(_unlockDate!) : 'Pick date',
                onTap: _pickUnlockDate,
              )),
              const SizedBox(width: 12),
              Expanded(child: _pickerButton(c,
                icon: LucideIcons.clock,
                label: _unlockTime != null ? _unlockTime!.format(context) : 'Pick time',
                onTap: _pickUnlockTime,
              )),
            ],
          ),
          if (_combinedUnlockDateTime != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [c.primary.withOpacity(0.08), c.primary.withOpacity(0.04)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.info, size: 14, color: c.primary),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    'Claimable after ${_dateFmt.format(_combinedUnlockDateTime!)} at ${_unlockTime?.format(context) ?? '12:00 AM'}',
                    style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.4),
                  )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Expiration section ─────────────────────────────────────────────────

  Widget _buildExpirySection(AppColor c) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _hasExpiry
              ? [c.warning.withOpacity(0.08), c.warning.withOpacity(0.04)]
              : [c.surface.withOpacity(0.95), c.surface.withOpacity(0.85)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _hasExpiry ? c.warning.withOpacity(0.2) : c.border.withOpacity(0.15),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _hasExpiry
                        ? [c.warning.withOpacity(0.15), c.warning.withOpacity(0.08)]
                        : [c.textSecondary.withOpacity(0.12), c.textSecondary.withOpacity(0.06)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(LucideIcons.timerOff, size: 18,
                    color: _hasExpiry ? c.warning : c.textSecondary),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('Set Expiration', style: TextStyle(
                color: c.textPrimary, fontWeight: FontWeight.w800,
                fontSize: 15, letterSpacing: -0.2,
              ))),
              SizedBox(
                height: 32,
                child: Switch.adaptive(
                  value: _hasExpiry,
                  activeColor: c.warning,
                  onChanged: (v) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _hasExpiry = v;
                      if (!v) { _expiryDate = null; _expiryTime = null; }
                    });
                  },
                ),
              ),
            ],
          ),
          if (!_hasExpiry) ...[
            const SizedBox(height: 10),
            Text('Balance stays claimable indefinitely without expiration.',
                style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.4)),
          ],
          if (_hasExpiry) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _pickerButton(c,
                  icon: LucideIcons.calendar,
                  label: _expiryDate != null ? _dateFmt.format(_expiryDate!) : 'Expiry date',
                  onTap: _pickExpiryDate, accentColor: c.warning,
                )),
                const SizedBox(width: 12),
                Expanded(child: _pickerButton(c,
                  icon: LucideIcons.clock,
                  label: _expiryTime != null ? _expiryTime!.format(context) : 'Expiry time',
                  onTap: _pickExpiryTime, accentColor: c.warning,
                )),
              ],
            ),
            if (_combinedExpiryDateTime != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [c.warning.withOpacity(0.1), c.warning.withOpacity(0.05)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.alertTriangle, size: 14, color: c.warning),
                    const SizedBox(width: 10),
                    Expanded(child: Text(
                      'Unclaimed funds can be reclaimed after ${_dateFmt.format(_combinedExpiryDateTime!)} at '
                          '${_expiryTime?.format(context) ?? '11:59 PM'}',
                      style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.4),
                    )),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ── Shared picker button ───────────────────────────────────────────────

  Widget _pickerButton(AppColor c, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? accentColor,
  }) {
    final color = accentColor ?? c.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.background.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border.withOpacity(0.2), width: 1.5),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: TextStyle(
                color: c.textPrimary, fontSize: 13,
                fontWeight: FontWeight.w600, letterSpacing: -0.1,
              ), overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Info card ──────────────────────────────────────────────────────────

  Widget _buildInfoCard(AppColor c) {
    final isTimeLocked = _mode == ClaimableMode.timeLocked;

    String body;
    if (isTimeLocked && _hasExpiry) {
      body = 'Funds are locked until unlock time. Recipient can claim between '
          'unlock and expiration. After expiry, you can reclaim unclaimed funds.';
    } else if (isTimeLocked) {
      body = 'Funds are locked until unlock time. Recipient can claim after '
          'that point. Balance stays claimable indefinitely once unlocked.';
    } else if (_hasExpiry) {
      body = 'Recipient can claim immediately but must do so before expiration. '
          'After expiry, you can reclaim unclaimed funds.';
    } else {
      body = 'Recipient can claim anytime. Balance is held on Stellar network '
          'until claimed. No expiration limit.';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.primary.withOpacity(0.06), c.primary.withOpacity(0.03)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.primary.withOpacity(0.12), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [c.primary.withOpacity(0.15), c.primary.withOpacity(0.08)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isTimeLocked ? LucideIcons.shieldQuestion : LucideIcons.info,
                  size: 16, color: c.primary,
                ),
              ),
              const SizedBox(width: 12),
              Text('How It Works', style: TextStyle(
                color: c.textPrimary, fontWeight: FontWeight.w800,
                fontSize: 14, letterSpacing: -0.1,
              )),
            ],
          ),
          const SizedBox(height: 12),
          Text(body, style: TextStyle(
            color: c.textSecondary, fontSize: 12.5, height: 1.5,
          )),
        ],
      ),
    );
  }

  // ── Bottom bar ─────────────────────────────────────────────────────────

  Widget _buildBottomBar(AppColor c) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [c.background.withOpacity(0.0), c.background],
          ),
          border: Border(top: BorderSide(color: c.border.withOpacity(0.1), width: 1.5)),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: _submitting
                    ? [c.primary.withOpacity(0.5), c.primary.withOpacity(0.4)]
                    : [c.primary, c.primary.withOpacity(0.85)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: _submitting ? null : [
                BoxShadow(color: c.primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _submitting ? null : _submit,
                borderRadius: BorderRadius.circular(16),
                child: Center(
                  child: _submitting
                      ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.send, size: 18, color: Colors.white),
                      const SizedBox(width: 12),
                      Text(
                        _mode == ClaimableMode.timeLocked
                            ? 'Create Time-Locked Balance'
                            : 'Create Claimable Balance',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800, color: Colors.white,
                          fontSize: 15, letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}