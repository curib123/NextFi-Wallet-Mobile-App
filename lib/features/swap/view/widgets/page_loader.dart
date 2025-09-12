import 'package:flutter/material.dart';

class PageLoader extends StatelessWidget {
  const PageLoader({super.key});
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.only(top: 60),
      child: SizedBox(height: 26, width: 26, child: CircularProgressIndicator(strokeWidth: 2)),
    ),
  );
}
