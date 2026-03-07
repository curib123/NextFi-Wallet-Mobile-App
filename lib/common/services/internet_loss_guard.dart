import 'package:flutter/material.dart';

class InternetLossGuard extends StatefulWidget {
  const InternetLossGuard({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<InternetLossGuard> createState() => _InternetLossGuardState();
}

class _InternetLossGuardState extends State<InternetLossGuard> {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
