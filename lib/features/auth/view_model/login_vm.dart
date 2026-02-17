// lib/features/login/view_model/login_vm.dart

import 'package:flutter/foundation.dart';
import 'package:next_fi/services/oath2.0/auth_service.dart';
import 'package:next_fi/services/oath2.0/models/user_model.dart';
import 'package:next_fi/services/oath2.0/models/auth_exception.dart';

class LoginVM extends ChangeNotifier {
  final AuthService _auth;

  LoginVM({AuthService? auth})
      : _auth = auth ?? AuthService();

  bool googleLoading = false;
  bool facebookLoading = false;

  User? user;

  bool get isBusy =>
      googleLoading || facebookLoading;

  // ── GOOGLE ─────────────────────────

  Future<User?> signInGoogle() async {
    if (isBusy) return null;

    googleLoading = true;
    notifyListeners();

    try {
      final u =
      await _auth.signInWithGoogle();

      user = u;
      return u;
    } on AuthException {
      rethrow;
    } finally {
      googleLoading = false;
      notifyListeners();
    }
  }

  // ── FACEBOOK ───────────────────────

  Future<User?> signInFacebook() async {
    if (isBusy) return null;

    facebookLoading = true;
    notifyListeners();

    try {
      final u =
      await _auth.signInWithFacebook();

      user = u;
      return u;
    } on AuthException {
      rethrow;
    } finally {
      facebookLoading = false;
      notifyListeners();
    }
  }
}
