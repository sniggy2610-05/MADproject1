import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_manor/data/case_loader.dart';
import 'package:midnight_manor/data/database.dart';
import 'package:midnight_manor/data/repositories/repositories.dart';
import 'package:midnight_manor/domain/accusation_checker.dart';
import 'package:midnight_manor/domain/models/case_content.dart';
import 'package:midnight_manor/domain/models/player_data.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const caseId = 'case_last_toast';

/// A ticking fake clock so timestamps are predictable and strictly ordered.
class FakeClock {
  DateTime current = DateTime.utc(2026, 10, 25, 20, 0);
  DateTime next() {
    current = current.add(const Duration(seconds: 1));
    return current;
  }
}

Future<Repositories> freshRepos() async {
  final db = await AppDatabase.open(
    factory: databaseFactoryFfi,
    path: inMemoryDatabasePath,
  );
  await CaseLoader(db.db, readAsset: (p) => File(p).readAsString())
      .loadBundledCases();
  return Repositories(db, now: FakeClock().next);
}

void main() {
  setUpAll(sqfliteFfiInit);

  late Repositories repos;
  setUp(() async => repos = await freshRepos());
  tearDown(() => repos.database.close());

  group('cases', () {
    test('library lists the case as New', () async {
      final list = await repos.cases.listCases();
      expect(list, hasLength(1));
      expect(list.single.info.title, 'The Last Toast');
      expect(list.single.status, CaseStatus.fresh);
    });

    test('reads rooms, evidence per room, suspects, options, solution',
        () async {
      final scenes = await repos.cases.scenes(caseId);
      expect(scenes.map((s) => s.name).first, 'The Study');
      final study = await repos.cases.evidence(caseId, sceneId: scenes.first.id);
      expect(study, hasLength(4));
      expect(await repos.cases.evidence(caseId), hasLength(12));
      expect(await repos.cases.suspects(caseId), hasLength(5));
      final methods = await repos.cases
          .accusationOptions(caseId, AccusationOption.kindMethod);
      expect(methods, hasLength(5));
      expect(methods.first.orderIndex, 0);
      expect((await repos.cases.solution(caseId))!.culpritId, 'sus_isabelle');
      expect(await repos.cases.clueLinks(caseId), hasLength(8));
    });
  });

  group('evidence', () {
    test('collecting a clue starts the case and is idempotent', () async {
      expect(await repos.evidence.collect(caseId, 'ev_decanter'), isTrue);
      expect(await repos.evidence.collect(caseId, 'ev_decanter'), isFalse);
      expect(await repos.evidence.collectedIds(caseId), {'ev_decanter'});
      expect((await repos.progress.get(caseId)).status, CaseStatus.inProgress);
      expect((await repos.progress.get(caseId)).startedAt, isNotNull);
    });

    test('refuses a clue from another case', () async {
      expect(
        () => repos.evidence.collect(caseId, 'ev_nonsense'),
        throwsA(isA<RuleViolation>()),
      );
    });
  });

  group('notes', () {
    test('saves trimmed text and lists newest first', () async {
      await repos.notes.add(caseId, '  first  ', evidenceId: 'ev_decanter');
      await repos.notes.add(caseId, 'second', suspectId: 'sus_isabelle');
      final all = await repos.notes.list(caseId);
      expect(all.map((n) => n.text), ['second', 'first']);
      expect(
        (await repos.notes.list(caseId, evidenceId: 'ev_decanter')).single.text,
        'first',
      );
      expect(
        (await repos.notes.list(caseId, suspectId: 'sus_isabelle')).single.text,
        'second',
      );
    });

    test('refuses an empty note', () async {
      expect(
        () => repos.notes.add(caseId, '   '),
        throwsA(isA<RuleViolation>()),
      );
      expect(await repos.notes.list(caseId), isEmpty);
    });

    test('edits and deletes', () async {
      final n = await repos.notes.add(caseId, 'draft');
      await repos.notes.updateText(n.id, 'final');
      expect((await repos.notes.byId(n.id))!.text, 'final');
      expect(
        () => repos.notes.updateText(n.id, ''),
        throwsA(isA<RuleViolation>()),
      );
      await repos.notes.delete(n.id);
      expect(await repos.notes.byId(n.id), isNull);
    });
  });

  group('board', () {
    test('cannot pin a clue that was not collected', () async {
      expect(
        () => repos.board.pin(caseId, 'ev_decanter'),
        throwsA(isA<RuleViolation>()),
      );
    });

    test('pinning twice returns the same card', () async {
      await repos.evidence.collect(caseId, 'ev_decanter');
      final a = await repos.board.pin(caseId, 'ev_decanter', x: 10, y: 20);
      final b = await repos.board.pin(caseId, 'ev_decanter', x: 99, y: 99);
      expect(b.id, a.id);
      expect(b.x, 10);
      expect(await repos.board.nodes(caseId), hasLength(1));
    });

    test('moving a card persists its position', () async {
      await repos.evidence.collect(caseId, 'ev_decanter');
      final node = await repos.board.pin(caseId, 'ev_decanter');
      await repos.board.move(node.id, 120.5, 340.25);
      final moved = await repos.board.nodeById(node.id);
      expect(moved!.x, 120.5);
      expect(moved.y, 340.25);
    });

    test('rejects self links and duplicate links in either direction',
        () async {
      await repos.evidence.collect(caseId, 'ev_decanter');
      await repos.evidence.collect(caseId, 'ev_foxglove');
      final a = await repos.board.pin(caseId, 'ev_decanter');
      final b = await repos.board.pin(caseId, 'ev_foxglove');

      expect(
        () => repos.board.connect(caseId, a.id, a.id),
        throwsA(isA<RuleViolation>()),
      );
      final link = await repos.board.connect(caseId, a.id, b.id, label: ' same poison ');
      expect(link.label, 'same poison');
      expect(
        () => repos.board.connect(caseId, a.id, b.id),
        throwsA(isA<RuleViolation>()),
      );
      expect(
        () => repos.board.connect(caseId, b.id, a.id),
        throwsA(isA<RuleViolation>()),
      );
      expect(await repos.board.links(caseId), hasLength(1));
    });

    test('rejects a link to a card that is not on the board', () async {
      await repos.evidence.collect(caseId, 'ev_decanter');
      final a = await repos.board.pin(caseId, 'ev_decanter');
      expect(
        () => repos.board.connect(caseId, a.id, 9999),
        throwsA(isA<RuleViolation>()),
      );
    });

    test('unpinning removes strings but keeps the clue collected', () async {
      await repos.evidence.collect(caseId, 'ev_decanter');
      await repos.evidence.collect(caseId, 'ev_foxglove');
      final a = await repos.board.pin(caseId, 'ev_decanter');
      final b = await repos.board.pin(caseId, 'ev_foxglove');
      await repos.board.connect(caseId, a.id, b.id);

      await repos.board.unpin(a.id);
      expect(await repos.board.links(caseId), isEmpty);
      expect(await repos.board.nodes(caseId), hasLength(1));
      expect(await repos.evidence.isCollected(caseId, 'ev_decanter'), isTrue);
    });

    test('reports connected pairs as evidence ids', () async {
      await repos.evidence.collect(caseId, 'ev_decanter');
      await repos.evidence.collect(caseId, 'ev_foxglove');
      final a = await repos.board.pin(caseId, 'ev_decanter');
      final b = await repos.board.pin(caseId, 'ev_foxglove');
      final link = await repos.board.connect(caseId, a.id, b.id);
      expect(await repos.board.connectedEvidencePairs(caseId), [
        ('ev_decanter', 'ev_foxglove'),
      ]);
      await repos.board.setLabel(link.id, 'poison');
      expect((await repos.board.linkById(link.id))!.label, 'poison');
      await repos.board.disconnect(link.id);
      expect(await repos.board.connectedEvidencePairs(caseId), isEmpty);
    });
  });

  group('hints', () {
    test('records shown hints, counts them, and tracks completion', () async {
      await repos.hints.recordShown(caseId, 'h1');
      await repos.hints.recordShown(caseId, 'h2');
      await repos.hints.recordShown(caseId, 'h1');
      expect((await repos.progress.get(caseId)).hintsUsed, 3);
      expect(await repos.hints.recentHintIds(caseId, count: 2), ['h1', 'h2']);
      await repos.hints.markCompleted(caseId, 'h1');
      expect(await repos.hints.completedHintIds(caseId), {'h1'});
      expect(
        (await repos.hints.history(caseId)).where((h) => h.actionCompleted),
        hasLength(2),
      );
    });
  });

  group('accusations', () {
    const right = Accusation(
      suspectId: 'sus_isabelle',
      methodId: 'm_poisoned_brandy',
      motiveId: 'mo_embezzlement',
    );

    test('an incomplete accusation is not recorded', () async {
      final r = await repos.accusations
          .submit(caseId, const Accusation(suspectId: 'sus_isabelle'));
      expect(r.verdict, AccusationVerdict.incomplete);
      expect(await repos.accusations.history(caseId), isEmpty);
    });

    test('a wrong accusation is recorded and the case stays open', () async {
      final r = await repos.accusations.submit(
        caseId,
        const Accusation(
          suspectId: 'sus_julian',
          methodId: 'm_poisoned_brandy',
          motiveId: 'mo_inheritance',
        ),
      );
      expect(r.verdict, AccusationVerdict.notQuite);
      expect(r.correctParts, 1);
      final history = await repos.accusations.history(caseId);
      expect(history.single.isCorrect, isFalse);
      expect((await repos.progress.get(caseId)).status, CaseStatus.inProgress);
    });

    test('a right accusation solves the case with a score', () async {
      await repos.hints.recordShown(caseId, 'h1');
      await repos.accusations.submit(
        caseId,
        const Accusation(
          suspectId: 'sus_thomas',
          methodId: 'm_poisoned_brandy',
          motiveId: 'mo_embezzlement',
        ),
      );
      final r = await repos.accusations.submit(caseId, right);
      expect(r.isSolved, isTrue);
      expect(r.score, 85); // 100 - 10 (one wrong try) - 5 (one hint)
      final progress = await repos.progress.get(caseId);
      expect(progress.status, CaseStatus.solved);
      expect(progress.score, 85);
      expect(progress.completedAt, isNotNull);
      expect((await repos.cases.listCases()).single.status, CaseStatus.solved);
    });

    test('board links feed into the result', () async {
      for (final id in ['ev_decanter', 'ev_foxglove', 'ev_logbook', 'ev_clock']) {
        await repos.evidence.collect(caseId, id);
      }
      final d = await repos.board.pin(caseId, 'ev_decanter');
      final f = await repos.board.pin(caseId, 'ev_foxglove');
      final l = await repos.board.pin(caseId, 'ev_logbook');
      final c = await repos.board.pin(caseId, 'ev_clock');
      await repos.board.connect(caseId, f.id, d.id);
      await repos.board.connect(caseId, l.id, c.id);
      final r = await repos.accusations.submit(caseId, right);
      expect(r.linksMade, 2);
      expect(r.linksRequired, 3);
    });
  });

  group('progress', () {
    test('reset wipes player data and returns the case to New', () async {
      await repos.evidence.collect(caseId, 'ev_decanter');
      await repos.notes.add(caseId, 'note');
      await repos.board.pin(caseId, 'ev_decanter');
      await repos.hints.recordShown(caseId, 'h1');
      await repos.progress.reset(caseId);
      expect(await repos.evidence.collectedIds(caseId), isEmpty);
      expect(await repos.notes.list(caseId), isEmpty);
      expect(await repos.board.nodes(caseId), isEmpty);
      final p = await repos.progress.get(caseId);
      expect(p.status, CaseStatus.fresh);
      expect(p.hintsUsed, 0);
      expect(p.startedAt, isNull);
    });
  });
}
