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
import 'package:next_fi/services/federation_address/federation_address_core_service.dart';
import 'package:next_fi/services/federation_address/models/federation_address_models.dart';

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
  bool _federationLoading = false;
  FederationResolveResponse? _resolvedFederation;
  String? _federationError;
  int _federationResolveSeq = 0;
  final String _federationDomain = FederationAddressCoreService.defaultDomain;
  List<String> _federationSuggestions = const [];

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
  bool _looksLikeFederation(String x) =>
      RegExp(r'^[^*\s]+\*[^*\s]+$').hasMatch(x);
  bool _looksLikeFederationAliasInput(String x) =>
      RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(x);

  void _onRecipientChanged() {
    final addr = _recipientCtl.text.trim();

    if (addr.isEmpty) {
      setState(() {
        _resolvedRecipient = null;
        _recipientLoading = false;
        _resolvedFederation = null;
        _federationError = null;
        _federationLoading = false;
        _federationSuggestions = const [];
      });
      return;
    }

    if (_looksLikeStellarPk(addr)) {
      setState(() {
        _resolvedFederation = null;
        _federationError = null;
        _federationLoading = false;
        _federationSuggestions = const [];
      });
      _lookupRecipient(addr);
      return;
    }

    if (_looksLikeFederation(addr)) {
      setState(() {
        _resolvedRecipient = null;
        _federationSuggestions = const [];
      });
      _resolveFederation(addr);
      return;
    }

    _updateFederationSuggestions(addr);
    setState(() {
      _resolvedRecipient = null;
      _recipientLoading = false;
      _resolvedFederation = null;
      _federationError = null;
      _federationLoading = false;
    });
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

  Future<void> _resolveFederation(String federationAddress) async {
    final requestId = ++_federationResolveSeq;

    setState(() {
      _federationLoading = true;
      _federationError = null;
      _resolvedFederation = null;
      _recipientLoading = true;
      _resolvedRecipient = null;
    });

    try {
      final resolved = await FederationAddressCoreService.I.resolveByName(
        federationAddress,
        domain: _federationDomain,
      );
      if (!mounted || requestId != _federationResolveSeq) return;

      final accountId = resolved.accountId.trim();
      if (accountId.isEmpty || !_looksLikeStellarPk(accountId)) {
        throw StateError('Resolved federation has no valid Stellar account id');
      }

      setState(() {
        _resolvedFederation = resolved;
        _federationLoading = false;
      });
      await _lookupRecipient(accountId);
    } catch (_) {
      if (!mounted || requestId != _federationResolveSeq) return;
      setState(() {
        _federationLoading = false;
        _recipientLoading = false;
        _resolvedFederation = null;
        _federationError = 'Federation not found or unavailable.';
      });
    }
  }

  void _updateFederationSuggestions(String input) {
    final domain = _federationDomain.trim();
    if (domain.isEmpty ||
        input.isEmpty ||
        input.contains('*') ||
        !_looksLikeFederationAliasInput(input)) {
      if (_federationSuggestions.isNotEmpty) {
        setState(() => _federationSuggestions = const []);
      }
      return;
    }

    final candidate = '${input.toLowerCase()}*$domain';
    if (_federationSuggestions.length == 1 &&
        _federationSuggestions.first == candidate) {
      return;
    }
    setState(() => _federationSuggestions = [candidate]);
  }

  void _applyFederationSuggestion(String value) {
    _recipientCtl.text = value;
    _recipientCtl.selection = TextSelection.fromPosition(
      TextPosition(offset: _recipientCtl.text.length),
    );
  }

  String? _resolvedRecipientAddressForSubmit() {
    final input = _recipientCtl.text.trim();
    if (_looksLikeStellarPk(input)) return input;
    if (_looksLikeFederation(input)) {
      final resolved = _resolvedFederation?.accountId.trim();
      if (resolved != null && _looksLikeStellarPk(resolved)) return resolved;
    }
    return null;
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
    final addr = _resolvedRecipientAddressForSubmit();
    if (addr == null) {
      return 'Enter a valid Stellar address or federation address.';
    }

    final amt = double.tryParse(_amountCtl.text.trim()) ?? 0;
    if (amt <= 0) return 'Enter a valid amount';

    final vm = context.read<ClaimableVM>();
    if (!vm.hasSufficientBalance(_selectedAsset, amt)) {
      return 'Insufficient $_selectedAsset balance';
    }

    if (_mode == ClaimableMode.timeLocked) {
      final dt = _combinedUnlockDateTime;
      if (dt == null) return 'Pick an unlock date';
      if (dt.isBefore(DateTime.now())) {
        return 'Unlock time must be in the future';
      }
    }

    if (_hasExpiry) {
      final dt = _combinedExpiryDateTime;
      if (dt == null) return 'Pick an expiry date';
      if (dt.isBefore(DateTime.now())) {
        return 'Expiry time must be in the future';
      }

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
      final addr = _resolvedRecipientAddressForSubmit();
      if (addr == null) {
        throw StateError('Recipient must resolve to a valid Stellar account.');
      }
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
        subtitle: 'Claimable balance created successfully\n$txHash',
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
      _onRecipientChanged();
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
      setState(() {
        _resolvedRecipient = selected;
        _resolvedFederation = null;
        _federationError = null;
        _federationLoading = false;
        _federationSuggestions = const [];
      });
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
    return '${addr.substring(0, 6)}...${addr.substring(addr.length - 6)}';
  }

  Color _blend(Color base, Color accent, double amount) =>
      Color.lerp(base, accent, amount) ?? base;

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
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                  children: [
                    const SizedBox(height: 12),
                    _buildModeCard(c),
                    const SizedBox(height: 16),
                    _buildAmountCard(c, currentBal),
                    const SizedBox(height: 16),
                    _buildRecipientCard(c),
                    if (_mode == ClaimableMode.timeLocked) ...[
                      const SizedBox(height: 16),
                      _buildUnlockCard(c),
                    ],
                    const SizedBox(height: 16),
                    _buildExpirationCard(c),
                    if (_mode == ClaimableMode.timeLocked || _hasExpiry) ...[
                      const SizedBox(height: 16),
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

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // MODERN HEADER
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildModernHeader(AppColor c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 24, 14),
      decoration: BoxDecoration(
        color: c.background,
        border: Border(bottom: BorderSide(color: c.border, width: 1)),
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
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Send crypto with conditions',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 13,
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

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // MODE SELECTOR CARD
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildModeCard(AppColor c) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? c.surface : c.onPrimary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border, width: 1),
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
          const SizedBox(width: 8),
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
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? c.primary : (isDark ? c.background : c.surface),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? c.primary : c.border,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? _blend(c.primary, c.surface, 0.22)
                    : _blend(c.surface, c.textSecondary, 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected ? c.onPrimary : c.textSecondary,
              ),
            ),
            const SizedBox(height: 11),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? c.onPrimary : c.textPrimary,
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected ? c.onPrimary : c.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // AMOUNT CARD
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildAmountCard(AppColor c, double currentBal) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? c.surface : c.onPrimary,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Amount',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  height: 1,
                ),
              ),
              const Spacer(),
              Icon(LucideIcons.wallet, size: 14, color: c.textSecondary),
              const SizedBox(width: 6),
              Text(
                '${currentBal.toStringAsFixed(2)} $_selectedAsset',
                style: TextStyle(
                  color: c.textSecondary,
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
                      color: c.border,
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
                      color: c.textSecondary,
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
                        color: _blend(c.surface, c.primary, 0.16),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: c.primary, width: 1),
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

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // RECIPIENT CARD
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildRecipientCard(AppColor c) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final addr = _recipientCtl.text.trim();
    final resolvedAccountId = _resolvedFederation?.accountId.trim();
    final hasValidAddr =
        _looksLikeStellarPk(addr) ||
        (_looksLikeFederation(addr) &&
            resolvedAccountId != null &&
            _looksLikeStellarPk(resolvedAccountId));
    final hasFederationInput = _looksLikeFederation(addr);
    final recipientLookupAddress = _looksLikeStellarPk(addr)
        ? addr
        : (resolvedAccountId ?? addr);
    final isLoadingRecipient = _recipientLoading || _federationLoading;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? c.surface : c.onPrimary,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Recipient',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 13.5,
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
          if (isLoadingRecipient)
            _buildRecipientLoadingState(c)
          else if (hasValidAddr && _resolvedRecipient != null)
            _buildSavedRecipientChip(c, _resolvedRecipient!)
          else if (hasValidAddr && _resolvedRecipient == null)
            _buildNewRecipientChip(c, recipientLookupAddress)
          else
            _buildRecipientInputField(c, addr, isDark),
          if (_federationSuggestions.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildFederationSuggestions(c),
          ],
          if (hasFederationInput) ...[
            const SizedBox(height: 10),
            _buildFederationStatus(c),
          ],
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
          color: isDark ? c.background : c.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.border, width: 1),
        ),
        child: Icon(icon, size: 18, color: c.primary),
      ),
    );
  }

  Widget _buildRecipientLoadingState(AppColor c) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: _blend(c.surface, c.primary, 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.primary, width: 1.2),
      ),
      child: Center(
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: c.primary),
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
        color: _blend(isDark ? c.background : c.surface, color, 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _blend(c.border, color, 0.7), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _blend(c.surface, color, 0.22),
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
                    color: c.textSecondary,
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
                color: _blend(c.surface, color, 0.22),
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
        color: isDark ? c.background : c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _blend(c.surface, c.primary, 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(LucideIcons.userPlus, size: 18, color: c.primary),
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
                    color: c.textSecondary,
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
                color: c.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Save',
                style: TextStyle(
                  color: c.onPrimary,
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
        color: isDark ? c.background : c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border, width: 1.5),
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
          hintText: 'Paste G... or alias*$_federationDomain',
          hintStyle: TextStyle(
            color: c.textSecondary,
            fontSize: 14,
            letterSpacing: -0.2,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Icon(LucideIcons.wallet, color: c.textSecondary, size: 18),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0),
          suffixIcon: addr.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    onPressed: () {
                      _recipientCtl.clear();
                      setState(() {
                        _resolvedRecipient = null;
                        _resolvedFederation = null;
                        _federationError = null;
                        _federationLoading = false;
                        _federationSuggestions = const [];
                      });
                    },
                    icon: Icon(LucideIcons.x, size: 18, color: c.textSecondary),
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

  Widget _buildFederationSuggestions(AppColor c) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _federationSuggestions
          .map(
            (s) => ActionChip(
              avatar: Icon(LucideIcons.atSign, size: 14, color: c.primary),
              label: Text(s),
              labelStyle: TextStyle(
                color: c.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
              side: BorderSide(color: c.primary),
              backgroundColor: _blend(c.surface, c.primary, 0.12),
              onPressed: () => _applyFederationSuggestion(s),
            ),
          )
          .toList(),
    );
  }

  Widget _buildFederationStatus(AppColor c) {
    if (_federationLoading) {
      return _buildFederationBanner(
        c,
        icon: null,
        title: 'Resolving federation address...',
        color: c.primary,
        showSpinner: true,
      );
    }

    if (_federationError != null) {
      return _buildFederationBanner(
        c,
        icon: LucideIcons.alertCircle,
        title: _federationError!,
        color: c.error,
      );
    }

    final resolved = _resolvedFederation;
    if (resolved != null && resolved.accountId.trim().isNotEmpty) {
      return _buildFederationBanner(
        c,
        icon: LucideIcons.checkCircle2,
        title: 'Resolved to ${_shortenAddress(resolved.accountId)}',
        subtitle: resolved.stellarAddress,
        color: c.success,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildFederationBanner(
    AppColor c, {
    required IconData? icon,
    required String title,
    required Color color,
    String? subtitle,
    bool showSpinner = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _blend(c.surface, color, 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _blend(c.border, color, 0.65), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showSpinner)
            SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else if (icon != null)
            Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
                if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle.trim(),
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // UNLOCK SCHEDULE CARD
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildUnlockCard(AppColor c) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? c.surface : c.onPrimary,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _blend(c.surface, c.primary, 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(LucideIcons.clock, size: 16, color: c.primary),
              ),
              const SizedBox(width: 12),
              Text(
                'Unlock schedule',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 13.5,
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
                color: _blend(c.surface, c.primary, 0.14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.primary, width: 1),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.checkCircle2, size: 16, color: c.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Unlocks ${_dateFmt.format(_combinedUnlockDateTime!)} at ${_unlockTime?.format(context) ?? '12:00 AM'}',
                      style: TextStyle(
                        color: c.textPrimary,
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

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // EXPIRATION CARD
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildExpirationCard(AppColor c) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? c.surface : c.onPrimary,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _blend(c.surface, c.warning, 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(LucideIcons.timerOff, size: 16, color: c.warning),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Add expiration',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 13.5,
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
                  color: _blend(c.surface, c.warning, 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.warning, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.alertTriangle, size: 16, color: c.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Reclaimable after ${_dateFmt.format(_combinedExpiryDateTime!)} at ${_expiryTime?.format(context) ?? '11:59 PM'}',
                        style: TextStyle(
                          color: c.textPrimary,
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
          color: isDark ? c.background : c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: value != null ? color : c.border,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: value != null ? color : c.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: value != null ? c.textPrimary : c.textSecondary,
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

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // INFO CARD
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
        color: isDark ? c.surface : c.onPrimary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _blend(c.surface, c.primary, 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(LucideIcons.info, size: 16, color: c.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: c.textSecondary,
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

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // FLOATING ACTION BAR
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildFloatingActionBar(AppColor c) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? c.surface : c.onPrimary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border, width: 1),
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
              foregroundColor: c.onPrimary,
              elevation: 0,
              shadowColor: c.surface,
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

