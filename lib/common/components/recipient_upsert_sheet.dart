import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:next_fi/features/wallet_home/model/recipient_address_model.dart';
import 'package:next_fi/features/wallet_home/view_model/recipient_address_vm.dart';
import 'package:provider/provider.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

/// Call this to open the sheet.
/// Returns true if something was saved.
Future<bool?> showRecipientUpsertSheet(
    BuildContext context, {
      RecipientAddressModel? initial,
    }) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false, // handle SafeArea inside
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _RecipientEditSheet(initial: initial),
  );
}

class _RecipientEditSheet extends StatefulWidget {
  const _RecipientEditSheet({this.initial});
  final RecipientAddressModel? initial;

  @override
  State<_RecipientEditSheet> createState() => _RecipientEditSheetState();
}

class _RecipientEditSheetState extends State<_RecipientEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _addr;
  late int _color;

  bool _saving = false;
  bool _addrTouched = false;

  static const _palette = <int>[
    0xFF2563EB, // blue-600
    0xFF16A34A, // green-600
    0xFFEA580C, // orange-600
    0xFFDC2626, // red-600
    0xFF7C3AED, // violet-600
    0xFF0891B2, // cyan-700
    0xFF9333EA, // purple-600
    0xFF0EA5E9, // sky-500
  ];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial?.name ?? '');
    _addr = TextEditingController(text: widget.initial?.address ?? '');
    _color = widget.initial?.color ?? Colors.blue.value;

    _name.addListener(() => setState(() {}));
    _addr.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _addr.dispose();
    super.dispose();
  }

  // Accept classic G... and (visually) allow M... muxed;
  // relies on StrKey validator for checksum/account id.
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
      _addr.selection =
          TextSelection.collapsed(offset: _addr.text.length);
      setState(() => _addrTouched = true);
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      return;
    }
    setState(() => _saving = true);
    try {
      final prov = context.read<RecipientAddressVM>();
      final name = _name.text.trim();
      final address = _addr.text.trim();

      if (widget.initial == null) {
        await prov.add(name: name, address: address, color: _color);
      } else {
        await prov.update(
          widget.initial!.id,
          name: name,
          address: address,
          color: _color,
        );
      }
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildHandle() {
    final c = Theme.of(context).colorScheme;
    return Container(
      width: 44,
      height: 5,
      margin: const EdgeInsets.only(top: 8, bottom: 12),
      decoration: BoxDecoration(
        color: c.outlineVariant.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _buildHeader(bool isEdit) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(.1),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(
            isEdit ? Icons.edit : Icons.person_add_alt_1_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            isEdit ? 'Edit Recipient' : 'Add Recipient',
            style: t.titleLarge,
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context, false),
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close',
        )
      ],
    );
  }

  InputDecoration _decoration({
    required String label,
    required String hint,
    IconData? prefix,
    Widget? suffix,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefix == null ? null : Icon(prefix),
      suffixIcon: suffix,
      filled: true,
      fillColor: cs.surfaceContainerHighest.withOpacity(.4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: cs.primary, width: 1.6),
        borderRadius: BorderRadius.circular(14),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  Widget _addressStatus() {
    final cs = Theme.of(context).colorScheme;
    final valid = _addrValid;
    final touched = _addrTouched || _addr.text.isNotEmpty;

    if (!touched) return const SizedBox.shrink();

    final (icon, label, bg) = valid
        ? (Icons.verified_rounded, 'Valid Stellar address', cs.primary.withOpacity(.12))
        : _isMuxedLike
        ? (Icons.error_outline_rounded, 'Muxed (M…) not supported here', cs.error.withOpacity(.10))
        : (Icons.error_outline_rounded, 'Invalid address', cs.error.withOpacity(.10));

    final fg = valid ? cs.primary : cs.error;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: fg)),
        ],
      ),
    );
  }

  Widget _colorPicker() {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Color Tag', style: t.labelLarge),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _palette.map((c) {
            final selected = _color == c;
            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => setState(() => _color = c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: selected ? 36 : 32,
                height: selected ? 36 : 32,
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  boxShadow: selected
                      ? const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    )
                  ]
                      : null,
                ),
                child: selected
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEdit = widget.initial != null;

    final addressSuffix = SizedBox(
      width: 96,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_addr.text.isNotEmpty)
            IconButton(
              tooltip: 'Clear',
              onPressed: () {
                _addr.clear();
                setState(() => _addrTouched = true);
              },
              icon: const Icon(Icons.close_rounded),
            ),
          IconButton(
            tooltip: 'Paste',
            onPressed: _pasteFromClipboard,
            icon: const Icon(Icons.paste_rounded),
          ),
        ],
      ),
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: LayoutBuilder(builder: (context, constraints) {
          final maxW = constraints.maxWidth;
          final isWide = maxW >= 520;

          final content = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: _buildHeader(isEdit),
              ),
              const SizedBox(height: 8),
              Form(
                key: _formKey,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _name,
                        autofocus: widget.initial == null,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: _decoration(
                          label: 'Name',
                          hint: 'e.g. Alice (USDC payouts)',
                          prefix: Icons.badge_outlined,
                        ),
                        validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addr,
                        onTap: () => setState(() => _addrTouched = true),
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.done,
                        decoration: _decoration(
                          label: 'Wallet Address (Stellar / XLM)',
                          hint: 'G… (56 chars) — classic account',
                          prefix: Icons.account_balance_wallet_outlined,
                          suffix: addressSuffix,
                        ),
                        inputFormatters: [
                          // Force uppercase (Stellar base32 uses A–Z and 2–7)
                          TextInputFormatter.withFunction(
                                (oldValue, newValue) => newValue.copyWith(
                              text: newValue.text.toUpperCase(),
                            ),
                          ),
                          FilteringTextInputFormatter.deny(RegExp(r'\s')), // no spaces
                        ],
                        minLines: 1,
                        maxLines: 2,
                        validator: (v) => (v == null || !_isValidStellarAddress(v))
                            ? 'Enter a valid Stellar address (G…)'
                            : null,
                        onFieldSubmitted: (_) => _canSave ? _save() : null,
                      ),
                      _addressStatus(),
                      const SizedBox(height: 16),
                      _colorPicker(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              // Sticky action bar
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _canSave ? _save : null,
                        icon: _saving
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : const Icon(Icons.save_outlined),
                        label: Text(isEdit ? 'Save' : 'Add'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          return SingleChildScrollView(child: content);
        }),
      ),
    );
  }
}
