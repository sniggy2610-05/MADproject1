import '../../domain/models/evidence_note.dart';
import '../database/app_database.dart';

class NoteRepository {
  Future<List<EvidenceNote>> getAll(int caseId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'EvidenceNote',
      where: 'caseId = ?',
      whereArgs: [caseId],
      orderBy: 'createdAt DESC',
    );
    return rows.map(EvidenceNote.fromMap).toList();
  }

  Future<int> create(EvidenceNote note) async {
    if (note.text.trim().isEmpty) {
      throw ArgumentError('Note cannot be empty.');
    }

    final db = await AppDatabase.instance.database;
    return db.insert('EvidenceNote', note.toMap()..remove('id'));
  }

  Future<int> update(EvidenceNote note) async {
    if (note.text.trim().isEmpty) {
      throw ArgumentError('Note cannot be empty.');
    }

    final db = await AppDatabase.instance.database;
    return db.update(
      'EvidenceNote',
      note.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await AppDatabase.instance.database;
    return db.delete('EvidenceNote', where: 'id = ?', whereArgs: [id]);
  }
}
