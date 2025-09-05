import 'package:flutter/material.dart';
import 'package:next_fi/Provider/RecipientAddressProvider.dart';
import 'package:provider/provider.dart';
import '../model/recipient_address.dart';

/// Call this to open the sheet.
/// Returns true if something was saved.
Future<bool?> showRecipientUpsertSheet(
    BuildContext context, {
      RecipientAddress? initial,
    }) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _RecipientEditSheet(initial: initial),
  );
}

class _RecipientEditSheet extends StatefulWidget {
  const _RecipientEditSheet({this.initial});
  final RecipientAddress? initial;

  @override
  State<_RecipientEditSheet> createState() => _RecipientEditSheetState();
}

class _RecipientEditSheetState extends State<_RecipientEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(text: widget.initial?.name ?? '');
  late final TextEditingController _addr = TextEditingController(text: widget.initial?.address ?? '');
  late int _color = widget.initial?.color ?? Colors.blue.value;

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

  bool _looksLikeTron(String a) {
    final s = a.trim();
    // Quick check; replace with your TronWalletService validator if desired.
    return s.isNotEmpty && s.startsWith('T') && s.length >= 34;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final prov = context.read<RecipientAddressProvider>();
    if (widget.initial == null) {
      await prov.add(name: _name.text, address: _addr.text, color: _color);
    } else {
      await prov.update(widget.initial!.id,
          name: _name.text, address: _addr.text, color: _color);
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEdit = widget.initial != null;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44, height: 5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400, borderRadius: BorderRadius.circular(8),
                ),
              ),
              Row(
                children: [
                  Icon(isEdit ? Icons.edit : Icons.person_add_alt_1_rounded),
                  const SizedBox(width: 8),
                  Text(isEdit ? 'Edit Recipient' : 'Add Recipient',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                  )
                ],
              ),
              const SizedBox(height: 8),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _name,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        hintText: 'e.g. Alice (USDT payouts)',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addr,
                      decoration: const InputDecoration(
                        labelText: 'Wallet Address (TRON)',
                        hintText: 'e.g. T... (Base58)',
                        prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                      ),
                      minLines: 1,
                      maxLines: 2,
                      validator: (v) =>
                      (v == null || !_looksLikeTron(v)) ? 'Enter a valid TRON address' : null,
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Color Tag', style: Theme.of(context).textTheme.labelLarge),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _palette.map((c) {
                        final selected = _color == c;
                        return GestureDetector(
                          onTap: () => setState(() => _color = c),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: selected ? 34 : 30,
                            height: selected ? 34 : 30,
                            decoration: BoxDecoration(
                              color: Color(c),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected ? Colors.white : Colors.black12,
                                width: selected ? 3 : 1,
                              ),
                              boxShadow: selected
                                  ? [BoxShadow(color: Colors.black26, blurRadius: 6, offset: const Offset(0, 2))]
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _save,
                            icon: const Icon(Icons.save_outlined),
                            label: Text(isEdit ? 'Save' : 'Add'),
                          ),
                        ),
                      ],
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
