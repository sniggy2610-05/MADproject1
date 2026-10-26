import 'package:sqflite/sqflite.dart';

import '../../domain/models/player_data.dart';

/// The player's notebook. A note may be attached to a clue, a suspect,
/// both, or neither.
class NoteRepository {
  NoteRepository(this._db, this._now);
  final DatabaseExecutor _db;
  final DateTime Function() _now;

  /// Saves a note. Blank text is refused with a [RuleViolation] so the
  /// notebook never fills with empty entries.
  Future<Note> add(
    String caseId,
    String text, {
    String? evidenceId,
    String? suspectId,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw const RuleViolation('Write something before saving the note.');
    }
    final id = await _db.insert('notes', {
      'case_id': caseId,
      'evidence_id': evidenceId,
      'suspect_id': suspectId,
      'text': trimmed,
      'created_at': _now().toIso8601String(),
    });
    return (await byId(id))!;
  }

  Future<Note?> byId(int id) async {
    final rows = await _db.query('notes', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Note.fromMap(rows.first);
  }

  /// Notes for a case, newest first. Filter by clue or suspect if given.
  Future<List<Note>> list(
    String caseId, {
    String? evidenceId,
    String? suspectId,
  }) async {
    final where = StringBuffer('case_id = ?');
    final args = <Object?>[caseId];
    if (evidenceId != null) {
      where.write(' AND evidence_id = ?');
      args.add(evidenceId);
    }
    if (suspectId != null) {
      where.write(' AND suspect_id = ?');
      args.add(suspectId);
    }
    final rows = await _db.query(
      'notes',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'created_at DESC, id DESC',
    );
    return rows.map(Note.fromMap).toList();
  }

  Future<void> updateText(int id, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw const RuleViolation('A note cannot be empty. Delete it instead.');
    }
    await _db.update('notes', {'text': trimmed},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> delete(int id) =>
      _db.delete('notes', where: 'id = ?', whereArgs: [id]);
}
