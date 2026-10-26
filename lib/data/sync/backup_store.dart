/// Where backups live. Firestore in the real app, memory in tests and in
/// builds where Firebase is not configured.
library;

import '../../domain/models/backup.dart';

/// A cloud problem with a message that is safe to show on screen.
class BackupFailure implements Exception {
  const BackupFailure(this.message);
  final String message;

  @override
  String toString() => 'BackupFailure: $message';
}

abstract class BackupStore {
  /// Overwrites the user's backup.
  Future<void> write(String uid, BackupSnapshot snapshot);

  /// The user's backup, or null if they have none.
  Future<BackupSnapshot?> read(String uid);
}

/// Keeps backups in a map. Tests can make it fail on demand.
class InMemoryBackupStore implements BackupStore {
  final Map<String, BackupSnapshot> backups = {};

  /// When set, every call throws with this message.
  String? failWith;

  int writes = 0;
  int reads = 0;

  @override
  Future<void> write(String uid, BackupSnapshot snapshot) async {
    writes++;
    if (failWith != null) throw BackupFailure(failWith!);
    backups[uid] = snapshot;
  }

  @override
  Future<BackupSnapshot?> read(String uid) async {
    reads++;
    if (failWith != null) throw BackupFailure(failWith!);
    return backups[uid];
  }
}

/// Used when Firebase is not configured for this build.
class UnavailableBackupStore implements BackupStore {
  const UnavailableBackupStore();

  static const message = 'Cloud backup is not set up in this build.';

  @override
  Future<void> write(String uid, BackupSnapshot snapshot) =>
      throw const BackupFailure(message);

  @override
  Future<BackupSnapshot?> read(String uid) =>
      throw const BackupFailure(message);
}
