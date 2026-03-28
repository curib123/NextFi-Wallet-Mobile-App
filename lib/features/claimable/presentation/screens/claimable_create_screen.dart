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
import 'package:next_fi/core/widgets/alert/app_alert.dart';
import 'package:next_fi/core/widgets/modal/recipient_list_modal.dart';
import 'package:next_fi/core/widgets/modal/recipient_upsert_sheet.dart';
import 'package:next_fi/core/widgets/recipient/recipient_common_widgets.dart';

import 'package:next_fi/features/claimable/data/models/claimable_item.dart';
import 'package:next_fi/features/contact/presentation/viewmodels/contact_list_notifier.dart';
import 'package:next_fi/features/contact/data/models/recipient_address_model.dart';
import 'package:next_fi/features/scanner/presentation/screens/scanner_screen.dart';
import 'package:next_fi/core/services/federation_address/federation_address_core_service.dart';

class ClaimableCreateScreen extends ConsumerStatefulWidget {
  final String initialAsset;
  final bool useScaffold;

  const ClaimableCreateScreen({
    super.key,
    this.initialAsset = 'XLM',
    this.useScaffold = true,
  });

  @override
  ConsumerState<ClaimableCreateScreen> createState() =>
      _ClaimableCreateScreenState();
}

class _ClaimableCreateScreenState extends ConsumerState<ClaimableCreateScreen> {
  final _recipientCtl = TextEditingController();
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
  bool _syncingRecipientField = false;

  static final _dateFmt = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    _selectedAsset = _normalizeAssetSymbol(widget.initialAsset);
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
    _recipientCtl.addListener(() {
      if (_syncingRecipientField) return;
      _recipientFlow.setTypedInput(_recipientCtl.text);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recipientFlow.initialize();
    });
  }

  @override
  void dispose() {
    _recipientCtl.dispose();
    _amountCtl.dispose();
    super.dispose();
  }

  void _applyFederationSuggestion(String value) {
    _recipientCtl.text = value;
    _recipientCtl.selection = TextSelection.fromPosition(
      TextPosition(offset: _recipientCtl.text.length),
    );
  }

  void _syncRecipientField() {
    final expectedText = switch (_recipientState.mode) {
      RecipientInputMode.publicAddress => _recipientState.manualPublicAddress,
      RecipientInputMode.federation => _recipientState.federationInput,
      RecipientInputMode.savedRecipient || RecipientInputMode.scannedQr => '',
    };
    if (_recipientCtl.text == expectedText) return;
    _syncingRecipientField = true;
    _recipientCtl.value = TextEditingValue(
      text: expectedText,
      selection: TextSelection.collapsed(offset: expectedText.length),
    );
    _syncingRecipientField = false;
  }

  Future<void> _clearTypedRecipientInput() async {
    _recipientCtl.clear();
    await _recipientFlow.setTypedInput('');
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
      return 'Enter a valid recipient';
    }

    final amt = double.tryParse(_amountCtl.text.trim()) ?? 0;
    if (amt <= 0) return 'Enter a valid amount';

    final vm = ref.read(claimableVmProvider);
    if (!vm.hasSufficientBalance(_selectedAsset, amt)) {
      return 'Insufficient $_selectedAsset balance';
    }

    if (_mode == ClaimableMode.timeLocked) {
      final dt = _combinedUnlockDateTime;
      if (dt == null) return 'Set an unlock date';
      if (dt.isBefore(DateTime.now())) {
        return 'Unlock time must be in the future';
      }
    }

    if (_hasExpiry) {
      final dt = _combinedExpiryDateTime;
      if (dt == null) return 'Set an expiry date';
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
        title: 'Check details',
        subtitle: err,
      );
      return;
    }

    final ctl = showAppAlert(
      context,
      type: AppAlertType.loading,
      title: 'Creating claimable',
      subtitle: 'Submitting transaction...',
      barrierDismissible: false,
    );

    try {
      final vm = ref.read(claimableVmProvider);
      final addr = _recipientState.finalDestinationAddress;
      if (addr == null) {
        throw StateError('Recipient must resolve to a valid address.');
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
        title: 'Claimable created',
        subtitle: txHash,
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
    final selected = await showRecipientListModal(context, selectionMode: true);
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

  Color _blend(Color base, Color accent, double amount) =>
      Color.lerp(base, accent, amount) ?? base;

  String _normalizeAssetSymbol(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'XLM';

    final assetVm = ref.read(assetVmProvider);
    final direct = assetVm.findAsset(trimmed);
    if (direct != null) {
      final code = (direct.assetCode ?? direct.symbol).trim().toUpperCase();
      if (code.isNotEmpty) return code;
    }

    for (final asset in assetVm.assets) {
      if (!asset.matchesKey(trimmed)) continue;
      final code = (asset.assetCode ?? asset.symbol).trim().toUpperCase();
      if (code.isNotEmpty) return code;
    }

    final upper = trimmed.toUpperCase();
    if (upper.contains('USDC')) return 'USDC';
    if (upper.contains('XLM') || upper == 'NATIVE') return 'XLM';
    return upper;
  }

  String _formatAmountValue(double value, {int decimals = 7}) {
    final text = value.toStringAsFixed(decimals);
    return text.contains('.') ? text.replaceFirst(RegExp(r'\.?0+$'), '') : text;
  }

  Color _cardBackground(AppColor c) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? c.surface.withValues(alpha: 0.88)
        : c.onPrimary.withValues(alpha: 0.96);
  }

  Widget _buildModalCard(
    AppColor c, {
    required Widget child,
    Color? accent,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _cardBackground(c),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: accent == null ? c.border : _blend(c.border, accent, 0.32),
        ),
      ),
      child: child,
    );
  }

  Widget _buildCardLabel(AppColor c, String label) {
    return Text(
      label,
      style: TextStyle(
        color: c.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.35,
      ),
    );
  }

  Widget _buildModeChip(
    AppColor c, {
    required bool selected,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? _blend(c.surface, c.primary, 0.14) : c.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? c.primary : c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _timingSummary() {
    final unlock = _combinedUnlockDateTime;
    final expiry = _combinedExpiryDateTime;

    if (_mode == ClaimableMode.unconditional && !_hasExpiry) {
      return null;
    }

    if (_mode == ClaimableMode.timeLocked && unlock != null && _hasExpiry && expiry != null) {
      return 'Claim after ${_dateFmt.format(unlock)} ${_unlockTime?.format(context) ?? '12:00 AM'} and before ${_dateFmt.format(expiry)} ${_expiryTime?.format(context) ?? '11:59 PM'}.';
    }

    if (_mode == ClaimableMode.timeLocked && unlock != null) {
      return 'Claim after ${_dateFmt.format(unlock)} ${_unlockTime?.format(context) ?? '12:00 AM'}.';
    }

    if (_hasExpiry && expiry != null) {
      return 'Claim before ${_dateFmt.format(expiry)} ${_expiryTime?.format(context) ?? '11:59 PM'}.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final vm = ref.watch(claimableVmProvider);
    final currentBal = vm.getBalanceForSymbol(_selectedAsset);
    _syncRecipientField();

    final content = ColoredBox(
      color: c.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildModernHeader(c),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                children: [
                  _buildAmountCard(c, currentBal),
                  const SizedBox(height: 16),
                  _buildRecipientCard(c),
                  const SizedBox(height: 16),
                  _buildTimingCard(c),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            _buildFloatingActionBar(c),
          ],
        ),
      ),
    );

    if (widget.useScaffold) {
      return Scaffold(backgroundColor: c.background, body: content);
    }
    return ColoredBox(color: c.background, child: content);
  }

  Widget _buildModernHeader(AppColor c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(LucideIcons.x, color: c.textPrimary, size: 20),
            splashRadius: 20,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Create claimable',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.35,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _blend(c.surface, c.primary, 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _blend(c.border, c.primary, 0.3)),
                  ),
                  child: Text(
                    _selectedAsset,
                    style: TextStyle(
                      color: c.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildAmountCard(AppColor c, double currentBal) {
    return _buildModalCard(
      c,
      accent: c.primary,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildCardLabel(c, 'AMOUNT'),
              const Spacer(),
              Text(
                'Available ${_formatAmountValue(currentBal, decimals: _selectedAsset == 'XLM' ? 4 : 2)} $_selectedAsset',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
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
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                    letterSpacing: -1.8,
                    height: 1.05,
                  ),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(
                      color: c.border,
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.8,
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: c.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.border),
                    ),
                    child: Text(
                      _selectedAsset,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _amountCtl.text = currentBal > 0
                          ? _formatAmountValue(currentBal)
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
                        color: _blend(c.surface, c.primary, 0.14),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _blend(c.border, c.primary, 0.32)),
                      ),
                      child: Text(
                        'MAX',
                        style: TextStyle(
                          color: c.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.45,
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

    return _buildModalCard(
      c,
      accent: c.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildCardLabel(c, 'TO'),
              const Spacer(),
              _buildQuickActionButton(
                c,
                icon: LucideIcons.qrCode,
                label: 'Scan',
                onTap: _scanQR,
              ),
              const SizedBox(width: 8),
              _buildQuickActionButton(
                c,
                icon: LucideIcons.users,
                label: 'Contacts',
                onTap: _selectRecipient,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_recipientState.mode == RecipientInputMode.savedRecipient)
            _buildSavedRecipientPanel(c)
          else if (_recipientState.mode == RecipientInputMode.scannedQr)
            _buildScannedRecipientPanel(c, activeRecipient, hasValidDestination)
          else
            _buildTypedRecipientPanel(c, activeRecipient, hasValidDestination),
        ],
      ),
    );
  }

  Widget _buildTimingCard(AppColor c) {
    final summary = _timingSummary();

    return _buildModalCard(
      c,
      accent: _mode == ClaimableMode.timeLocked || _hasExpiry
          ? c.primary
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardLabel(c, 'AVAILABILITY'),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildModeChip(
                  c,
                  selected: _mode == ClaimableMode.unconditional,
                  title: 'Now',
                  subtitle: 'Claim anytime',
                  onTap: () {
                    if (_mode == ClaimableMode.unconditional) return;
                    setState(() => _mode = ClaimableMode.unconditional);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildModeChip(
                  c,
                  selected: _mode == ClaimableMode.timeLocked,
                  title: 'Schedule',
                  subtitle: 'Unlock later',
                  onTap: () {
                    if (_mode == ClaimableMode.timeLocked) return;
                    setState(() => _mode = ClaimableMode.timeLocked);
                  },
                ),
              ),
            ],
          ),
          if (_mode == ClaimableMode.timeLocked) ...[
            const SizedBox(height: 18),
            Text(
              'Unlock',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 10),
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
          ],
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              children: [
                Text(
                  'Expiry',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: _hasExpiry,
                  activeColor: c.primary,
                  onChanged: (value) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _hasExpiry = value;
                      if (!value) {
                        _expiryDate = null;
                        _expiryTime = null;
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          if (_hasExpiry) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildDateTimePicker(c, isDate: true, isUnlock: false),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildDateTimePicker(c, isDate: false, isUnlock: false),
                ),
              ],
            ),
          ],
          if (summary != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _blend(c.surface, c.primary, 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _blend(c.border, c.primary, 0.3)),
              ),
              child: Text(
                summary,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(
    AppColor c, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return RecipientQuickActionButton(
      icon: icon,
      label: label,
      onTap: onTap,
      backgroundColor: c.background,
      borderColor: _blend(c.border, c.primary, 0.08),
      iconColor: c.primary,
    );
  }

  bool _isRecipientBusy() {
    return _recipientState.recipientLoading ||
        _recipientState.federationLoading;
  }

  Widget _buildRecipientLoadingState(AppColor c) {
    return RecipientLookupLoadingCard(
      backgroundColor: c.background,
      borderColor: _blend(c.border, c.primary, 0.22),
      spinnerColor: c.primary,
      labelColor: c.textPrimary,
    );
  }

  Widget _buildSavedRecipientPanel(AppColor c) {
    final recipient = _recipientState.savedRecipient;
    if (recipient == null) {
      return _buildRecipientPickerEmptyState(
        c,
        title: 'No recipient selected',
        subtitle: 'Paste an address or choose a contact.',
        buttonLabel: 'Contacts',
        icon: LucideIcons.users,
        onTap: _selectRecipient,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSavedRecipientChip(c, recipient),
        const SizedBox(height: 10),
        Wrap(
          spacing: 4,
          children: [
            TextButton.icon(
              onPressed: _selectRecipient,
              icon: const Icon(LucideIcons.repeat2, size: 16),
              label: const Text('Replace'),
            ),
            TextButton.icon(
              onPressed: _clearTypedRecipientInput,
              icon: const Icon(LucideIcons.pencil, size: 16),
              label: const Text('Manual'),
            ),
          ],
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
        RecipientScannedValueCard(
          rawValue: payload.rawValue,
          emptyMessage: 'Scan an address or federation.',
          backgroundColor: c.background,
          borderColor: c.border,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _scanQR,
                icon: const Icon(LucideIcons.scanLine, size: 16),
                label: const Text('Rescan'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _clearTypedRecipientInput,
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

  Widget _buildTypedRecipientPanel(
    AppColor c,
    RecipientAddressModel? activeRecipient,
    bool hasValidDestination,
  ) {
    final destination = _recipientState.finalDestinationAddress;
    final currentValue = _recipientCtl.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRecipientInputField(c, currentValue),
        if (_recipientState.federationSuggestions.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildFederationSuggestions(c),
        ],
        if (_recipientState.shouldShowFederationUi &&
            currentValue.isNotEmpty) ...[
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
    return RecipientPickerEmptyState(
      title: title,
      subtitle: subtitle,
      buttonLabel: buttonLabel,
      icon: icon,
      onTap: onTap,
      backgroundColor: c.background,
      borderColor: c.border,
    );
  }

  Widget _buildSavedRecipientChip(AppColor c, RecipientAddressModel recipient) {
    final color = Color(recipient.color);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RecipientSavedCard(
      name: recipient.name,
      address: recipient.address,
      colorValue: recipient.color,
      onEdit: _editRecipient,
      backgroundColor: _blend(isDark ? c.background : c.surface, color, 0.16),
      borderColor: _blend(c.border, color, 0.7),
      avatarBackgroundColor: _blend(c.surface, color, 0.22),
      editBackgroundColor: _blend(c.surface, color, 0.22),
      addressColor: c.textSecondary,
    );
  }

  Widget _buildNewRecipientChip(AppColor c, String addr) {
    return RecipientNewAddressCard(
      address: addr,
      onAdd: () async {
        final saved = await showRecipientUpsertSheet(context, address: addr);
        if (saved == true && mounted) {
          await ref.read(contactListProvider.notifier).refresh();
          await _recipientFlow.initialize();
        }
      },
      backgroundColor: c.background,
      borderColor: c.border,
      iconBackgroundColor: _blend(c.surface, c.primary, 0.18),
      iconColor: c.primary,
      addressColor: c.textSecondary,
      saveBackgroundColor: c.primary,
      saveBorderColor: c.primary,
      saveTextColor: c.onPrimary,
    );
  }

  Widget _buildRecipientInputField(AppColor c, String addr) {
    final isFederationEntry =
        _recipientState.mode == RecipientInputMode.federation;
    return Container(
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
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
          hintText: 'Address or name*$_federationDomain',
          hintStyle: TextStyle(
            color: c.textSecondary,
            fontSize: 14,
            letterSpacing: -0.2,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Icon(
              isFederationEntry ? LucideIcons.atSign : LucideIcons.wallet,
              color: c.textSecondary,
              size: 18,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0),
          suffixIcon: addr.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    onPressed: _clearTypedRecipientInput,
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
              side: BorderSide(color: _blend(c.border, c.primary, 0.28)),
              backgroundColor: c.background,
              onPressed: () => _applyFederationSuggestion(s),
            ),
          )
          .toList(),
    );
  }

  Widget _buildFederationStatus(AppColor c) {
    final input = _recipientState.federationInput.trim();
    if (_recipientState.federationLoading) {
      return RecipientStatusBanner(
        title: 'Resolving address...',
        color: c.primary,
        backgroundColor: c.background,
        borderColor: _blend(c.border, c.primary, 0.3),
        showSpinner: true,
      );
    }

    if (_recipientState.federationError != null) {
      return RecipientStatusBanner(
        icon: LucideIcons.alertCircle,
        title: _recipientState.federationError!,
        color: c.error,
        backgroundColor: c.background,
        borderColor: _blend(c.border, c.error, 0.3),
        titleColor: c.textPrimary,
      );
    }

    if (_recipientState.shouldShowFederationUi &&
        input.isNotEmpty &&
        _recipientState.activeValueKind == RecipientValueKind.invalid) {
      return RecipientStatusBanner(
        icon: LucideIcons.info,
        title: 'Use name*$_federationDomain',
        color: c.primary,
        backgroundColor: c.background,
        borderColor: _blend(c.border, c.primary, 0.3),
        titleColor: c.textPrimary,
      );
    }

    final resolved = _recipientState.resolvedFederation;
    if (resolved != null && resolved.accountId.trim().isNotEmpty) {
      return RecipientStatusBanner(
        icon: LucideIcons.checkCircle2,
        title: 'Resolved ${shortenRecipientAddress(resolved.accountId)}',
        subtitle: resolved.stellarAddress,
        color: c.success,
        backgroundColor: c.background,
        borderColor: _blend(c.border, c.success, 0.3),
        titleColor: c.textPrimary,
        subtitleColor: c.textSecondary,
        trailing: _recipientState.shouldShowFederationUi
            ? IconButton(
                onPressed: _clearTypedRecipientInput,
                icon: Icon(LucideIcons.x, size: 16, color: c.textSecondary),
                splashRadius: 18,
              )
            : null,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildDateTimePicker(
    AppColor c, {
    required bool isDate,
    required bool isUnlock,
  }) {
    final icon = isDate ? LucideIcons.calendar : LucideIcons.clock;
    final color = c.primary;
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
          color: c.background,
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

  Widget _buildFloatingActionBar(AppColor c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: BoxDecoration(
        color: c.background,
        border: Border(
          top: BorderSide(color: c.border.withValues(alpha: 0.85)),
        ),
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
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text(
              'Create claimable',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
