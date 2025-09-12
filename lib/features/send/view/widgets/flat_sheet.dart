import 'package:flutter/material.dart';
import 'package:next_fi/Helper/AppColor.dart';

class FlatSheet extends StatelessWidget {
  const FlatSheet({super.key, required this.child, this.maxHeightFactor = 0.92});
  final Widget child;
  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final h = MediaQuery.of(context).size.height;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: c.surface,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
          elevation: 0,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: h * maxHeightFactor),
            child: SafeArea(top: false, child: child),
          ),
        ),
      ),
    );
  }
}
