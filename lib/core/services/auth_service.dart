import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Wraps Firebase Auth + Google Sign-In. Registered as a singleton via Provider.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> registerWithEmail({required String email, required String password}) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await _createUserDocIfMissing(cred.user!, authProvider: 'password');
    return cred;
  }

  Future<UserCredential> loginWithEmail({required String email, required String password}) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw FirebaseAuthException(code: 'sign-in-cancelled');
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final userCred = await _auth.signInWithCredential(credential);
    await _createUserDocIfMissing(userCred.user!, authProvider: 'google');
    return userCred;
  }

  Future<void> sendPasswordResetEmail(String email) => _auth.sendPasswordResetEmail(email: email);

  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<bool> hasCompletedProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    final name = doc.data()?['displayName'] as String?;
    return name != null && name.isNotEmpty;
  }

  Future<void> saveProfile({required String uid, required String displayName, required String avatarSpriteId}) {
    return _firestore.collection('users').doc(uid).update({
      'displayName': displayName,
      'avatarSpriteId': avatarSpriteId,
    });
  }

  Future<void> _createUserDocIfMissing(User user, {required String authProvider}) async {
    final ref = _firestore.collection('users').doc(user.uid);
    if (!(await ref.get()).exists) {
      await ref.set({
        'email': user.email ?? '',
        'displayName': '',
        'avatarSpriteId': '',
        'authProvider': authProvider,
        'coupleId': null,
        'locationEnabled': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}