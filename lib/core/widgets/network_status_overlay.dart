import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:next_fi/app/config/app_providers.dart';
import 'package:next_fi/app/theme/app_color.dart';

/// App-level overlay that wraps the entire widget tree and shows an animated
/// bottom banner while the device is offline, then briefly confirms reconnect.
class NetworkStatusOverlay extends ConsumerWidget {
  const NetworkStatusOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monitor = ref.watch(networkMonitorProvider);
    final showBanner = !monitor.isOnline || monitor.justReconnected;
    return Stack(
      children: [
        child,
        AnimatedPositioned(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeInOut,
          left: 0,
          right: 0,
          bottom: showBanner ? 0 : -120,
          child: _NetworkBanner(
            isOnline: monitor.isOnline,
            justReconnected: monitor.justReconnected,
          ),
        ),
      ],
    );
  }
}

class _NetworkBanner extends StatelessWidget {
  const _NetworkBanner({
    required this.isOnline,
    required this.justReconnected,
  });

  final bool isOnline;
  final bool justReconnected;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final isConnected = isOnline && justReconnected;
    final bgColor = isConnected
        ? colors.success
        : colors.textPrimary;
    final textColor = colors.onPrimary;
    final iconColor = colors.onPrimary;

    return Material(
      color: colors.surface,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          boxShadow: [
            BoxShadow(
              color: colors.textPrimary.withValues(alpha: ((51) / 255.0)),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (isConnected) ...[
                  Icon(
                    Icons.check_circle_rounded,
                    color: iconColor,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Back online',
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                        Text(
                          'Connection restored.',
                          style: TextStyle(
                            color: textColor.withValues(alpha: ((204) / 255.0)),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  _PulsingDot(color: colors.error),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'No internet connection',
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                        Text(
                          'You are offline. Some wallet data may be unavailable.',
                          style: TextStyle(
                            color: textColor.withValues(alpha: ((178) / 255.0)),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.wifi_off_rounded, color: iconColor, size: 18),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});
  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

