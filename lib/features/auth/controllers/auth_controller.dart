import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/services/auth_service.dart';

enum AuthStatus { idle, loading, success }

enum AuthErrorType {
  none,
  wrongCredentials,
  emailInUse,
  weakPassword,
  invalidEmail,
  tooManyAttempts,
  network,
  googleFailed,
  unknown,
}

class AuthController extends ChangeNotifier {
  final AuthService _authService;
  AuthController(this._authService);

  AuthStatus status = AuthStatus.idle;
  AuthErrorType errorType = AuthErrorType.none;

  Future<bool> login(String email, String password) => _run(
        () => _authService.loginWithEmail(email: email, password: password),
      );

  Future<bool> register(String email, String password) => _run(
        () => _authService.registerWithEmail(email: email, password: password),
      );

  Future<bool> continueWithGoogle() =>
      _run(_authService.signInWithGoogle, google: true);

  /// Drops a stale error, e.g. when switching between LOGIN and REGISTER.
  void clearError() {
    if (errorType == AuthErrorType.none) return;
    errorType = AuthErrorType.none;
    notifyListeners();
  }

  Future<bool> _run(
    Future<Object?> Function() action, {
    bool google = false,
  }) async {
    status = AuthStatus.loading;
    errorType = AuthErrorType.none;
    notifyListeners();
    try {
      await action();
      status = AuthStatus.success;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _fail(_fromAuthCode(e.code));
    } on FirebaseException catch (e) {
      // e.g. the profile document write right after registering.
      _fail(e.code == 'unavailable' ? AuthErrorType.network : AuthErrorType.unknown);
    } on PlatformException catch (e) {
      // google_sign_in reports its own failures as platform exceptions.
      _fail(_fromGoogleCode(e.code));
    } catch (e) {
      debugPrint('Sign-in failed: $e');
      _fail(google ? AuthErrorType.googleFailed : AuthErrorType.unknown);
    }
    return false;
  }

  void _fail(AuthErrorType type) {
    status = AuthStatus.idle;
    errorType = type;
    notifyListeners();
  }

  static AuthErrorType _fromAuthCode(String code) => switch (code) {
        // Closing the Google account picker is not an error.
        'sign-in-cancelled' => AuthErrorType.none,
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' ||
        'invalid-login-credentials' =>
          AuthErrorType.wrongCredentials,
        'email-already-in-use' => AuthErrorType.emailInUse,
        'weak-password' => AuthErrorType.weakPassword,
        'invalid-email' => AuthErrorType.invalidEmail,
        'too-many-requests' => AuthErrorType.tooManyAttempts,
        'network-request-failed' => AuthErrorType.network,
        _ => AuthErrorType.unknown,
      };

  static AuthErrorType _fromGoogleCode(String code) => switch (code) {
        'sign_in_canceled' || 'canceled' => AuthErrorType.none,
        'network_error' => AuthErrorType.network,
        _ => AuthErrorType.googleFailed,
      };
}
