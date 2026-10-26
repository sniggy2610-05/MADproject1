import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Opens the Midnight Manor SQLite database and keeps its schema up to date.
///
/// How versions work:
/// - [schemaVersion] is the version this build of the app expects.
/// - On a fresh install, [_createAll] builds the latest schema in one go.
/// - On an upgrade, every entry in [_migrations] from the old version + 1 up
///   to [schemaVersion] runs in order inside one transaction, so notes and
///   boards made with an older build survive the update.
///
/// To change the schema later: bump [schemaVersion], add the change to
/// [_createAll] (for fresh installs) and add a matching entry to
/// [_migrations] (for existing installs). Never edit an old migration.
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static const schemaVersion = 1;
  static const fileName = 'midnight_manor.db';

  /// Opens (and creates or migrates) the database at the default location.
  /// [factory] lets tests pass an in-memory factory (sqflite_common_ffi).
  static Future<AppDatabase> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final dbFactory = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await dbFactory.getDatabasesPath(), fileName);
    final db = await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) => _createAll(db),
        onUpgrade: _upgrade,
      ),
    );
    return AppDatabase._(db);
  }

  Future<void> close() => db.close();

  // ---------------------------------------------------------------------------
  // Schema
  // ---------------------------------------------------------------------------

  /// Content tables: filled from the bundled JSON, read-only during play.
  static const contentTables = [
    'cases',
    'scenes',
    'evidence',
    'suspects',
    'accusation_options',
    'solutions',
    'clue_links',
  ];

  /// Player tables: written as the player plays.
  static const playerTables = [
    'player_progress',
    'evidence_collected',
    'notes',
    'board_nodes',
    'board_links',
    'accusations',
    'hint_history',
  ];

  static Future<void> _createAll(Database db) async {
    final batch = db.batch();
    for (final sql in _schemaV1) {
      batch.execute(sql);
    }
    await batch.commit(noResult: true);
  }

  static Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    await db.transaction((txn) async {
      for (var v = oldVersion + 1; v <= newVersion; v++) {
        final steps = _migrations[v];
        if (steps == null) {
          throw StateError('No migration defined for schema version $v');
        }
        for (final sql in steps) {
          await txn.execute(sql);
        }
      }
    });
  }

  /// Migrations keyed by the version they upgrade TO.
  /// Version 1 is created by [_createAll], so the map starts at 2.
  static const Map<int, List<String>> _migrations = {
    // 2: ['ALTER TABLE notes ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0'],
  };

  static const List<String> _schemaV1 = [
    // ----- content -----
    '''
    CREATE TABLE cases (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      synopsis TEXT NOT NULL,
      intro TEXT NOT NULL,
      epilogue TEXT NOT NULL,
      difficulty TEXT NOT NULL,
      content_version INTEGER NOT NULL
    )''',
    '''
    CREATE TABLE scenes (
      id TEXT PRIMARY KEY,
      case_id TEXT NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      description TEXT NOT NULL,
      order_index INTEGER NOT NULL
    )''',
    '''
    CREATE TABLE evidence (
      id TEXT PRIMARY KEY,
      case_id TEXT NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
      scene_id TEXT NOT NULL REFERENCES scenes(id) ON DELETE CASCADE,
      title TEXT NOT NULL,
      description TEXT NOT NULL,
      kind TEXT NOT NULL,
      is_key INTEGER NOT NULL DEFAULT 0
    )''',
    '''
    CREATE TABLE suspects (
      id TEXT PRIMARY KEY,
      case_id TEXT NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      role TEXT NOT NULL,
      bio TEXT NOT NULL,
      statement TEXT NOT NULL,
      motive_hint TEXT NOT NULL
    )''',
    '''
    CREATE TABLE accusation_options (
      id TEXT PRIMARY KEY,
      case_id TEXT NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
      kind TEXT NOT NULL CHECK (kind IN ('method', 'motive')),
      label TEXT NOT NULL,
      order_index INTEGER NOT NULL
    )''',
    '''
    CREATE TABLE solutions (
      id TEXT PRIMARY KEY,
      case_id TEXT NOT NULL UNIQUE REFERENCES cases(id) ON DELETE CASCADE,
      culprit_id TEXT NOT NULL REFERENCES suspects(id),
      method TEXT NOT NULL REFERENCES accusation_options(id),
      motive TEXT NOT NULL REFERENCES accusation_options(id),
      required_links TEXT NOT NULL
    )''',
    '''
    CREATE TABLE clue_links (
      id TEXT PRIMARY KEY,
      case_id TEXT NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
      evidence_a_id TEXT NOT NULL REFERENCES evidence(id),
      evidence_b_id TEXT NOT NULL REFERENCES evidence(id),
      description TEXT NOT NULL,
      stage INTEGER NOT NULL DEFAULT 1,
      CHECK (evidence_a_id <> evidence_b_id)
    )''',

    // ----- player -----
    '''
    CREATE TABLE player_progress (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      case_id TEXT NOT NULL UNIQUE REFERENCES cases(id) ON DELETE CASCADE,
      status TEXT NOT NULL DEFAULT 'new'
        CHECK (status IN ('new', 'in_progress', 'solved')),
      started_at TEXT,
      completed_at TEXT,
      hints_used INTEGER NOT NULL DEFAULT 0,
      score INTEGER NOT NULL DEFAULT 0
    )''',
    '''
    CREATE TABLE evidence_collected (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      case_id TEXT NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
      evidence_id TEXT NOT NULL REFERENCES evidence(id),
      collected_at TEXT NOT NULL,
      UNIQUE (case_id, evidence_id)
    )''',
    '''
    CREATE TABLE notes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      case_id TEXT NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
      evidence_id TEXT REFERENCES evidence(id),
      suspect_id TEXT REFERENCES suspects(id),
      text TEXT NOT NULL CHECK (length(trim(text)) > 0),
      created_at TEXT NOT NULL
    )''',
    '''
    CREATE TABLE board_nodes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      case_id TEXT NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
      evidence_id TEXT NOT NULL REFERENCES evidence(id),
      x REAL NOT NULL DEFAULT 0,
      y REAL NOT NULL DEFAULT 0,
      UNIQUE (case_id, evidence_id)
    )''',
    '''
    CREATE TABLE board_links (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      case_id TEXT NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
      from_node INTEGER NOT NULL REFERENCES board_nodes(id) ON DELETE CASCADE,
      to_node INTEGER NOT NULL REFERENCES board_nodes(id) ON DELETE CASCADE,
      label TEXT NOT NULL DEFAULT '',
      CHECK (from_node <> to_node),
      UNIQUE (case_id, from_node, to_node)
    )''',
    '''
    CREATE TABLE accusations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      case_id TEXT NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
      suspect_id TEXT NOT NULL REFERENCES suspects(id),
      method TEXT NOT NULL REFERENCES accusation_options(id),
      motive TEXT NOT NULL REFERENCES accusation_options(id),
      is_correct INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    )''',
    '''
    CREATE TABLE hint_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      case_id TEXT NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
      hint_id TEXT NOT NULL,
      shown_at TEXT NOT NULL,
      action_completed INTEGER NOT NULL DEFAULT 0
    )''',

    // ----- indexes for the lookups the screens do most -----
    'CREATE INDEX idx_scenes_case ON scenes(case_id, order_index)',
    'CREATE INDEX idx_evidence_scene ON evidence(case_id, scene_id)',
    'CREATE INDEX idx_suspects_case ON suspects(case_id)',
    'CREATE INDEX idx_links_case ON clue_links(case_id)',
    'CREATE INDEX idx_collected_case ON evidence_collected(case_id)',
    'CREATE INDEX idx_notes_case ON notes(case_id, created_at)',
    'CREATE INDEX idx_board_nodes_case ON board_nodes(case_id)',
    'CREATE INDEX idx_board_links_case ON board_links(case_id)',
    'CREATE INDEX idx_hints_case ON hint_history(case_id, shown_at)',
  ];
}
