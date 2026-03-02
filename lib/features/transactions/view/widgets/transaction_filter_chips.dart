import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/features/transactions/model/tx.dart';
import 'package:next_fi/features/transactions/view_model/transactions_vm.dart';

class TransactionFilterChips extends StatelessWidget {
  const TransactionFilterChips({
    super.key,
    required this.colors,
    required this.vm,
  });

  final AppColor colors;
  final TransactionsVM vm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          _chip(label: 'All', value: TxFilter.all),
          const SizedBox(width: 8),
          _chip(label: 'Receive', value: TxFilter.receive),
          const SizedBox(width: 8),
          _chip(label: 'Send', value: TxFilter.send),
        ],
      ),
    );
  }

  Widget _chip({required String label, required TxFilter value}) {
    final selected = vm.state.filter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: selected ? colors.onPrimary : colors.primary,
        ),
      ),
      selected: selected,
      showCheckmark: false,
      selectedColor: colors.primary,
      backgroundColor: colors.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? colors.surface : colors.primary.withValues(alpha: 0.55),
          width: 1.2,
        ),
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      onSelected: (_) => vm.setFilter(value),
    );
  }
}

