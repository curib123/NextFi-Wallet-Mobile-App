import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Components/SnackBar.dart';
import 'package:next_fi/Services/security_storage.dart';
import 'package:next_fi/Components/CustomButton.dart';

class AuthGateScreen extends StatefulWidget {
  final VoidCallback? goNext;

  const AuthGateScreen({Key? key, this.goNext}) : super(key: key);

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  final TextEditingController _pinController = TextEditingController();

  String? _savedPin;
  bool _isNewUser = false;
  bool _canCheckBiometrics = false;
  bool _obscurePin = true;

  @override
  void initState() {
    super.initState();
    _initAuthCheck();
  }

  Future<void> _initAuthCheck() async {
    final pin = await SecurityStorage.read("user_pin");
    final canCheck = await auth.canCheckBiometrics;
    final available = await auth.getAvailableBiometrics();

    setState(() {
      _savedPin = pin;
      _isNewUser = pin == null;
      _canCheckBiometrics = canCheck && available.isNotEmpty;
    });

  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Authenticate to continue',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (didAuthenticate) {
        showFloatingSnackBar(
          context,
          message: "Authentication successful",
          type: SnackBarType.success,
        );
        _onAuthSuccess();
      } else {
        showFloatingSnackBar(
          context,
          message: "Biometric authentication failed",
          type: SnackBarType.error,
        );
      }
    } catch (e) {
      showFloatingSnackBar(
        context,
        message: "Biometric error: $e",
        type: SnackBarType.error,
      );
      debugPrint("Biometric error: $e");
    }
  }

  Future<void> _onSubmitPin() async {
    if (_pinController.text.length < 6) {
      showFloatingSnackBar(
        context,
        message: "PIN must be 6 digits",
        type: SnackBarType.warning,
      );
      return;
    }

    if (_isNewUser) {
      await SecurityStorage.save("user_pin", _pinController.text);
      showFloatingSnackBar(
        context,
        message: "PIN saved successfully",
        type: SnackBarType.success,
      );
      _onAuthSuccess();
    } else {
      if (_pinController.text == _savedPin) {
        showFloatingSnackBar(
          context,
          message: "PIN verified successfully",
          type: SnackBarType.success,
        );
        _onAuthSuccess();
      } else {
        showFloatingSnackBar(
          context,
          message: "Invalid PIN",
          type: SnackBarType.error,
        );
      }
    }
  }

  void _onAuthSuccess() {
    if (widget.goNext != null) {
      widget.goNext!();
    } else {
      Navigator.pushReplacementNamed(context, "/home");
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Security",
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        leading: Navigator.canPop(context)
            ? IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
          ),
          color: colors.textPrimary,
          onPressed: () => Navigator.pop(context),
        )
            : null,
      ),

      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lock_rounded, size: 60, color: colors.primary),
                ),

                const SizedBox(height: 28),

                Text(
                  _isNewUser ? "Set Your PIN" : "Enter PIN",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  _isNewUser
                      ? "Secure your wallet with a 6-digit PIN"
                      : "Unlock your wallet securely",
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                // --- Centered PIN field (replace your current TextField) ---
                Align(
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280), // <- keeps it narrow & centered
                    child: TextField(
                      controller: _pinController,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      obscureText: _obscurePin,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      textAlignVertical: TextAlignVertical.center,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _onSubmitPin(),
                      style: TextStyle(
                        fontSize: 20,
                        letterSpacing: 8,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        counterText: "",
                        filled: true,
                        fillColor: colors.surface,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: colors.primary.withOpacity(0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: colors.primary, width: 1.5),
                        ),
                        hintText: "••••••",
                        hintStyle: TextStyle(
                          fontSize: 20,
                          letterSpacing: 6,
                          color: colors.textSecondary.withOpacity(0.4),
                        ),

                        // Keep text VISUALLY centered by balancing the suffix icon width:
                        prefixIcon: const SizedBox(width: 48),
                        prefixIconConstraints: const BoxConstraints(minWidth: 48),

                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePin ? Icons.visibility_off : Icons.visibility,
                            color: colors.textSecondary,
                          ),
                          onPressed: () => setState(() => _obscurePin = !_obscurePin),
                        ),
                        suffixIconConstraints: const BoxConstraints(minWidth: 48),
                      ),
                    ),
                  ),
                ),


                const SizedBox(height: 24),

                // Action button using CustomButton with icon
                CustomButton(
                  text: _isNewUser ? "Save PIN" : "Unlock",
                  onPressed: _onSubmitPin,
                  type: ButtonType.filled,
                  icon: _isNewUser ? Icons.save : Icons.lock_open,
                ),

                const SizedBox(height: 16),

                if (!_isNewUser && _canCheckBiometrics)
                  TextButton.icon(
                    onPressed: _authenticateWithBiometrics,
                    icon: Icon(Icons.fingerprint_rounded, color: colors.primary),
                    label: Text(
                      "Use Biometrics",
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: colors.primary,
                      ),
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
