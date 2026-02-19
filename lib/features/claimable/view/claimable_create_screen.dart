// lib/features/claimable/view/claimable_create_screen.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:next_fi/common/components/button/app_buttons.dart';
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

  const ClaimableCreateScreen({super.key, this.initialAsset = 'XLM'});

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

  bool _looksLikeStellarPk(String x) => RegExp(r'^G[A-Z2-7]{55}$').hasMatch(x);

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
    return DateTime(
      _unlockDate!.year,
      _unlockDate!.month,
      _unlockDate!.day,
      t.hour,
      t.minute,
    );
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
    return DateTime(
      _expiryDate!.year,
      _expiryDate!.month,
      _expiryDate!.day,
      t.hour,
      t.minute,
    );
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
      if (dt.isBefore(DateTime.now()))
        return 'Unlock time must be in the future';
    }

    if (_hasExpiry) {
      final dt = _combinedExpiryDateTime;
      if (dt == null) return 'Pick an expiry date';
      if (dt.isBefore(DateTime.now()))
        return 'Expiry time must be in the future';

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
      ctl.update(AppAlertType.error, title: 'Error', subtitle: e.toString());
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
            _buildModernHeader(c),
            Expanded(
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    const SizedBox(height: 20),
                    _buildModeCard(c),
                    const SizedBox(height: 20),
                    _buildAmountCard(c, currentBal),
                    const SizedBox(height: 20),
                    _buildRecipientCard(c),
                    if (_mode == ClaimableMode.timeLocked) ...[
                      const SizedBox(height: 20),
                      _buildUnlockCard(c),
                    ],
                    const SizedBox(height: 20),
                    _buildExpirationCard(c),
                    if (_mode == ClaimableMode.timeLocked || _hasExpiry) ...[
                      const SizedBox(height: 20),
                      _buildInfoCard(c),
                    ],
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildFloatingActionBar(c),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // MODERN HEADER
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildModernHeader(AppColor c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 12),
      decoration: BoxDecoration(
        color: c.background,
        border: Border(
          bottom: BorderSide(color: c.border.withOpacity(0.06), width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(LucideIcons.arrowLeft, color: c.textPrimary, size: 22),
            splashRadius: 22,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Claimable Balance',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Send crypto with conditions',
                  style: TextStyle(
                    color: c.textSecondary.withOpacity(0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
          AssetLogo(keyOrSymbol: _selectedAsset, size: 32),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // MODE SELECTOR CARD
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildModeCard(AppColor c) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark ? c.surface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: c.border.withOpacity(isDark ? 0.08 : 0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildModeOption(
              c,
              icon: LucideIcons.zap,
              label: 'Instant',
              subtitle: 'Claim anytime',
              isSelected: _mode == ClaimableMode.unconditional,
              onTap: () => setState(() => _mode = ClaimableMode.unconditional),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildModeOption(
              c,
              icon: LucideIcons.clock,
              label: 'Scheduled',
              subtitle: 'Time-locked',
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
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    c.primary.withOpacity(0.12),
                    c.primary.withOpacity(0.06),
                  ],
                )
              : null,
          color: isSelected
              ? null
              : (isDark ? c.background : c.surface.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? c.primary.withOpacity(0.3)
                : c.border.withOpacity(isDark ? 0.08 : 0.1),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? c.primary.withOpacity(0.15)
                    : c.textSecondary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected
                    ? c.primary
                    : c.textSecondary.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? c.primary : c.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: c.textSecondary.withOpacity(isSelected ? 0.7 : 0.5),
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // AMOUNT CARD
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildAmountCard(AppColor c, double currentBal) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? c.surface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: c.border.withOpacity(isDark ? 0.08 : 0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Amount',
                style: TextStyle(
                  color: c.textSecondary.withOpacity(0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  height: 1,
                ),
              ),
              const Spacer(),
              Icon(
                LucideIcons.wallet,
                size: 14,
                color: c.textSecondary.withOpacity(0.5),
              ),
              const SizedBox(width: 6),
              Text(
                '${currentBal.toStringAsFixed(2)} $_selectedAsset',
                style: TextStyle(
                  color: c.textSecondary.withOpacity(0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: _amountCtl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,7}$'),
                    ),
                  ],
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                    letterSpacing: -1.5,
                    height: 1.1,
                  ),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(
                      color: c.textSecondary.withOpacity(0.2),
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.5,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _selectedAsset,
                    style: TextStyle(
                      color: c.textSecondary.withOpacity(0.6),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _amountCtl.text = currentBal > 0
                          ? currentBal
                                .toStringAsFixed(7)
                                .replaceFirst(RegExp(r'\.?0+$'), '')
                          : '';
                      _amountCtl.selection = TextSelection.fromPosition(
                        TextPosition(offset: _amountCtl.text.length),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
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
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
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

  // ──────────────────────────────────────────────────────────────────────────
  // RECIPIENT CARD
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildRecipientCard(AppColor c) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final addr = _recipientCtl.text.trim();
    final hasValidAddr = _looksLikeStellarPk(addr);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? c.surface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: c.border.withOpacity(isDark ? 0.08 : 0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Recipient',
                style: TextStyle(
                  color: c.textSecondary.withOpacity(0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              _buildQuickActionButton(
                c,
                icon: LucideIcons.qrCode,
                onTap: _scanQR,
              ),
              const SizedBox(width: 8),
              _buildQuickActionButton(
                c,
                icon: LucideIcons.users,
                onTap: _selectRecipient,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_recipientLoading)
            _buildRecipientLoadingState(c)
          else if (hasValidAddr && _resolvedRecipient != null)
            _buildSavedRecipientChip(c, _resolvedRecipient!)
          else if (hasValidAddr && _resolvedRecipient == null)
            _buildNewRecipientChip(c, addr)
          else
            _buildRecipientInputField(c, addr, isDark),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(
    AppColor c, {
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? c.background : c.surface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: c.border.withOpacity(isDark ? 0.1 : 0.15),
            width: 1,
          ),
        ),
        child: Icon(icon, size: 18, color: c.primary.withOpacity(0.8)),
      ),
    );
  }

  Widget _buildRecipientLoadingState(AppColor c) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: c.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.primary.withOpacity(0.1), width: 1),
      ),
      child: Center(
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: c.primary.withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildSavedRecipientChip(AppColor c, RecipientAddressModel recipient) {
    final color = Color(recipient.color);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(isDark ? 0.2 : 0.15),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                recipient.name.isNotEmpty
                    ? recipient.name[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipient.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _shortenAddress(recipient.address),
                  style: TextStyle(
                    color: c.textSecondary.withOpacity(0.6),
                    fontFamily: 'monospace',
                    fontSize: 12,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _editRecipient,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(LucideIcons.pencil, size: 16, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewRecipientChip(AppColor c, String addr) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? c.background : c.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: c.border.withOpacity(isDark ? 0.12 : 0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: c.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              LucideIcons.userPlus,
              size: 18,
              color: c.primary.withOpacity(0.7),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New address',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _shortenAddress(addr),
                  style: TextStyle(
                    color: c.textSecondary.withOpacity(0.6),
                    fontFamily: 'monospace',
                    fontSize: 12,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              final saved = await showRecipientUpsertSheet(
                context,
                address: addr,
              );
              if (saved == true && mounted) _lookupRecipient(addr);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: c.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Save',
                style: TextStyle(
                  color: c.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientInputField(AppColor c, String addr, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? c.background : c.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: c.border.withOpacity(isDark ? 0.12 : 0.2),
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
          hintText: 'Paste or enter Stellar address',
          hintStyle: TextStyle(
            color: c.textSecondary.withOpacity(0.4),
            fontSize: 14,
            letterSpacing: -0.2,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Icon(
              LucideIcons.wallet,
              color: c.textSecondary.withOpacity(0.5),
              size: 18,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0),
          suffixIcon: addr.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    onPressed: () {
                      _recipientCtl.clear();
                      setState(() => _resolvedRecipient = null);
                    },
                    icon: Icon(
                      LucideIcons.x,
                      size: 18,
                      color: c.textSecondary.withOpacity(0.5),
                    ),
                    splashRadius: 20,
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        onChanged: (_) => setState(() {}),
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // UNLOCK SCHEDULE CARD
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildUnlockCard(AppColor c) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? c.surface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: c.border.withOpacity(isDark ? 0.08 : 0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
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
                'Unlock schedule',
                style: TextStyle(
                  color: c.textSecondary.withOpacity(0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDateTimePicker(c, isDate: true, isUnlock: true),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDateTimePicker(c, isDate: false, isUnlock: true),
              ),
            ],
          ),
          if (_combinedUnlockDateTime != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: c.primary.withOpacity(0.15),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.checkCircle2,
                    size: 16,
                    color: c.primary.withOpacity(0.7),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Unlocks ${_dateFmt.format(_combinedUnlockDateTime!)} at ${_unlockTime?.format(context) ?? '12:00 AM'}',
                      style: TextStyle(
                        color: c.textPrimary.withOpacity(0.85),
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
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // EXPIRATION CARD
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildExpirationCard(AppColor c) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? c.surface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: c.border.withOpacity(isDark ? 0.08 : 0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
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
                  'Add expiration',
                  style: TextStyle(
                    color: c.textSecondary.withOpacity(0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Transform.scale(
                scale: 0.85,
                child: Switch(
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
          if (_hasExpiry) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDateTimePicker(c, isDate: true, isUnlock: false),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildDateTimePicker(
                    c,
                    isDate: false,
                    isUnlock: false,
                  ),
                ),
              ],
            ),
            if (_combinedExpiryDateTime != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.warning.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: c.warning.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.alertTriangle,
                      size: 16,
                      color: c.warning.withOpacity(0.7),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Reclaimable after ${_dateFmt.format(_combinedExpiryDateTime!)} at ${_expiryTime?.format(context) ?? '11:59 PM'}',
                        style: TextStyle(
                          color: c.textPrimary.withOpacity(0.85),
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
      ),
    );
  }

  Widget _buildDateTimePicker(
    AppColor c, {
    required bool isDate,
    required bool isUnlock,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final icon = isDate ? LucideIcons.calendar : LucideIcons.clock;
    final color = isUnlock ? c.primary : c.warning;
    final value = isDate
        ? (isUnlock ? _unlockDate : _expiryDate)
        : (isUnlock ? _unlockTime : _expiryTime);
    final text = isDate
        ? (value != null ? _dateFmt.format(value as DateTime) : 'Select date')
        : (value != null
              ? (value as TimeOfDay).format(context)
              : 'Select time');

    final onTap = isDate
        ? (isUnlock ? _pickUnlockDate : _pickExpiryDate)
        : (isUnlock ? _pickUnlockTime : _pickExpiryTime);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? c.background : c.surface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: value != null
                ? color.withOpacity(isDark ? 0.25 : 0.2)
                : c.border.withOpacity(isDark ? 0.12 : 0.2),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: value != null
                  ? color.withOpacity(0.8)
                  : c.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: value != null
                      ? c.textPrimary
                      : c.textSecondary.withOpacity(0.5),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // INFO CARD
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildInfoCard(AppColor c) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTimeLocked = _mode == ClaimableMode.timeLocked;

    String message;
    if (isTimeLocked && _hasExpiry) {
      message =
          'Funds locked until unlock time. Recipient can claim between unlock and expiry. You can reclaim after expiry if unclaimed.';
    } else if (isTimeLocked) {
      message =
          'Funds locked until unlock time. Recipient can claim anytime after that.';
    } else if (_hasExpiry) {
      message =
          'Recipient can claim immediately but must do so before expiry. You can reclaim if unclaimed.';
    } else {
      message =
          'Recipient can claim anytime. Balance held on Stellar network until claimed.';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? c.surface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: c.border.withOpacity(isDark ? 0.08 : 0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.15)
                : Colors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 3),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: c.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              LucideIcons.info,
              size: 16,
              color: c.primary.withOpacity(0.8),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: c.textSecondary.withOpacity(0.8),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.5,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // FLOATING ACTION BAR
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildFloatingActionBar(AppColor c) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? c.surface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: c.border.withOpacity(isDark ? 0.1 : 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.4)
                : Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, -4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: AppElevatedButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              _submit();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: c.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
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
