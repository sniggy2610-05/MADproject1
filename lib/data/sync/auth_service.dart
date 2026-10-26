/// Sign-in abstraction. The app talks to [AuthService]; Firebase is one
/// implementation, tests use a fake, and builds without Firebase configured
/// get [UnavailableAuthService] so everything still runs as a guest.
library;

import 'dart:async';

/// Who is playing. A guest has no account and no cloud backup.
class AppUser {
  const AppUser({required this.uid, this.email, this.isGuest = false});

  static const guest = AppUser(uid: 'guest', isGuest: true);

  final String uid;
  final String? email;
  final bool isGuest;

  bool get canSync => !isGuest;

  @override
  bool operator ==(Object other) =>
      other is AppUser && other.uid == uid && other.isGuest == isGuest;

  @override
  int get hashCode => Object.hash(uid, isGuest);

  @override
  String toString() => isGuest ? 'AppUser(guest)' : 'AppUser($uid, $email)';
}

/// A sign-in problem with a message that is safe to show on screen.
class AuthFailure implements Exception {
  const AuthFailure(this.message, {this.code = 'unknown'});
  final String message;
  final String code;

  @override
  String toString() => 'AuthFailure($code): $message';
}

abstract class AuthService {
  /// False when this build has no Firebase configuration.
  bool get isAvailable;

  /// The signed-in account, or null.
  AppUser? get currentUser;

  /// Emits whenever the account changes (sign-in, sign-out).
  Stream<AppUser?> get userChanges;

  Future<AppUser> signIn({required String email, required String password});
  Future<AppUser> register({required String email, required String password});
  Future<void> signOut();
}

/// Used when `flutterfire configure` has not been run for this build.
class UnavailableAuthService implements AuthService {
  const UnavailableAuthService();

  static const message =
      'Cloud features are not set up in this build. You can keep playing as a guest.';

  @override
  bool get isAvailable => false;
  @override
  AppUser? get currentUser => null;
  @override
  Stream<AppUser?> get userChanges => const Stream.empty();
  @override
  Future<AppUser> signIn({required String email, required String password}) =>
      throw const AuthFailure(message, code: 'unavailable');
  @override
  Future<AppUser> register({required String email, required String password}) =>
      throw const AuthFailure(message, code: 'unavailable');
  @override
  Future<void> signOut() async {}
}

/// Checks the form before any network call, so obvious mistakes get an
/// instant message. Shared by every implementation.
class CredentialRules {
  static const minPasswordLength = 6;

  static void check(String email, String password) {
    final e = email.trim();
    if (e.isEmpty) {
      throw const AuthFailure('Enter your email address.', code: 'empty-email');
    }
    if (!e.contains('@') || !e.contains('.') || e.startsWith('@') || e.endsWith('.')) {
      throw const AuthFailure('That does not look like an email address.',
          code: 'invalid-email');
    }
    if (password.isEmpty) {
      throw const AuthFailure('Enter your password.', code: 'empty-password');
    }
    if (password.length < minPasswordLength) {
      throw const AuthFailure(
        'Passwords need at least $minPasswordLength characters.',
        code: 'weak-password',
      );
    }
  }
}

/// The player's session: a signed-in account or a guest. Wraps an
/// [AuthService] and adds the play-as-guest option from the proposal.
class AccountService {
  AccountService(this._auth) : _current = _auth.currentUser ?? AppUser.guest {
    _sub = _auth.userChanges.listen((u) => _set(u ?? AppUser.guest));
  }

  final AuthService _auth;
  AppUser _current;
  StreamSubscription<AppUser?>? _sub;
  final _controller = StreamController<AppUser>.broadcast();

  AppUser get current => _current;
  bool get isGuest => _current.isGuest;
  bool get cloudAvailable => _auth.isAvailable;
  Stream<AppUser> get changes => _controller.stream;

  void _set(AppUser u) {
    if (u == _current) return;
    _current = u;
    _controller.add(u);
  }

  /// Keeps playing without an account. Never fails.
  void continueAsGuest() => _set(AppUser.guest);

  /// Signs in. On failure throws [AuthFailure]; the caller shows the message
  /// and the player can [continueAsGuest].
  Future<AppUser> signIn(String email, String password) async {
    CredentialRules.check(email, password);
    final u = await _auth.signIn(email: email.trim(), password: password);
    _set(u);
    return u;
  }

  Future<AppUser> register(String email, String password) async {
    CredentialRules.check(email, password);
    final u = await _auth.register(email: email.trim(), password: password);
    _set(u);
    return u;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _set(AppUser.guest);
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _controller.close();
  }
}
