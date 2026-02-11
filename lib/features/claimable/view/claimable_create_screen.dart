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
import 'package:next_fi/common/components/modal/recipient_upsert_sheet.dart';

import 'package:next_fi/features/claimable/model/claimable_item.dart';
import 'package:next_fi/features/claimable/view_model/claimable_vm.dart';
import 'package:next_fi/features/wallet_home/view_model/recipient_address_vm.dart';
import 'package:next_fi/features/wallet_home/model/recipient_address_model.dart';
import 'package:next_fi/features/wallet_home/view/widgets/recipient_list_widget.dart';
import 'package:next_fi/features/scanner/view/scanner_screen.dart';

import 'package:next_fi/features/send/view/widgets/recipient_badge.dart';
import 'package:next_fi/features/send/view/widgets/recipient_add_template.dart';
import 'package:next_fi/features/send/view/widgets/recipient_loading_line.dart';

class ClaimableCreateScreen extends StatefulWidget {
  final String initialAsset;

  const ClaimableCreateScreen({
    super.key,
    this.initialAsset = 'XLM',
  });

  @override
  State<ClaimableCreateScreen> createState() => _ClaimableCreateScreenState();
}

class _ClaimableCreateScreenState extends State<ClaimableCreateScreen> {
  final _form = GlobalKey<FormState>();
  final _recipientCtl = TextEditingController();
  final _amountCtl = TextEditingController();

  late String _selectedAsset;

  ClaimableMode _mode = ClaimableMode.unconditional;

  DateTime? _unlockDate;
  TimeOfDay? _unlockTime;

  bool _hasExpiry = false;
  DateTime? _expiryDate;
  TimeOfDay? _expiryTime;

  bool _recipientLoading = false;
  RecipientAddressModel? _resolvedRecipient;

  static final _dateFmt = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    _selectedAsset = widget.initialAsset;
    _recipientCtl.addListener(_onRecipientChanged);
  }

  @override
  void dispose() {
    _recipientCtl.removeListener(_onRecipientChanged);
    _recipientCtl.dispose();
    _amountCtl.dispose();
    super.dispose();
  }

  bool _looksLikeStellarPk(String x) =>
      RegExp(r'^G[A-Z2-7]{55}$').hasMatch(x);

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
      final dt = _combinedExpiryDateTime;
      if (dt == null) return 'Pick an expiry date';
      if (dt.isBefore(DateTime.now())) return 'Expiry time must be in the future';

      if (_mode == ClaimableMode.timeLocked) {
        final unlock = _combinedUnlockDateTime;
        if (unlock != null && !dt.isAfter(unlock)) {
          return 'Expiry must be after unlock time';
        }
      }
    }

    return null;
  }

  Future<void> _submit() async {
    final err = _validate();
    if (err != null) {
      showAppAlert(
        context,
        type: AppAlertType.error,
        title: 'Validation Error',
        subtitle: err,
      );
      return;
    }

    final ctl = showAppAlert(
      context,
      type: AppAlertType.loading,
      title: 'Creating Balance',
      subtitle: 'Please wait while we process your transaction...',
      barrierDismissible: false,
    );

    try {
      final vm = context.read<ClaimableVM>();
      final addr = _recipientCtl.text.trim();
      final amt = double.parse(_amountCtl.text.trim());

      String txHash;

      if (_mode == ClaimableMode.timeLocked && _hasExpiry) {
        txHash = await vm.createTimeLockedWithExpiry(
          assetSymbol: _selectedAsset,
          amount: amt,
          recipientId: addr,
          unlockTime: _combinedUnlockDateTime!,
          expiryTime: _combinedExpiryDateTime!,
        );
      } else if (_mode == ClaimableMode.timeLocked) {
        txHash = await vm.createTimeLocked(
          assetSymbol: _selectedAsset,
          amount: amt,
          recipientId: addr,
          unlockTime: _combinedUnlockDateTime!,
        );
      } else if (_hasExpiry) {
        txHash = await vm.createUnconditionalWithExpiry(
          assetSymbol: _selectedAsset,
          amount: amt,
          recipientId: addr,
          expiryTime: _combinedExpiryDateTime!,
        );
      } else {
        txHash = await vm.createUnconditional(
          assetSymbol: _selectedAsset,
          amount: amt,
          recipientId: addr,
        );
      }

      if (!mounted) return;

      ctl.update(
        AppAlertType.success,
        title: 'Balance Created',
        subtitle: 'Claimable balance created successfully',
        onPrimary: () => Navigator.pop(context, true),
      );
    } catch (e) {
      if (!mounted) return;
      ctl.update(
        AppAlertType.error,
        title: 'Error',
        subtitle: e.toString(),
      );
    }
  }

  Future<void> _scanQR() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (result != null && mounted) {
      _recipientCtl.text = result;
      _lookupRecipient(result);
    }
  }

  Future<void> _selectRecipient() async {
    final c = AppColor.of(context);
    final selected = await Navigator.push<RecipientAddressModel>(
      context,
      MaterialPageRoute(
        builder: (_) => RecipientListWidget(
          colors: c,
          onSelect: (recipient) {
            Navigator.pop(context, recipient);
          },
        ),
      ),
    );
    if (selected != null && mounted) {
      _recipientCtl.text = selected.address;
      setState(() => _resolvedRecipient = selected);
    }
  }

  Future<void> _editRecipient() async {
    if (_resolvedRecipient == null) return;
    final saved = await showRecipientUpsertSheet(
      context,
      initial: _resolvedRecipient,
    );
    if (saved == true && mounted) {
      _lookupRecipient(_recipientCtl.text.trim());
    }
  }

  String _shortenAddress(String addr) {
    if (addr.length <= 16) return addr;
    return '${addr.substring(0, 6)}…${addr.substring(addr.length - 6)}';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final vm = context.watch<ClaimableVM>();
    final currentBal = vm.getBalanceForSymbol(_selectedAsset);
    final addr = _recipientCtl.text.trim();
    final hasValidAddr = _looksLikeStellarPk(addr);
    final isTimeLocked = _mode == ClaimableMode.timeLocked;

    String infoBody;
    if (isTimeLocked && _hasExpiry) {
      infoBody = 'Funds locked until unlock time. Recipient can claim between unlock and expiry. You can reclaim after expiry if unclaimed.';
    } else if (isTimeLocked) {
      infoBody = 'Funds locked until unlock time. Recipient can claim anytime after that with no expiration.';
    } else if (_hasExpiry) {
      infoBody = 'Recipient can claim immediately but must claim before expiry. You can reclaim after expiry if unclaimed.';
    } else {
      infoBody = 'Recipient can claim anytime. Balance held on Stellar network until claimed. No time limits.';
    }

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(c),
            Expanded(
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildModeSelector(c),
                    const SizedBox(height: 24),
                    _buildRecipientField(c, hasValidAddr, addr),
                    const SizedBox(height: 24),
                    _buildAmountField(c, currentBal),
                    if (_mode == ClaimableMode.timeLocked) ...[
                      const SizedBox(height: 24),
                      _buildUnlockSchedule(c),
                    ],
                    const SizedBox(height: 24),
                    _buildExpirationSection(c),
                    const SizedBox(height: 24),
                    _buildInfoCard(c, infoBody, isTimeLocked),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(c),
    );
  }

  Widget _buildAppBar(AppColor c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: c.background,
        border: Border(
          bottom: BorderSide(
            color: c.border.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(LucideIcons.arrowLeft, color: c.textPrimary),
            iconSize: 24,
          ),
          Expanded(
            child: Text(
              'Create Claimable Balance',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector(AppColor c) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: c.border.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _modeButton(
              c,
              LucideIcons.zap,
              'Instant',
              _mode == ClaimableMode.unconditional,
                  () => setState(() => _mode = ClaimableMode.unconditional),
            ),
          ),
          Expanded(
            child: _modeButton(
              c,
              LucideIcons.clock,
              'Time-Locked',
              _mode == ClaimableMode.timeLocked,
                  () => setState(() => _mode = ClaimableMode.timeLocked),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeButton(AppColor c, IconData icon, String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? c.background : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: selected
              ? Border.all(color: c.primary.withOpacity(0.15), width: 1)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? c.primary : c.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? c.textPrimary : c.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipientField(AppColor c, bool hasValidAddr, String addr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'Recipient',
            style: TextStyle(
              color: c.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
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
            Container(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: c.border.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: TextFormField(
                controller: _recipientCtl,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.multiline,
                minLines: 1,
                maxLines: null,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: c.textPrimary,
                  fontFeatures: const [ui.FontFeature.tabularFigures()],
                ),
                decoration: InputDecoration(
                  hintText: 'Stellar address (G… 56 chars)',
                  hintStyle: TextStyle(
                    color: c.textSecondary.withOpacity(0.4),
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(LucideIcons.user, color: c.primary, size: 18),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: _scanQR,
                        icon: Icon(LucideIcons.qrCode, size: 18, color: c.primary),
                        tooltip: 'Scan QR',
                      ),
                      IconButton(
                        onPressed: _selectRecipient,
                        icon: Icon(LucideIcons.contact, size: 18, color: c.primary),
                        tooltip: 'Select',
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
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onChanged: (_) => setState(() {}),
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
              ),
            ),
      ],
    );
  }

  Widget _buildAmountField(AppColor c, double currentBal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Amount',
                style: TextStyle(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                'Balance: ${currentBal.toStringAsFixed(2)} $_selectedAsset',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: c.border.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: TextFormField(
            controller: _amountCtl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,7}$')),
            ],
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: '0.00',
              hintStyle: TextStyle(
                color: c.textSecondary.withOpacity(0.3),
                fontSize: 16,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: AssetLogo(keyOrSymbol: _selectedAsset, size: 22),
              ),
              suffixIcon: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _amountCtl.text = currentBal > 0
                      ? currentBal.toStringAsFixed(7).replaceFirst(RegExp(r'\.?0+$'), '')
                      : '';
                  _amountCtl.selection = TextSelection.fromPosition(
                    TextPosition(offset: _amountCtl.text.length),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  margin: const EdgeInsets.only(right: 10, top: 10, bottom: 10),
                  decoration: BoxDecoration(
                    color: c.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: c.primary.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'MAX',
                    style: TextStyle(
                      color: c.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
          ),
        ),
      ],
    );
  }

  Widget _buildUnlockSchedule(AppColor c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: c.border.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: c.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(LucideIcons.lock, size: 14, color: c.primary),
              ),
              const SizedBox(width: 10),
              Text(
                'Unlock Schedule',
                style: TextStyle(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _pickUnlockDate,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: c.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: c.border.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.calendar, size: 14, color: c.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _unlockDate != null
                                ? _dateFmt.format(_unlockDate!)
                                : 'Select date',
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: _pickUnlockTime,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: c.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: c.border.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.clock, size: 14, color: c.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _unlockTime != null
                                ? _unlockTime!.format(context)
                                : 'Select time',
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_combinedUnlockDateTime != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: c.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.info, size: 12, color: c.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Unlocks on ${_dateFmt.format(_combinedUnlockDateTime!)} at ${_unlockTime?.format(context) ?? '12:00 AM'}',
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 12,
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

  Widget _buildExpirationSection(AppColor c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: c.border.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: c.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(LucideIcons.clock3, size: 14, color: c.warning),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Expiration',
                      style: TextStyle(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _hasExpiry,
                activeColor: c.warning,
                onChanged: (v) {
                  setState(() {
                    _hasExpiry = v;
                    if (!v) {
                      _expiryDate = null;
                      _expiryTime = null;
                    }
                  });
                },
              ),
            ],
          ),
          if (!_hasExpiry) ...[
            const SizedBox(height: 10),
            Text(
              'No expiration - claimable indefinitely',
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
          if (_hasExpiry) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _pickExpiryDate,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: c.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: c.border.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(LucideIcons.calendar, size: 14, color: c.warning),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _expiryDate != null
                                  ? _dateFmt.format(_expiryDate!)
                                  : 'Select date',
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _pickExpiryTime,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: c.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: c.border.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(LucideIcons.clock, size: 14, color: c.warning),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _expiryTime != null
                                  ? _expiryTime!.format(context)
                                  : 'Select time',
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_combinedExpiryDateTime != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: c.warning.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.alertCircle, size: 12, color: c.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Reclaimable after ${_dateFmt.format(_combinedExpiryDateTime!)} at ${_expiryTime?.format(context) ?? '11:59 PM'}',
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 12,
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

  Widget _buildInfoCard(AppColor c, String infoBody, bool isTimeLocked) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: c.primary.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: c.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isTimeLocked ? LucideIcons.shieldCheck : LucideIcons.info,
              size: 14,
              color: c.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How it works',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  infoBody,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(AppColor c) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: c.background,
          border: Border(
            top: BorderSide(
              color: c.border.withOpacity(0.1),
              width: 1,
            ),
          ),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: c.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.send, size: 16),
                const SizedBox(width: 10),
                Text(
                  _mode == ClaimableMode.timeLocked
                      ? 'Create Time-Locked Balance'
                      : 'Create Claimable Balance',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}