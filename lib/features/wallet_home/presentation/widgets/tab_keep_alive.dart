import 'package:flutter/material.dart';

class TabKeepAlive extends StatefulWidget {
  const TabKeepAlive({
    super.key,
    required this.child,
    required this.storageKey,
  });
  final Widget child;
  final String storageKey;
  @override
  State<TabKeepAlive> createState() => _TabKeepAliveState();
}

class _TabKeepAliveState extends State<TabKeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return KeyedSubtree(
      key: PageStorageKey(widget.storageKey),
      child: widget.child,
    );
  }
}
