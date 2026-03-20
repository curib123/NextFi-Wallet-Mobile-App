import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:next_fi/core/services/device_meta/device_meta_service.dart';
import 'package:next_fi/core/services/fcm_notification/fcm_notification_core.dart';
import 'package:next_fi/core/services/auth/api/auth_http_client.dart';
import 'package:next_fi/core/services/auth/api/auth_endpoints.dart';
import 'package:next_fi/core/services/auth/models/auth_exception.dart';
import 'package:next_fi/core/services/auth/models/auth_response.dart';
import 'package:next_fi/core/services/auth/models/user_model.dart';
import 'package:next_fi/core/services/secure_storage/token_storage.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthService {
  late final TokenStorage _tokenStorage;
  late final AuthHttpClient _http;
  late final GoogleSignIn _googleSignIn;

  final _statusCtrl = StreamController<AuthStatus>.broadcast();

  User? _cachedUser;

  DateTime? _userFetchTime;

  static const _userCacheDuration = Duration(minutes: 5);

  bool? _isAuthenticatedCache;

  AuthService({
    TokenStorage? tokenStorage,
    AuthHttpClient? httpClient,
    GoogleSignIn? googleSignIn,
  }) {
    _tokenStorage = tokenStorage ?? TokenStorage();
    _googleSignIn =
        googleSignIn ??
        GoogleSignIn(
          scopes: ['email', 'profile', 'openid'],
          serverClientId:
              '53734918028-hvsc41gb8ogai7rrqs6ctjgnf5mhcscr.apps.googleusercontent.com',
        );
    _http = httpClient ?? AuthHttpClient(tokenStorage: _tokenStorage);
  }

  Stream<AuthStatus> get status => _statusCtrl.stream;

  Future<void> init() async {
    final hasTokens = await _tokenStorage.hasTokens;
    _isAuthenticatedCache = hasTokens;

    debugPrint('[AUTH] Init â†’ hasTokens: $hasTokens');

    _statusCtrl.add(
      hasTokens ? AuthStatus.authenticated : AuthStatus.unauthenticated,
    );

    if (hasTokens) {
      _loadUserInBackground();
    }
  }

  void _loadUserInBackground() {
    currentUser
        .then((user) {
          debugPrint('[AUTH] Background user loaded: ${user.email}');
        })
        .catchError((e) {
          debugPrint('[AUTH] Background user load failed: $e');
        });
  }

  Future<User> signInWithGoogle() async {
    try {
      debugPrint('[GOOGLE] Start login');

      await _googleSignIn.signOut();

      final account = await _googleSignIn.signIn();

      if (account == null) {
        debugPrint('[GOOGLE] Cancelled');
        throw const AuthException('Google sign-in cancelled');
      }

      debugPrint('[GOOGLE] Email: ${account.email}');

      final googleAuth = await account.authentication;

      debugPrint('[GOOGLE] AccessToken: ${googleAuth.accessToken != null}');
      debugPrint('[GOOGLE] IdToken: ${googleAuth.idToken != null}');

      if (googleAuth.idToken == null) {
        throw const AuthException('No Google ID token');
      }

      final json = await _http.post(
        AuthEndpoints.googleToken,
        body: {
          'idToken': googleAuth.idToken,
          'accessToken': googleAuth.accessToken,
        },
        auth: false,
      );

      return await _handleAuthResponse(AuthResponse.fromJson(json));
    } on PlatformException catch (e) {
      debugPrint('[GOOGLE][PlatformException]');
      debugPrint('code: ${e.code}');
      debugPrint('message: ${e.message}');
      debugPrint('details: ${e.details}');

      throw AuthException('Google sign-in platform error: ${e.message}');
    } catch (e, s) {
      debugPrint('[GOOGLE][ERROR] $e');
      debugPrint('[STACK] $s');

      throw AuthException('Google sign-in failed: $e');
    }
  }

  Future<User> signInWithFacebook() async {
    try {
      debugPrint(
        'â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”',
      );
      debugPrint('[FACEBOOK] Starting login flow');

      await FacebookAuth.instance.logOut();

      final result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
        loginBehavior: LoginBehavior.nativeWithFallback,
      );

      debugPrint('[FACEBOOK] LoginStatus â†’ ${result.status}');
      debugPrint('[FACEBOOK] Message â†’ ${result.message}');

      if (result.status == LoginStatus.cancelled) {
        throw const AuthException('Facebook login cancelled');
      }

      if (result.status == LoginStatus.failed) {
        throw AuthException(result.message ?? 'Facebook login failed');
      }

      if (result.status != LoginStatus.success) {
        throw const AuthException('Facebook login unsuccessful');
      }

      final accessToken = result.accessToken;

      if (accessToken == null) {
        throw const AuthException('No Facebook access token');
      }

      try {
        final profile = await FacebookAuth.instance.getUserData(
          fields: "id,name,email,picture.width(200)",
        );

        debugPrint('[FACEBOOK] Local Profile â†’ $profile');
      } catch (e) {
        debugPrint('[FACEBOOK] Profile fetch skipped â†’ $e');
      }

      debugPrint('[FACEBOOK] Sending token to backend...');

      final json = await _http.post(
        AuthEndpoints.facebookToken,
        body: {'accessToken': accessToken},
        auth: false,
      );

      debugPrint('[FACEBOOK] Backend response â†’ $json');

      return await _handleAuthResponse(AuthResponse.fromJson(json));
    } on AuthException catch (e) {
      debugPrint('[FACEBOOK][AuthException] ${e.message}');
      rethrow;
    } on PlatformException catch (e, s) {
      debugPrint('[FACEBOOK][PlatformException]');
      debugPrint('code â†’ ${e.code}');
      debugPrint('message â†’ ${e.message}');
      debugPrint('details â†’ ${e.details}');
      debugPrint('stack â†’ $s');

      throw AuthException('Facebook platform error: ${e.message}');
    } catch (e, s) {
      debugPrint('[FACEBOOK][ERROR] $e');
      debugPrint('[FACEBOOK][STACK] $s');

      throw AuthException('Facebook sign-in failed: $e');
    }
  }

  Future<User> get currentUser async {
    if (_cachedUser != null && _userFetchTime != null) {
      final age = DateTime.now().difference(_userFetchTime!);

      if (age < _userCacheDuration) {
        debugPrint('[AUTH] Returning cached user (age: ${age.inSeconds}s)');
        return _cachedUser!;
      }

      debugPrint('[AUTH] Cache stale, refreshing (age: ${age.inMinutes}min)');
    }

    return await _fetchUser();
  }

  Future<User> refreshUser() async {
    debugPrint('[AUTH] Force refresh user');
    return await _fetchUser();
  }

  Future<User> _fetchUser() async {
    try {
      debugPrint('[AUTH] Fetching current user');

      final json = await _http.get(AuthEndpoints.me);

      debugPrint('[AUTH] /me response: $json');

      final user = User.fromJson(json);

      _cachedUser = user;
      _userFetchTime = DateTime.now();

      return user;
    } catch (e, s) {
      debugPrint('[AUTH][ERROR] Current user: $e');
      debugPrint('[AUTH][STACK] $s');
      rethrow;
    }
  }

  User? get currentUserSync => _cachedUser;

  Future<void> logout() async {
    debugPrint('[AUTH] Logout');

    try {
      final meta = await DeviceMetaService.instance.getMeta();
      await FcmNotificationCore().logoutDeactivateDevice(meta.deviceId);
      debugPrint('[FCM] Deactivated deviceId=${meta.deviceId}');
    } catch (e) {
      debugPrint('[FCM] Deactivate skipped/failed: $e');
    }

    try {
      await _http.post(AuthEndpoints.logout);
    } catch (e) {
      debugPrint('[AUTH] Logout API failed: $e');
    }

    await Future.wait([
      _tokenStorage.clear(),
      _googleSignIn.signOut(),
      FacebookAuth.instance.logOut(),
    ]);

    _cachedUser = null;
    _userFetchTime = null;
    _isAuthenticatedCache = false;

    _statusCtrl.add(AuthStatus.unauthenticated);
  }

  Future<bool> get isAuthenticated async {
    if (_isAuthenticatedCache != null) {
      return _isAuthenticatedCache!;
    }

    final hasTokens = await _tokenStorage.hasTokens;
    _isAuthenticatedCache = hasTokens;

    return hasTokens;
  }

  bool? get isAuthenticatedSync => _isAuthenticatedCache;

  Future<User> _handleAuthResponse(AuthResponse response) async {
    debugPrint('[AUTH] Saving tokens');

    await _tokenStorage.saveTokens(
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
    );

    _cachedUser = response.user;
    _userFetchTime = DateTime.now();
    _isAuthenticatedCache = true;

    _statusCtrl.add(AuthStatus.authenticated);

    debugPrint('[AUTH] User authenticated: ${response.user.email}');

    return response.user;
  }

  void invalidateUserCache() {
    debugPrint('[AUTH] Cache invalidated');
    _cachedUser = null;
    _userFetchTime = null;
  }

  bool get isUserCacheStale {
    if (_userFetchTime == null) return true;

    final age = DateTime.now().difference(_userFetchTime!);
    return age >= _userCacheDuration;
  }

  void dispose() {
    _statusCtrl.close();
    _http.dispose();
  }
}
