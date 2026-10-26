import 'package:sqflite/sqflite.dart';

import '../../domain/models/player_data.dart';
import 'progress_repository.dart';

/// Which clues the player has found. Finding a clue twice is harmless.
class EvidenceRepository {
  EvidenceRepository(this._db, this._progress, this._now);
  final DatabaseExecutor _db;
  final ProgressRepository _progress;
  final DateTime Function() _now;

  Future<Set<String>> collectedIds(String caseId) async {
    final rows = await _db.query(
      'evidence_collected',
      columns: ['evidence_id'],
      where: 'case_id = ?',
      whereArgs: [caseId],
    );
    return rows.map((r) => r['evidence_id'] as String).toSet();
  }

  Future<bool> isCollected(String caseId, String evidenceId) async {
    final rows = await _db.query(
      'evidence_collected',
      columns: ['id'],
      where: 'case_id = ? AND evidence_id = ?',
      whereArgs: [caseId, evidenceId],
    );
    return rows.isNotEmpty;
  }

  /// Marks a clue as found. Returns true the first time, false when the
  /// player is revisiting a room and the clue was already in the inventory.
  /// Throws [RuleViolation] if the clue does not belong to the case.
  Future<bool> collect(String caseId, String evidenceId) async {
    final exists = await _db.query(
      'evidence',
      columns: ['id'],
      where: 'id = ? AND case_id = ?',
      whereArgs: [evidenceId, caseId],
    );
    if (exists.isEmpty) {
      throw RuleViolation('That clue is not part of this case.');
    }
    if (await isCollected(caseId, evidenceId)) return false;

    await _db.insert(
      'evidence_collected',
      {
        'case_id': caseId,
        'evidence_id': evidenceId,
        'collected_at': _now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await _progress.markStarted(caseId);
    return true;
  }
}
