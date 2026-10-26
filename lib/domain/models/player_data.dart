/// Plain Dart models for everything the player creates while playing.
///
/// These mirror the player tables in SQLite. No Flutter imports.
library;

import 'case_content.dart';

/// Thrown when the player tries something the game rules forbid, such as
/// pinning a clue they have not found. The message is safe to show on screen.
class RuleViolation implements Exception {
  const RuleViolation(this.message);
  final String message;

  @override
  String toString() => 'RuleViolation: $message';
}

enum CaseStatus {
  fresh('new'),
  inProgress('in_progress'),
  solved('solved');

  const CaseStatus(this.dbValue);
  final String dbValue;

  static CaseStatus fromDb(String value) =>
      values.firstWhere((s) => s.dbValue == value);
}

class PlayerProgress {
  const PlayerProgress({
    required this.caseId,
    required this.status,
    this.startedAt,
    this.completedAt,
    this.hintsUsed = 0,
    this.score = 0,
  });

  final String caseId;
  final CaseStatus status;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int hintsUsed;
  final int score;

  factory PlayerProgress.fromMap(Map<String, Object?> row) => PlayerProgress(
        caseId: row['case_id'] as String,
        status: CaseStatus.fromDb(row['status'] as String),
        startedAt: _parseDate(row['started_at']),
        completedAt: _parseDate(row['completed_at']),
        hintsUsed: row['hints_used'] as int,
        score: row['score'] as int,
      );
}

/// A case as shown in the library: its content info plus player status.
class CaseSummary {
  const CaseSummary({required this.info, required this.progress});
  final CaseInfo info;
  final PlayerProgress progress;
  CaseStatus get status => progress.status;
}

class Note {
  const Note({
    required this.id,
    required this.caseId,
    required this.text,
    required this.createdAt,
    this.evidenceId,
    this.suspectId,
  });

  final int id;
  final String caseId;
  final String? evidenceId;
  final String? suspectId;
  final String text;
  final DateTime createdAt;

  factory Note.fromMap(Map<String, Object?> row) => Note(
        id: row['id'] as int,
        caseId: row['case_id'] as String,
        evidenceId: row['evidence_id'] as String?,
        suspectId: row['suspect_id'] as String?,
        text: row['text'] as String,
        createdAt: _parseDate(row['created_at'])!,
      );
}

/// A clue card on the Evidence Board.
class BoardNode {
  const BoardNode({
    required this.id,
    required this.caseId,
    required this.evidenceId,
    required this.x,
    required this.y,
  });

  final int id;
  final String caseId;
  final String evidenceId;
  final double x;
  final double y;

  factory BoardNode.fromMap(Map<String, Object?> row) => BoardNode(
        id: row['id'] as int,
        caseId: row['case_id'] as String,
        evidenceId: row['evidence_id'] as String,
        x: (row['x'] as num).toDouble(),
        y: (row['y'] as num).toDouble(),
      );
}

/// A string between two cards on the Evidence Board.
class BoardLink {
  const BoardLink({
    required this.id,
    required this.caseId,
    required this.fromNode,
    required this.toNode,
    required this.label,
  });

  final int id;
  final String caseId;
  final int fromNode;
  final int toNode;
  final String label;

  factory BoardLink.fromMap(Map<String, Object?> row) => BoardLink(
        id: row['id'] as int,
        caseId: row['case_id'] as String,
        fromNode: row['from_node'] as int,
        toNode: row['to_node'] as int,
        label: row['label'] as String,
      );
}

class AccusationRecord {
  const AccusationRecord({
    required this.id,
    required this.caseId,
    required this.suspectId,
    required this.methodId,
    required this.motiveId,
    required this.isCorrect,
    required this.createdAt,
  });

  final int id;
  final String caseId;
  final String suspectId;
  final String methodId;
  final String motiveId;
  final bool isCorrect;
  final DateTime createdAt;

  factory AccusationRecord.fromMap(Map<String, Object?> row) =>
      AccusationRecord(
        id: row['id'] as int,
        caseId: row['case_id'] as String,
        suspectId: row['suspect_id'] as String,
        methodId: row['method'] as String,
        motiveId: row['motive'] as String,
        isCorrect: (row['is_correct'] as int) == 1,
        createdAt: _parseDate(row['created_at'])!,
      );
}

class HintRecord {
  const HintRecord({
    required this.id,
    required this.caseId,
    required this.hintId,
    required this.shownAt,
    required this.actionCompleted,
  });

  final int id;
  final String caseId;
  final String hintId;
  final DateTime shownAt;
  final bool actionCompleted;

  factory HintRecord.fromMap(Map<String, Object?> row) => HintRecord(
        id: row['id'] as int,
        caseId: row['case_id'] as String,
        hintId: row['hint_id'] as String,
        shownAt: _parseDate(row['shown_at'])!,
        actionCompleted: (row['action_completed'] as int) == 1,
      );
}

DateTime? _parseDate(Object? value) =>
    value == null ? null : DateTime.parse(value as String);
