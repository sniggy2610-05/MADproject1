import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_manor/data/case_loader.dart';
import 'package:midnight_manor/data/database.dart';
import 'package:midnight_manor/data/hint_service.dart';
import 'package:midnight_manor/data/repositories/repositories.dart';
import 'package:midnight_manor/domain/accusation_checker.dart';
import 'package:midnight_manor/domain/hint_engine.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const caseId = 'case_last_toast';

void main() {
  setUpAll(sqfliteFfiInit);

  late Repositories repos;
  late HintService hints;
  var tick = DateTime.utc(2026, 10, 25, 21);

  setUp(() async {
    final db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    await CaseLoader(db.db, readAsset: (p) => File(p).readAsString())
        .loadBundledCases();
    repos = Repositories(db, now: () => tick = tick.add(const Duration(seconds: 1)));
    hints = HintService(repos);
  });
  tearDown(() => repos.database.close());

  test('builds the state from the database', () async {
    await repos.evidence.collect(caseId, 'ev_decanter');
    await repos.evidence.collect(caseId, 'ev_foxglove');
    await repos.notes.add(caseId, 'bitter smell', evidenceId: 'ev_decanter');
    final d = await repos.board.pin(caseId, 'ev_decanter');
    final f = await repos.board.pin(caseId, 'ev_foxglove');
    await repos.board.connect(caseId, d.id, f.id);

    final s = await hints.stateFor(caseId);
    expect(s.collectedIds, {'ev_decanter', 'ev_foxglove'});
    expect(s.pinnedIds, {'ev_decanter', 'ev_foxglove'});
    expect(s.connectedPairs, [('ev_decanter', 'ev_foxglove')]);
    expect(s.notedEvidenceIds, {'ev_decanter'});
    expect(s.evidence, hasLength(12));
    expect(s.solved, isFalse);
  });

  test('request records the hint and counts it against the score', () async {
    final r = await hints.request(caseId);
    expect(r.outcome, HintOutcome.hint);
    final history = await repos.hints.history(caseId);
    expect(history.single.hintId, r.hint!.id);
    expect((await repos.progress.get(caseId)).hintsUsed, 1);
  });

  test('asking twice in a row gives a different hint', () async {
    final first = await hints.request(caseId);
    final second = await hints.request(caseId);
    expect(second.hint!.id, isNot(first.hint!.id));
  });

  test('a followed hint is not offered again', () async {
    final first = await hints.request(caseId);
    await hints.markFollowed(caseId, first.hint!.id);
    final s = await hints.stateFor(caseId);
    expect(s.completedHintIds, {first.hint!.id});
    final next = await hints.peek(caseId);
    expect(next.candidates.map((c) => c.id), isNot(contains(first.hint!.id)));
  });

  test('peek does not record anything', () async {
    await hints.peek(caseId);
    expect(await repos.hints.history(caseId), isEmpty);
    expect((await repos.progress.get(caseId)).hintsUsed, 0);
  });

  test('after solving, the hint screen shows the completion message', () async {
    await repos.accusations.submit(
      caseId,
      const Accusation(
        suspectId: 'sus_isabelle',
        methodId: 'm_poisoned_brandy',
        motiveId: 'mo_embezzlement',
      ),
    );
    final r = await hints.request(caseId);
    expect(r.outcome, HintOutcome.caseSolved);
    expect(await repos.hints.history(caseId), isEmpty);
  });
}
