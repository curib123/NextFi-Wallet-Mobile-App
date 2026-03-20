import 'package:flutter/material.dart';
import 'package:next_fi/core/widgets/empty_state/empty_state.dart';

class EmptyChart extends StatelessWidget {
  const EmptyChart({super.key});

  @override
  Widget build(BuildContext context) {
    return EmptyState.noData(
      context: context,
      title: 'No data',
      message: 'Chart data is not available for this range yet.',
      compact: true,
      fill: true,
    );
  }
}
