import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/backup.dart';
import 'backup_store.dart';

/// [BackupStore] on Cloud Firestore.
///
/// One document per user at `users/{uid}`:
/// ```
/// { updated_at: "2026-10-25T20:00:00Z", snapshot: { ...BackupSnapshot } }
/// ```
/// The security rules in `firebase/firestore.rules` let a user read and
/// write only their own document.
class FirestoreBackupStore implements BackupStore {
  FirestoreBackupStore([FirebaseFirestore? firestore])
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const collection = 'users';

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection(collection).doc(uid);

  @override
  Future<void> write(String uid, BackupSnapshot snapshot) => _guard(
        () => _doc(uid).set({
          'updated_at': snapshot.updatedAt.toIso8601String(),
          'snapshot': snapshot.toJson(),
        }),
      );

  @override
  Future<BackupSnapshot?> read(String uid) => _guard(() async {
        final doc = await _doc(uid).get();
        final data = doc.data();
        if (!doc.exists || data == null || data['snapshot'] == null) return null;
        return BackupSnapshot.fromJson(
          Map<String, dynamic>.from(data['snapshot'] as Map),
        );
      });

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseException catch (e) {
      throw BackupFailure(switch (e.code) {
        'permission-denied' => 'You are not allowed to access that backup.',
        'unavailable' => 'No connection. Your progress is saved on this device and will back up later.',
        _ => 'Backup failed (${e.code}). Your progress is still saved on this device.',
      });
    } on FormatException catch (e) {
      throw BackupFailure(e.message);
    }
  }
}
