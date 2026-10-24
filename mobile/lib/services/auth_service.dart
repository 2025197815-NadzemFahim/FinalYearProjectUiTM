// All sign-in / sign-out logic lives here. Screens never call Firebase directly.
//
// Why a separate service?
//  - Screens stay about layout; this file is about authentication.
//  - Swapping Firebase for something else only changes this file.
//  - Tests can pass in a fake AuthService instead of real Firebase
//    (see test/login_test.dart), so they run instantly and offline.
import 'package:firebase_auth/firebase_auth.dart';

/// The signed-in user, as the rest of the app sees it.
/// (A plain class, so screens don't depend on firebase_auth types.)
class AppUser {
  const AppUser({required this.uid, this.email, this.displayName});

  final String uid;
  final String? email;
  final String? displayName;
}

/// A login problem, already turned into a message a user can read.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// What the app needs from authentication. Firebase implements it below;
/// tests implement it with a fake.
abstract class AuthService {
  /// Emits the user whenever they sign in or out (null = signed out).
  Stream<AppUser?> authStateChanges();

  AppUser? get currentUser;

  /// FR-01 / FR-03: check the credentials. Throws [AuthFailure] if wrong.
  Future<void> signIn({required String email, required String password});

  /// FR-02 Register (Table 3.12): create the account. Afterwards the user is
  /// signed out again, because the use case returns them to the Login screen.
  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  });

  /// Forgot Password (Figure 3.17): email the user a reset link.
  Future<void> sendPasswordReset(String email);

  /// FR-11: end the session.
  Future<void> signOut();

  /// Token to send to the FastAPI backend as `Authorization: Bearer <token>`
  /// so deep-check results are saved to this user's history.
  Future<String?> idToken();
}

class FirebaseAuthService implements AuthService {
  FirebaseAuthService(this._auth);

  final FirebaseAuth _auth;

  AppUser? _toAppUser(User? u) => u == null
      ? null
      : AppUser(uid: u.uid, email: u.email, displayName: u.displayName);

  @override
  Stream<AppUser?> authStateChanges() => _auth.authStateChanges().map(_toAppUser);

  @override
  AppUser? get currentUser => _toAppUser(_auth.currentUser);

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e.code));
    }
  }

  @override
  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password);
      await cred.user?.updateDisplayName('${firstName.trim()} ${lastName.trim()}');
      // Contact number, age and sex belong in the Firestore profile
      // (users/{uid}); that needs the cloud_firestore package - see
      // docs/MOBILE_GUIDE.md section 4, step 4.
      await _auth.signOut(); // Table 3.12: "redirects the user to the Login Interface"
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e.code));
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e.code));
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<String?> idToken() async => _auth.currentUser?.getIdToken();

  /// Firebase error codes -> messages for the error popup.
  /// Note: wrong email and wrong password give the SAME message on purpose,
  /// so an attacker can't use the login form to find out which emails exist.
  String _messageFor(String code) {
    switch (code) {
      case 'invalid-credential':
      case 'user-not-found':
      case 'wrong-password':
        return 'Incorrect email or password.';
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No connection to the server. Check your internet (or that the Firebase emulator is running).';
      default:
        return 'Sign-in failed ($code). Please try again.';
    }
  }
}
