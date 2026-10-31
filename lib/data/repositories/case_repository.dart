import 'package:sqflite/sqflite.dart';

import 'dart:convert';

import '../../domain/models/case_record.dart';
import '../database/app_database.dart';

class CaseRepository {
  Future<List<CaseRecord>> getAll() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('CaseRecord', orderBy: 'id DESC');
    return rows.map(CaseRecord.fromMap).toList();
  }

  Future<int> create(CaseRecord record) async {
    final db = await AppDatabase.instance.database;
    return db.insert('CaseRecord', record.toMap()..remove('id'));
  }

  Future<int> update(CaseRecord record) async {
    final db = await AppDatabase.instance.database;
    return db.update(
      'CaseRecord',
      record.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await AppDatabase.instance.database;
    return db.delete('CaseRecord', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> inspectClue(int caseId, String clueId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'CaseRecord',
      where: 'id = ?',
      whereArgs: [caseId],
    );

    if (rows.isEmpty) return;

    final record = CaseRecord.fromMap(rows.first);
    final clues = record.inspectedClueKeys;

    if (!clues.contains(clueId)) clues.add(clueId);

    await update(
      record.copyWith(
        inspectedClueKeysJson: jsonEncode(clues),
        status: 'In Progress',
      ),
    );
  }

  Future<bool> submitGuess(int caseId, String suspectId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'CaseRecord',
      where: 'id = ?',
      whereArgs: [caseId],
    );

    if (rows.isEmpty) return false;

    final record = CaseRecord.fromMap(rows.first);
    final correct = suspectId == record.solutionKey;

    await update(
      record.copyWith(
        lastGuess: suspectId,
        status: correct ? 'Solved' : 'In Progress',
      ),
    );

    return correct;
  }

  Future<void> reset(int caseId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'CaseRecord',
      where: 'id = ?',
      whereArgs: [caseId],
    );

    if (rows.isEmpty) return;

    final record = CaseRecord.fromMap(rows.first);

    await update(
      record.copyWith(
        status: 'New',
        lastGuess: null,
        inspectedClueKeysJson: '[]',
      ),
    );
  }

  Future<int> solvedCount() async {
    final db = await AppDatabase.instance.database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) AS total FROM CaseRecord WHERE status = 'Solved'",
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
