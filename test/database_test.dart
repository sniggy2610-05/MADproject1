import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_manor/data/case_loader.dart';
import 'package:midnight_manor/data/database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Opens a fresh in-memory database for each test.
Future<AppDatabase> openTestDb() => AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );

CaseLoader loaderFor(AppDatabase db) => CaseLoader(
      db.db,
      readAsset: (path) => File(path).readAsString(),
    );

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('schema', () {
    test('creates every content and player table', () async {
      final db = await openTestDb();
      final rows = await db.db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final names = rows.map((r) => r['name'] as String).toSet();
      for (final t in [
        ...AppDatabase.contentTables,
        ...AppDatabase.playerTables,
      ]) {
        expect(names, contains(t));
      }
      expect(await db.db.getVersion(), AppDatabase.schemaVersion);
      await db.close();
    });

    test('rejects an empty note', () async {
      final db = await openTestDb();
      await loaderFor(db).loadBundledCases();
      expect(
        () => db.db.insert('notes', {
          'case_id': 'case_last_toast',
          'text': '   ',
          'created_at': '2026-10-25T00:00:00Z',
        }),
        throwsA(isA<DatabaseException>()),
      );
      await db.close();
    });

    test('rejects a board link from a card to itself', () async {
      final db = await openTestDb();
      await loaderFor(db).loadBundledCases();
      final node = await db.db.insert('board_nodes', {
        'case_id': 'case_last_toast',
        'evidence_id': 'ev_decanter',
      });
      expect(
        () => db.db.insert('board_links', {
          'case_id': 'case_last_toast',
          'from_node': node,
          'to_node': node,
        }),
        throwsA(isA<DatabaseException>()),
      );
      await db.close();
    });

    test('rejects pinning the same clue twice', () async {
      final db = await openTestDb();
      await loaderFor(db).loadBundledCases();
      final row = {'case_id': 'case_last_toast', 'evidence_id': 'ev_decanter'};
      await db.db.insert('board_nodes', row);
      expect(
        () => db.db.insert('board_nodes', row),
        throwsA(isA<DatabaseException>()),
      );
      await db.close();
    });

    test('removing a card removes its strings but keeps the evidence',
        () async {
      final db = await openTestDb();
      await loaderFor(db).loadBundledCases();
      final a = await db.db.insert('board_nodes', {
        'case_id': 'case_last_toast',
        'evidence_id': 'ev_decanter',
      });
      final b = await db.db.insert('board_nodes', {
        'case_id': 'case_last_toast',
        'evidence_id': 'ev_foxglove',
      });
      await db.db.insert('board_links', {
        'case_id': 'case_last_toast',
        'from_node': a,
        'to_node': b,
        'label': 'same poison',
      });
      await db.db.delete('board_nodes', where: 'id = ?', whereArgs: [a]);
      expect(await db.db.query('board_links'), isEmpty);
      expect(
        await db.db.query('evidence', where: 'id = ?', whereArgs: ['ev_decanter']),
        hasLength(1),
      );
      await db.close();
    });
  });

  group('case loader', () {
    test('loads The Last Toast into the content tables', () async {
      final db = await openTestDb();
      final changed = await loaderFor(db).loadBundledCases();
      expect(changed, ['case_last_toast']);

      Future<int> count(String table) async {
        final rows = await db.db.rawQuery('SELECT COUNT(*) AS n FROM $table');
        return rows.first['n'] as int;
      }

      expect(await count('cases'), 1);
      expect(await count('scenes'), 3);
      expect(await count('evidence'), 12);
      expect(await count('suspects'), 5);
      expect(await count('solutions'), 1);
      expect(await count('accusation_options'), 10);
      expect(await count('clue_links'), 8);
      expect(await count('player_progress'), 1);

      final progress = await db.db.query('player_progress');
      expect(progress.single['status'], 'new');
      await db.close();
    });

    test('does nothing on a second launch with the same content version',
        () async {
      final db = await openTestDb();
      final loader = loaderFor(db);
      await loader.loadBundledCases();
      final changed = await loader.loadBundledCases();
      expect(changed, isEmpty);
      await db.close();
    });

    test('a newer content version replaces story rows but keeps player data',
        () async {
      final db = await openTestDb();
      final loader = loaderFor(db);
      await loader.loadBundledCases();

      // Player writes a note and pins a clue.
      await db.db.insert('notes', {
        'case_id': 'case_last_toast',
        'evidence_id': 'ev_decanter',
        'text': 'smells bitter',
        'created_at': '2026-10-25T00:00:00Z',
      });
      await db.db.update(
        'player_progress',
        {'status': 'in_progress'},
        where: 'case_id = ?',
        whereArgs: ['case_last_toast'],
      );

      // A later release ships version 2 of the same case with a new title.
      final original = await CaseLoader.parse(
        await File('assets/cases/the_last_toast.json').readAsString(),
      );
      final updatedJson = original.info.toMap()
        ..['title'] = 'The Last Toast (revised)'
        ..['content_version'] = 2;
      final text = await File('assets/cases/the_last_toast.json').readAsString();
      final updatedText = text
          .replaceFirst('"content_version": 1', '"content_version": 2')
          .replaceFirst('"title": "The Last Toast"',
              '"title": "${updatedJson['title']}"');
      final updated = await CaseLoader.parse(updatedText);

      expect(await loader.upsert(updated), isTrue);

      final caseRow = await db.db.query('cases');
      expect(caseRow.single['title'], 'The Last Toast (revised)');
      expect(caseRow.single['content_version'], 2);
      expect(await db.db.query('notes'), hasLength(1));
      final progress = await db.db.query('player_progress');
      expect(progress.single['status'], 'in_progress');
      await db.close();
    });

    test('refuses a case whose references are broken', () async {
      final text = await File('assets/cases/the_last_toast.json').readAsString();
      final broken = text.replaceFirst('"culprit_id": "sus_isabelle"',
          '"culprit_id": "sus_ghost"');
      expect(() => CaseLoader.parse(broken), throwsA(isA<FormatException>()));
    });
  });
}
