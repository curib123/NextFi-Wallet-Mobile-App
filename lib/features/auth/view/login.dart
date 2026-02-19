import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/modal/login_success_modal.dart';
import 'package:next_fi/features/auth/view_model/login_vm.dart';
import 'package:next_fi/services/oath2.0/models/auth_exception.dart';
import 'package:next_fi/features/wallet_creation/view/widgets/fintech_background.dart';

// ═══════════════════════════════════════════════════════════════════
// LOGIN SCREEN
// ═══════════════════════════════════════════════════════════════════

class LoginScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;
  const LoginScreen({super.key, this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final vm = LoginVM();

  bool _googleLoading = false;
  bool _facebookLoading = false;
  bool _visible = false;

  late final AnimationController _bgCtrl;

  @override
  void initState() {
    super.initState();

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    super.dispose();
  }

  // ── System UI ────────────────────────────────────────────────────

  void _applySystemUi(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: isDark
            ? AppColor.dark.background
            : AppColor.light.background,
      ),
    );
  }

  // ── Auth ─────────────────────────────────────────────────────────

  Future<void> _signInGoogle() async {
    if (_googleLoading || _facebookLoading) return;

    HapticFeedback.lightImpact();
    setState(() => _googleLoading = true);

    try {
      final user = await vm.signInGoogle();

      if (!mounted) return;

      setState(() => _googleLoading = false);

      if (user != null) {
        HapticFeedback.mediumImpact();

        // Show success modal
        await showLoginSuccessModal(context, user: user);

        if (!mounted) return;

        // Trigger success callback
        widget.onLoginSuccess?.call();

        // Navigate back
        Navigator.pop(context, true);
      } else {
        _snack('Login was cancelled or failed');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _googleLoading = false);
        _snack(e.toString());
      }
    }
  }

  Future<void> _signInFacebook() async {
    if (_googleLoading || _facebookLoading) return;

    HapticFeedback.lightImpact();
    setState(() => _facebookLoading = true);

    try {
      final user = await vm.signInFacebook();

      if (!mounted) return;

      setState(() => _facebookLoading = false);

      if (user != null) {
        HapticFeedback.mediumImpact();

        // Show success modal
        await showLoginSuccessModal(context, user: user);

        if (!mounted) return;

        // Trigger success callback
        widget.onLoginSuccess?.call();

        // Navigate back
        Navigator.pop(context, true);
      } else {
        _snack('Login was cancelled or failed');
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _facebookLoading = false);
        _snack(e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _facebookLoading = false);
        _snack('Something went wrong');
      }
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: AppColor.dark.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _applySystemUi(isDark ? Brightness.dark : Brightness.light);
    final bottom = MediaQuery.of(context).padding.bottom;
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;

    // ✅ Show loading overlay when any auth is in progress
    final isLoading = _googleLoading || _facebookLoading;

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // ── Fintech animated background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bgCtrl,
              builder: (_, __) {
                return FintechBackground(
                  progress: _bgCtrl.value,
                  devicePixelRatio: devicePixelRatio,
                  topBandFraction: 0.55,
                  colors: AppColor.of(context),
                );
              },
            ),
          ),

          // ── Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(flex: 3),

                  // ── Logo
                  _fadeSlide(visible: _visible, delay: 0, child: _buildLogo()),

                  const SizedBox(height: 20),

                  // ── Headline
                  _fadeSlide(
                    visible: _visible,
                    delay: 80,
                    child: _buildHeadline(colors),
                  ),

                  const Spacer(flex: 4),

                  // ── Buttons
                  _fadeSlide(
                    visible: _visible,
                    delay: 160,
                    child: _buildButtons(colors, isDark),
                  ),

                  const SizedBox(height: 24),

                  // ── Terms
                  _fadeSlide(
                    visible: _visible,
                    delay: 220,
                    child: _buildTerms(colors),
                  ),

                  SizedBox(height: bottom + 24),
                ],
              ),
            ),
          ),

          // ✅ Loading overlay
          if (isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation(colors.primary),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Signing you in...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please wait',
                          style: TextStyle(
                            fontSize: 14,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Fade + slide helper ──────────────────────────────────────────

  Widget _fadeSlide({
    required bool visible,
    required int delay,
    required Widget child,
  }) {
    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: Duration(milliseconds: 500 + delay),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 0.12),
        duration: Duration(milliseconds: 600 + delay),
        curve: Curves.easeOutCubic,
        child: child,
      ),
    );
  }

  // ── Logo ─────────────────────────────────────────────────────────

  Widget _buildLogo() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3A5BFF).withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          'assets/icon/ic_stat_notification.png',
          width: 56,
          height: 56,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  // ── Headline ─────────────────────────────────────────────────────

  Widget _buildHeadline(AppColor colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome to\nNextFi',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
            letterSpacing: -1.0,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Manage your XLM & USDC pair — send, receive, claim balances, and trade seamlessly. Login is optional for buy & sell.',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: colors.textSecondary,
            height: 1.55,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }

  // ── Buttons ──────────────────────────────────────────────────────

  Widget _buildButtons(AppColor colors, bool isDark) {
    final googleBg = isDark ? const Color(0xFFFFFFFF) : const Color(0xFFFFFFFF);
    const googleText = Color(0xFF1A1A2E);

    final fbBg = colors.surface;
    final fbText = colors.textPrimary;

    return Column(
      children: [
        _AuthButton(
          label: 'Continue with Google',
          icon: const _GoogleIcon(),
          isLoading: _googleLoading,
          onTap: _signInGoogle,
          backgroundColor: googleBg,
          textColor: googleText,
          borderColor: isDark ? null : colors.border,
          loadingColor: const Color(0xFF3A5BFF),
        ),
        const SizedBox(height: 12),
        _AuthButton(
          label: 'Continue with Facebook',
          icon: const _FacebookIcon(),
          isLoading: _facebookLoading,
          onTap: _signInFacebook,
          backgroundColor: fbBg,
          textColor: fbText,
          borderColor: colors.border,
          loadingColor: const Color(0xFF1877F2),
        ),
      ],
    );
  }

  // ── Terms ────────────────────────────────────────────────────────

  Widget _buildTerms(AppColor colors) {
    return Center(
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: TextStyle(
            fontSize: 12,
            color: colors.textSecondary.withOpacity(0.6),
            height: 1.6,
          ),
          children: [
            const TextSpan(text: 'By continuing, you agree to our '),
            TextSpan(
              text: 'Terms of Service',
              style: TextStyle(
                color: const Color(0xFF3A5BFF).withOpacity(0.85),
                fontWeight: FontWeight.w500,
              ),
            ),
            const TextSpan(text: ' and '),
            TextSpan(
              text: 'Privacy Policy',
              style: TextStyle(
                color: const Color(0xFF3A5BFF).withOpacity(0.85),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// AUTH BUTTON
// ═══════════════════════════════════════════════════════════════════

class _AuthButton extends StatefulWidget {
  final String label;
  final Widget icon;
  final bool isLoading;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;
  final Color loadingColor;

  const _AuthButton({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.onTap,
    required this.backgroundColor,
    required this.textColor,
    required this.loadingColor,
    this.borderColor,
  });

  @override
  State<_AuthButton> createState() => _AuthButtonState();
}

class _AuthButtonState extends State<_AuthButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.isLoading
          ? null
          : (_) => setState(() => _pressed = true),
      onTapUp: widget.isLoading
          ? null
          : (_) {
              setState(() => _pressed = false);
              widget.onTap();
            },
      onTapCancel: widget.isLoading
          ? null
          : () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: _pressed
                ? widget.backgroundColor.withOpacity(0.82)
                : widget.backgroundColor,
            borderRadius: BorderRadius.circular(14),
            border: widget.borderColor != null
                ? Border.all(color: widget.borderColor!, width: 1)
                : null,
            boxShadow: _pressed
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Center(
            child: widget.isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(widget.loadingColor),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      widget.icon,
                      const SizedBox(width: 12),
                      Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: widget.textColor,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// GOOGLE ICON
// ═══════════════════════════════════════════════════════════════════

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final cx = s / 2;
    final cy = s / 2;
    final r = s / 2;

    final bounds = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    final blue = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final red = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.fill;
    final yellow = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.fill;
    final green = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.fill;
    final white = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawArc(bounds, -math.pi / 2, math.pi, true, blue);
    canvas.drawArc(bounds, 0, math.pi / 2, true, green);
    canvas.drawArc(bounds, math.pi / 2, math.pi / 2, true, yellow);
    canvas.drawArc(bounds, math.pi, math.pi / 2, true, red);

    canvas.drawCircle(Offset(cx, cy), r * 0.58, white);

    final barTop = cy - r * 0.195;
    final barBottom = cy + r * 0.195;
    canvas.drawRect(Rect.fromLTRB(cx, barTop, cx + r, barBottom), blue);

    canvas.drawRect(Rect.fromLTRB(cx, barTop, cx + r, cy), white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════
// FACEBOOK ICON
// ═══════════════════════════════════════════════════════════════════

class _FacebookIcon extends StatelessWidget {
  const _FacebookIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF1877F2),
      ),
      child: const Center(
        child: Text(
          'f',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.2,
            fontFamily: 'Georgia',
          ),
        ),
      ),
    );
  }
}
