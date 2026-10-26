import '../../domain/models/backup.dart';
import '../repositories/repositories.dart';
import 'auth_service.dart';
import 'backup_store.dart';

enum SyncStatus {
  /// Backup written, or restore applied.
  done,

  /// Nothing to do: guest, no backup, or local data is newer.
  skipped,

  /// The cloud call failed. Local data is untouched and a backup is pending.
  failed,
}

class SyncResult {
  const SyncResult(this.status, this.message);
  final SyncStatus status;
  final String message;

  bool get ok => status != SyncStatus.failed;

  @override
  String toString() => 'SyncResult($status: $message)';
}

/// Backs up and restores player data. SQLite is always the source of truth:
/// the game writes locally first and syncs when it can.
///
/// Conflict rule (proposal section 19): last write wins. A restore only
/// replaces local data when the backup is newer than the last thing done
/// on this device, unless the player asks to force it.
class SyncService {
  SyncService(this._repos, this._account, this._store);

  final Repositories _repos;
  final AccountService _account;
  final BackupStore _store;

  /// Uploads a snapshot of everything the player has done.
  Future<SyncResult> backup() async {
    final user = _account.current;
    if (!user.canSync) {
      return const SyncResult(
        SyncStatus.skipped,
        'Sign in to back up your progress. Playing as a guest keeps it on this device only.',
      );
    }
    final now = _repos.now();
    final snapshot = await _repos.sync.export(now: now);
    try {
      await _store.write(user.uid, snapshot);
    } on BackupFailure catch (e) {
      await _repos.sync.setBackupPending(true);
      return SyncResult(SyncStatus.failed, e.message);
    }
    await _repos.sync.setMeta(SyncRepository.keyLastBackupAt, now.toIso8601String());
    await _repos.sync.setBackupPending(false);
    return SyncResult(
      SyncStatus.done,
      snapshot.isEmpty ? 'Backed up (nothing played yet).' : 'Progress backed up.',
    );
  }

  /// Runs a backup only if an earlier one failed. Call this when the app
  /// comes back online or returns to the foreground.
  Future<SyncResult> retryPendingBackup() async {
    if (!await _repos.sync.backupPending()) {
      return const SyncResult(SyncStatus.skipped, 'Nothing waiting to back up.');
    }
    return backup();
  }

  /// Downloads the backup and applies it if it is newer than local play.
  /// With [force] the backup replaces local data regardless.
  Future<SyncResult> restore({bool force = false}) async {
    final user = _account.current;
    if (!user.canSync) {
      return const SyncResult(
        SyncStatus.skipped,
        'Sign in to restore a backup.',
      );
    }
    final BackupSnapshot? remote;
    try {
      remote = await _store.read(user.uid);
    } on BackupFailure catch (e) {
      return SyncResult(SyncStatus.failed, e.message);
    }
    if (remote == null || remote.isEmpty) {
      return const SyncResult(SyncStatus.skipped, 'No backup found for this account.');
    }

    final local = await _repos.sync.latestLocalActivity();
    final remoteIsNewer = local == null || remote.updatedAt.isAfter(local);
    if (!remoteIsNewer && !force) {
      return const SyncResult(
        SyncStatus.skipped,
        'Your progress on this device is newer than the backup, so it was kept. '
        'Back up now to update the cloud copy.',
      );
    }

    await _repos.database.db.transaction((txn) => SyncRepository(txn).import(remote!));
    await _repos.sync.setMeta(
      SyncRepository.keyLastRestoreAt,
      _repos.now().toIso8601String(),
    );
    return SyncResult(
      SyncStatus.done,
      'Restored ${remote.cases.length} ${remote.cases.length == 1 ? 'case' : 'cases'} from your backup.',
    );
  }

  /// What the settings screen shows.
  Future<SyncInfo> info() async => SyncInfo(
        user: _account.current,
        cloudAvailable: _account.cloudAvailable,
        lastBackupAt: await _repos.sync.lastBackupAt(),
        lastRestoreAt: await _repos.sync.lastRestoreAt(),
        backupPending: await _repos.sync.backupPending(),
      );
}

class SyncInfo {
  const SyncInfo({
    required this.user,
    required this.cloudAvailable,
    this.lastBackupAt,
    this.lastRestoreAt,
    this.backupPending = false,
  });

  final AppUser user;
  final bool cloudAvailable;
  final DateTime? lastBackupAt;
  final DateTime? lastRestoreAt;
  final bool backupPending;
}
