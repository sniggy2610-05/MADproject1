/// A portable copy of everything the player has done, for cloud backup.
///
/// Plain Dart with JSON in and out. Board strings are stored by evidence id,
/// not by node id, because node ids are regenerated on restore.
library;

class BackupSnapshot {
  const BackupSnapshot({required this.updatedAt, required this.cases});

  /// When this snapshot was taken on the device.
  final DateTime updatedAt;

  /// Keyed by case id.
  final Map<String, CaseBackup> cases;

  static const formatVersion = 1;

  bool get isEmpty => cases.isEmpty;

  Map<String, dynamic> toJson() => {
        'format_version': formatVersion,
        'updated_at': updatedAt.toIso8601String(),
        'cases': {for (final e in cases.entries) e.key: e.value.toJson()},
      };

  factory BackupSnapshot.fromJson(Map<String, dynamic> json) {
    final version = json['format_version'] as int? ?? 1;
    if (version > formatVersion) {
      throw FormatException(
        'Backup was made by a newer version of the app ($version).',
      );
    }
    final cases = (json['cases'] as Map<String, dynamic>? ?? {}).map(
      (id, value) =>
          MapEntry(id, CaseBackup.fromJson(value as Map<String, dynamic>)),
    );
    return BackupSnapshot(
      updatedAt: DateTime.parse(json['updated_at'] as String),
      cases: cases,
    );
  }
}

class CaseBackup {
  const CaseBackup({
    required this.status,
    this.startedAt,
    this.completedAt,
    this.hintsUsed = 0,
    this.score = 0,
    this.evidence = const [],
    this.notes = const [],
    this.boardNodes = const [],
    this.boardLinks = const [],
    this.accusations = const [],
    this.hints = const [],
  });

  final String status;
  final String? startedAt;
  final String? completedAt;
  final int hintsUsed;
  final int score;
  final List<Map<String, dynamic>> evidence;
  final List<Map<String, dynamic>> notes;
  final List<Map<String, dynamic>> boardNodes;
  final List<Map<String, dynamic>> boardLinks;
  final List<Map<String, dynamic>> accusations;
  final List<Map<String, dynamic>> hints;

  Map<String, dynamic> toJson() => {
        'status': status,
        'started_at': startedAt,
        'completed_at': completedAt,
        'hints_used': hintsUsed,
        'score': score,
        'evidence': evidence,
        'notes': notes,
        'board_nodes': boardNodes,
        'board_links': boardLinks,
        'accusations': accusations,
        'hints': hints,
      };

  factory CaseBackup.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> rows(String key) =>
        (json[key] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
    return CaseBackup(
      status: json['status'] as String,
      startedAt: json['started_at'] as String?,
      completedAt: json['completed_at'] as String?,
      hintsUsed: json['hints_used'] as int? ?? 0,
      score: json['score'] as int? ?? 0,
      evidence: rows('evidence'),
      notes: rows('notes'),
      boardNodes: rows('board_nodes'),
      boardLinks: rows('board_links'),
      accusations: rows('accusations'),
      hints: rows('hints'),
    );
  }
}
