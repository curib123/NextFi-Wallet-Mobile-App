import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:next_fi/features/auth_gate/view/widgets/lock_out_banner.dart';
import 'package:next_fi/features/auth_gate/view_model/auth_gate_vm.dart';
import 'package:next_fi/features/wallet_creation/view/widgets/fintech_background.dart';
import 'package:provider/provider.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/snackbar/SnackBar.dart';

class AuthGateScreen extends StatefulWidget {
  final VoidCallback? goNext;
  const AuthGateScreen({super.key, this.goNext});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  Timer? _smallVisualDelay;
  String _currentPin = '';
  late AuthGateVM _vm;

  // Animation controllers
  late final AnimationController _bgCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  )..repeat();

  late final AnimationController _scaleCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  late final AnimationController _shakeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scaleCtrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _vm.init();
      if (!mounted) return;

      final warn = _vm.state.initWarning;
      if (warn != null) {
        showFloatingSnackBar(context, message: warn, type: SnackBarType.error);
        if (!mounted) return;
      }

      final auto = await _vm.maybeAutoBiometric();
      if (!mounted) return;
      if (auto?.message != null) {
        showFloatingSnackBar(
          context,
          message: auto!.message!,
          type: auto.success ? SnackBarType.success : SnackBarType.error,
        );
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _vm = context.read<AuthGateVM>();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _vm.disposeTimers();
    _smallVisualDelay?.cancel();
    _bgCtrl.dispose();
    _scaleCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _vm.refreshLockout();
      _vm.maybeAutoBiometric();
    }
  }

  void _onSuccessNavigate() {
    _smallVisualDelay?.cancel();
    _smallVisualDelay = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      final goNext = widget.goNext;
      if (goNext != null) {
        goNext();
      } else {
        Navigator.pushReplacementNamed(context, "/home");
      }
    });
  }

  void _onNumberPressed(String number) {
    if (_currentPin.length < 6 && !_vm.isLockedOut && !_vm.state.submitting) {
      setState(() {
        _currentPin += number;
      });
      HapticFeedback.lightImpact();

      if (_currentPin.length == 6) {
        _submit();
      }
    }
  }

  void _onBackspacePressed() {
    if (_currentPin.isNotEmpty && !_vm.state.submitting) {
      setState(() {
        _currentPin = _currentPin.substring(0, _currentPin.length - 1);
      });
      HapticFeedback.lightImpact();
    }
  }

  void _playShakeAnimation() {
    _shakeCtrl.reset();
    _shakeCtrl.forward();
  }

  Future<void> _submit() async {
    final res = await _vm.submitPin(_currentPin);
    if (!mounted) return;

    if (res.message != null) {
      showFloatingSnackBar(
        context,
        message: res.message!,
        type: switch (res.status) {
          PinStatus.saved || PinStatus.verified => SnackBarType.success,
          PinStatus.needFirstConfirm => SnackBarType.info,
          PinStatus.mismatch ||
          PinStatus.invalid ||
          PinStatus.storageError ||
          PinStatus.error =>
          SnackBarType.error,
          PinStatus.lockedOut => SnackBarType.warning,
        },
      );
    }

    switch (res.status) {
      case PinStatus.needFirstConfirm:
        setState(() => _currentPin = '');
        break;
      case PinStatus.mismatch:
      case PinStatus.invalid:
      case PinStatus.storageError:
      case PinStatus.error:
        _playShakeAnimation();
        HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) setState(() => _currentPin = '');
        break;
      case PinStatus.lockedOut:
        setState(() => _currentPin = '');
        break;
      case PinStatus.saved:
      case PinStatus.verified:
        setState(() => _currentPin = '');
        _onSuccessNavigate();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final vm = context.watch<AuthGateVM>();
    final s = vm.state;
    final dpr = MediaQuery.of(context).devicePixelRatio;

    final isLockedOut = vm.isLockedOut;
    final headline = s.isNewUser
        ? (s.firstPinEntry == null ? "Create PIN" : "Confirm PIN")
        : "Enter PIN";
    final subhead = s.isNewUser
        ? (s.firstPinEntry == null
        ? "Set a 6-digit PIN to secure your wallet"
        : "Please enter your PIN again")
        : "Enter your PIN to unlock";

    return WillPopScope(
      onWillPop: () async => Navigator.canPop(context),
      child: Scaffold(
        backgroundColor: colors.background,
        body: Stack(
          children: [
            // Animated background
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _bgCtrl,
                  builder: (_, __) => FintechBackground(
                    progress: _bgCtrl.value,
                    colors: colors,
                    devicePixelRatio: dpr,
                    topBandFraction: .55,
                  ),
                ),
              ),
            ),

            // Main content
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ScaleTransition(
                      scale: CurvedAnimation(
                        parent: _scaleCtrl,
                        curve: Curves.easeOutBack,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Lock icon
                          _LockIcon(
                            unlocked: s.unlockedVisual,
                            colors: colors,
                          ),

                          const SizedBox(height: 32),

                          // Headline
                          Text(
                            headline,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Subheadline
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              subhead,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                color: colors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),

                          if (isLockedOut) ...[
                            const SizedBox(height: 20),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: LockoutBanner(
                                remaining: s.lockoutRemaining!,
                                colors: colors,
                              ),
                            ),
                          ],

                          const SizedBox(height: 48),

                          // PIN dots display
                          AnimatedBuilder(
                            animation: _shakeCtrl,
                            builder: (context, child) {
                              final shake = _shakeCtrl.value;
                              final offset = shake < 0.5
                                  ? shake * 20
                                  : (1 - shake) * 20;
                              return Transform.translate(
                                offset: Offset(
                                  shake > 0 ? (offset - 10) * (shake < 0.5 ? 1 : -1) : 0,
                                  0,
                                ),
                                child: child,
                              );
                            },
                            child: _PinDotsDisplay(
                              pinLength: _currentPin.length,
                              colors: colors,
                              obscure: s.obscurePin,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Custom numeric keyboard with biometric button integrated
                  _NumericKeyboard(
                    onNumberPressed: _onNumberPressed,
                    onBackspacePressed: _onBackspacePressed,
                    colors: colors,
                    enabled: !isLockedOut && !s.submitting,
                    showBiometric: !s.isNewUser &&
                        s.deviceSupportsBiometrics &&
                        s.biometricsEnabled &&
                        !isLockedOut,
                    onBiometricPressed: () async {
                      final res = await _vm.authenticateWithBiometrics();
                      if (!mounted) return;
                      if (res.message != null) {
                        showFloatingSnackBar(
                          context,
                          message: res.message!,
                          type: res.success
                              ? SnackBarType.success
                              : SnackBarType.error,
                        );
                      }
                      if (res.success) _onSuccessNavigate();
                    },
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modern lock icon with animation
class _LockIcon extends StatelessWidget {
  const _LockIcon({
    required this.unlocked,
    required this.colors,
  });

  final bool unlocked;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 400),
      tween: Tween(begin: 0.0, end: unlocked ? 1.0 : 0.0),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                (unlocked ? Colors.green : colors.primary).withOpacity(.15),
                (unlocked ? Colors.green : colors.primary).withOpacity(.05),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: (unlocked ? Colors.green : colors.primary).withOpacity(.2),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Center(
            child: Icon(
              unlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
              size: 36,
              color: unlocked ? Colors.green : colors.primary,
            ),
          ),
        );
      },
    );
  }
}

/// PIN dots display
class _PinDotsDisplay extends StatelessWidget {
  const _PinDotsDisplay({
    required this.pinLength,
    required this.colors,
    required this.obscure,
  });

  final int pinLength;
  final AppColor colors;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (index) {
        final isFilled = index < pinLength;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: isFilled ? 16 : 14,
            height: isFilled ? 16 : 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isFilled
                  ? colors.primary
                  : colors.primary.withOpacity(.15),
              border: Border.all(
                color: isFilled
                    ? colors.primary
                    : colors.primary.withOpacity(.3),
                width: isFilled ? 0 : 2,
              ),
              boxShadow: isFilled
                  ? [
                BoxShadow(
                  color: colors.primary.withOpacity(.4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
                  : null,
            ),
          ),
        );
      }),
    );
  }
}

/// Custom numeric keyboard
class _NumericKeyboard extends StatelessWidget {
  const _NumericKeyboard({
    required this.onNumberPressed,
    required this.onBackspacePressed,
    required this.colors,
    required this.enabled,
    this.showBiometric = false,
    this.onBiometricPressed,
  });

  final Function(String) onNumberPressed;
  final VoidCallback onBackspacePressed;
  final AppColor colors;
  final bool enabled;
  final bool showBiometric;
  final VoidCallback? onBiometricPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _buildRow(['1', '2', '3']),
          const SizedBox(height: 16),
          _buildRow(['4', '5', '6']),
          const SizedBox(height: 16),
          _buildRow(['7', '8', '9']),
          const SizedBox(height: 16),
          _buildRow([
            showBiometric ? 'biometric' : '',
            '0',
            'backspace'
          ]),
        ],
      ),
    );
  }

  Widget _buildRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) {
        if (key.isEmpty) {
          return const Expanded(child: SizedBox());
        }
        if (key == 'biometric') {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _BiometricKeyButton(
                colors: colors,
                onPressed: onBiometricPressed ?? () {},
                enabled: enabled,
              ),
            ),
          );
        }
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _KeyButton(
              label: key,
              onPressed: () {
                if (!enabled) return;
                if (key == 'backspace') {
                  onBackspacePressed();
                } else {
                  onNumberPressed(key);
                }
              },
              colors: colors,
              enabled: enabled,
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Individual key button
class _KeyButton extends StatefulWidget {
  const _KeyButton({
    required this.label,
    required this.onPressed,
    required this.colors,
    required this.enabled,
  });

  final String label;
  final VoidCallback onPressed;
  final AppColor colors;
  final bool enabled;

  @override
  State<_KeyButton> createState() => _KeyButtonState();
}

class _KeyButtonState extends State<_KeyButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isBackspace = widget.label == 'backspace';

    return GestureDetector(
      onTapDown: widget.enabled ? (_) => _controller.forward() : null,
      onTapUp: widget.enabled ? (_) {
        _controller.reverse();
        widget.onPressed();
      } : null,
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final scale = 1.0 - (_controller.value * 0.05);
          return Transform.scale(
            scale: scale,
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: widget.enabled
                    ? widget.colors.surface.withOpacity(.6 + (_controller.value * 0.1))
                    : widget.colors.surface.withOpacity(.3),
                border: Border.all(
                  color: widget.colors.primary.withOpacity(.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.colors.primary.withOpacity(.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Center(
                    child: isBackspace
                        ? Icon(
                      Icons.backspace_outlined,
                      size: 24,
                      color: widget.enabled
                          ? widget.colors.textPrimary
                          : widget.colors.textSecondary.withOpacity(.5),
                    )
                        : Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: widget.enabled
                            ? widget.colors.textPrimary
                            : widget.colors.textSecondary.withOpacity(.5),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Biometric key button (integrated into keyboard)
class _BiometricKeyButton extends StatefulWidget {
  const _BiometricKeyButton({
    required this.colors,
    required this.onPressed,
    required this.enabled,
  });

  final AppColor colors;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  State<_BiometricKeyButton> createState() => _BiometricKeyButtonState();
}

class _BiometricKeyButtonState extends State<_BiometricKeyButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => _controller.forward() : null,
      onTapUp: widget.enabled ? (_) {
        _controller.reverse();
        widget.onPressed();
      } : null,
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final scale = 1.0 - (_controller.value * 0.05);
          return Transform.scale(
            scale: scale,
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: widget.enabled
                    ? widget.colors.surface.withOpacity(.6 + (_controller.value * 0.1))
                    : widget.colors.surface.withOpacity(.3),
                border: Border.all(
                  color: widget.colors.primary.withOpacity(.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.colors.primary.withOpacity(.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Center(
                    child: Icon(
                      Icons.fingerprint,
                      size: 28,
                      color: widget.enabled
                          ? widget.colors.primary
                          : widget.colors.primary.withOpacity(.5),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Biometric quick action button (deprecated - now integrated into keyboard)
class _BiometricButton extends StatelessWidget {
  const _BiometricButton({
    required this.colors,
    required this.onPressed,
  });

  final AppColor colors;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: colors.surface.withOpacity(.5),
          border: Border.all(
            color: colors.primary.withOpacity(.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fingerprint,
              size: 20,
              color: colors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Use Biometrics',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}