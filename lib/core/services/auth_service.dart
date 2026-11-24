import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../data/repositories/user_repository.dart';

/// Wraps Firebase Auth and Google Sign-In.
class AuthService {
  AuthService(this._users);

  final UserRepository _users;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;

  Future<void> registerWithEmail({
    required String email,
    required String password,
  }) async {
    await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await _tryEnsureProfile();
  }

  Future<void> loginWithEmail({
    required String email,
    required String password,
  }) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<void> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(code: 'sign-in-cancelled');
    }
    final googleAuth = await googleUser.authentication;
    await _auth.signInWithCredential(GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    ));
    await _tryEnsureProfile();
  }

  Future<void> sendPasswordResetEmail(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  Future<void> logout() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('Google sign-out failed: $e');
    }
    await _auth.signOut();
  }

  /// Creates this account's profile document if it doesn't exist yet.
  Future<void> ensureProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final isGoogle =
        user.providerData.any((p) => p.providerId == 'google.com');
    await _users.createIfMissing(
      uid: user.uid,
      email: user.email ?? '',
      authProvider: isGoogle ? 'google' : 'password',
    );
  }

  /// The account itself is already signed in here, so a failed profile write
  /// must not look like a failed sign-in. Onboarding ensures it again.
  Future<void> _tryEnsureProfile() async {
    try {
      await ensureProfile();
    } catch (e) {
      debugPrint('Creating the profile failed: $e');
    }
  }
}
