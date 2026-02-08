// lib/features/claimable/view/claimable_create_screen.dart
import 'dart:convert' show utf8;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/features/wallet_home/view/widgets/recipient_list_widget.dart';
import 'package:provider/provider.dart';

import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/asset/asset_logo.dart';
import 'package:next_fi/common/components/Input/modern_input.dart';
import 'package:next_fi/common/components/alert/AppAlert.dart';
import 'package:next_fi/common/components/snackbar/SnackBar.dart';
import 'package:next_fi/common/components/modal/recipient_upsert_sheet.dart';

import 'package:next_fi/features/claimable/model/claimable_item.dart';
import 'package:next_fi/features/claimable/view_model/claimable_vm.dart';
import 'package:next_fi/features/wallet_home/view_model/recipient_address_vm.dart';
import 'package:next_fi/features/wallet_home/model/recipient_address_model.dart';
import 'package:next_fi/features/scanner/view/scanner_screen.dart';

class ClaimableCreateScreen extends StatefulWidget {
  const ClaimableCreateScreen({super.key});

  @override
  State<ClaimableCreateScreen> createState() => _ClaimableCreateScreenState();
}

class _ClaimableCreateScreenState extends State<ClaimableCreateScreen> {
  final _form = GlobalKey<FormState>();
  final _recipientCtl = TextEditingController();
  final _amountCtl = TextEditingController();

  bool _isXlm = true;
  ClaimableMode _mode = ClaimableMode.unconditional;

  // ── Unlock (time-locked mode) ──────────────────────────────────────────
  DateTime? _unlockDate;
  TimeOfDay? _unlockTime;

  // ── Expiration (both modes) ────────────────────────────────────────────
  bool _hasExpiry = false;
  DateTime? _expiryDate;
  TimeOfDay? _expiryTime;

  double? _xlmBal;
  double? _usdcBal;
  bool _loadingBal = true;
  bool _submitting = false;

  static final _dateFmt = DateFormat('MMM d, yyyy');
  static final _timeFmt = DateFormat('h:mm a');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBalances());
  }

  @override
  void dispose() {
    _recipientCtl.dispose();
    _amountCtl.dispose();
    super.dispose();
  }

  Future<void> _loadBalances() async {
    final vm = context.read<ClaimableVM>();
    try {
      final results = await Future.wait([
        vm.getBalance(true),
        vm.getBalance(false),
      ]);
      if (!mounted) return;
      setState(() {
        _xlmBal = results[0];
        _usdcBal = results[1];
        _loadingBal = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingBal = false);
    }
  }

  double get _currentBal => _isXlm ? (_xlmBal ?? 0) : (_usdcBal ?? 0);
  String get _tokenStr => _isXlm ? 'XLM' : 'USDC';

  bool _looksLikeStellarPk(String x) =>
      RegExp(r'^G[A-Z2-7]{55}$').hasMatch(x);

  // ── Unlock pickers ─────────────────────────────────────────────────────

  Future<void> _pickUnlockDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _unlockDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (date != null && mounted) {
      setState(() => _unlockDate = date);
    }
  }

  Future<void> _pickUnlockTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _unlockTime ?? TimeOfDay.now(),
    );
    if (time != null && mounted) {
      setState(() => _unlockTime = time);
    }
  }

  DateTime? get _combinedUnlockDateTime {
    if (_unlockDate == null) return null;
    final t = _unlockTime ?? const TimeOfDay(hour: 0, minute: 0);
    return DateTime(
      _unlockDate!.year,
      _unlockDate!.month,
      _unlockDate!.day,
      t.hour,
      t.minute,
    );
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
    if (date != null && mounted) {
      setState(() => _expiryDate = date);
    }
  }

  Future<void> _pickExpiryTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _expiryTime ?? TimeOfDay.now(),
    );
    if (time != null && mounted) {
      setState(() => _expiryTime = time);
    }
  }

  DateTime? get _combinedExpiryDateTime {
    if (_expiryDate == null) return null;
    final t = _expiryTime ?? const TimeOfDay(hour: 23, minute: 59);
    return DateTime(
      _expiryDate!.year,
      _expiryDate!.month,
      _expiryDate!.day,
      t.hour,
      t.minute,
    );
  }

  // ── Validation ─────────────────────────────────────────────────────────

  String? _validate() {
    final addr = _recipientCtl.text.trim();
    if (!_looksLikeStellarPk(addr)) return 'Enter a valid Stellar address (G…)';

    final amt = double.tryParse(_amountCtl.text.trim()) ?? 0;
    if (amt <= 0) return 'Enter a valid amount';
    if (amt > _currentBal) return 'Amount exceeds $_tokenStr balance';

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
    if (existing != null) {
      return;
    }

    final saved = await showRecipientUpsertSheet(
      context,
      address: address,
    );

    if (saved == true && mounted) {
      showFloatingSnackBar(
        context,
        message: 'Recipient saved',
        type: SnackBarType.info,
      );
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final reason = _validate();
    if (reason != null) {
      showFloatingSnackBar(context,
          message: reason, type: SnackBarType.warning);
      return;
    }

    setState(() => _submitting = true);

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
        // ── Instant, no expiry (original) ──────────────────────────────
        txHash = await vm.createUnconditional(
          isXlm: _isXlm,
          amount: amt,
          recipientId: addr,
        );
      } else if (_mode == ClaimableMode.unconditional && _hasExpiry) {
        // ── Instant with expiry ────────────────────────────────────────
        txHash = await vm.createUnconditionalWithExpiry(
          isXlm: _isXlm,
          amount: amt,
          recipientId: addr,
          expiryTime: _combinedExpiryDateTime!,
        );
      } else if (_mode == ClaimableMode.timeLocked && !_hasExpiry) {
        // ── Time-locked, no expiry (original) ──────────────────────────
        txHash = await vm.createTimeLocked(
          isXlm: _isXlm,
          amount: amt,
          recipientId: addr,
          unlockTime: _combinedUnlockDateTime!,
        );
      } else {
        // ── Time-locked with expiry ────────────────────────────────────
        txHash = await vm.createTimeLockedWithExpiry(
          isXlm: _isXlm,
          amount: amt,
          recipientId: addr,
          unlockTime: _combinedUnlockDateTime!,
          expiryTime: _combinedExpiryDateTime!,
        );
      }

      if (!mounted) return;
      HapticFeedback.mediumImpact();

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
      await _loadBalances();
    } catch (e) {
      if (!mounted) return;
      ctl.update(
        AppAlertType.error,
        title: 'Failed to create',
        subtitle: '$e',
        primaryText: 'Dismiss',
        onPrimary: ctl.close,
      );
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
          onSelect: (recipient) {
            Navigator.pop(context, recipient);
          },
        ),
      ),
    );
    if (selected != null && mounted) {
      _recipientCtl.text = selected.address;
      setState(() {});
    }
  }

  Future<void> _scanQR() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const ScannerScreen(),
      ),
    );

    if (result != null && mounted) {
      _recipientCtl.text = result.trim();
      setState(() {});
    }
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
        backgroundColor: c.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Create Claimable Balance',
            style: TextStyle(
                fontWeight: FontWeight.w700, color: c.textPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          _buildAssetToggle(c),
          const SizedBox(height: 14),
          _buildBalanceRow(c),
          const SizedBox(height: 14),
          _buildModeToggle(c),
          const SizedBox(height: 16),
          Form(
            key: _form,
            child: Column(
              children: [
                _buildRecipientField(c),
                const SizedBox(height: 14),
                _buildAmountField(c),

                // ── Unlock picker (time-locked only) ─────────────────────
                if (_mode == ClaimableMode.timeLocked) ...[
                  const SizedBox(height: 16),
                  _buildUnlockPicker(c),
                ],

                // ── Expiration toggle + picker (both modes) ──────────────
                const SizedBox(height: 16),
                _buildExpirySection(c),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildInfoCard(c),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(c),
    );
  }

  // ── Asset toggle ───────────────────────────────────────────────────────

  Widget _buildAssetToggle(AppColor c) {
    return Row(
      children: [
        Expanded(child: _assetChip(c, 'XLM', true)),
        const SizedBox(width: 10),
        Expanded(child: _assetChip(c, 'USDC', false)),
      ],
    );
  }

  Widget _assetChip(AppColor c, String label, bool isXlm) {
    final active = _isXlm == isXlm;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _isXlm = isXlm);
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: active
                ? c.primary.withValues(alpha: 0.1)
                : c.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active
                  ? c.primary.withValues(alpha: 0.4)
                  : c.border.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AssetLogo(keyOrSymbol: label, size: 20),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                    color: active ? c.primary : c.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  // ── Balance row ────────────────────────────────────────────────────────

  Widget _buildBalanceRow(AppColor c) {
    if (_loadingBal) {
      return Container(
        height: 48,
        decoration: BoxDecoration(
          color: c.primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: c.primary.withValues(alpha: 0.4)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.primary.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          AssetLogo(keyOrSymbol: _tokenStr, size: 18),
          const SizedBox(width: 10),
          Text('Available',
              style: TextStyle(color: c.textSecondary, fontSize: 13)),
          const Spacer(),
          Text(
            '${_currentBal.toStringAsFixed(_currentBal >= 100 ? 2 : 4)} $_tokenStr',
            style: TextStyle(
                color: c.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ── Mode toggle ────────────────────────────────────────────────────────

  Widget _buildModeToggle(AppColor c) {
    return Row(
      children: [
        Expanded(
            child: _modeChip(
                c, 'Instant', ClaimableMode.unconditional, LucideIcons.zap)),
        const SizedBox(width: 10),
        Expanded(
            child: _modeChip(
                c, 'Time-locked', ClaimableMode.timeLocked, LucideIcons.clock)),
      ],
    );
  }

  Widget _modeChip(
      AppColor c, String label, ClaimableMode mode, IconData icon) {
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
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active
                ? c.primary.withValues(alpha: 0.1)
                : c.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active
                  ? c.primary.withValues(alpha: 0.4)
                  : c.border.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: active ? c.primary : c.textSecondary),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    color: active ? c.primary : c.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  // ── Recipient field ────────────────────────────────────────────────────

  Widget _buildRecipientField(AppColor c) {
    return TextFormField(
      controller: _recipientCtl,
      textInputAction: TextInputAction.next,
      keyboardType: TextInputType.multiline,
      minLines: 1,
      maxLines: null,
      style: const TextStyle(
        fontSize: 12,
        height: 1.2,
        letterSpacing: 0.15,
        fontFeatures: [ui.FontFeature.tabularFigures()],
      ),
      decoration: modernInput(
        context,
        placeholder: 'Recipient Address (G… 56 chars)',
        prefix: Icon(LucideIcons.wallet, color: c.primary, size: 18),
      ).copyWith(
        isDense: true,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: _scanQR,
              icon: Icon(LucideIcons.qrCode, size: 16, color: c.primary),
              tooltip: 'Scan QR code',
            ),
            IconButton(
              onPressed: _selectRecipient,
              icon: Icon(LucideIcons.contact, size: 16, color: c.primary),
              tooltip: 'Select from saved recipients',
            ),
            if (_recipientCtl.text.trim().isNotEmpty)
              IconButton(
                onPressed: () {
                  _recipientCtl.clear();
                  setState(() {});
                },
                icon: const Icon(LucideIcons.x, size: 16),
              ),
          ],
        ),
      ),
      validator: (_) {
        final addr = _recipientCtl.text.trim();
        if (addr.isEmpty) return 'Required';
        if (!_looksLikeStellarPk(addr)) return 'Invalid Stellar address';
        return null;
      },
      onChanged: (_) => setState(() {}),
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
    );
  }

  // ── Amount field ───────────────────────────────────────────────────────

  Widget _buildAmountField(AppColor c) {
    return TextFormField(
      controller: _amountCtl,
      keyboardType:
      const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,7}$')),
      ],
      decoration: modernInput(
        context,
        placeholder: 'Amount ($_tokenStr)',
        prefix: Padding(
          padding: const EdgeInsets.all(8),
          child: AssetLogo(keyOrSymbol: _tokenStr, size: 18),
        ),
      ).copyWith(
        isDense: true,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        suffixIcon: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            final bal = _currentBal;
            final v = _isXlm && bal > 1 ? bal - 1 : bal;
            _amountCtl.text = v > 0
                ? v.toStringAsFixed(7).replaceFirst(RegExp(r'\.?0+$'), '')
                : '';
            _amountCtl.selection = TextSelection.fromPosition(
                TextPosition(offset: _amountCtl.text.length));
          },
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text('MAX',
                style: TextStyle(
                  color: c.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                )),
          ),
        ),
      ),
      validator: (_) {
        final amt = double.tryParse(_amountCtl.text.trim()) ?? 0;
        if (amt <= 0) return 'Enter amount';
        if (amt > _currentBal) return 'Exceeds balance';
        return null;
      },
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
    );
  }

  // ── Unlock picker (time-locked mode) ───────────────────────────────────

  Widget _buildUnlockPicker(AppColor c) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.calendarClock,
                  size: 16, color: c.primary),
              const SizedBox(width: 8),
              Text('Unlock schedule',
                  style: TextStyle(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _pickerButton(
                  c,
                  icon: LucideIcons.calendar,
                  label: _unlockDate != null
                      ? _dateFmt.format(_unlockDate!)
                      : 'Pick date',
                  onTap: _pickUnlockDate,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _pickerButton(
                  c,
                  icon: LucideIcons.clock,
                  label: _unlockTime != null
                      ? _unlockTime!.format(context)
                      : 'Pick time',
                  onTap: _pickUnlockTime,
                ),
              ),
            ],
          ),
          if (_combinedUnlockDateTime != null) ...[
            const SizedBox(height: 10),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: c.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.info, size: 13, color: c.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Recipient can claim after ${_dateFmt.format(_combinedUnlockDateTime!)} at ${_unlockTime?.format(context) ?? '12:00 AM'}',
                      style: TextStyle(
                          color: c.textSecondary, fontSize: 11.5),
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

  // ── Expiration section (both modes) ────────────────────────────────────

  Widget _buildExpirySection(AppColor c) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _hasExpiry
            ? c.warning.withValues(alpha: 0.03)
            : c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _hasExpiry
              ? c.warning.withValues(alpha: 0.15)
              : c.border.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toggle row
          Row(
            children: [
              Icon(
                LucideIcons.timerOff,
                size: 16,
                color: _hasExpiry ? c.warning : c.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Set expiration',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              SizedBox(
                height: 28,
                child: Switch.adaptive(
                  value: _hasExpiry,
                  activeColor: c.warning,
                  onChanged: (v) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _hasExpiry = v;
                      if (!v) {
                        _expiryDate = null;
                        _expiryTime = null;
                      }
                    });
                  },
                ),
              ),
            ],
          ),

          if (!_hasExpiry) ...[
            const SizedBox(height: 6),
            Text(
              'Without expiration, the balance stays claimable indefinitely.',
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ],

          if (_hasExpiry) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _pickerButton(
                    c,
                    icon: LucideIcons.calendar,
                    label: _expiryDate != null
                        ? _dateFmt.format(_expiryDate!)
                        : 'Expiry date',
                    onTap: _pickExpiryDate,
                    accentColor: c.warning,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _pickerButton(
                    c,
                    icon: LucideIcons.clock,
                    label: _expiryTime != null
                        ? _expiryTime!.format(context)
                        : 'Expiry time',
                    onTap: _pickExpiryTime,
                    accentColor: c.warning,
                  ),
                ),
              ],
            ),
            if (_combinedExpiryDateTime != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: c.warning.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.alertTriangle,
                        size: 13, color: c.warning),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'If unclaimed by ${_dateFmt.format(_combinedExpiryDateTime!)} at '
                            '${_expiryTime?.format(context) ?? '11:59 PM'}, '
                            'you can reclaim the funds.',
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
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

  Widget _pickerButton(
      AppColor c, {
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
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: c.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.border.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis),
              ),
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
      body = 'Funds are locked until the unlock time. '
          'The recipient can claim between the unlock and expiration dates. '
          'After expiry, you can reclaim the unclaimed balance.';
    } else if (isTimeLocked) {
      body = 'Funds are locked on the Stellar network until the unlock time. '
          'The recipient can claim them after that point. '
          'If unclaimed, you can reclaim the balance.';
    } else if (_hasExpiry) {
      body = 'The recipient can claim these funds immediately, '
          'but must do so before the expiration date. '
          'After expiry, you can reclaim the unclaimed balance.';
    } else {
      body = 'The recipient can claim these funds at any time. '
          'The balance is held on the Stellar network, not in their account, '
          'until they claim it.';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.primary.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.primary.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isTimeLocked
                    ? LucideIcons.shieldQuestion
                    : LucideIcons.info,
                size: 15,
                color: c.textSecondary,
              ),
              const SizedBox(width: 8),
              Text('How it works',
                  style: TextStyle(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom bar ─────────────────────────────────────────────────────────

  Widget _buildBottomBar(AppColor c) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        decoration: BoxDecoration(
          color: c.background,
          border: Border(
            top: BorderSide(color: c.border.withValues(alpha: 0.12)),
          ),
        ),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
                : const Icon(LucideIcons.send,
                size: 16, color: Colors.white),
            label: Text(
              _mode == ClaimableMode.timeLocked
                  ? 'Create Time-Locked Balance'
                  : 'Create Claimable Balance',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: Colors.white),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: c.primary,
              disabledBackgroundColor: c.primary.withValues(alpha: 0.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ),
    );
  }
}