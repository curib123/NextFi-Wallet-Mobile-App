import 'package:flutter/material.dart';
import 'package:next_fi/common/services/network_monitor.dart';
import 'package:provider/provider.dart';

/// App-level overlay that wraps the entire widget tree and shows an animated
/// bottom banner when the device goes offline, then auto-closes on reconnect.
class NetworkStatusOverlay extends StatelessWidget {
  const NetworkStatusOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkMonitor>(
      builder: (_, monitor, __) {
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
      },
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
    final isConnected = isOnline && justReconnected;
    final bgColor = isConnected
        ? const Color(0xFF22C55E)
        : const Color(0xFF1E1E2E);
    final textColor = Colors.white;
    final iconColor = Colors.white;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(51),
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
                          'Connection restored. Closing automatically...',
                          style: TextStyle(
                            color: textColor.withAlpha(204),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  _PulsingDot(color: const Color(0xFFEF4444)),
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
                          'Waiting to reconnect... Retrying automatically.',
                          style: TextStyle(
                            color: textColor.withAlpha(178),
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
