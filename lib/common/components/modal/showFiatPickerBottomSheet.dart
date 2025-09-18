// lib/common/components/fiat_picker_sheet.dart
import 'package:flutter/material.dart';
import 'package:next_fi/reusable_view_model/currency_vm.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/AppColor.dart';

/// Call this to open the modal. Returns the selected fiat code (e.g., "php") or null if cancelled.
Future<String?> showFiatPickerBottomSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _FiatPickerSheet(),
  );
}

class _FiatPickerSheet extends StatefulWidget {
  const _FiatPickerSheet({super.key});
  @override
  State<_FiatPickerSheet> createState() => _FiatPickerSheetState();
}

class _FiatPickerSheetState extends State<_FiatPickerSheet> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    final current = context.read<CurrencyVM>().fiat.toLowerCase();
    _selected = _kFiats.any((f) => f.code == current) ? current : 'usd';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = (AppColor.of(context)); // fallback to your app’s primary tint

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.badgeDollarSign, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Select Fiat Currency",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.x),
                onPressed: () => Navigator.pop(context),
                tooltip: "Close",
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Dropdown
          DropdownButtonFormField<String>(
            value: _selected,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: "Fiat",
              hintText: "Choose a currency",
              filled: true,
              fillColor: cs.surfaceContainerLowest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            items: _kFiats
                .map((f) => DropdownMenuItem<String>(
              value: f.code,
              child: Row(
                children: [
                  Text(f.flag, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Text("${f.code.toUpperCase()} • ${f.name}"),
                ],
              ),
            ))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selected = val);
            },
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text("Cancel"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    context.read<CurrencyVM>().setFiat(_selected);
                    Navigator.pop(context, _selected);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text("Apply"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ---- Fiat options (common & PH-focused set) ----
/// Add/remove freely; codes should be lowercase to match CurrencyProvider.
class _Fiat {
  final String code; // e.g., "usd"
  final String name; // e.g., "US Dollar"
  final String flag; // emoji flag
  const _Fiat(this.code, this.name, this.flag);
}

const List<_Fiat> _kFiats = [
  _Fiat('php', 'Philippine Peso', '🇵🇭'),
  _Fiat('usd', 'US Dollar', '🇺🇸'),
  _Fiat('eur', 'Euro', '🇪🇺'),
  _Fiat('jpy', 'Japanese Yen', '🇯🇵'),
  _Fiat('cny', 'Chinese Yuan', '🇨🇳'),
  _Fiat('hkd', 'Hong Kong Dollar', '🇭🇰'),
  _Fiat('sgd', 'Singapore Dollar', '🇸🇬'),
  _Fiat('aud', 'Australian Dollar', '🇦🇺'),
  _Fiat('nzd', 'New Zealand Dollar', '🇳🇿'),
  _Fiat('gbp', 'British Pound', '🇬🇧'),
  _Fiat('cad', 'Canadian Dollar', '🇨🇦'),
  _Fiat('inr', 'Indian Rupee', '🇮🇳'),
  _Fiat('thb', 'Thai Baht', '🇹🇭'),
  _Fiat('idr', 'Indonesian Rupiah', '🇮🇩'),
  _Fiat('myr', 'Malaysian Ringgit', '🇲🇾'),
  _Fiat('vnd', 'Vietnamese Dong', '🇻🇳'),
  _Fiat('twd', 'New Taiwan Dollar', '🇹🇼'),
  _Fiat('krw', 'South Korean Won', '🇰🇷'),
  _Fiat('aed', 'UAE Dirham', '🇦🇪'),
  _Fiat('sar', 'Saudi Riyal', '🇸🇦'),
  _Fiat('brl', 'Brazilian Real', '🇧🇷'),
  _Fiat('mxn', 'Mexican Peso', '🇲🇽'),
  _Fiat('chf', 'Swiss Franc', '🇨🇭'),
  _Fiat('sek', 'Swedish Krona', '🇸🇪'),
  _Fiat('nok', 'Norwegian Krone', '🇳🇴'),
  _Fiat('dkk', 'Danish Krone', '🇩🇰'),
  _Fiat('pln', 'Polish Złoty', '🇵🇱'),
  _Fiat('czk', 'Czech Koruna', '🇨🇿'),
  _Fiat('huf', 'Hungarian Forint', '🇭🇺'),
  _Fiat('try', 'Turkish Lira', '🇹🇷'),
  _Fiat('ils', 'Israeli Shekel', '🇮🇱'),
  _Fiat('ngn', 'Nigerian Naira', '🇳🇬'),
  _Fiat('zar', 'South African Rand', '🇿🇦'),
];

