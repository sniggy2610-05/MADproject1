import 'package:flutter/foundation.dart';

import '../data/repositories/case_repository.dart';
import '../data/repositories/note_repository.dart';
import '../domain/models/case_record.dart';
import '../domain/models/evidence_note.dart';

class AppState extends ChangeNotifier {
  final cases = CaseRepository();
  final notes = NoteRepository();

  List<CaseRecord> caseList = [];
  List<EvidenceNote> noteList = [];

  bool loading = false;
  String? error;

  Future<void> loadCases() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      caseList = await cases.getAll();
    } catch (e) {
      error = e.toString();
    }

    loading = false;
    notifyListeners();
  }

  Future<void> loadNotes(int caseId) async {
    noteList = await notes.getAll(caseId);
    notifyListeners();
  }

  Future<void> addCase(CaseRecord record) async {
    await cases.create(record);
    await loadCases();
  }

  Future<void> updateCase(CaseRecord record) async {
    await cases.update(record);
    await loadCases();
  }

  Future<void> deleteCase(int id) async {
    await cases.delete(id);
    await loadCases();
  }

  Future<void> addNote(EvidenceNote note) async {
    await notes.create(note);
    await loadNotes(note.caseId);
  }

  Future<void> updateNote(EvidenceNote note) async {
    await notes.update(note);
    await loadNotes(note.caseId);
  }

  Future<void> deleteNote(int id, int caseId) async {
    await notes.delete(id);
    await loadNotes(caseId);
  }
}
