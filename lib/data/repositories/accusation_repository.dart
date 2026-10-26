import 'package:sqflite/sqflite.dart';

import '../../domain/accusation_checker.dart';
import '../../domain/models/player_data.dart';
import 'board_repository.dart';
import 'case_repository.dart';
import 'progress_repository.dart';

/// Records accusations and runs the checker against the stored solution.
class AccusationRepository {
  AccusationRepository(
    this._db,
    this._cases,
    this._board,
    this._progress,
    this._now, {
    this.checker = const AccusationChecker(),
  });

  final DatabaseExecutor _db;
  final CaseRepository _cases;
  final BoardRepository _board;
  final ProgressRepository _progress;
  final DateTime Function() _now;
  final AccusationChecker checker;

  /// Checks the accusation, records it (unless incomplete), and marks the
  /// case solved when it is right. Returns the result for the result screen.
  Future<AccusationResult> submit(String caseId, Accusation accusation) async {
    final solution = await _cases.solution(caseId);
    if (solution == null) {
      throw RuleViolation('No solution is stored for case $caseId.');
    }
    final clueLinks = await _cases.clueLinks(caseId);
    final pairs = await _board.connectedEvidencePairs(caseId);
    final progress = await _progress.get(caseId);
    final previousWrong = await wrongAttempts(caseId);

    final result = checker.check(
      accusation: accusation,
      solution: solution,
      clueLinks: clueLinks,
      boardConnections: pairs,
      previousWrongAttempts: previousWrong,
      hintsUsed: progress.hintsUsed,
    );
    if (result.verdict == AccusationVerdict.incomplete) return result;

    await _db.insert('accusations', {
      'case_id': caseId,
      'suspect_id': accusation.suspectId,
      'method': accusation.methodId,
      'motive': accusation.motiveId,
      'is_correct': result.isSolved ? 1 : 0,
      'created_at': _now().toIso8601String(),
    });

    if (result.isSolved) {
      await _progress.markSolved(caseId, result.score);
    } else {
      await _progress.markStarted(caseId);
    }
    return result;
  }

  Future<List<AccusationRecord>> history(String caseId) async {
    final rows = await _db.query(
      'accusations',
      where: 'case_id = ?',
      whereArgs: [caseId],
      orderBy: 'created_at, id',
    );
    return rows.map(AccusationRecord.fromMap).toList();
  }

  Future<int> wrongAttempts(String caseId) async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS n FROM accusations '
      'WHERE case_id = ? AND is_correct = 0',
      [caseId],
    );
    return rows.first['n'] as int;
  }
}
