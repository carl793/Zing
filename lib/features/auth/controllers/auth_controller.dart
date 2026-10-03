import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/auth_service.dart';

enum AuthStatus { idle, loading, success }
enum AuthErrorType { none, wrongCredentials, tooManyAttempts, network, unknown }

class AuthController extends ChangeNotifier {
  final AuthService _authService;
  AuthController(this._authService);

  AuthStatus status = AuthStatus.idle;
  AuthErrorType errorType = AuthErrorType.none;

  Future<bool> login(String email, String password) async {
    _setLoading();
    try {
      await _authService.loginWithEmail(email: email, password: password);
      _setSuccess();
      return true;
    } on FirebaseAuthException catch (e) {
      _handleException(e);
      return false;
    } catch (_) {
      _setNetworkError();
      return false;
    }
  }

  Future<bool> register(String email, String password) async {
    _setLoading();
    try {
      await _authService.registerWithEmail(email: email, password: password);
      _setSuccess();
      return true;
    } on FirebaseAuthException catch (e) {
      _handleException(e);
      return false;
    } catch (_) {
      _setNetworkError();
      return false;
    }
  }

  Future<bool> continueWithGoogle() async {
    _setLoading();
    try {
      await _authService.signInWithGoogle();
      _setSuccess();
      return true;
    } catch (_) {
      _setNetworkError();
      return false;
    }
  }

  void _setLoading() {
    status = AuthStatus.loading;
    errorType = AuthErrorType.none;
    notifyListeners();
  }

  void _setSuccess() {
    status = AuthStatus.success;
    notifyListeners();
  }

  void _setNetworkError() {
    status = AuthStatus.idle;
    errorType = AuthErrorType.network;
    notifyListeners();
  }

  void _handleException(FirebaseAuthException e) {
    status = AuthStatus.idle;
    errorType = switch (e.code) {
      'user-not-found' || 'wrong-password' || 'invalid-credential' => AuthErrorType.wrongCredentials,
      'too-many-requests' => AuthErrorType.tooManyAttempts,
      'network-request-failed' => AuthErrorType.network,
      _ => AuthErrorType.unknown,
    };
    notifyListeners();
  }
}