import 'package:sqflite/sqflite.dart';

import '../../domain/models/case_content.dart';
import '../../domain/models/player_data.dart';

/// Reads the authored content tables. Nothing here writes.
class CaseRepository {
  CaseRepository(this._db);
  final DatabaseExecutor _db;

  /// Every case with its player status, for the case library screen.
  Future<List<CaseSummary>> listCases() async {
    final rows = await _db.rawQuery('''
      SELECT c.*, p.status, p.started_at, p.completed_at, p.hints_used, p.score
      FROM cases c
      LEFT JOIN player_progress p ON p.case_id = c.id
      ORDER BY c.title
    ''');
    return rows.map((row) {
      final info = CaseInfo.fromMap(row);
      final progress = row['status'] == null
          ? PlayerProgress(caseId: info.id, status: CaseStatus.fresh)
          : PlayerProgress.fromMap({...row, 'case_id': info.id});
      return CaseSummary(info: info, progress: progress);
    }).toList();
  }

  Future<CaseInfo?> getCase(String caseId) async {
    final rows =
        await _db.query('cases', where: 'id = ?', whereArgs: [caseId]);
    return rows.isEmpty ? null : CaseInfo.fromMap(rows.first);
  }

  Future<List<Scene>> scenes(String caseId) async {
    final rows = await _db.query(
      'scenes',
      where: 'case_id = ?',
      whereArgs: [caseId],
      orderBy: 'order_index',
    );
    return rows.map(Scene.fromMap).toList();
  }

  /// All evidence in the case, or only the evidence in one room.
  Future<List<Evidence>> evidence(String caseId, {String? sceneId}) async {
    final rows = await _db.query(
      'evidence',
      where: sceneId == null ? 'case_id = ?' : 'case_id = ? AND scene_id = ?',
      whereArgs: sceneId == null ? [caseId] : [caseId, sceneId],
      orderBy: 'rowid',
    );
    return rows.map(Evidence.fromMap).toList();
  }

  Future<Evidence?> evidenceById(String evidenceId) async {
    final rows = await _db
        .query('evidence', where: 'id = ?', whereArgs: [evidenceId]);
    return rows.isEmpty ? null : Evidence.fromMap(rows.first);
  }

  Future<List<Suspect>> suspects(String caseId) async {
    final rows = await _db.query(
      'suspects',
      where: 'case_id = ?',
      whereArgs: [caseId],
      orderBy: 'rowid',
    );
    return rows.map(Suspect.fromMap).toList();
  }

  Future<Suspect?> suspectById(String suspectId) async {
    final rows =
        await _db.query('suspects', where: 'id = ?', whereArgs: [suspectId]);
    return rows.isEmpty ? null : Suspect.fromMap(rows.first);
  }

  /// Method or motive choices for the accusation screen, in authored order.
  Future<List<AccusationOption>> accusationOptions(
    String caseId,
    String kind,
  ) async {
    final rows = await _db.query(
      'accusation_options',
      where: 'case_id = ? AND kind = ?',
      whereArgs: [caseId, kind],
      orderBy: 'order_index',
    );
    return rows.map(AccusationOption.fromMap).toList();
  }

  Future<Solution?> solution(String caseId) async {
    final rows = await _db
        .query('solutions', where: 'case_id = ?', whereArgs: [caseId]);
    return rows.isEmpty ? null : Solution.fromMap(rows.first);
  }

  Future<List<ClueLink>> clueLinks(String caseId) async {
    final rows = await _db.query(
      'clue_links',
      where: 'case_id = ?',
      whereArgs: [caseId],
      orderBy: 'stage, rowid',
    );
    return rows.map(ClueLink.fromMap).toList();
  }
}
