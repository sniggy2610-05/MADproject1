import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_manor/data/case_loader.dart';
import 'package:midnight_manor/data/database.dart';
import 'package:midnight_manor/data/repositories/repositories.dart';
import 'package:midnight_manor/domain/accusation_checker.dart';
import 'package:midnight_manor/domain/models/backup.dart';
import 'package:midnight_manor/domain/models/player_data.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const caseId = 'case_last_toast';

Future<Repositories> freshRepos({DateTime? start}) async {
  var tick = start ?? DateTime.utc(2026, 10, 25, 22);
  final db = await AppDatabase.open(
    factory: databaseFactoryFfi,
    path: inMemoryDatabasePath,
  );
  await CaseLoader(db.db, readAsset: (p) => File(p).readAsString())
      .loadBundledCases();
  return Repositories(db, now: () => tick = tick.add(const Duration(seconds: 1)));
}

/// Plays a little of the case so there is something to back up.
Future<void> playSome(Repositories r) async {
  await r.evidence.collect(caseId, 'ev_decanter');
  await r.evidence.collect(caseId, 'ev_foxglove');
  await r.notes.add(caseId, 'smells bitter', evidenceId: 'ev_decanter');
  await r.notes.add(caseId, 'too calm', suspectId: 'sus_isabelle');
  final d = await r.board.pin(caseId, 'ev_decanter', x: 10, y: 20);
  final f = await r.board.pin(caseId, 'ev_foxglove', x: 30, y: 40);
  await r.board.connect(caseId, d.id, f.id, label: 'same poison');
  await r.hints.recordShown(caseId, 'find:sc_dining');
  await r.accusations.submit(
    caseId,
    const Accusation(
      suspectId: 'sus_julian',
      methodId: 'm_poisoned_brandy',
      motiveId: 'mo_inheritance',
    ),
  );
}

void main() {
  setUpAll(sqfliteFfiInit);

  group('BackupSnapshot', () {
    test('round-trips through JSON', () {
      final snap = BackupSnapshot(
        updatedAt: DateTime.utc(2026, 10, 25, 12),
        cases: {
          'c1': const CaseBackup(
            status: 'in_progress',
            startedAt: '2026-10-25T11:00:00.000Z',
            hintsUsed: 2,
            score: 0,
            evidence: [
              {'evidence_id': 'e1', 'collected_at': '2026-10-25T11:01:00.000Z'},
            ],
            boardLinks: [
              {'from_evidence': 'e1', 'to_evidence': 'e2', 'label': 'x'},
            ],
          ),
        },
      );
      final text = jsonEncode(snap.toJson());
      final back = BackupSnapshot.fromJson(jsonDecode(text) as Map<String, dynamic>);
      expect(back.updatedAt, snap.updatedAt);
      expect(back.cases.keys, ['c1']);
      expect(back.cases['c1']!.hintsUsed, 2);
      expect(back.cases['c1']!.evidence.single['evidence_id'], 'e1');
      expect(back.cases['c1']!.boardLinks.single['label'], 'x');
      expect(back.cases['c1']!.notes, isEmpty);
    });

    test('refuses a snapshot from a newer app', () {
      expect(
        () => BackupSnapshot.fromJson({
          'format_version': 99,
          'updated_at': '2026-10-25T12:00:00.000Z',
          'cases': {},
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('schema v2 migration', () {
    test('fresh database is at version 2 with sync_meta', () async {
      final db = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      expect(await db.db.getVersion(), 2);
      final tables = (await db.db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      ))
          .map((r) => r['name'])
          .toSet();
      expect(tables, contains('sync_meta'));
      await db.close();
    });

    test('upgrading a version 1 file keeps notes and boards', () async {
      final dir = await Directory.systemTemp.createTemp('mm_migrate');
      final path = '${dir.path}/v1.db';

      // Build a real version 1 database with some play in it.
      final v1 = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: (db, _) async {
            for (final sql in AppDatabase.schemaV1) {
              await db.execute(sql);
            }
          },
        ),
      );
      await CaseLoader(v1, readAsset: (p) => File(p).readAsString())
          .loadBundledCases();
      await v1.insert('evidence_collected', {
        'case_id': caseId,
        'evidence_id': 'ev_clock',
        'collected_at': '2026-10-25T10:00:00.000Z',
      });
      await v1.insert('notes', {
        'case_id': caseId,
        'text': 'kept across upgrade',
        'created_at': '2026-10-25T10:01:00.000Z',
      });
      final node = await v1.insert('board_nodes', {
        'case_id': caseId,
        'evidence_id': 'ev_clock',
        'x': 5,
        'y': 6,
      });
      expect(await v1.getVersion(), 1);
      await v1.close();

      // Open the same file with the current app: migration 2 runs.
      final upgraded = await AppDatabase.open(factory: databaseFactoryFfi, path: path);
      expect(await upgraded.db.getVersion(), AppDatabase.schemaVersion);
      final repos = Repositories(upgraded);
      expect((await repos.notes.list(caseId)).single.text, 'kept across upgrade');
      expect((await repos.board.nodeById(node))!.x, 5);
      expect(await repos.evidence.isCollected(caseId, 'ev_clock'), isTrue);
      expect(await repos.sync.backupPending(), isFalse); // sync_meta usable
      await upgraded.close();
      await dir.delete(recursive: true);
    });
  });

  group('SyncRepository export and import', () {
    test('export captures every player table by evidence id', () async {
      final r = await freshRepos();
      await playSome(r);
      final snap = await r.sync.export(now: DateTime.utc(2026, 10, 26));

      final c = snap.cases[caseId]!;
      expect(c.status, 'in_progress');
      expect(c.hintsUsed, 1);
      expect(c.evidence.map((e) => e['evidence_id']), ['ev_decanter', 'ev_foxglove']);
      expect(c.notes, hasLength(2));
      expect(c.boardNodes, hasLength(2));
      expect(c.boardLinks.single, {
        'from_evidence': 'ev_decanter',
        'to_evidence': 'ev_foxglove',
        'label': 'same poison',
      });
      expect(c.accusations.single['is_correct'], 0);
      expect(c.hints.single['hint_id'], 'find:sc_dining');
      await r.database.close();
    });

    test('untouched cases are left out of the export', () async {
      final r = await freshRepos();
      final snap = await r.sync.export(now: DateTime.utc(2026, 10, 26));
      expect(snap.isEmpty, isTrue);
      await r.database.close();
    });

    test('import rebuilds the same state on another device', () async {
      final a = await freshRepos();
      await playSome(a);
      final snap = await a.sync.export(now: DateTime.utc(2026, 10, 26));
      final json = jsonDecode(jsonEncode(snap.toJson())) as Map<String, dynamic>;

      final b = await freshRepos();
      await b.sync.import(BackupSnapshot.fromJson(json));

      expect(await b.evidence.collectedIds(caseId), {'ev_decanter', 'ev_foxglove'});
      expect((await b.notes.list(caseId)).map((n) => n.text), ['too calm', 'smells bitter']);
      final nodes = await b.board.nodes(caseId);
      expect(nodes.map((n) => n.evidenceId).toSet(), {'ev_decanter', 'ev_foxglove'});
      expect(nodes.firstWhere((n) => n.evidenceId == 'ev_decanter').x, 10);
      expect(await b.board.connectedEvidencePairs(caseId), [('ev_decanter', 'ev_foxglove')]);
      expect((await b.board.links(caseId)).single.label, 'same poison');
      expect((await b.accusations.history(caseId)).single.suspectId, 'sus_julian');
      expect((await b.hints.history(caseId)).single.hintId, 'find:sc_dining');
      final p = await b.progress.get(caseId);
      expect(p.status, CaseStatus.inProgress);
      expect(p.hintsUsed, 1);
      await a.database.close();
      await b.database.close();
    });

    test('import replaces old local data for the case', () async {
      final r = await freshRepos();
      await r.evidence.collect(caseId, 'ev_clock');
      await r.notes.add(caseId, 'old local note');
      await r.sync.import(BackupSnapshot(
        updatedAt: DateTime.utc(2026, 10, 26),
        cases: {
          caseId: const CaseBackup(status: 'in_progress', evidence: [
            {'evidence_id': 'ev_gloves', 'collected_at': '2026-10-26T00:00:00.000Z'},
          ]),
        },
      ));
      expect(await r.evidence.collectedIds(caseId), {'ev_gloves'});
      expect(await r.notes.list(caseId), isEmpty);
      await r.database.close();
    });

    test('import skips rows that point at unknown content instead of failing',
        () async {
      final r = await freshRepos();
      await r.sync.import(BackupSnapshot(
        updatedAt: DateTime.utc(2026, 10, 26),
        cases: {
          caseId: const CaseBackup(status: 'in_progress', evidence: [
            {'evidence_id': 'ev_from_future_case_file', 'collected_at': '2026-10-26T00:00:00.000Z'},
            {'evidence_id': 'ev_clock', 'collected_at': '2026-10-26T00:00:01.000Z'},
          ]),
          'case_unknown': const CaseBackup(status: 'solved'),
        },
      ));
      expect(await r.evidence.collectedIds(caseId), {'ev_clock'});
      await r.database.close();
    });

    test('latestLocalActivity follows the newest timestamp', () async {
      final r = await freshRepos();
      expect(await r.sync.latestLocalActivity(), isNull);
      await r.evidence.collect(caseId, 'ev_clock');
      final t1 = await r.sync.latestLocalActivity();
      await r.notes.add(caseId, 'later');
      final t2 = await r.sync.latestLocalActivity();
      expect(t2!.isAfter(t1!), isTrue);
      await r.database.close();
    });
  });
}
