import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:next_fi/services/device_meta/devices_meta.dart';
import 'package:next_fi/services/fcm_notification/fcm_notification_core.dart';
import 'package:next_fi/services/oath2.0/api/auth_http_client.dart';
import 'package:next_fi/services/oath2.0/api/endpoints.dart';
import 'package:next_fi/services/oath2.0/models/auth_exception.dart';
import 'package:next_fi/services/oath2.0/models/auth_response.dart';
import 'package:next_fi/services/oath2.0/models/user_model.dart';
import 'package:next_fi/services/secure_storage/token_storage.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthService {
  late final TokenStorage _tokenStorage;
  late final AuthHttpClient _http;
  late final GoogleSignIn _googleSignIn;

  final _statusCtrl = StreamController<AuthStatus>.broadcast();

  // ── CACHE LAYER ────────────────────────────────────

  /// In-memory user cache (survives until logout or app restart)
  User? _cachedUser;

  /// Timestamp of last user fetch (for staleness check)
  DateTime? _userFetchTime;

  /// Cache TTL - refresh user data after this duration
  static const _userCacheDuration = Duration(minutes: 5);

  /// Fast auth state cache (avoids repeated storage reads)
  bool? _isAuthenticatedCache;

  // ───────────────────────────────────────────────────

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

    debugPrint('[AUTH] Init → hasTokens: $hasTokens');

    _statusCtrl.add(
      hasTokens ? AuthStatus.authenticated : AuthStatus.unauthenticated,
    );

    // Pre-warm user cache if authenticated
    if (hasTokens) {
      _loadUserInBackground();
    }
  }

  /// Silent background user fetch (doesn't throw errors to UI)
  void _loadUserInBackground() {
    currentUser
        .then((user) {
          debugPrint('[AUTH] Background user loaded: ${user.email}');
        })
        .catchError((e) {
          debugPrint('[AUTH] Background user load failed: $e');
        });
  }

  // ── Google Sign-In ─────────────────────────────

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

  // ── Facebook Sign-In ─────────────────────────────

  Future<User> signInWithFacebook() async {
    try {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('[FACEBOOK] Starting login flow');

      // ── Ensure clean session
      await FacebookAuth.instance.logOut();

      // ── Trigger login
      final result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
        loginBehavior: LoginBehavior.nativeWithFallback,
      );

      debugPrint('[FACEBOOK] LoginStatus → ${result.status}');
      debugPrint('[FACEBOOK] Message → ${result.message}');

      // ── Handle login states
      if (result.status == LoginStatus.cancelled) {
        throw const AuthException('Facebook login cancelled');
      }

      if (result.status == LoginStatus.failed) {
        throw AuthException(result.message ?? 'Facebook login failed');
      }

      if (result.status != LoginStatus.success) {
        throw const AuthException('Facebook login unsuccessful');
      }

      // ── Extract token
      final accessToken = result.accessToken;

      if (accessToken == null) {
        throw const AuthException('No Facebook access token');
      }

      // ── Optional: fetch profile locally (debug help)
      try {
        final profile = await FacebookAuth.instance.getUserData(
          fields: "id,name,email,picture.width(200)",
        );

        debugPrint('[FACEBOOK] Local Profile → $profile');
      } catch (e) {
        debugPrint('[FACEBOOK] Profile fetch skipped → $e');
      }

      // ── Send token to backend
      debugPrint('[FACEBOOK] Sending token to backend...');

      final json = await _http.post(
        AuthEndpoints.facebookToken,
        body: {'accessToken': accessToken},
        auth: false,
      );

      debugPrint('[FACEBOOK] Backend response → $json');

      // ── Handle auth response
      return await _handleAuthResponse(AuthResponse.fromJson(json));
    }
    // ── Custom handled errors
    on AuthException catch (e) {
      debugPrint('[FACEBOOK][AuthException] ${e.message}');
      rethrow;
    }
    // ── Facebook SDK platform errors
    on PlatformException catch (e, s) {
      debugPrint('[FACEBOOK][PlatformException]');
      debugPrint('code → ${e.code}');
      debugPrint('message → ${e.message}');
      debugPrint('details → ${e.details}');
      debugPrint('stack → $s');

      throw AuthException('Facebook platform error: ${e.message}');
    }
    // ── Unknown errors
    catch (e, s) {
      debugPrint('[FACEBOOK][ERROR] $e');
      debugPrint('[FACEBOOK][STACK] $s');

      throw AuthException('Facebook sign-in failed: $e');
    }
  }

  // ── Session (CACHED) ─────────────────────────────

  /// Returns cached user or fetches fresh data
  /// Cache is valid for [_userCacheDuration] (default 5min)
  Future<User> get currentUser async {
    // Return cached user if still fresh
    if (_cachedUser != null && _userFetchTime != null) {
      final age = DateTime.now().difference(_userFetchTime!);

      if (age < _userCacheDuration) {
        debugPrint('[AUTH] Returning cached user (age: ${age.inSeconds}s)');
        return _cachedUser!;
      }

      debugPrint('[AUTH] Cache stale, refreshing (age: ${age.inMinutes}min)');
    }

    // Fetch fresh user data
    return await _fetchUser();
  }

  /// Force refresh user data (bypasses cache)
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

      // Update cache
      _cachedUser = user;
      _userFetchTime = DateTime.now();

      return user;
    } catch (e, s) {
      debugPrint('[AUTH][ERROR] Current user: $e');
      debugPrint('[AUTH][STACK] $s');
      rethrow;
    }
  }

  /// Returns cached user immediately (may be null or stale)
  /// Use this for UI that needs instant data without waiting
  User? get currentUserSync => _cachedUser;

  // ── Logout ─────────────────────────────

  Future<void> logout() async {
    debugPrint('[AUTH] Logout');

    // 1) Deactivate this device's push token on backend (best-effort)
    try {
      final meta = await DeviceMetaService.instance.getMeta();
      await FcmNotificationCore().logoutDeactivateDevice(meta.deviceId);
      debugPrint('[FCM] Deactivated deviceId=${meta.deviceId}');
    } catch (e) {
      debugPrint('[FCM] Deactivate skipped/failed: $e');
    }

    // 2) Call backend logout (best-effort)
    try {
      await _http.post(AuthEndpoints.logout);
    } catch (e) {
      debugPrint('[AUTH] Logout API failed: $e');
    }

    // 3) Clear tokens + social sessions
    await Future.wait([
      _tokenStorage.clear(),
      _googleSignIn.signOut(),
      FacebookAuth.instance.logOut(),
    ]);

    // 4) Clear caches
    _cachedUser = null;
    _userFetchTime = null;
    _isAuthenticatedCache = false;

    // 5) Notify app
    _statusCtrl.add(AuthStatus.unauthenticated);
  }

  // ── Authentication State (CACHED) ─────────────────────────────

  /// Fast auth check using memory cache (no storage I/O)
  Future<bool> get isAuthenticated async {
    // Return cached value if available
    if (_isAuthenticatedCache != null) {
      return _isAuthenticatedCache!;
    }

    // Otherwise check storage and cache result
    final hasTokens = await _tokenStorage.hasTokens;
    _isAuthenticatedCache = hasTokens;

    return hasTokens;
  }

  /// Synchronous auth check (returns cached value, null if unknown)
  bool? get isAuthenticatedSync => _isAuthenticatedCache;

  // ── Auth Response Handler ─────────────────────────────

  Future<User> _handleAuthResponse(AuthResponse response) async {
    debugPrint('[AUTH] Saving tokens');

    await _tokenStorage.saveTokens(
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
    );

    // Update caches immediately
    _cachedUser = response.user;
    _userFetchTime = DateTime.now();
    _isAuthenticatedCache = true;

    _statusCtrl.add(AuthStatus.authenticated);

    debugPrint('[AUTH] User authenticated: ${response.user.email}');

    return response.user;
  }

  // ── Cache Management ─────────────────────────────

  /// Invalidate user cache (forces next currentUser call to fetch fresh data)
  void invalidateUserCache() {
    debugPrint('[AUTH] Cache invalidated');
    _cachedUser = null;
    _userFetchTime = null;
  }

  /// Check if user cache is stale
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
