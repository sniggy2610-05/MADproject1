import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_manor/data/case_loader.dart';
import 'package:midnight_manor/data/database.dart';
import 'package:midnight_manor/data/repositories/repositories.dart';
import 'package:midnight_manor/data/sync/auth_service.dart';
import 'package:midnight_manor/data/sync/backup_store.dart';
import 'package:midnight_manor/data/sync/sync_service.dart';
import 'package:midnight_manor/domain/models/backup.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const caseId = 'case_last_toast';

/// A sign-in service with one known account and no network.
class FakeAuthService implements AuthService {
  FakeAuthService({this.available = true});

  final bool available;
  final accounts = <String, String>{'lakshmi@example.com': 'secret1'};
  AppUser? _user;
  final _changes = StreamController<AppUser?>.broadcast();
  String? failWithCode;

  @override
  bool get isAvailable => available;
  @override
  AppUser? get currentUser => _user;
  @override
  Stream<AppUser?> get userChanges => _changes.stream;

  @override
  Future<AppUser> signIn({required String email, required String password}) async {
    if (failWithCode != null) {
      throw AuthFailure('fake failure', code: failWithCode!);
    }
    if (accounts[email] != password) {
      throw const AuthFailure('Email or password is wrong.', code: 'wrong-password');
    }
    _user = AppUser(uid: 'uid_$email', email: email);
    _changes.add(_user);
    return _user!;
  }

  @override
  Future<AppUser> register({required String email, required String password}) async {
    if (accounts.containsKey(email)) {
      throw const AuthFailure('Already registered.', code: 'email-already-in-use');
    }
    accounts[email] = password;
    return signIn(email: email, password: password);
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _changes.add(null);
  }
}

class Harness {
  Harness(this.repos, this.auth, this.account, this.store, this.sync);
  final Repositories repos;
  final FakeAuthService auth;
  final AccountService account;
  final InMemoryBackupStore store;
  final SyncService sync;

  Future<void> close() async {
    await account.dispose();
    await repos.database.close();
  }
}

Future<Harness> harness({DateTime? start, InMemoryBackupStore? store}) async {
  var tick = start ?? DateTime.utc(2026, 10, 25, 22);
  final db = await AppDatabase.open(
    factory: databaseFactoryFfi,
    path: inMemoryDatabasePath,
  );
  await CaseLoader(db.db, readAsset: (p) => File(p).readAsString())
      .loadBundledCases();
  final repos = Repositories(db, now: () => tick = tick.add(const Duration(seconds: 1)));
  final auth = FakeAuthService();
  final account = AccountService(auth);
  final s = store ?? InMemoryBackupStore();
  return Harness(repos, auth, account, s, SyncService(repos, account, s));
}

void main() {
  setUpAll(sqfliteFfiInit);

  group('AccountService', () {
    test('starts as a guest and can sign in', () async {
      final h = await harness();
      expect(h.account.isGuest, isTrue);
      final u = await h.account.signIn('lakshmi@example.com', 'secret1');
      expect(u.isGuest, isFalse);
      expect(h.account.current.email, 'lakshmi@example.com');
      await h.account.signOut();
      expect(h.account.isGuest, isTrue);
      await h.close();
    });

    test('a wrong password gives a clear message and guest play continues',
        () async {
      final h = await harness();
      await expectLater(
        h.account.signIn('lakshmi@example.com', 'nope12'),
        throwsA(isA<AuthFailure>().having((e) => e.code, 'code', 'wrong-password')),
      );
      h.account.continueAsGuest();
      expect(h.account.isGuest, isTrue);
      await h.close();
    });

    test('obvious form mistakes are caught before any network call', () async {
      final h = await harness();
      Future<void> expectFailure(String email, String password, String code) =>
          expectLater(
            h.account.signIn(email, password),
            throwsA(isA<AuthFailure>().having((e) => e.code, 'code', code)),
          );
      await expectFailure('', 'secret1', 'empty-email');
      await expectFailure('not-an-email', 'secret1', 'invalid-email');
      await expectFailure('a@b.com', '', 'empty-password');
      await expectFailure('a@b.com', '123', 'weak-password');
      await h.close();
    });

    test('registering a new account signs it in', () async {
      final h = await harness();
      final u = await h.account.register('new@example.com', 'secret1');
      expect(u.email, 'new@example.com');
      expect(h.account.isGuest, isFalse);
      await h.close();
    });

    test('unavailable build: sign-in explains and guest still works', () async {
      final account = AccountService(const UnavailableAuthService());
      expect(account.cloudAvailable, isFalse);
      await expectLater(
        account.signIn('a@b.com', 'secret1'),
        throwsA(isA<AuthFailure>().having((e) => e.code, 'code', 'unavailable')),
      );
      expect(account.isGuest, isTrue);
      await account.dispose();
    });
  });

  group('SyncService backup', () {
    test('guest backup is skipped with a message', () async {
      final h = await harness();
      final r = await h.sync.backup();
      expect(r.status, SyncStatus.skipped);
      expect(r.message, contains('Sign in'));
      expect(h.store.writes, 0);
      await h.close();
    });

    test('signed-in backup writes a snapshot and records the time', () async {
      final h = await harness();
      await h.account.signIn('lakshmi@example.com', 'secret1');
      await h.repos.evidence.collect(caseId, 'ev_decanter');
      final r = await h.sync.backup();
      expect(r.status, SyncStatus.done);
      final saved = h.store.backups['uid_lakshmi@example.com']!;
      expect(saved.cases[caseId]!.evidence.single['evidence_id'], 'ev_decanter');
      expect(await h.repos.sync.lastBackupAt(), isNotNull);
      expect(await h.repos.sync.backupPending(), isFalse);
      await h.close();
    });

    test('a failed backup keeps local data and marks a retry', () async {
      final h = await harness();
      await h.account.signIn('lakshmi@example.com', 'secret1');
      await h.repos.notes.add(caseId, 'keep me');
      h.store.failWith = 'No connection.';

      final r = await h.sync.backup();
      expect(r.status, SyncStatus.failed);
      expect(r.message, 'No connection.');
      expect((await h.repos.notes.list(caseId)).single.text, 'keep me');
      expect(await h.repos.sync.backupPending(), isTrue);

      // Back online: the retry goes through, and a second retry is a no-op.
      h.store.failWith = null;
      expect((await h.sync.retryPendingBackup()).status, SyncStatus.done);
      expect(await h.repos.sync.backupPending(), isFalse);
      expect((await h.sync.retryPendingBackup()).status, SyncStatus.skipped);
      await h.close();
    });
  });

  group('SyncService restore (last write wins)', () {
    test('no backup: skipped', () async {
      final h = await harness();
      await h.account.signIn('lakshmi@example.com', 'secret1');
      final r = await h.sync.restore();
      expect(r.status, SyncStatus.skipped);
      expect(r.message, contains('No backup'));
      await h.close();
    });

    test('a newer backup replaces local data', () async {
      final store = InMemoryBackupStore();
      final h = await harness(start: DateTime.utc(2026, 10, 25, 10), store: store);
      await h.account.signIn('lakshmi@example.com', 'secret1');
      await h.repos.evidence.collect(caseId, 'ev_clock'); // local, 10:00

      store.backups['uid_lakshmi@example.com'] = BackupSnapshot(
        updatedAt: DateTime.utc(2026, 10, 25, 12), // newer than local
        cases: {
          caseId: const CaseBackup(status: 'in_progress', evidence: [
            {'evidence_id': 'ev_gloves', 'collected_at': '2026-10-25T11:59:00.000Z'},
          ]),
        },
      );
      final r = await h.sync.restore();
      expect(r.status, SyncStatus.done);
      expect(await h.repos.evidence.collectedIds(caseId), {'ev_gloves'});
      expect(await h.repos.sync.lastRestoreAt(), isNotNull);
      await h.close();
    });

    test('an older backup is kept out unless forced', () async {
      final store = InMemoryBackupStore();
      final h = await harness(start: DateTime.utc(2026, 10, 25, 15), store: store);
      await h.account.signIn('lakshmi@example.com', 'secret1');
      await h.repos.evidence.collect(caseId, 'ev_clock'); // local, 15:00

      store.backups['uid_lakshmi@example.com'] = BackupSnapshot(
        updatedAt: DateTime.utc(2026, 10, 25, 12), // older than local
        cases: {
          caseId: const CaseBackup(status: 'in_progress', evidence: [
            {'evidence_id': 'ev_gloves', 'collected_at': '2026-10-25T11:59:00.000Z'},
          ]),
        },
      );
      final kept = await h.sync.restore();
      expect(kept.status, SyncStatus.skipped);
      expect(kept.message, contains('newer'));
      expect(await h.repos.evidence.collectedIds(caseId), {'ev_clock'});

      final forced = await h.sync.restore(force: true);
      expect(forced.status, SyncStatus.done);
      expect(await h.repos.evidence.collectedIds(caseId), {'ev_gloves'});
      await h.close();
    });

    test('a cloud error during restore leaves local data alone', () async {
      final h = await harness();
      await h.account.signIn('lakshmi@example.com', 'secret1');
      await h.repos.evidence.collect(caseId, 'ev_clock');
      h.store.failWith = 'permission denied';
      final r = await h.sync.restore();
      expect(r.status, SyncStatus.failed);
      expect(await h.repos.evidence.collectedIds(caseId), {'ev_clock'});
      await h.close();
    });

    test('round trip between two devices', () async {
      final store = InMemoryBackupStore();
      final phone = await harness(start: DateTime.utc(2026, 10, 25, 9), store: store);
      await phone.account.signIn('lakshmi@example.com', 'secret1');
      await phone.repos.evidence.collect(caseId, 'ev_decanter');
      await phone.repos.notes.add(caseId, 'from the phone');
      expect((await phone.sync.backup()).status, SyncStatus.done);

      final tablet = await harness(start: DateTime.utc(2026, 10, 25, 8), store: store);
      await tablet.account.signIn('lakshmi@example.com', 'secret1');
      expect((await tablet.sync.restore()).status, SyncStatus.done);
      expect((await tablet.repos.notes.list(caseId)).single.text, 'from the phone');
      expect(await tablet.repos.evidence.isCollected(caseId, 'ev_decanter'), isTrue);

      final info = await tablet.sync.info();
      expect(info.user.email, 'lakshmi@example.com');
      expect(info.lastRestoreAt, isNotNull);
      await phone.close();
      await tablet.close();
    });
  });
}
