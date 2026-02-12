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

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(c),
            Expanded(
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  children: [
                    _buildModeSelector(c),
                    const SizedBox(height: 48),
                    _buildRecipientSection(c),
                    const SizedBox(height: 36),
                    _buildAmountSection(c, currentBal),
                    if (_mode == ClaimableMode.timeLocked) ...[
                      const SizedBox(height: 36),
                      _buildUnlockSection(c),
                    ],
                    const SizedBox(height: 36),
                    _buildExpirationSection(c),
                    if (_mode == ClaimableMode.timeLocked || _hasExpiry) ...[
                      const SizedBox(height: 28),
                      _buildInfoBanner(c),
                    ],
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

  Widget _buildHeader(AppColor c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 24, 16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(LucideIcons.arrowLeft, color: c.textPrimary, size: 24),
            splashRadius: 24,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Claimable Balance',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.8,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Send crypto with conditions',
                  style: TextStyle(
                    color: c.textSecondary.withOpacity(0.65),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector(AppColor c) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark ? c.surface.withOpacity(0.4) : c.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildModeOption(
              c,
              icon: LucideIcons.zap,
              label: 'Instant',
              isSelected: _mode == ClaimableMode.unconditional,
              onTap: () => setState(() => _mode = ClaimableMode.unconditional),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildModeOption(
              c,
              icon: LucideIcons.lock,
              label: 'Scheduled',
              isSelected: _mode == ClaimableMode.timeLocked,
              onTap: () => setState(() => _mode = ClaimableMode.timeLocked),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeOption(
      AppColor c, {
        required IconData icon,
        required String label,
        required bool isSelected,
        required VoidCallback onTap,
      }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? c.background : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.3)
                  : c.border.withOpacity(0.15),
              blurRadius: isDark ? 12 : 8,
              offset: const Offset(0, 2),
            ),
          ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: isSelected ? c.primary : c.textSecondary.withOpacity(0.65),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? c.textPrimary : c.textSecondary.withOpacity(0.65),
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipientSection(AppColor c) {
    final addr = _recipientCtl.text.trim();
    final hasValidAddr = _looksLikeStellarPk(addr);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: c.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(LucideIcons.userCheck, size: 16, color: c.primary),
            ),
            const SizedBox(width: 12),
            Text(
              'Recipient',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
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
            _buildRecipientInput(c, addr),
      ],
    );
  }

  Widget _buildRecipientInput(AppColor c, String addr) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? c.surface.withOpacity(0.5) : c.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? c.border.withOpacity(0.12) : c.border.withOpacity(0.15),
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: _recipientCtl,
        textInputAction: TextInputAction.next,
        keyboardType: TextInputType.multiline,
        minLines: 1,
        maxLines: null,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: c.textPrimary,
          letterSpacing: -0.3,
          fontFeatures: const [ui.FontFeature.tabularFigures()],
        ),
        decoration: InputDecoration(
          hintText: 'Enter address or select contact',
          hintStyle: TextStyle(
            color: c.textSecondary.withOpacity(0.4),
            fontSize: 14,
            letterSpacing: -0.2,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 18, right: 12),
            child: Icon(LucideIcons.user, color: c.textSecondary.withOpacity(0.5), size: 20),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0),
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: _scanQR,
                  icon: Icon(LucideIcons.qrCode, size: 20, color: c.primary.withOpacity(0.8)),
                  splashRadius: 20,
                ),
                IconButton(
                  onPressed: _selectRecipient,
                  icon: Icon(LucideIcons.contact, size: 20, color: c.primary.withOpacity(0.8)),
                  splashRadius: 20,
                ),
                if (addr.isNotEmpty)
                  IconButton(
                    onPressed: () {
                      _recipientCtl.clear();
                      setState(() => _resolvedRecipient = null);
                    },
                    icon: Icon(LucideIcons.x, size: 18, color: c.textSecondary.withOpacity(0.5)),
                    splashRadius: 20,
                  ),
              ],
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        ),
        onChanged: (_) => setState(() {}),
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
      ),
    );
  }

  Widget _buildAmountSection(AppColor c, double currentBal) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: c.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(LucideIcons.coins, size: 16, color: c.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Amount',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            Text(
              '${currentBal.toStringAsFixed(2)} $_selectedAsset',
              style: TextStyle(
                color: c.textSecondary.withOpacity(0.7),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: isDark ? c.surface.withOpacity(0.5) : c.surface.withOpacity(0.7),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? c.border.withOpacity(0.12) : c.border.withOpacity(0.15),
              width: 1.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 18, right: 14),
                child: AssetLogo(keyOrSymbol: _selectedAsset, size: 32),
              ),
              Expanded(
                child: TextField(
                  controller: _amountCtl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,7}$')),
                  ],
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                    letterSpacing: -0.8,
                    height: 1.2,
                  ),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: TextStyle(
                      color: c.textSecondary.withOpacity(0.25),
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 20),
                  ),
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: GestureDetector(
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          c.primary.withOpacity(isDark ? 0.2 : 0.15),
                          c.primary.withOpacity(isDark ? 0.12 : 0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: c.primary.withOpacity(isDark ? 0.25 : 0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'MAX',
                      style: TextStyle(
                        color: c.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUnlockSection(AppColor c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: c.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(LucideIcons.clock, size: 16, color: c.primary),
            ),
            const SizedBox(width: 12),
            Text(
              'Unlock Schedule',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildDateTimePicker(c, isDate: true, isUnlock: true)),
            const SizedBox(width: 12),
            Expanded(child: _buildDateTimePicker(c, isDate: false, isUnlock: true)),
          ],
        ),
        if (_combinedUnlockDateTime != null) ...[
          const SizedBox(height: 16),
          Container(
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
              children: [
                Icon(LucideIcons.checkCircle2, size: 16, color: c.primary.withOpacity(0.8)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Unlocks ${_dateFmt.format(_combinedUnlockDateTime!)} at ${_unlockTime?.format(context) ?? '12:00 AM'}',
                    style: TextStyle(
                      color: c.textSecondary.withOpacity(0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildExpirationSection(AppColor c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: c.warning.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(LucideIcons.timerOff, size: 16, color: c.warning),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Expiration',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            Transform.scale(
              scale: 0.9,
              child: Switch(
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
            ),
          ],
        ),
        if (_hasExpiry) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildDateTimePicker(c, isDate: true, isUnlock: false)),
              const SizedBox(width: 12),
              Expanded(child: _buildDateTimePicker(c, isDate: false, isUnlock: false)),
            ],
          ),
          if (_combinedExpiryDateTime != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: c.warning.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.alertTriangle, size: 16, color: c.warning.withOpacity(0.8)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Reclaimable after ${_dateFmt.format(_combinedExpiryDateTime!)} at ${_expiryTime?.format(context) ?? '11:59 PM'}',
                      style: TextStyle(
                        color: c.textSecondary.withOpacity(0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildDateTimePicker(AppColor c, {required bool isDate, required bool isUnlock}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final icon = isDate ? LucideIcons.calendar : LucideIcons.clock;
    final color = isUnlock ? c.primary : c.warning;
    final value = isDate
        ? (isUnlock ? _unlockDate : _expiryDate)
        : (isUnlock ? _unlockTime : _expiryTime);
    final text = isDate
        ? (value != null ? _dateFmt.format(value as DateTime) : 'Date')
        : (value != null ? (value as TimeOfDay).format(context) : 'Time');

    final onTap = isDate
        ? (isUnlock ? _pickUnlockDate : _pickExpiryDate)
        : (isUnlock ? _pickUnlockTime : _pickExpiryTime);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: isDark ? c.surface.withOpacity(0.5) : c.surface.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: value != null
                ? color.withOpacity(isDark ? 0.3 : 0.25)
                : (isDark ? c.border.withOpacity(0.12) : c.border.withOpacity(0.15)),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color.withOpacity(0.8)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: value != null ? c.textPrimary : c.textSecondary.withOpacity(0.5),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner(AppColor c) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTimeLocked = _mode == ClaimableMode.timeLocked;

    String message;
    if (isTimeLocked && _hasExpiry) {
      message = 'Funds locked until unlock time. Recipient can claim between unlock and expiry. You can reclaim after expiry if unclaimed.';
    } else if (isTimeLocked) {
      message = 'Funds locked until unlock time. Recipient can claim anytime after that.';
    } else if (_hasExpiry) {
      message = 'Recipient can claim immediately but must do so before expiry. You can reclaim if unclaimed.';
    } else {
      message = 'Recipient can claim anytime. Balance held on Stellar network until claimed.';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.surface.withOpacity(0.4),
            c.surface.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: c.primary.withOpacity(0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: c.primary.withOpacity(isDark ? 0.15 : 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              LucideIcons.info,
              size: 16,
              color: c.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: c.textSecondary.withOpacity(0.9),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.6,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(AppColor c) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      decoration: BoxDecoration(
        color: c.background,
        border: Border(
          top: BorderSide(
            color: isDark ? c.border.withOpacity(0.12) : c.border.withOpacity(0.1),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : c.border.withOpacity(0.08),
            blurRadius: isDark ? 24 : 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 58,
          child: ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: c.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.send, size: 20),
                const SizedBox(width: 12),
                Text(
                  _mode == ClaimableMode.timeLocked
                      ? 'Create Scheduled Balance'
                      : 'Create Balance',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
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