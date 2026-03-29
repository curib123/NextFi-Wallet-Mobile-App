import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:next_fi/app/config/app_providers.dart';
import 'package:next_fi/features/contact/presentation/viewmodels/contact_list_notifier.dart';
import 'package:next_fi/features/contact/data/models/recipient_address_model.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:next_fi/core/widgets/button/custom_button.dart';
import 'package:next_fi/core/widgets/modal/base/app_modal_base.dart';

Future<bool?> showRecipientUpsertSheet(
  BuildContext context, {
  RecipientAddressModel? initial,
  String? address,
}) {
  return showAppModalBottomSheet<bool>(
    context,
    useSafeArea: false,
    builder: (_) => _RecipientEditSheet(initial: initial, address: address),
  );
}

class _RecipientEditSheet extends ConsumerStatefulWidget {
  const _RecipientEditSheet({this.initial, this.address});
  final RecipientAddressModel? initial;
  final String? address;

  @override
  ConsumerState<_RecipientEditSheet> createState() =>
      _RecipientEditSheetState();
}

class _RecipientEditSheetState extends ConsumerState<_RecipientEditSheet>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _addr;
  late int _color;
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  bool _saving = false;
  bool _addrTouched = false;
  String? _statusMessage;
  bool _statusIsError = false;
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _addrFocus = FocusNode();

  void _onFocusChange() => setState(() {});

  static const _palette = <int>[
    0xFF7B16FF,
    0xFF00D4FF,
    0xFF00E676,
    0xFFFFB300,
    0xFFFF1744,
    0xFF627EEA,
    0xFFF7931A,
    0xFF9C27B0,
  ];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial?.name ?? '');
    _addr = TextEditingController(text: widget.initial?.address ?? '');
    _color = widget.initial?.color ?? _palette.first;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );

    _animController.forward();

    if ((_addr.text.isEmpty) &&
        (widget.address != null) &&
        widget.address!.trim().isNotEmpty) {
      final incoming = widget.address!.trim().toUpperCase().replaceAll(
        RegExp(r'\s+'),
        '',
      );
      _addr.text = incoming;
      _addr.selection = TextSelection.collapsed(offset: _addr.text.length);
      _addrTouched = true;
    }

    _name.addListener(() => setState(() {}));
    _addr.addListener(() => setState(() {}));
    _nameFocus.addListener(_onFocusChange);
    _addrFocus.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _nameFocus.removeListener(_onFocusChange);
    _addrFocus.removeListener(_onFocusChange);
    _animController.dispose();
    _name.dispose();
    _addr.dispose();
    _nameFocus.dispose();
    _addrFocus.dispose();
    super.dispose();
  }

  bool _isValidStellarAddress(String a) {
    final s = a.trim();
    return StrKey.isValidStellarAccountId(s);
  }

  bool get _isMuxedLike => _addr.text.trim().startsWith('M');
  bool get _addrValid => _isValidStellarAddress(_addr.text);
  bool get _nameValid => _name.text.trim().isNotEmpty;
  bool get _canSave => _nameValid && _addrValid && !_saving;

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      _addr.text = text.toUpperCase().replaceAll(RegExp(r'\s+'), '');
      _addr.selection = TextSelection.collapsed(offset: _addr.text.length);
      setState(() {
        _addrTouched = true;
        _statusMessage = 'Address pasted from clipboard.';
        _statusIsError = false;
      });
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _save() async {
    final notifier = ref.read(contactListProvider.notifier);

    if (ref.read(contactListProvider).loading) {
      await notifier.ensureLoaded();
      if (!mounted) return;
    }

    final prov = ref.read(contactListProvider);
    if (!prov.isAuthenticated) {
      setState(() {
        _statusMessage = 'Open an active wallet session to save recipients.';
        _statusIsError = true;
      });
      return;
    }

    if (!_formKey.currentState!.validate()) {
      setState(() {
        _statusMessage =
            'Enter a name and a valid Stellar address to continue.';
        _statusIsError = true;
      });
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() {
      _saving = true;
      _statusMessage = null;
      _statusIsError = false;
    });
    try {
      final name = _name.text.trim();
      final address = _addr.text.trim().toUpperCase();
      final activeWalletAddress =
          ref.read(seedKeypairProvider).accountId?.trim().toUpperCase() ?? '';

      if (activeWalletAddress.isNotEmpty && address == activeWalletAddress) {
        setState(() {
          _saving = false;
          _statusMessage =
              'You cannot save the active wallet as a recipient. Add a different address instead.';
          _statusIsError = true;
        });
        return;
      }

      if (widget.initial == null) {
        await notifier.add(name: name, address: address, color: _color);
      } else {
        final updated = await notifier.update(
          widget.initial!.id,
          name: name,
          address: address,
          color: _color,
        );
        if (updated == null) {
          throw Exception(
            'Recipient no longer exists. Please refresh and try again.',
          );
        }
      }
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _statusMessage = widget.initial != null
            ? 'Recipient updated.'
            : 'Recipient added.';
        _statusIsError = false;
      });

      await _animController.reverse();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = _friendlyError(e);
        _statusIsError = true;
        _saving = false;
      });
    }
  }

  String _friendlyError(Object e) {
    final raw = e.toString();
    if (raw.contains('You cannot save the active wallet as a recipient')) {
      return 'You cannot save the active wallet as a recipient.';
    }
    if (raw.contains('Not authenticated') ||
        raw.contains('401') ||
        raw.contains('wallet session')) {
      return 'Wallet session expired. Reopen the active wallet and try again.';
    }
    if (raw.contains('HTTP 400:')) {
      final parsed = _extractBackendMessage(raw);
      if (parsed != null && parsed.isNotEmpty) {
        return parsed;
      }
    }
    final cleaned = raw.startsWith('Exception: ')
        ? raw.substring('Exception: '.length)
        : raw;
    return 'Failed to save: $cleaned';
  }

  String? _extractBackendMessage(String raw) {
    final jsonStart = raw.indexOf('{');
    if (jsonStart < 0) return null;

    try {
      final decoded = jsonDecode(raw.substring(jsonStart));
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
        if (message is List) {
          final parts = message
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList();
          if (parts.isNotEmpty) {
            return parts.join(' ');
          }
        }
      }
    } catch (_) {}

    return null;
  }

  Future<void> _close() async {
    await _animController.reverse();
    if (!mounted) return;
    Navigator.of(context).pop(false);
  }

  Widget _buildHeader(bool isEdit) {
    final c = AppColor.of(context);
    final prov = ref.watch(contactListProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: c.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: c.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  isEdit ? LucideIcons.edit3 : LucideIcons.userPlus,
                  color: AppColor.of(context).onPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEdit ? 'Edit Recipient' : 'Add Recipient',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEdit
                          ? 'Update contact details'
                          : 'Save for quick transfers',
                      style: TextStyle(fontSize: 13, color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              Material(
                color: AppColor.of(context).surface,
                child: InkWell(
                  onTap: _close,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    child: Icon(
                      LucideIcons.x,
                      color: c.textSecondary,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (!prov.loading && !prov.isAuthenticated)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: c.warning.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.alertCircle, color: c.warning, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Active wallet session required to save recipients',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    final message = _statusMessage;
    if (message == null || message.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final c = AppColor.of(context);
    final accent = _statusIsError ? c.error : c.success;
    final icon = _statusIsError
        ? LucideIcons.alertCircle
        : LucideIcons.badgeCheck;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: accent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addressStatus() {
    final c = AppColor.of(context);
    final valid = _addrValid;
    final touched = _addrTouched || _addr.text.isNotEmpty;

    if (!touched) return const SizedBox.shrink();

    final (icon, label, bgColor, fgColor) = valid
        ? (
            LucideIcons.checkCircle2,
            'Valid Stellar address',
            c.success.withValues(alpha: 0.12),
            c.success,
          )
        : _isMuxedLike
        ? (
            LucideIcons.alertCircle,
            'Muxed (M...) not supported',
            c.warning.withValues(alpha: 0.12),
            c.warning,
          )
        : (
            LucideIcons.xCircle,
            'Invalid address format',
            c.error.withValues(alpha: 0.12),
            c.error,
          );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fgColor.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fgColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fgColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _colorPicker() {
    final c = AppColor.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Color Tag',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: c.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _palette.map((colorValue) {
            final selected = _color == colorValue;
            return Material(
              color: AppColor.of(context).surface,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () {
                  setState(() => _color = colorValue);
                  HapticFeedback.selectionClick();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: selected ? 44 : 40,
                  height: selected ? 44 : 40,
                  decoration: BoxDecoration(
                    color: Color(colorValue),
                    shape: BoxShape.circle,
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: Color(colorValue).withValues(alpha: 0.4),
                              blurRadius: 12,
                              spreadRadius: 2,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                    border: selected
                        ? Border.all(
                            color: AppColor.of(context).onPrimary,
                            width: 3,
                          )
                        : null,
                  ),
                  child: selected
                      ? Icon(
                          LucideIcons.check,
                          color: AppColor.of(context).onPrimary,
                          size: 20,
                        )
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffix,
    int? maxLines,
    TextInputAction? textInputAction,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization? textCapitalization,
    String? Function(String?)? validator,
    VoidCallback? onTap,
    Function(String)? onFieldSubmitted,
  }) {
    final c = AppColor.of(context);
    final isFocused = focusNode.hasFocus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: c.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isFocused
                  ? c.primary.withValues(alpha: 0.5)
                  : c.border.withValues(alpha: 0.3),
              width: isFocused ? 2 : 1,
            ),
            boxShadow: isFocused
                ? [
                    BoxShadow(
                      color: c.primary.withValues(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            onTap: onTap,
            textCapitalization: textCapitalization ?? TextCapitalization.none,
            textInputAction: textInputAction,
            inputFormatters: inputFormatters,
            maxLines: maxLines ?? 1,
            minLines: 1,
            validator: validator,
            onFieldSubmitted: onFieldSubmitted,
            style: TextStyle(
              fontSize: maxLines != null ? 12 : 15,
              fontWeight: FontWeight.w500,
              color: c.textPrimary,
              letterSpacing: maxLines != null ? 0.3 : 0,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: maxLines != null ? 12 : 14,
                color: c.textSecondary.withValues(alpha: 0.5),
              ),
              prefixIcon: Icon(
                icon,
                color: isFocused ? c.primary : c.textSecondary,
                size: 20,
              ),
              suffixIcon: suffix,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final isEdit = widget.initial != null;
    final prov = ref.watch(contactListProvider);
    final canSubmit = _canSave && !prov.loading && prov.isAuthenticated;

    final addressSuffix = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_addr.text.isNotEmpty)
          IconButton(
            tooltip: 'Clear',
            onPressed: () {
              _addr.clear();
              setState(() => _addrTouched = true);
              HapticFeedback.selectionClick();
            },
            icon: Icon(LucideIcons.x, size: 18, color: c.textSecondary),
          ),
        IconButton(
          tooltip: 'Paste',
          onPressed: _pasteFromClipboard,
          icon: Icon(LucideIcons.clipboard, size: 18, color: c.primary),
        ),
      ],
    );

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: AppModalBase(
          backgroundColor: c.background,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(isEdit),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildStatusBanner(),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildInputField(
                          controller: _name,
                          focusNode: _nameFocus,
                          label: 'Recipient Name',
                          hint: 'e.g., Alice - USDC payouts',
                          icon: LucideIcons.user,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Please enter a name'
                              : null,
                        ),
                        const SizedBox(height: 20),

                        _buildInputField(
                          controller: _addr,
                          focusNode: _addrFocus,
                          label: 'Stellar Address',
                          hint: 'G... (56 characters)',
                          icon: LucideIcons.wallet,
                          suffix: addressSuffix,
                          maxLines: 3,
                          textInputAction: TextInputAction.done,
                          inputFormatters: [
                            TextInputFormatter.withFunction(
                              (oldValue, newValue) => newValue.copyWith(
                                text: newValue.text.toUpperCase(),
                              ),
                            ),
                            FilteringTextInputFormatter.deny(RegExp(r'\s')),
                          ],
                          validator: (v) =>
                              (v == null || !_isValidStellarAddress(v))
                              ? 'Invalid Stellar address'
                              : null,
                          onTap: () => setState(() => _addrTouched = true),
                          onFieldSubmitted: (_) => canSubmit ? _save() : null,
                        ),
                        _addressStatus(),
                        const SizedBox(height: 24),

                        _colorPicker(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border(
                    top: BorderSide(
                      color: c.border.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        text: 'Cancel',
                        type: _saving
                            ? ButtonType.disabled
                            : ButtonType.outlined,
                        onPressed: _saving ? () {} : _close,
                        fullWidth: true,
                        icon: LucideIcons.x,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: CustomButton(
                        text: _saving
                            ? 'Saving...'
                            : prov.loading
                            ? 'Checking session...'
                            : !prov.isAuthenticated
                            ? 'Login Required'
                            : (isEdit ? 'Save Changes' : 'Add Recipient'),
                        type: canSubmit
                            ? ButtonType.filled
                            : ButtonType.disabled,
                        onPressed: canSubmit ? _save : () {},
                        fullWidth: true,
                        icon: _saving
                            ? LucideIcons.loader2
                            : !prov.isAuthenticated
                            ? LucideIcons.lock
                            : LucideIcons.check,
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
