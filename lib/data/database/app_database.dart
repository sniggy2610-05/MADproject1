import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._();
  AppDatabase._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    final dbPath = await getDatabasesPath();

    _database = await openDatabase(
      join(dbPath, 'midnight_manor.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE CaseRecord (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            synopsis TEXT NOT NULL,
            contentJson TEXT NOT NULL,
            solutionKey TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'New',
            lastGuess TEXT,
            inspectedClueKeysJson TEXT NOT NULL DEFAULT '[]'
          )
        ''');

        await db.execute('''
          CREATE TABLE EvidenceNote (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            caseId INTEGER NOT NULL,
            clueKey TEXT NOT NULL,
            type TEXT NOT NULL,
            text TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            FOREIGN KEY(caseId) REFERENCES CaseRecord(id)
              ON DELETE CASCADE
          )
        ''');

        await db.insert('CaseRecord', {
          'title': 'The Missing Lantern',
          'synopsis':
              'A treasured lantern disappears during a celebration '
              'at Blackwood Manor.',
          'contentJson': '''
          {
            "suspects": [
              {"id":"S1","name":"Eleanor","role":"The Host"},
              {"id":"S2","name":"Arthur","role":"The Groundskeeper"},
              {"id":"S3","name":"Clara","role":"The Guest"}
            ],
            "clues": [
              {"id":"C1","name":"The Ribbon","description":"A ribbon is found near the window."},
              {"id":"C2","name":"The Program","description":"A penciled note appears on the event program."},
              {"id":"C3","name":"The Footprint","description":"A muddy footprint is found near the entrance."}
            ],
            "hints": [
              {"id":"H1","text":"Compare the ribbon with the guests' belongings.","requires":["C1"],"relatedGuess":"S2"},
              {"id":"H2","text":"Look closely at the penciled program note.","requires":["C2"]},
              {"id":"H3","text":"Consider who could access the entrance.","requires":["C3"]}
            ]
          }
          ''',
          'solutionKey': 'S2',
          'status': 'New',
          'lastGuess': null,
          'inspectedClueKeysJson': '[]',
        });
      },
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );

    return _database!;
  }
}
