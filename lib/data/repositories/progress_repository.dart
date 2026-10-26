import 'package:sqflite/sqflite.dart';

import '../../domain/models/player_data.dart';

/// New / In Progress / Solved for each case, plus hints used and score.
class ProgressRepository {
  ProgressRepository(this._db, this._now);
  final DatabaseExecutor _db;
  final DateTime Function() _now;

  /// Always returns a row: the loader creates one per case, and this
  /// creates it on the spot if something removed it.
  Future<PlayerProgress> get(String caseId) async {
    final rows = await _db.query(
      'player_progress',
      where: 'case_id = ?',
      whereArgs: [caseId],
    );
    if (rows.isNotEmpty) return PlayerProgress.fromMap(rows.first);
    await _db.insert(
      'player_progress',
      {'case_id': caseId, 'status': CaseStatus.fresh.dbValue},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return get(caseId);
  }

  /// Moves a fresh case to In Progress. Does nothing otherwise.
  Future<void> markStarted(String caseId) async {
    final current = await get(caseId);
    if (current.status != CaseStatus.fresh) return;
    await _db.update(
      'player_progress',
      {
        'status': CaseStatus.inProgress.dbValue,
        'started_at': _now().toIso8601String(),
      },
      where: 'case_id = ?',
      whereArgs: [caseId],
    );
  }

  Future<void> markSolved(String caseId, int score) async {
    await get(caseId);
    await _db.update(
      'player_progress',
      {
        'status': CaseStatus.solved.dbValue,
        'completed_at': _now().toIso8601String(),
        'score': score,
      },
      where: 'case_id = ?',
      whereArgs: [caseId],
    );
  }

  Future<void> incrementHintsUsed(String caseId) async {
    await get(caseId);
    await _db.rawUpdate(
      'UPDATE player_progress SET hints_used = hints_used + 1 '
      'WHERE case_id = ?',
      [caseId],
    );
  }

  /// Wipes every player table for the case so it can be played again.
  Future<void> reset(String caseId) async {
    for (final table in [
      'hint_history',
      'accusations',
      'board_links',
      'board_nodes',
      'notes',
      'evidence_collected',
    ]) {
      await _db.delete(table, where: 'case_id = ?', whereArgs: [caseId]);
    }
    await _db.update(
      'player_progress',
      {
        'status': CaseStatus.fresh.dbValue,
        'started_at': null,
        'completed_at': null,
        'hints_used': 0,
        'score': 0,
      },
      where: 'case_id = ?',
      whereArgs: [caseId],
    );
  }
}
