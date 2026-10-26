import 'package:sqflite/sqflite.dart';

import '../../domain/models/player_data.dart';
import 'progress_repository.dart';

/// Which hints have been shown and whether the player acted on them.
/// The hint engine reads this to avoid repeating itself.
class HintRepository {
  HintRepository(this._db, this._progress, this._now);
  final DatabaseExecutor _db;
  final ProgressRepository _progress;
  final DateTime Function() _now;

  /// Records that a hint was shown and counts it against the score.
  Future<HintRecord> recordShown(String caseId, String hintId) async {
    final id = await _db.insert('hint_history', {
      'case_id': caseId,
      'hint_id': hintId,
      'shown_at': _now().toIso8601String(),
      'action_completed': 0,
    });
    await _progress.incrementHintsUsed(caseId);
    await _progress.markStarted(caseId);
    final rows =
        await _db.query('hint_history', where: 'id = ?', whereArgs: [id]);
    return HintRecord.fromMap(rows.first);
  }

  /// Marks every shown copy of this hint as acted on.
  Future<void> markCompleted(String caseId, String hintId) => _db.update(
        'hint_history',
        {'action_completed': 1},
        where: 'case_id = ? AND hint_id = ?',
        whereArgs: [caseId, hintId],
      );

  /// Hint history for a case, most recent first.
  Future<List<HintRecord>> history(String caseId, {int? limit}) async {
    final rows = await _db.query(
      'hint_history',
      where: 'case_id = ?',
      whereArgs: [caseId],
      orderBy: 'shown_at DESC, id DESC',
      limit: limit,
    );
    return rows.map(HintRecord.fromMap).toList();
  }

  /// Ids of the last [count] hints shown, newest first.
  Future<List<String>> recentHintIds(String caseId, {int count = 3}) async =>
      (await history(caseId, limit: count)).map((h) => h.hintId).toList();

  /// Ids of hints the player has completed.
  Future<Set<String>> completedHintIds(String caseId) async {
    final rows = await _db.query(
      'hint_history',
      columns: ['hint_id'],
      where: 'case_id = ? AND action_completed = 1',
      whereArgs: [caseId],
    );
    return rows.map((r) => r['hint_id'] as String).toSet();
  }
}
