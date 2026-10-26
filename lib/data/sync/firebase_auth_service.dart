import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'auth_service.dart';

/// [AuthService] backed by Firebase Authentication (email and password).
class FirebaseAuthService implements AuthService {
  FirebaseAuthService([fb.FirebaseAuth? auth])
      : _auth = auth ?? fb.FirebaseAuth.instance;

  final fb.FirebaseAuth _auth;

  @override
  bool get isAvailable => true;

  @override
  AppUser? get currentUser => _toAppUser(_auth.currentUser);

  @override
  Stream<AppUser?> get userChanges => _auth.authStateChanges().map(_toAppUser);

  @override
  Future<AppUser> signIn({required String email, required String password}) =>
      _guard(() async {
        final cred = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        return _toAppUser(cred.user)!;
      });

  @override
  Future<AppUser> register({required String email, required String password}) =>
      _guard(() async {
        final cred = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        return _toAppUser(cred.user)!;
      });

  @override
  Future<void> signOut() => _auth.signOut();

  static AppUser? _toAppUser(fb.User? u) =>
      u == null ? null : AppUser(uid: u.uid, email: u.email);

  /// Turns Firebase's error codes into plain messages for the sign-in screen.
  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on fb.FirebaseAuthException catch (e) {
      throw AuthFailure(messageFor(e.code), code: e.code);
    } catch (e) {
      throw AuthFailure('Could not reach the sign-in service. Check your '
          'connection or continue as a guest.', code: 'unknown');
    }
  }

  static String messageFor(String code) => switch (code) {
        'invalid-email' => 'That does not look like an email address.',
        'user-disabled' => 'This account has been disabled.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'Email or password is wrong. Try again or continue as a guest.',
        'email-already-in-use' => 'There is already an account with that email. Try signing in.',
        'weak-password' => 'Passwords need at least 6 characters.',
        'too-many-requests' => 'Too many attempts. Wait a minute and try again.',
        'network-request-failed' => 'No connection. You can keep playing as a guest and back up later.',
        _ => 'Sign-in failed ($code). You can continue as a guest.',
      };
}
