/// One object that owns every repository, built from an [AppDatabase].
///
/// Screens and view models get a [Repositories] through Provider and never
/// touch SQLite directly.
library;

import '../database.dart';
import 'accusation_repository.dart';
import 'board_repository.dart';
import 'case_repository.dart';
import 'evidence_repository.dart';
import 'hint_repository.dart';
import 'note_repository.dart';
import 'progress_repository.dart';

export 'accusation_repository.dart';
export 'board_repository.dart';
export 'case_repository.dart';
export 'evidence_repository.dart';
export 'hint_repository.dart';
export 'note_repository.dart';
export 'progress_repository.dart';

class Repositories {
  /// [now] is injectable so tests get predictable timestamps.
  Repositories(this.database, {DateTime Function()? now})
      : _now = now ?? (() => DateTime.now().toUtc()) {
    final db = database.db;
    cases = CaseRepository(db);
    progress = ProgressRepository(db, _now);
    evidence = EvidenceRepository(db, progress, _now);
    notes = NoteRepository(db, _now);
    board = BoardRepository(db, evidence);
    hints = HintRepository(db, progress, _now);
    accusations = AccusationRepository(db, cases, board, progress, _now);
  }

  final AppDatabase database;
  final DateTime Function() _now;

  late final CaseRepository cases;
  late final ProgressRepository progress;
  late final EvidenceRepository evidence;
  late final NoteRepository notes;
  late final BoardRepository board;
  late final HintRepository hints;
  late final AccusationRepository accusations;
}
