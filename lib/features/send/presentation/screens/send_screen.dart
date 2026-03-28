import 'dart:convert' show utf8;
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:next_fi/core/widgets/button/app_buttons.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/core/recipient_input/recipient_flow_controller.dart';
import 'package:next_fi/core/widgets/asset/asset_logo.dart';
import 'package:next_fi/core/widgets/fintech/fintech_flow_widgets.dart';
import 'package:next_fi/core/widgets/loader/page_loader.dart';
import 'package:next_fi/core/widgets/modal/recipient_list_modal.dart';
import 'package:next_fi/core/widgets/modal/recipient_upsert_sheet.dart';
import 'package:next_fi/core/widgets/recipient/recipient_common_widgets.dart';
import 'package:next_fi/core/widgets/snackbar/snack_bar.dart';
import 'package:next_fi/core/widgets/alert/app_alert.dart';

import 'package:next_fi/features/contact/data/models/recipient_address_model.dart';
import 'package:next_fi/features/scanner/presentation/screens/scanner_screen.dart';
import 'package:next_fi/features/contact/presentation/viewmodels/contact_list_notifier.dart';
import 'package:next_fi/features/send/presentation/viewmodels/send_controller.dart';
import 'package:next_fi/features/send/presentation/viewmodels/send_state.dart';

class _ST {
  final bool isDark;

  final Color cardBg;
  final Color inputBg;
  final Color chipBg;
  final Color chipBorder;

  final Color primaryTint;
  final Color primaryTintBorder;
  final Color primaryMuted;

  final Color successTint;
  final Color successBorder;
  final Color successText;
  final Color errorTint;
  final Color errorBorder;
  final Color warningTint;
  final Color warningBorder;

  final Color labelColor;
  final Color metaColor;
  final Color monoColor;
  final Color dividerColor;

  const _ST._({
    required this.isDark,
    required this.cardBg,
    required this.inputBg,
    required this.chipBg,
    required this.chipBorder,
    required this.primaryTint,
    required this.primaryTintBorder,
    required this.primaryMuted,
    required this.successTint,
    required this.successBorder,
    required this.successText,
    required this.errorTint,
    required this.errorBorder,
    required this.warningTint,
    required this.warningBorder,
    required this.labelColor,
    required this.metaColor,
    required this.monoColor,
    required this.dividerColor,
  });

  static _ST of(BuildContext context) {
    final c = AppColor.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return _ST._(
      isDark: dark,
      cardBg: dark ? c.surface : c.onPrimary,
      inputBg: c.background,
      chipBg: c.background,
      chipBorder: c.border,
      primaryTint: c.background,
      primaryTintBorder: c.border,
      primaryMuted: c.primary,
      successTint: c.background,
      successBorder: c.border,
      successText: c.success,
      errorTint: c.background,
      errorBorder: c.border,
      warningTint: c.background,
      warningBorder: c.border,
      labelColor: c.textSecondary,
      metaColor: c.textSecondary,
      monoColor: c.textSecondary,
      dividerColor: c.border,
    );
  }
}

class SendScreen extends ConsumerStatefulWidget {
  final String address;
  final String assetId;
  final double balance;
  final bool autoOpenScanner;
  final String? prefillAddress;
  final String? prefillName;
  final RecipientAddressModel? prefillRecipient;
  final RecipientInputMode? initialRecipientMode;
  final Future<void> Function()? onTransactionCompleted;
  final bool useScaffold;

  const SendScreen({
    super.key,
    required this.address,
    required this.assetId,
    required this.balance,
    this.autoOpenScanner = false,
    this.prefillAddress,
    this.prefillName,
    this.prefillRecipient,
    this.initialRecipientMode,
    this.onTransactionCompleted,
    this.useScaffold = true,
  });

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen> {
  final _recipientCtl = TextEditingController();
  final _amtCtl = TextEditingController();
  final _memoCtl = TextEditingController();

  int _memoBytes = 0;
  double? _lastPct;
  final _numFmt = NumberFormat('#,##0.######');

  bool _booted = false;
  bool _scannerOpenedOnce = false;
  bool _syncingRecipientField = false;

  SendControllerArgs get _args => SendControllerArgs(
    address: widget.address,
    assetId: widget.assetId,
    balance: widget.balance,
    prefillAddress: widget.prefillAddress,
    prefillName: widget.prefillName,
    prefillRecipient: widget.prefillRecipient,
    initialRecipientMode: widget.initialRecipientMode,
  );

  @override
  void initState() {
    super.initState();
    if (_booted) return;

    final prefillAddress = (widget.prefillAddress ?? '').trim();
    final initialMode =
        widget.initialRecipientMode ??
        (widget.prefillRecipient != null
            ? RecipientInputMode.savedRecipient
            : RecipientInputParser.isFederationAddress(prefillAddress)
            ? RecipientInputMode.federation
            : RecipientInputMode.publicAddress);
    if (initialMode == RecipientInputMode.publicAddress ||
        initialMode == RecipientInputMode.federation) {
      _recipientCtl.text = prefillAddress;
    }

    _amtCtl.addListener(() {
      final v = double.tryParse(_amtCtl.text.trim()) ?? 0;
      ref.read(sendControllerProvider(_args).notifier).setTypedAmount(v);
      _lastPct = null;
      setState(() {});
    });

    _recipientCtl.addListener(() {
      if (_syncingRecipientField) return;
      ref
          .read(sendControllerProvider(_args).notifier)
          .setTypedRecipientInput(_recipientCtl.text);
    });

    _memoCtl.addListener(() {
      _memoBytes = utf8.encode(_memoCtl.text).length;
      ref.read(sendControllerProvider(_args).notifier).setMemo(_memoCtl.text);
      setState(() {});
    });

    if (widget.autoOpenScanner && !_scannerOpenedOnce) {
      final hasPrefill =
          (widget.prefillAddress ?? '').trim().isNotEmpty ||
          _recipientCtl.text.trim().isNotEmpty ||
          widget.prefillRecipient != null;
      if (!hasPrefill) {
        _scannerOpenedOnce = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _openScanner());
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(contactListProvider.notifier).ensureLoaded();
    });
    _booted = true;
  }

  @override
  void dispose() {
    _recipientCtl.dispose();
    _amtCtl.dispose();
    _memoCtl.dispose();
    super.dispose();
  }

  void _applyFederationSuggestion(String value) {
    _recipientCtl.text = value;
    _recipientCtl.selection = TextSelection.fromPosition(
      TextPosition(offset: _recipientCtl.text.length),
    );
  }

  void _syncRecipientField(RecipientInputState recipient) {
    final expectedText = switch (recipient.mode) {
      RecipientInputMode.publicAddress => recipient.manualPublicAddress,
      RecipientInputMode.federation => recipient.federationInput,
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
    await ref
        .read(sendControllerProvider(_args).notifier)
        .setTypedRecipientInput('');
  }

  Future<void> _refresh() async {
    await ref.read(sendControllerProvider(_args).notifier).refreshFees();
    await ref
        .read(sendControllerProvider(_args).notifier)
        .refreshRecipientState();
    await Future.delayed(const Duration(milliseconds: 250));
  }

  double _floorTo(double v, int dec) {
    final scale = math.pow(10, dec);
    return (v >= 0 ? (v * scale).floor() / scale : (v * scale).ceil() / scale)
        .toDouble();
  }

  String _fmtAmount(double v, {int decimals = 7}) {
    final s = v.toStringAsFixed(decimals);
    return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
  }

  void _applyPercent(SendState vm, double percent) {
    HapticFeedback.selectionClick();
    double targetAmount;
    if (percent >= 0.999) {
      targetAmount = vm.isXlm
          ? (vm.senderBalanceToken - vm.networkFee).clamp(0, double.infinity)
          : vm.senderBalanceToken;
    } else {
      targetAmount = vm.senderBalanceToken * percent;
    }
    final v = _floorTo(targetAmount, 7);
    _amtCtl.text = _fmtAmount(v);
    _amtCtl.selection = TextSelection.fromPosition(
      TextPosition(offset: _amtCtl.text.length),
    );
    _lastPct = percent;
    setState(() {});
  }

  Future<void> _confirmAndSend(SendState vm) async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColor.of(context).surface,
      builder: (_) => _ReviewSheet(
        args: _args,
        recipientName: vm.recipient.activeRecipient?.name,
        onTransactionCompleted: widget.onTransactionCompleted,
      ),
    );
    if (sent == true && mounted) {
      _amtCtl.clear();
      _memoCtl.clear();
      setState(() => _lastPct = null);
    }
  }

  Future<void> _openScanner() async {
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    final navigator = Navigator.of(context);
    await Future.delayed(const Duration(milliseconds: 60));
    if (!mounted) return;

    final raw = await navigator.push(
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (!mounted || raw is! String) return;

    final parsed = RecipientInputParser.parseQr(raw);
    if (parsed.kind == RecipientValueKind.invalid ||
        parsed.kind == RecipientValueKind.empty) {
      if (!mounted) return;
      showFloatingSnackBar(
        context,
        message: 'No valid Stellar address found',
        type: SnackBarType.warning,
      );
      return;
    }
    if (parsed.memoText != null && parsed.memoText!.trim().isNotEmpty) {
      if (parsed.hasSupportedTextMemo) {
        _memoCtl.text = parsed.memoText!;
      } else if (mounted) {
        showFloatingSnackBar(
          context,
          message:
              'QR memo type "${parsed.memoType?.trim()}" not supported (only TEXT).',
          type: SnackBarType.warning,
        );
      }
    }
    await ref
        .read(sendControllerProvider(_args).notifier)
        .applyScannedValue(raw.trim());
  }

  Future<void> _openRecipientsPicker() async {
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    final picked = await showRecipientListModal(
      context,
      fromAddress: widget.address,
      selectionMode: true,
    );
    if (!mounted || picked == null) return;
    ref
        .read(sendControllerProvider(_args).notifier)
        .selectSavedRecipient(picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final t = _ST.of(context);
    final vm = ref.watch(sendControllerProvider(_args));
    final tokenStr = vm.assetSymbol;
    _syncRecipientField(vm.recipient);

    if (vm.loading) {
      return _wrapRoot(c, const _LoadingState());
    }
    if (vm.error != null) {
      return _wrapRoot(c, _ErrorState(message: vm.error!, onRetry: _refresh));
    }

    final content = FintechFlowBackground(
      colors: c,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(c, t, vm),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                color: c.primary,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(0, 6, 0, 28),
                  children: [
                    _buildAmountCard(c, t, vm, tokenStr),
                    const SizedBox(height: 22),
                    _buildSectionIntro(c, title: 'Recipient'),
                    const SizedBox(height: 12),
                    _buildRecipientCard(c, t, vm),
                    if (!vm.isXlm) ...[
                      const SizedBox(height: 12),
                      _buildTrustlineStatus(c, t, vm),
                    ],
                    const SizedBox(height: 22),
                    _buildSectionIntro(c, title: 'Memo'),
                    const SizedBox(height: 12),
                    _buildMemoCard(c, t),
                    if (vm.typedAmount > 0) ...[
                      const SizedBox(height: 22),
                      _buildSectionIntro(c, title: 'Review'),
                      const SizedBox(height: 12),
                      _buildBreakdownCard(c, t, vm, tokenStr),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            _buildActionBar(c, t, vm),
          ],
        ),
      ),
    );

    return _wrapRoot(c, content);
  }

  Widget _wrapRoot(AppColor c, Widget child) {
    if (widget.useScaffold) {
      return Scaffold(backgroundColor: c.background, body: child);
    }
    return ColoredBox(color: c.background, child: child);
  }

  Widget _buildHeader(AppColor c, _ST t, SendState vm) {
    final tokenStr = vm.assetSymbol;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  LucideIcons.arrowLeft,
                  color: c.textPrimary,
                  size: 21,
                ),
                splashRadius: 22,
              ),
              Expanded(
                child: Text(
                  'Send',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.35,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 8),
         
        ],
      ),
    );
  }

  Widget _buildSectionIntro(AppColor c, {required String title}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: FintechSectionIntro(title: title, colors: c),
    );
  }

  Widget _buildAmountCard(AppColor c, _ST t, SendState vm, String tokenStr) {
    return FintechFullBleedSection(
      colors: c,
      emphasisColor: c.primary,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SectionLabel('Amount'),
              const Spacer(),
              Icon(LucideIcons.wallet, size: 13, color: t.labelColor),
              const SizedBox(width: 5),
              Text(
                'Spendable: ${_fmtAmount(vm.senderBalanceToken, decimals: vm.isXlm ? 4 : 2)} $tokenStr',
                style: TextStyle(
                  color: t.labelColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
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
                  controller: _amtCtl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,7}$'),
                    ),
                  ],
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                    letterSpacing: -2,
                    height: 1.05,
                  ),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(
                      color: t.metaColor,
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -2,
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tokenStr,
                    style: TextStyle(
                      color: t.labelColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _MaxButton(t: t, c: c, onTap: () => _applyPercent(vm, 1.0)),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),
          _buildDivider(t),
          const SizedBox(height: 14),

          _buildPctChips(c, t, vm),
        ],
      ),
    );
  }

  Widget _buildPctChips(AppColor c, _ST t, SendState vm) {
    const presets = [('25%', 0.25), ('50%', 0.50), ('75%', 0.75)];
    return Row(
      children: [
        for (int i = 0; i < presets.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _buildPctChip(
              c,
              t,
              label: presets[i].$1,
              pct: presets[i].$2,
              vm: vm,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPctChip(
    AppColor c,
    _ST t, {
    required String label,
    required double pct,
    required SendState vm,
  }) {
    final active = _lastPct != null && (_lastPct! - pct).abs() < 0.001;
    return GestureDetector(
      onTap: () => _applyPercent(vm, pct),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? t.primaryTint : t.chipBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? t.primaryTintBorder : t.chipBorder,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: active ? c.primary : t.labelColor,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecipientCard(AppColor c, _ST t, SendState vm) {
    final recipient = vm.recipient;
    final destination = recipient.finalDestinationAddress;
    final hasValidDestination =
        destination != null &&
        RecipientInputParser.isStellarPublicAddress(destination);
    final activeRecipient = recipient.activeRecipient;

    return FintechFullBleedSection(
      colors: c,
      emphasisColor: c.primary,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SectionLabel('Send to'),
              const Spacer(),
              RecipientQuickActionButton(
                icon: LucideIcons.qrCode,
                label: 'Scan',
                onTap: _openScanner,
                backgroundColor: t.chipBg,
                borderColor: t.chipBorder,
                iconColor: t.primaryMuted,
              ),
              const SizedBox(width: 8),
              RecipientQuickActionButton(
                icon: LucideIcons.contact2,
                label: 'Contacts',
                onTap: _openRecipientsPicker,
                backgroundColor: t.chipBg,
                borderColor: t.chipBorder,
                iconColor: t.primaryMuted,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (recipient.mode == RecipientInputMode.savedRecipient)
            _buildSavedRecipientPanel(c, t, vm)
          else if (recipient.mode == RecipientInputMode.scannedQr)
            _buildScannedRecipientPanel(
              c,
              t,
              vm,
              activeRecipient,
              hasValidDestination,
            )
          else if (recipient.mode == RecipientInputMode.publicAddress)
            _buildTypedRecipientPanel(
              c,
              t,
              vm,
              activeRecipient,
              hasValidDestination,
            )
          else
            _buildTypedRecipientPanel(
              c,
              t,
              vm,
              activeRecipient,
              hasValidDestination,
            ),
        ],
      ),
    );
  }

  Widget _buildSavedRecipientPanel(AppColor c, _ST t, SendState vm) {
    final recipient = vm.recipient.savedRecipient;
    if (recipient == null) {
      return _buildSelectorEmptyState(
        title: 'Choose a saved recipient',
        subtitle: 'Pick from saved contacts.',
        buttonLabel: 'Open recipient list',
        icon: LucideIcons.contact2,
        onTap: _openRecipientsPicker,
        backgroundColor: t.inputBg,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSavedRecipientCard(
          c,
          t,
          name: recipient.name,
          address: recipient.address,
          colorValue: recipient.color,
          onEdit: () async {
            final ok = await showRecipientUpsertSheet(
              context,
              initial: recipient,
            );
            if (ok == true && mounted) {
              await ref.read(contactListProvider.notifier).refresh();
              final updated = ref
                  .read(contactListProvider)
                  .byAddress(recipient.address.trim());
              await ref
                  .read(sendControllerProvider(_args).notifier)
                  .selectSavedRecipient(updated ?? recipient);
            }
          },
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 4,
            children: [
              TextButton.icon(
                onPressed: _openRecipientsPicker,
                icon: const Icon(LucideIcons.repeat2, size: 16),
                label: const Text('Replace'),
              ),
              TextButton.icon(
                onPressed: _clearTypedRecipientInput,
                icon: const Icon(LucideIcons.pencil, size: 16),
                label: const Text('Enter manually'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScannedRecipientPanel(
    AppColor c,
    _ST t,
    SendState vm,
    RecipientAddressModel? activeRecipient,
    bool hasValidDestination,
  ) {
    final recipient = vm.recipient;
    final scannedPayload = recipient.scannedPayload;
    final destination = recipient.finalDestinationAddress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RecipientScannedValueCard(
          rawValue: scannedPayload.rawValue,
          emptyMessage: 'Scan an address or federation code.',
          backgroundColor: t.inputBg,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openScanner,
                icon: const Icon(LucideIcons.scanLine, size: 16),
                label: const Text('Scan again'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => ref
                    .read(sendControllerProvider(_args).notifier)
                    .setTypedRecipientInput(''),
                icon: const Icon(LucideIcons.x, size: 16),
                label: const Text('Clear'),
              ),
            ),
          ],
        ),
        if (recipient.shouldShowFederationUi) ...[
          const SizedBox(height: 10),
          _buildFederationStatus(c, t, vm),
        ],
        if (isLoadingForRecipient(recipient)) ...[
          const SizedBox(height: 10),
          RecipientLookupLoadingCard(
            backgroundColor: t.inputBg,
            borderColor: t.chipBorder,
            spinnerColor: t.primaryMuted,
            labelColor: t.labelColor,
          ),
        ] else if (hasValidDestination && activeRecipient != null) ...[
          const SizedBox(height: 10),
          _buildSavedRecipientCard(
            c,
            t,
            name: activeRecipient.name,
            address: destination ?? activeRecipient.address,
            colorValue: activeRecipient.color,
            onEdit: () async {
              final ok = await showRecipientUpsertSheet(
                context,
                initial: activeRecipient,
              );
              if (ok == true && mounted) {
                await ref.read(contactListProvider.notifier).refresh();
                await ref
                    .read(sendControllerProvider(_args).notifier)
                    .refreshRecipientState();
              }
            },
          ),
        ] else if (hasValidDestination && activeRecipient == null) ...[
          const SizedBox(height: 10),
          _buildNewRecipientCard(
            c,
            t,
            address: destination!,
            onAdd: () async {
              final saved = await showRecipientUpsertSheet(
                context,
                address: destination,
              );
              if (saved == true && mounted) {
                await ref.read(contactListProvider.notifier).refresh();
                await ref
                    .read(sendControllerProvider(_args).notifier)
                    .refreshRecipientState();
              }
            },
          ),
        ],
      ],
    );
  }

  Widget _buildTypedRecipientPanel(
    AppColor c,
    _ST t,
    SendState vm,
    RecipientAddressModel? activeRecipient,
    bool hasValidDestination,
  ) {
    final recipient = vm.recipient;
    final destination = recipient.finalDestinationAddress;
    final currentValue = _recipientCtl.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRecipientInput(c, t, currentValue, recipient),
        if (recipient.federationSuggestions.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildFederationSuggestions(c, t, recipient),
        ],
        if (recipient.shouldShowFederationUi && currentValue.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildFederationStatus(c, t, vm),
        ],
        if (isLoadingForRecipient(recipient)) ...[
          const SizedBox(height: 10),
          RecipientLookupLoadingCard(
            backgroundColor: t.inputBg,
            borderColor: t.chipBorder,
            spinnerColor: t.primaryMuted,
            labelColor: t.labelColor,
          ),
        ] else if (hasValidDestination && activeRecipient != null) ...[
          const SizedBox(height: 10),
          _buildSavedRecipientCard(
            c,
            t,
            name: activeRecipient.name,
            address: destination ?? activeRecipient.address,
            colorValue: activeRecipient.color,
            onEdit: () async {
              final ok = await showRecipientUpsertSheet(
                context,
                initial: activeRecipient,
              );
              if (ok == true && mounted) {
                await ref.read(contactListProvider.notifier).refresh();
                await ref
                    .read(sendControllerProvider(_args).notifier)
                    .refreshRecipientState();
              }
            },
          ),
        ] else if (hasValidDestination && activeRecipient == null) ...[
          const SizedBox(height: 10),
          _buildNewRecipientCard(
            c,
            t,
            address: destination!,
            onAdd: () async {
              final saved = await showRecipientUpsertSheet(
                context,
                address: destination,
              );
              if (saved == true && mounted) {
                await ref.read(contactListProvider.notifier).refresh();
                await ref
                    .read(sendControllerProvider(_args).notifier)
                    .refreshRecipientState();
              }
            },
          ),
        ],
      ],
    );
  }

  bool isLoadingForRecipient(RecipientInputState recipient) {
    return recipient.recipientLoading || recipient.federationLoading;
  }

  Widget _buildSelectorEmptyState({
    required String title,
    required String subtitle,
    required String buttonLabel,
    required IconData icon,
    required VoidCallback onTap,
    required Color backgroundColor,
  }) {
    return RecipientPickerEmptyState(
      title: title,
      subtitle: subtitle,
      buttonLabel: buttonLabel,
      icon: icon,
      onTap: onTap,
      backgroundColor: backgroundColor,
    );
  }

  Widget _buildRecipientInput(
    AppColor c,
    _ST t,
    String addr,
    RecipientInputState recipient,
  ) {
    final isFederationEntry = recipient.mode == RecipientInputMode.federation;
    return Container(
      decoration: BoxDecoration(
        color: t.inputBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: _recipientCtl,
        textInputAction: TextInputAction.next,
        keyboardType: TextInputType.multiline,
        minLines: 1,
        maxLines: null,
        style: TextStyle(
          fontSize: 15.5,
          fontWeight: FontWeight.w500,
          color: c.textPrimary,
          letterSpacing: -0.2,
          fontFeatures: const [ui.FontFeature.tabularFigures()],
        ),
        decoration: InputDecoration(
          hintText: 'Paste address or name*${recipient.federationDomain}',
          hintMaxLines: 1,
          hintStyle: TextStyle(
            color: t.metaColor,
            fontSize: 14,
            letterSpacing: -0.2,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 15, right: 10),
            child: Icon(
              isFederationEntry ? LucideIcons.atSign : LucideIcons.wallet,
              color: t.labelColor,
              size: 17,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0),
          suffixIcon: addr.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: IconButton(
                    onPressed: _clearTypedRecipientInput,
                    icon: Icon(LucideIcons.x, size: 16, color: t.labelColor),
                    splashRadius: 18,
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 19,
          ),
        ),
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
      ),
    );
  }

  Widget _buildFederationSuggestions(
    AppColor c,
    _ST t,
    RecipientInputState recipient,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: recipient.federationSuggestions
          .map(
            (s) => GestureDetector(
              onTap: () => _applyFederationSuggestion(s),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width - 80,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: t.primaryTint,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: t.primaryTintBorder, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.atSign, size: 13, color: c.primary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          s,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildFederationStatus(AppColor c, _ST t, SendState vm) {
    final recipient = vm.recipient;
    final federationInput = recipient.federationInput.trim();
    if (recipient.federationLoading) {
      return RecipientStatusBanner(
        icon: null,
        title: 'Resolving federation address...',
        color: c.primary,
        backgroundColor: t.primaryTint,
        borderColor: t.primaryTintBorder,
        showSpinner: true,
      );
    }
    if (recipient.federationError != null) {
      return RecipientStatusBanner(
        icon: LucideIcons.alertCircle,
        title: recipient.federationError!,
        color: c.error,
        backgroundColor: t.errorTint,
        borderColor: t.errorBorder,
      );
    }
    if (recipient.shouldShowFederationUi &&
        federationInput.isNotEmpty &&
        vm.recipient.activeValueKind == RecipientValueKind.invalid) {
      return RecipientStatusBanner(
        icon: LucideIcons.info,
        title:
            'Enter a federation address like name*${recipient.federationDomain}',
        color: c.primary,
        backgroundColor: t.primaryTint,
        borderColor: t.primaryTintBorder,
      );
    }
    final resolved = recipient.resolvedFederation;
    if (resolved != null && resolved.accountId.trim().isNotEmpty) {
      return RecipientStatusBanner(
        icon: LucideIcons.checkCircle2,
        title: 'Resolved - ${shortenRecipientAddress(resolved.accountId)}',
        subtitle: resolved.stellarAddress,
        color: t.successText,
        backgroundColor: t.successTint,
        borderColor: t.successBorder,
        trailing: recipient.shouldShowFederationUi
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

  Widget _buildTrustlineStatus(AppColor c, _ST t, SendState vm) {
    if (vm.destinationAddress.trim().isEmpty) return const SizedBox.shrink();
    if (vm.checking) {
      return RecipientStatusBanner(
        icon: null,
        title: 'Verifying trustline...',
        color: c.primary,
        backgroundColor: t.primaryTint,
        borderColor: t.primaryTintBorder,
        showSpinner: true,
      );
    }
    if (vm.destinationHasTrustline == false) {
      return RecipientStatusBanner(
        icon: LucideIcons.alertCircle,
        title: 'Cannot receive ${vm.assetSymbol}',
        subtitle: 'Recipient needs to add a ${vm.assetSymbol} trustline first',
        color: c.error,
        backgroundColor: t.errorTint,
        borderColor: t.errorBorder,
      );
    }
    if (vm.destinationHasTrustline == true) {
      return RecipientStatusBanner(
        icon: LucideIcons.checkCircle2,
        title: 'Ready to receive ${vm.assetSymbol}',
        color: t.successText,
        backgroundColor: t.successTint,
        borderColor: t.successBorder,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildSavedRecipientCard(
    AppColor c,
    _ST t, {
    required String name,
    required String address,
    required int colorValue,
    required VoidCallback onEdit,
  }) {
    Color mix(Color a, Color b, double amount) => Color.lerp(a, b, amount)!;
    final brand = Color(colorValue);
    final base = t.isDark ? c.surface : c.onPrimary;
    return RecipientSavedCard(
      name: name,
      address: address,
      colorValue: colorValue,
      onEdit: onEdit,
      backgroundColor: mix(base, brand, t.isDark ? 0.13 : 0.09),
      borderColor: mix(base, brand, t.isDark ? 0.25 : 0.20),
      avatarBackgroundColor: mix(base, brand, t.isDark ? 0.22 : 0.16),
      editBackgroundColor: mix(
        t.isDark ? c.surface : c.background,
        brand,
        0.14,
      ),
      addressColor: t.monoColor,
    );
  }

  Widget _buildNewRecipientCard(
    AppColor c,
    _ST t, {
    required String address,
    required VoidCallback onAdd,
  }) {
    return RecipientNewAddressCard(
      address: address,
      onAdd: onAdd,
      backgroundColor: t.inputBg,
      borderColor: t.chipBorder,
      iconBackgroundColor: t.primaryTint,
      iconColor: t.primaryMuted,
      addressColor: t.monoColor,
      saveBackgroundColor: t.primaryTint,
      saveBorderColor: t.primaryTintBorder,
      saveTextColor: c.primary,
    );
  }

  Widget _buildMemoCard(AppColor c, _ST t) {
    final hasError = _memoBytes > 28;
    return FintechFullBleedSection(
      colors: c,
      emphasisColor: hasError ? c.error : c.primary,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SectionLabel('Memo'),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: t.chipBg,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  'OPTIONAL',
                  style: TextStyle(
                    color: t.metaColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '$_memoBytes / 28',
                style: TextStyle(
                  color: hasError ? c.error : t.metaColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _memoCtl,
            minLines: 2,
            maxLines: 3,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w500,
              color: c.textPrimary,
              letterSpacing: -0.2,
            ),
            decoration: InputDecoration(
              hintText: 'Add a note (e.g. invoice ref, exchange tag)',
              hintStyle: TextStyle(
                color: t.metaColor,
                fontSize: 14,
                letterSpacing: -0.2,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              isDense: false,
            ),
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
          ),
          if (hasError) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(LucideIcons.alertCircle, size: 13, color: c.error),
                const SizedBox(width: 6),
                Text(
                  'Memo exceeds 28 bytes - shorten it',
                  style: TextStyle(
                    color: c.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBreakdownCard(AppColor c, _ST t, SendState vm, String tokenStr) {
    return FintechFullBleedSection(
      colors: c,
      emphasisColor: c.primary,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('Summary'),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: t.primaryTint,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: t.primaryTintBorder, width: 1),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.arrowUpRight, size: 15, color: c.primary),
                const SizedBox(width: 10),
                Text(
                  'Recipient receives',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_numFmt.format(vm.recipientWillReceive)} $tokenStr',
                  style: TextStyle(
                    color: c.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          _buildDivider(t),
          const SizedBox(height: 12),

          _BreakdownRow(
            icon: LucideIcons.zap,
            label: 'Network fee',
            value: '${(vm.estNetworkFeeXlm ?? 0).toStringAsFixed(7)} XLM',
            t: t,
            c: c,
          ),

          if (vm.isXlm && vm.totalDeductFromBalance > 0) ...[
            const SizedBox(height: 8),
            _BreakdownRow(
              icon: LucideIcons.minusCircle,
              label: 'Total deducted',
              value: '${_numFmt.format(vm.totalDeductFromBalance)} XLM',
              t: t,
              c: c,
            ),
          ],
          const SizedBox(height: 8),
          _BreakdownRow(
            icon: LucideIcons.wallet,
            label: 'Remaining',
            value: '${_fmtAmount(vm.remainingExpendable)} $tokenStr',
            t: t,
            c: c,
            muted: true,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(_ST t) => Container(height: 1, color: t.dividerColor);

  Widget _buildActionBar(AppColor c, _ST t, SendState vm) {
    final canSubmit = vm.blockingReason == null && _memoBytes <= 28;
    return FintechBottomActionShell(
      colors: c,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 8, 10),
              child: Row(
                children: [
                  Icon(
                    canSubmit ? LucideIcons.shieldCheck : LucideIcons.info,
                    size: 14,
                    color: canSubmit ? c.success : t.labelColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      canSubmit
                          ? 'Ready to review'
                          : (vm.blockingReason ?? 'Complete required fields'),
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 56,
              child: AppElevatedButton(
                onPressed: canSubmit
                    ? () async {
                        HapticFeedback.mediumImpact();
                        await _confirmAndSend(vm);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canSubmit ? c.primary : t.chipBg,
                  foregroundColor: canSubmit ? c.onPrimary : t.labelColor,
                  disabledBackgroundColor: t.chipBg,
                  disabledForegroundColor: t.labelColor,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      canSubmit ? LucideIcons.send : LucideIcons.lock,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      canSubmit ? 'Review & Send' : 'Complete all fields',
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = _ST.of(context);
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: t.labelColor,
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.9,
        height: 1,
      ),
    );
  }
}

class _MaxButton extends StatelessWidget {
  const _MaxButton({required this.t, required this.c, required this.onTap});
  final _ST t;
  final AppColor c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: t.primaryTint,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: t.primaryTintBorder, width: 1),
        ),
        child: Text(
          'MAX',
          style: TextStyle(
            color: c.primary,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.t,
    required this.c,
    this.muted = false,
  });
  final IconData icon;
  final String label;
  final String value;
  final _ST t;
  final AppColor c;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: muted ? t.metaColor : t.labelColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: muted ? t.metaColor : t.labelColor,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: muted ? t.labelColor : c.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _ReviewSheet extends ConsumerStatefulWidget {
  final SendControllerArgs args;
  final String? recipientName;
  final Future<void> Function()? onTransactionCompleted;
  const _ReviewSheet({
    required this.args,
    this.recipientName,
    this.onTransactionCompleted,
  });

  @override
  ConsumerState<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<_ReviewSheet> {
  String _short(String addr) => addr.length <= 16
      ? addr
      : '${addr.substring(0, 8)}...${addr.substring(addr.length - 8)}';

  Future<void> _confirm(BuildContext ctx) async {
    if (ref.read(sendControllerProvider(widget.args)).submitting) return;
    final rootContext = Navigator.of(ctx, rootNavigator: true).context;
    try {
      final txHash = await ref
          .read(sendControllerProvider(widget.args).notifier)
          .submit();
      if (!ctx.mounted) return;
      await widget.onTransactionCompleted?.call();
      if (!ctx.mounted) return;
      Navigator.pop(ctx, true);
      if (!rootContext.mounted) return;
      showAppAlert(
        rootContext,
        type: AppAlertType.success,
        title: 'Transaction Sent',
        subtitle: 'Broadcast successfully',
        primaryText: 'Copy TxID',
        onPrimary: () async => Clipboard.setData(ClipboardData(text: txHash)),
      );
    } catch (e) {
      if (!ctx.mounted) return;
      showAppAlert(
        ctx,
        type: AppAlertType.error,
        title: 'Transaction Failed',
        subtitle: e.toString(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final t = _ST.of(context);
    final vm = ref.watch(sendControllerProvider(widget.args));
    final tokenStr = vm.assetSymbol;
    final numFmt = NumberFormat('#,##0.######');

    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: c.textPrimary.withValues(alpha: t.isDark ? 0.24 : 0.10),
              blurRadius: 40,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 3,
                margin: const EdgeInsets.only(top: 12, bottom: 22),
                decoration: BoxDecoration(
                  color: t.chipBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CONFIRM',
                          style: TextStyle(
                            color: t.labelColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Transaction',
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    AssetLogo(keyOrSymbol: tokenStr, size: 30),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  decoration: BoxDecoration(
                    color: t.primaryTint,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: t.primaryTintBorder, width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SENDING',
                            style: TextStyle(
                              color: t.labelColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            numFmt.format(vm.recipientWillReceive),
                            style: TextStyle(
                              color: c.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 38,
                              letterSpacing: -1.8,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          tokenStr,
                          style: TextStyle(
                            color: t.primaryMuted,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    _ReviewSection(
                      t: t,
                      c: c,
                      children: [
                        _ReviewRow(
                          t: t,
                          c: c,
                          label: 'From',
                          value: _short(vm.senderAddress),
                          icon: LucideIcons.userCircle,
                        ),
                        Container(
                          height: 1,
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          color: t.dividerColor,
                        ),
                        _ReviewRow(
                          t: t,
                          c: c,
                          label: widget.recipientName != null
                              ? 'To | ${widget.recipientName}'
                              : 'To',
                          value: _short(vm.destinationAddress),
                          icon: LucideIcons.target,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _ReviewSection(
                      t: t,
                      c: c,
                      children: [
                        _ReviewRow(
                          t: t,
                          c: c,
                          label: 'Network fee',
                          value:
                              '${(vm.estNetworkFeeXlm ?? 0).toStringAsFixed(7)} XLM',
                          icon: LucideIcons.zap,
                        ),
                        if (vm.isXlm) ...[
                          Container(
                            height: 1,
                            margin: const EdgeInsets.symmetric(vertical: 10),
                            color: t.dividerColor,
                          ),
                          _ReviewRow(
                            t: t,
                            c: c,
                            label: 'Total deducted',
                            value:
                                '${numFmt.format(vm.totalDeductFromBalance)} XLM',
                            icon: LucideIcons.minusCircle,
                          ),
                        ],
                        Container(
                          height: 1,
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          color: t.dividerColor,
                        ),
                        _ReviewRow(
                          t: t,
                          c: c,
                          label: 'Remaining after send',
                          value:
                              '${numFmt.format(vm.remainingExpendable)} $tokenStr',
                          icon: LucideIcons.wallet,
                          muted: true,
                        ),
                      ],
                    ),
                    if (vm.memo.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _ReviewSection(
                        t: t,
                        c: c,
                        children: [
                          _ReviewRow(
                            t: t,
                            c: c,
                            label: 'Memo',
                            value: vm.memo,
                            icon: LucideIcons.messageSquare,
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: AppOutlinedButton(
                        onPressed: vm.submitting
                            ? null
                            : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: BorderSide(color: t.chipBorder, width: 1.5),
                          foregroundColor: c.textSecondary,
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: AppElevatedButton(
                        onPressed: vm.submitting
                            ? null
                            : () => _confirm(context),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          backgroundColor: c.primary,
                          foregroundColor: AppColor.of(context).onPrimary,
                          disabledBackgroundColor: t.chipBg,
                          elevation: 0,
                        ),
                        child: vm.submitting
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    height: 17,
                                    width: 17,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: AppColor.of(context).onPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Sending...',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14.5,
                                      letterSpacing: -0.2,
                                      color: AppColor.of(context).onPrimary,
                                    ),
                                  ),
                                ],
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(LucideIcons.checkCircle, size: 17),
                                  SizedBox(width: 10),
                                  Text(
                                    'Confirm Send',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14.5,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({
    required this.t,
    required this.c,
    required this.children,
  });
  final _ST t;
  final AppColor c;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: t.inputBg,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: t.chipBorder, width: 1),
      ),
      child: Column(children: children),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.t,
    required this.c,
    required this.label,
    required this.value,
    required this.icon,
    this.muted = false,
  });
  final _ST t;
  final AppColor c;
  final String label;
  final String value;
  final IconData icon;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: muted ? t.metaColor : t.labelColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: t.metaColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                value,
                style: TextStyle(
                  color: muted ? t.labelColor : c.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) =>
      const PageLoader(label: 'Loading wallet...');
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final t = _ST.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: t.errorTint,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: t.errorBorder, width: 1),
              ),
              child: Center(
                child: Icon(
                  LucideIcons.alertTriangle,
                  size: 28,
                  color: c.error,
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Unable to Load',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: t.labelColor,
                fontSize: 13.5,
                height: 1.55,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 26),
            AppElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(LucideIcons.refreshCw, size: 17),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                backgroundColor: c.primary,
                foregroundColor: AppColor.of(context).onPrimary,
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
