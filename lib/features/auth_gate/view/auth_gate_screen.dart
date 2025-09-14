import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:next_fi/features/auth_gate/view/widgets/biometrics_button.dart';
import 'package:next_fi/features/auth_gate/view/widgets/headings.dart';
import 'package:next_fi/features/auth_gate/view/widgets/lock_badge.dart';
import 'package:next_fi/features/auth_gate/view/widgets/lock_out_banner.dart';
import 'package:next_fi/features/auth_gate/view/widgets/pin_field.dart';
import 'package:next_fi/features/auth_gate/view/widgets/primary_action.dart';
import 'package:next_fi/features/auth_gate/view/widgets/tob_bar.dart';
import 'package:next_fi/features/auth_gate/view_model/auth_gate_vm.dart';
import 'package:provider/provider.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/common/components/SnackBar.dart';

class AuthGateScreen extends StatefulWidget {
  final VoidCallback? goNext;
  const AuthGateScreen({super.key, this.goNext});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen>
    with WidgetsBindingObserver {
  static const double _kFormWidth = 280;

  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocus = FocusNode();
  Timer? _smallVisualDelay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final vm = context.read<AuthGateVM>();
      await vm.init();

      final warn = vm.state.initWarning;
      if (warn != null) {
        showFloatingSnackBar(context, message: warn, type: SnackBarType.error);
      }

      final auto = await vm.maybeAutoBiometric();
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
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    context.read<AuthGateVM>().disposeTimers();
    _pinController.dispose();
    _pinFocus.dispose();
    _smallVisualDelay?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final vm = context.read<AuthGateVM>();
      vm.refreshLockout();
      vm.maybeAutoBiometric();
    }
  }

  void _onSuccessNavigate() {
    _smallVisualDelay?.cancel();
    _smallVisualDelay = Timer(const Duration(milliseconds: 200), () {
      final goNext = widget.goNext;
      if (goNext != null) {
        goNext();
      } else {
        Navigator.pushReplacementNamed(context, "/home");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final vm = context.watch<AuthGateVM>();
    final s = vm.state;

    final isLockedOut = vm.isLockedOut;
    final headline = s.isNewUser
        ? (s.firstPinEntry == null ? "Set Your PIN" : "Confirm PIN")
        : "Enter PIN";
    final subhead = s.isNewUser
        ? (s.firstPinEntry == null
        ? "Secure your wallet with a 6-digit PIN"
        : "Re-enter the same 6-digit PIN")
        : "Unlock your wallet securely";

    return WillPopScope(
      onWillPop: () async => Navigator.canPop(context),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: colors.background,
          appBar: TopBar(colors: colors),
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    LockBadge(unlocked: s.unlockedVisual, colors: colors),
                    const SizedBox(height: 28),

                    Headings(headline: headline, subhead: subhead, colors: colors),

                    if (isLockedOut) ...[
                      const SizedBox(height: 12),
                      LockoutBanner(remaining: s.lockoutRemaining!, colors: colors),
                    ],

                    const SizedBox(height: 28),

                    PinField(
                      maxWidth: _kFormWidth,
                      controller: _pinController,
                      focusNode: _pinFocus,
                      enabled: !isLockedOut && !s.submitting,
                      obscure: s.obscurePin,
                      colors: colors,
                      onSubmit: () => _submit(vm),
                      onToggleObscure: vm.toggleObscurePin,
                    ),

                    const SizedBox(height: 24),

                    PrimaryAction(
                      maxWidth: _kFormWidth,
                      colors: colors,
                      text: s.isNewUser
                          ? (s.firstPinEntry == null ? "Continue" : "Save PIN")
                          : "Unlock",
                      icon: s.unlockedVisual
                          ? Icons.lock_open_rounded
                          : (s.isNewUser
                          ? (s.firstPinEntry == null
                          ? Icons.arrow_forward
                          : Icons.save)
                          : Icons.lock_rounded),
                      enabled: !s.submitting && !isLockedOut,
                      onPressed: () => _submit(vm),
                    ),

                    const SizedBox(height: 16),

                    if (!s.isNewUser &&
                        s.deviceSupportsBiometrics &&
                        s.biometricsEnabled)
                      BiometricsButton(
                        maxWidth: _kFormWidth,
                        colors: colors,
                        onPressed: () async {
                          final res = await vm.authenticateWithBiometrics();
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(AuthGateVM vm) async {
    final res = await vm.submitPin(_pinController.text);
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
        _pinController.clear();
        _pinFocus.requestFocus();
        break;
      case PinStatus.mismatch:
      case PinStatus.invalid:
      case PinStatus.storageError:
      case PinStatus.error:
        _pinController.clear();
        _pinFocus.requestFocus();
        HapticFeedback.mediumImpact();
        break;
      case PinStatus.lockedOut:
        _pinController.clear();
        break;
      case PinStatus.saved:
      case PinStatus.verified:
        _pinController.clear();
        FocusScope.of(context).unfocus();
        _onSuccessNavigate();
        break;
    }
  }
}
