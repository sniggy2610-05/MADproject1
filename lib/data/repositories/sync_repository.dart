import 'package:sqflite/sqflite.dart';

import '../../domain/models/backup.dart';

/// Moves player data in and out of SQLite as a [BackupSnapshot], and keeps
/// the small `sync_meta` table (schema v2) with sync bookkeeping.
class SyncRepository {
  SyncRepository(this._db);
  final DatabaseExecutor _db;

  static const keyLastBackupAt = 'last_backup_at';
  static const keyLastRestoreAt = 'last_restore_at';
  static const keyBackupPending = 'backup_pending';

  // ---------------------------------------------------------------------------
  // sync_meta
  // ---------------------------------------------------------------------------

  Future<String?> meta(String key) async {
    final rows =
        await _db.query('sync_meta', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setMeta(String key, String? value) => _db.insert(
        'sync_meta',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<DateTime?> lastBackupAt() async => _date(await meta(keyLastBackupAt));
  Future<DateTime?> lastRestoreAt() async => _date(await meta(keyLastRestoreAt));
  Future<bool> backupPending() async => await meta(keyBackupPending) == '1';
  Future<void> setBackupPending(bool pending) =>
      setMeta(keyBackupPending, pending ? '1' : '0');

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  /// The most recent timestamp anywhere in the player tables, or null when
  /// nothing has been played. Board moves carry no timestamp, so this is
  /// "last meaningful action", which is what last-write-wins needs.
  Future<DateTime?> latestLocalActivity() async {
    final rows = await _db.rawQuery('''
      SELECT MAX(t) AS t FROM (
        SELECT MAX(collected_at) AS t FROM evidence_collected
        UNION ALL SELECT MAX(created_at) FROM notes
        UNION ALL SELECT MAX(created_at) FROM accusations
        UNION ALL SELECT MAX(shown_at) FROM hint_history
        UNION ALL SELECT MAX(started_at) FROM player_progress
        UNION ALL SELECT MAX(completed_at) FROM player_progress
      )
    ''');
    return _date(rows.first['t'] as String?);
  }

  /// Copies every player table into a snapshot. Cases the player has not
  /// touched (status new, nothing collected) are left out.
  Future<BackupSnapshot> export({required DateTime now}) async {
    final progressRows = await _db.query('player_progress');
    final cases = <String, CaseBackup>{};

    for (final p in progressRows) {
      final caseId = p['case_id'] as String;
      final evidence = await _rows(
        'SELECT evidence_id, collected_at FROM evidence_collected '
        'WHERE case_id = ? ORDER BY id',
        caseId,
      );
      if (p['status'] == 'new' && evidence.isEmpty) continue;

      cases[caseId] = CaseBackup(
        status: p['status'] as String,
        startedAt: p['started_at'] as String?,
        completedAt: p['completed_at'] as String?,
        hintsUsed: p['hints_used'] as int,
        score: p['score'] as int,
        evidence: evidence,
        notes: await _rows(
          'SELECT evidence_id, suspect_id, text, created_at FROM notes '
          'WHERE case_id = ? ORDER BY id',
          caseId,
        ),
        boardNodes: await _rows(
          'SELECT evidence_id, x, y FROM board_nodes WHERE case_id = ? ORDER BY id',
          caseId,
        ),
        boardLinks: await _rows(
          '''
          SELECT a.evidence_id AS from_evidence, b.evidence_id AS to_evidence,
                 l.label
          FROM board_links l
          JOIN board_nodes a ON a.id = l.from_node
          JOIN board_nodes b ON b.id = l.to_node
          WHERE l.case_id = ? ORDER BY l.id
          ''',
          caseId,
        ),
        accusations: await _rows(
          'SELECT suspect_id, method, motive, is_correct, created_at '
          'FROM accusations WHERE case_id = ? ORDER BY id',
          caseId,
        ),
        hints: await _rows(
          'SELECT hint_id, shown_at, action_completed FROM hint_history '
          'WHERE case_id = ? ORDER BY id',
          caseId,
        ),
      );
    }
    return BackupSnapshot(updatedAt: now, cases: cases);
  }

  // ---------------------------------------------------------------------------
  // Import
  // ---------------------------------------------------------------------------

  /// Replaces the player data of every case in the snapshot. Cases missing
  /// from the snapshot are left alone. Rows that point at content this
  /// build does not have (an evidence id from a newer case file) are skipped
  /// rather than failing the whole restore.
  Future<void> import(BackupSnapshot snapshot) async {
    final txn = _db;
    for (final entry in snapshot.cases.entries) {
      final caseId = entry.key;
      final c = entry.value;
      final known = await txn.query('cases', columns: ['id'], where: 'id = ?', whereArgs: [caseId]);
      if (known.isEmpty) continue;

      for (final table in [
        'hint_history',
        'accusations',
        'board_links',
        'board_nodes',
        'notes',
        'evidence_collected',
      ]) {
        await txn.delete(table, where: 'case_id = ?', whereArgs: [caseId]);
      }
      await txn.insert(
        'player_progress',
        {
          'case_id': caseId,
          'status': c.status,
          'started_at': c.startedAt,
          'completed_at': c.completedAt,
          'hints_used': c.hintsUsed,
          'score': c.score,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      for (final e in c.evidence) {
        await _tryInsert(txn, 'evidence_collected', {
          'case_id': caseId,
          'evidence_id': e['evidence_id'],
          'collected_at': e['collected_at'],
        });
      }
      for (final n in c.notes) {
        await _tryInsert(txn, 'notes', {
          'case_id': caseId,
          'evidence_id': n['evidence_id'],
          'suspect_id': n['suspect_id'],
          'text': n['text'],
          'created_at': n['created_at'],
        });
      }
      final nodeIdByEvidence = <String, int>{};
      for (final b in c.boardNodes) {
        final id = await _tryInsert(txn, 'board_nodes', {
          'case_id': caseId,
          'evidence_id': b['evidence_id'],
          'x': b['x'],
          'y': b['y'],
        });
        if (id != null) nodeIdByEvidence[b['evidence_id'] as String] = id;
      }
      for (final l in c.boardLinks) {
        final from = nodeIdByEvidence[l['from_evidence']];
        final to = nodeIdByEvidence[l['to_evidence']];
        if (from == null || to == null) continue;
        await _tryInsert(txn, 'board_links', {
          'case_id': caseId,
          'from_node': from,
          'to_node': to,
          'label': l['label'] ?? '',
        });
      }
      for (final a in c.accusations) {
        await _tryInsert(txn, 'accusations', {
          'case_id': caseId,
          'suspect_id': a['suspect_id'],
          'method': a['method'],
          'motive': a['motive'],
          'is_correct': a['is_correct'],
          'created_at': a['created_at'],
        });
      }
      for (final h in c.hints) {
        await _tryInsert(txn, 'hint_history', {
          'case_id': caseId,
          'hint_id': h['hint_id'],
          'shown_at': h['shown_at'],
          'action_completed': h['action_completed'],
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _rows(String sql, String caseId) async =>
      (await _db.rawQuery(sql, [caseId]))
          .map((r) => Map<String, dynamic>.from(r))
          .toList();

  static Future<int?> _tryInsert(
    DatabaseExecutor txn,
    String table,
    Map<String, Object?> row,
  ) async {
    try {
      return await txn.insert(table, row);
    } on DatabaseException {
      return null;
    }
  }

  static DateTime? _date(String? s) => s == null ? null : DateTime.parse(s);
}
