import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:next_fi/core/widgets/button/app_buttons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:next_fi/app/config/app_providers.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/core/recipient_input/recipient_flow_controller.dart';
import 'package:next_fi/core/widgets/asset/asset_logo.dart';
import 'package:next_fi/core/widgets/alert/app_alert.dart';
import 'package:next_fi/core/widgets/modal/recipient_upsert_sheet.dart';

import 'package:next_fi/features/claimable/data/models/claimable_item.dart';
import 'package:next_fi/features/contact/presentation/viewmodels/contact_list_notifier.dart';
import 'package:next_fi/features/contact/data/models/recipient_address_model.dart';
import 'package:next_fi/features/wallet_home/presentation/widgets/recipient_list_widget.dart';
import 'package:next_fi/features/scanner/presentation/screens/scanner_screen.dart';
import 'package:next_fi/core/services/federation_address/federation_address_core_service.dart';

class ClaimableCreateScreen extends ConsumerStatefulWidget {
  final String initialAsset;

  const ClaimableCreateScreen({super.key, this.initialAsset = 'XLM'});

  @override
  ConsumerState<ClaimableCreateScreen> createState() =>
      _ClaimableCreateScreenState();
}

class _ClaimableCreateScreenState extends ConsumerState<ClaimableCreateScreen> {
  final _form = GlobalKey<FormState>();
  final _publicAddressCtl = TextEditingController();
  final _federationCtl = TextEditingController();
  final _amountCtl = TextEditingController();

  late String _selectedAsset;

  ClaimableMode _mode = ClaimableMode.unconditional;

  DateTime? _unlockDate;
  TimeOfDay? _unlockTime;

  bool _hasExpiry = false;
  DateTime? _expiryDate;
  TimeOfDay? _expiryTime;

  late final RecipientFlowController _recipientFlow;
  late RecipientInputState _recipientState;
  final String _federationDomain = FederationAddressCoreService.defaultDomain;

  static final _dateFmt = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    _selectedAsset = widget.initialAsset;
    _recipientState = RecipientInputState.initial(
      federationDomain: _federationDomain,
    );
    _recipientFlow = RecipientFlowController(
      initialState: _recipientState,
      lookupRecipient: _lookupRecipientMatch,
      resolveFederation: (String federationAddress, {required String domain}) {
        return FederationAddressCoreService.I.resolveByName(
          federationAddress,
          domain: domain,
        );
      },
      onStateChanged: (RecipientInputState state) {
        if (!mounted) return;
        setState(() => _recipientState = state);
      },
    );
    _publicAddressCtl.addListener(() {
      _recipientFlow.setManualPublicAddress(_publicAddressCtl.text);
    });
    _federationCtl.addListener(() {
      _recipientFlow.setFederationInput(_federationCtl.text);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recipientFlow.initialize();
    });
  }

  @override
  void dispose() {
    _publicAddressCtl.dispose();
    _federationCtl.dispose();
    _amountCtl.dispose();
    super.dispose();
  }

  void _applyFederationSuggestion(String value) {
    _federationCtl.text = value;
    _federationCtl.selection = TextSelection.fromPosition(
      TextPosition(offset: _federationCtl.text.length),
    );
  }

  Future<RecipientAddressModel?> _lookupRecipientMatch(String address) async {
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      final notifier = container.read(contactListProvider.notifier);
      await notifier.ensureLoaded();
      return container.read(contactListProvider).byAddress(address);
    } catch (_) {
      return null;
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
    final addr = _recipientState.finalDestinationAddress;
    if (addr == null) {
      return 'Select or enter a valid recipient destination.';
    }

    final amt = double.tryParse(_amountCtl.text.trim()) ?? 0;
    if (amt <= 0) return 'Enter a valid amount';

    final vm = ref.read(claimableVmProvider);
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
      final vm = ref.read(claimableVmProvider);
      final addr = _recipientState.finalDestinationAddress;
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
      await _recipientFlow.setScannedValue(result);
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
      await _recipientFlow.selectSavedRecipient(selected);
    }
  }

  Future<void> _editRecipient() async {
    final recipient = _recipientState.activeRecipient;
    if (recipient == null) return;
    final saved = await showRecipientUpsertSheet(context, initial: recipient);
    if (saved == true && mounted) {
      await ref.read(contactListProvider.notifier).refresh();
      if (_recipientState.mode == RecipientInputMode.savedRecipient) {
        final updated = ref
            .read(contactListProvider)
            .byAddress(recipient.address.trim());
        await _recipientFlow.selectSavedRecipient(updated ?? recipient);
      } else {
        await _recipientFlow.initialize();
      }
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
    final vm = ref.watch(claimableVmProvider);
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
                  padding: const EdgeInsets.fromLTRB(22, 10, 22, 28),
                  children: [
                    const SizedBox(height: 8),
                    _buildSectionIntro(c, title: 'Mode'),
                    const SizedBox(height: 10),
                    _buildModeCard(c),
                    const SizedBox(height: 18),
                    _buildSectionIntro(c, title: 'Amount'),
                    const SizedBox(height: 10),
                    _buildAmountCard(c, currentBal),
                    const SizedBox(height: 18),
                    _buildSectionIntro(c, title: 'Recipient'),
                    const SizedBox(height: 10),
                    _buildRecipientCard(c),
                    if (_mode == ClaimableMode.timeLocked) ...[
                      const SizedBox(height: 18),
                      _buildSectionIntro(c, title: 'Unlock'),
                      const SizedBox(height: 10),
                      _buildUnlockCard(c),
                    ],
                    const SizedBox(height: 18),
                    _buildSectionIntro(c, title: 'Expiry'),
                    const SizedBox(height: 10),
                    _buildExpirationCard(c),
                    if (_mode == ClaimableMode.timeLocked || _hasExpiry) ...[
                      const SizedBox(height: 18),
                      _buildSectionIntro(c, title: 'Rules'),
                      const SizedBox(height: 10),
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

  Widget _buildModernHeader(AppColor c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 22, 14),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(
          bottom: BorderSide(color: c.border.withValues(alpha: 0.8), width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Create',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 12.8,
                    fontWeight: FontWeight.w600,
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

  Widget _buildSectionIntro(AppColor c, {required String title}) {
    return Text(
      title,
      style: TextStyle(
        color: c.textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.35,
      ),
    );
  }

  Widget _buildModeCard(AppColor c) {
    return Container(
      padding: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: c.border.withValues(alpha: 0.65), width: 1),
        ),
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

  Widget _buildAmountCard(AppColor c, double currentBal) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          bottom: BorderSide(color: c.border.withValues(alpha: 0.65), width: 1),
        ),
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

  Widget _buildRecipientCard(AppColor c) {
    final hasValidDestination =
        _recipientState.finalDestinationAddress != null &&
        RecipientInputParser.isStellarPublicAddress(
          _recipientState.finalDestinationAddress!,
        );
    final activeRecipient = _recipientState.activeRecipient;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          bottom: BorderSide(color: c.border.withValues(alpha: 0.65), width: 1),
        ),
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
          _buildRecipientModeSelector(c),
          const SizedBox(height: 16),
          if (_recipientState.mode == RecipientInputMode.savedRecipient)
            _buildSavedRecipientPanel(c)
          else if (_recipientState.mode == RecipientInputMode.scannedQr)
            _buildScannedRecipientPanel(c, activeRecipient, hasValidDestination)
          else if (_recipientState.mode == RecipientInputMode.publicAddress)
            _buildPublicAddressPanel(c, activeRecipient, hasValidDestination)
          else
            _buildFederationPanel(c, activeRecipient, hasValidDestination),
        ],
      ),
    );
  }

  Widget _buildRecipientModeSelector(AppColor c) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildRecipientModeChip(
          c,
          label: 'Saved',
          icon: LucideIcons.users,
          selected: _recipientState.mode == RecipientInputMode.savedRecipient,
          onTap: () =>
              _recipientFlow.switchMode(RecipientInputMode.savedRecipient),
        ),
        _buildRecipientModeChip(
          c,
          label: 'Scan',
          icon: LucideIcons.qrCode,
          selected: _recipientState.mode == RecipientInputMode.scannedQr,
          onTap: () async {
            await _recipientFlow.switchMode(RecipientInputMode.scannedQr);
            await _scanQR();
          },
        ),
        _buildRecipientModeChip(
          c,
          label: 'Address',
          icon: LucideIcons.wallet,
          selected: _recipientState.mode == RecipientInputMode.publicAddress,
          onTap: () =>
              _recipientFlow.switchMode(RecipientInputMode.publicAddress),
        ),
        _buildRecipientModeChip(
          c,
          label: 'Federation',
          icon: LucideIcons.atSign,
          selected: _recipientState.mode == RecipientInputMode.federation,
          onTap: () => _recipientFlow.switchMode(RecipientInputMode.federation),
        ),
      ],
    );
  }

  Widget _buildRecipientModeChip(
    AppColor c, {
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? _blend(c.surface, c.primary, 0.14) : c.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? c.primary : c.border,
            width: selected ? 1.2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? c.primary : c.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? c.primary : c.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
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

  bool _isRecipientBusy() {
    return _recipientState.recipientLoading ||
        _recipientState.federationLoading;
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

  Widget _buildSavedRecipientPanel(AppColor c) {
    final recipient = _recipientState.savedRecipient;
    if (recipient == null) {
      return _buildRecipientPickerEmptyState(
        c,
        title: 'Choose a saved recipient',
        subtitle: 'Select from your saved list to create a claimable balance.',
        buttonLabel: 'Open recipient list',
        icon: LucideIcons.users,
        onTap: _selectRecipient,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSavedRecipientChip(c, recipient),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: _selectRecipient,
          icon: const Icon(LucideIcons.repeat2, size: 16),
          label: const Text('Replace recipient'),
        ),
      ],
    );
  }

  Widget _buildScannedRecipientPanel(
    AppColor c,
    RecipientAddressModel? activeRecipient,
    bool hasValidDestination,
  ) {
    final payload = _recipientState.scannedPayload;
    final destination = _recipientState.finalDestinationAddress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                payload.rawValue.isEmpty
                    ? 'No QR scanned yet'
                    : 'Scanned value',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                payload.rawValue.isEmpty
                    ? 'Scan a public Stellar address or federation QR code.'
                    : payload.rawValue,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontFeatures: const [ui.FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _scanQR,
                icon: const Icon(LucideIcons.scanLine, size: 16),
                label: const Text('Scan again'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _recipientFlow.setScannedValue(''),
                icon: const Icon(LucideIcons.x, size: 16),
                label: const Text('Clear'),
              ),
            ),
          ],
        ),
        if (_recipientState.shouldShowFederationUi) ...[
          const SizedBox(height: 10),
          _buildFederationStatus(c),
        ],
        if (_isRecipientBusy()) ...[
          const SizedBox(height: 10),
          _buildRecipientLoadingState(c),
        ] else if (hasValidDestination && activeRecipient != null) ...[
          const SizedBox(height: 10),
          _buildSavedRecipientChip(c, activeRecipient),
        ] else if (hasValidDestination && activeRecipient == null) ...[
          const SizedBox(height: 10),
          _buildNewRecipientChip(c, destination!),
        ],
      ],
    );
  }

  Widget _buildPublicAddressPanel(
    AppColor c,
    RecipientAddressModel? activeRecipient,
    bool hasValidDestination,
  ) {
    final destination = _recipientState.finalDestinationAddress;
    final currentValue = _publicAddressCtl.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPublicAddressInputField(c, currentValue),
        if (_isRecipientBusy()) ...[
          const SizedBox(height: 10),
          _buildRecipientLoadingState(c),
        ] else if (hasValidDestination && activeRecipient != null) ...[
          const SizedBox(height: 10),
          _buildSavedRecipientChip(c, activeRecipient),
        ] else if (hasValidDestination && activeRecipient == null) ...[
          const SizedBox(height: 10),
          _buildNewRecipientChip(c, destination!),
        ],
      ],
    );
  }

  Widget _buildFederationPanel(
    AppColor c,
    RecipientAddressModel? activeRecipient,
    bool hasValidDestination,
  ) {
    final destination = _recipientState.finalDestinationAddress;
    final currentValue = _federationCtl.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFederationInputField(c, currentValue),
        if (_recipientState.federationSuggestions.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildFederationSuggestions(c),
        ],
        if (currentValue.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildFederationStatus(c),
        ],
        if (_isRecipientBusy()) ...[
          const SizedBox(height: 10),
          _buildRecipientLoadingState(c),
        ] else if (hasValidDestination && activeRecipient != null) ...[
          const SizedBox(height: 10),
          _buildSavedRecipientChip(c, activeRecipient),
        ] else if (hasValidDestination && activeRecipient == null) ...[
          const SizedBox(height: 10),
          _buildNewRecipientChip(c, destination!),
        ],
      ],
    );
  }

  Widget _buildRecipientPickerEmptyState(
    AppColor c, {
    required String title,
    required String subtitle,
    required String buttonLabel,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: c.primary),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 16, color: c.primary),
            label: Text(buttonLabel),
          ),
        ],
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
              if (saved == true && mounted) {
                await ref.read(contactListProvider.notifier).refresh();
                await _recipientFlow.initialize();
              }
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

  Widget _buildPublicAddressInputField(AppColor c, String addr) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? c.background : c.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: _publicAddressCtl,
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
          hintText: 'Paste a Stellar public address (G...)',
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
                      _publicAddressCtl.clear();
                      _recipientFlow.setManualPublicAddress('');
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
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
      ),
    );
  }

  Widget _buildFederationInputField(AppColor c, String addr) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? c.background : c.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: _federationCtl,
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
          hintText: 'Enter name*$_federationDomain',
          hintStyle: TextStyle(
            color: c.textSecondary,
            fontSize: 14,
            letterSpacing: -0.2,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Icon(LucideIcons.atSign, color: c.textSecondary, size: 18),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0),
          suffixIcon: addr.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    onPressed: () async {
                      _federationCtl.clear();
                      await _recipientFlow.clearFederationSelection();
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
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
      ),
    );
  }

  Widget _buildFederationSuggestions(AppColor c) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _recipientState.federationSuggestions
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
    final input = _recipientState.federationInput.trim();
    if (_recipientState.federationLoading) {
      return _buildFederationBanner(
        c,
        icon: null,
        title: 'Resolving federation address...',
        color: c.primary,
        showSpinner: true,
      );
    }

    if (_recipientState.federationError != null) {
      return _buildFederationBanner(
        c,
        icon: LucideIcons.alertCircle,
        title: _recipientState.federationError!,
        color: c.error,
      );
    }

    if (_recipientState.mode == RecipientInputMode.federation &&
        input.isNotEmpty &&
        _recipientState.activeValueKind == RecipientValueKind.invalid) {
      return _buildFederationBanner(
        c,
        icon: LucideIcons.info,
        title: 'Enter a federation address like name*$_federationDomain',
        color: c.primary,
      );
    }

    final resolved = _recipientState.resolvedFederation;
    if (resolved != null && resolved.accountId.trim().isNotEmpty) {
      return _buildFederationBanner(
        c,
        icon: LucideIcons.checkCircle2,
        title: 'Resolved to ${_shortenAddress(resolved.accountId)}',
        subtitle: resolved.stellarAddress,
        color: c.success,
        trailing: _recipientState.mode == RecipientInputMode.federation
            ? IconButton(
                onPressed: () async {
                  _federationCtl.clear();
                  await _recipientFlow.clearFederationSelection();
                },
                icon: Icon(LucideIcons.x, size: 16, color: c.textSecondary),
                splashRadius: 18,
              )
            : null,
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
    Widget? trailing,
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
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );
  }

  Widget _buildUnlockCard(AppColor c) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          bottom: BorderSide(color: c.border.withValues(alpha: 0.65), width: 1),
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

  Widget _buildExpirationCard(AppColor c) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          bottom: BorderSide(color: c.border.withValues(alpha: 0.65), width: 1),
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

  Widget _buildInfoCard(AppColor c) {
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
        color: Colors.transparent,
        border: Border(
          bottom: BorderSide(color: c.border.withValues(alpha: 0.65), width: 1),
        ),
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

  Widget _buildFloatingActionBar(AppColor c) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
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
