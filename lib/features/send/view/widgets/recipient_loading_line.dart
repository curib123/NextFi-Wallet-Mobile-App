// lib/features/send/view/widgets/recipient_loading_line.dart
import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class RecipientLoadingLine extends StatefulWidget {
  const RecipientLoadingLine({super.key});

  @override
  State<RecipientLoadingLine> createState() => _RecipientLoadingLineState();
}

class _RecipientLoadingLineState extends State<RecipientLoadingLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final alpha = 0.03 + (_ctrl.value * 0.05);
        return Container(
          height: 56,
          decoration: BoxDecoration(
            color: c.primary.withValues(alpha: alpha),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.primary.withValues(alpha: 0.06)),
          ),
          child: Center(
            child: SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                color: c.primary.withValues(alpha: 0.35),
              ),
            ),
          ),
        );
      },
    );
  }
}