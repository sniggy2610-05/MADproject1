import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite/sqflite.dart';

import '../domain/models/case_content.dart';

/// Reads the bundled case JSON files and copies them into the content tables.
///
/// Runs on every launch, but only writes when a case is missing from the
/// database or the JSON carries a newer `content_version`. Player data is
/// never touched, so updating the story in a later release keeps everyone's
/// notes and boards.
class CaseLoader {
  CaseLoader(this.db, {Future<String> Function(String path)? readAsset})
      : _readAsset = readAsset ?? rootBundle.loadString;

  final Database db;
  final Future<String> Function(String path) _readAsset;

  /// Paths of every case shipped with the app, in library order.
  static const bundledCases = [
    'assets/cases/the_last_toast.json',
  ];

  /// Loads every bundled case. Returns the ids of cases that were inserted
  /// or updated (empty when everything was already current).
  Future<List<String>> loadBundledCases({
    List<String> paths = bundledCases,
  }) async {
    final changed = <String>[];
    for (final path in paths) {
      final content = await parse(await _readAsset(path));
      if (await upsert(content)) {
        changed.add(content.info.id);
      }
    }
    return changed;
  }

  /// Parses one case file and throws if its references do not line up.
  static Future<CaseContent> parse(String jsonText) async {
    final content = CaseContent.fromJson(
      jsonDecode(jsonText) as Map<String, dynamic>,
    );
    final problems = content.validate();
    if (problems.isNotEmpty) {
      throw FormatException(
        'Case ${content.info.id} is invalid:\n- ${problems.join('\n- ')}',
      );
    }
    return content;
  }

  /// Writes the case if it is new or newer than what is stored.
  /// Returns true when something was written.
  Future<bool> upsert(CaseContent content) async {
    final existing = await db.query(
      'cases',
      columns: ['content_version'],
      where: 'id = ?',
      whereArgs: [content.info.id],
    );
    if (existing.isNotEmpty) {
      final stored = existing.first['content_version'] as int;
      if (stored >= content.info.contentVersion) return false;
    }

    await db.transaction((txn) async {
      final caseId = content.info.id;

      // Content rows are updated in place rather than deleted and re-inserted.
      // Player tables (notes, board_nodes, ...) point at evidence and suspect
      // ids, so deleting those rows would fail the foreign key checks and
      // wipe the player's links to them.
      final rows = <String, List<Map<String, Object?>>>{
        'cases': [content.info.toMap()],
        'scenes': content.scenes.map((s) => s.toMap()).toList(),
        'evidence': content.evidence.map((e) => e.toMap()).toList(),
        'suspects': content.suspects.map((s) => s.toMap()).toList(),
        'accusation_options':
            content.accusationOptions.map((o) => o.toMap()).toList(),
        'solutions': [content.solution.toMap()],
        'clue_links': content.clueLinks.map((l) => l.toMap()).toList(),
      };
      for (final entry in rows.entries) {
        for (final row in entry.value) {
          await _upsertRow(txn, entry.key, row);
        }
      }

      // Rows the new file no longer contains are removed, unless player data
      // still refers to them, in which case they stay as harmless leftovers.
      for (final entry in rows.entries) {
        if (entry.key == 'cases') continue;
        final keep = entry.value.map((r) => r['id'] as String).toList();
        final placeholders = List.filled(keep.length, '?').join(',');
        try {
          await txn.delete(
            entry.key,
            where: 'case_id = ? AND id NOT IN ($placeholders)',
            whereArgs: [caseId, ...keep],
          );
        } on DatabaseException {
          // Still referenced by player data; leave the old rows in place.
        }
      }

      // Every case gets a progress row so the library can show New / In
      // Progress / Solved without special cases. Ignore if one exists.
      await txn.insert(
        'player_progress',
        {'case_id': caseId, 'status': 'new'},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    });
    return true;
  }

  /// INSERT the row, or UPDATE every column if a row with that id exists.
  static Future<void> _upsertRow(
    DatabaseExecutor txn,
    String table,
    Map<String, Object?> row,
  ) {
    final cols = row.keys.toList();
    final placeholders = List.filled(cols.length, '?').join(', ');
    final updates =
        cols.where((c) => c != 'id').map((c) => '$c = excluded.$c').join(', ');
    return txn.rawInsert(
      'INSERT INTO $table (${cols.join(', ')}) VALUES ($placeholders) '
      'ON CONFLICT(id) DO UPDATE SET $updates',
      row.values.toList(),
    );
  }
}
