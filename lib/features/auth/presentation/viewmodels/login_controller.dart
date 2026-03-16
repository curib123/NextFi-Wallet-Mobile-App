import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:next_fi/app/config/app_providers.dart';
import 'package:next_fi/features/auth/data/services/login_service.dart';
import 'package:next_fi/features/auth/presentation/viewmodels/login_state.dart';
import 'package:next_fi/features/contact/presentation/viewmodels/contact_list_notifier.dart';
import 'package:next_fi/core/services/auth/models/user_model.dart';

final loginServiceProvider = Provider.autoDispose<LoginService>((ref) {
  final service = LoginService();
  ref.onDispose(service.dispose);
  return service;
});

final loginControllerProvider =
    NotifierProvider.autoDispose<LoginController, LoginState>(
      LoginController.new,
    );

class LoginController extends Notifier<LoginState> {
  @override
  LoginState build() {
    Future.microtask(loadLegalLinks);
    return const LoginState();
  }

  Future<void> loadLegalLinks() async {
    final config = ref.read(appConfigProvider);
    final links = await ref
        .read(loginServiceProvider)
        .fetchLegalLinks(config.backendBaseUrl);
    if (!ref.mounted) return;
    state = state.copyWith(
      termsUrl: links.termsUrl,
      privacyUrl: links.privacyUrl,
    );
  }

  Future<User?> signInGoogle() async {
    if (state.googleLoading || state.facebookLoading) return null;
    state = state.copyWith(googleLoading: true);
    try {
      final user = await ref.read(loginServiceProvider).signInWithGoogle();
      return await _handleSuccessfulLogin(
        user: user,
        clearGoogleLoading: true,
      );
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(
          googleLoading: false,
          postLoginLoading: false,
        );
      }
      rethrow;
    }
  }

  Future<User?> signInFacebook() async {
    if (state.googleLoading || state.facebookLoading) return null;
    state = state.copyWith(facebookLoading: true);
    try {
      final user = await ref.read(loginServiceProvider).signInWithFacebook();
      return await _handleSuccessfulLogin(
        user: user,
        clearFacebookLoading: true,
      );
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(
          facebookLoading: false,
          postLoginLoading: false,
        );
      }
      rethrow;
    }
  }

  Future<User?> _handleSuccessfulLogin({
    required User? user,
    bool clearGoogleLoading = false,
    bool clearFacebookLoading = false,
  }) async {
    if (user == null) {
      if (ref.mounted) {
        state = state.copyWith(
          googleLoading: clearGoogleLoading ? false : state.googleLoading,
          facebookLoading: clearFacebookLoading ? false : state.facebookLoading,
        );
      }
      return null;
    }

    if (ref.mounted) {
      state = state.copyWith(
        googleLoading: clearGoogleLoading ? false : state.googleLoading,
        facebookLoading: clearFacebookLoading ? false : state.facebookLoading,
        postLoginLoading: true,
      );
    }

    await ref.read(loginServiceProvider).syncWalletsAfterLogin();
    final contacts = ref.read(contactListProvider.notifier);
    contacts.setAuthenticated(true);
    await contacts.refresh();

    if (!ref.mounted) return user;
    state = state.copyWith(postLoginLoading: false);
    return user;
  }
}

