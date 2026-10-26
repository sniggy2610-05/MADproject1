/// Compares the player's accusation with the case solution.
///
/// Pure Dart, no database and no Flutter, so it can be unit tested with
/// hand-made inputs. The repositories gather the inputs and call [check].
library;

import 'models/case_content.dart';

/// What the player picked on the accusation screen. Any part may still be
/// empty; [missingParts] says which.
class Accusation {
  const Accusation({this.suspectId, this.methodId, this.motiveId});

  final String? suspectId;
  final String? methodId;
  final String? motiveId;

  List<String> get missingParts => [
        if (suspectId == null || suspectId!.isEmpty) 'suspect',
        if (methodId == null || methodId!.isEmpty) 'method',
        if (motiveId == null || motiveId!.isEmpty) 'motive',
      ];

  bool get isComplete => missingParts.isEmpty;
}

enum AccusationVerdict {
  /// A part of the accusation was left blank. Nothing is recorded.
  incomplete,

  /// At least one part is wrong. The player keeps investigating.
  notQuite,

  /// Culprit, method and motive are all right.
  solved,
}

/// The outcome of an accusation.
///
/// On purpose it does NOT say which parts were right. The proposal's edge
/// case table says a wrong accusation shows "Not Quite" without revealing
/// the answer, so screens only get a count.
class AccusationResult {
  const AccusationResult({
    required this.verdict,
    required this.correctParts,
    required this.linksMade,
    required this.linksRequired,
    required this.score,
    required this.message,
    this.missingParts = const [],
  });

  final AccusationVerdict verdict;

  /// How many of culprit, method and motive were right (0 to 3).
  final int correctParts;
  static const totalParts = 3;

  /// How many of the solution's required clue links the player has drawn on
  /// the board, out of how many there are.
  final int linksMade;
  final int linksRequired;

  /// 0 unless solved. See [AccusationChecker.scoreFor].
  final int score;

  /// Short text for the result screen.
  final String message;

  /// Only filled for [AccusationVerdict.incomplete].
  final List<String> missingParts;

  bool get isSolved => verdict == AccusationVerdict.solved;
}

class AccusationChecker {
  const AccusationChecker();

  static const maxScore = 100;
  static const minSolvedScore = 10;
  static const wrongAttemptPenalty = 10;
  static const hintPenalty = 5;

  /// [boardConnections] are pairs of evidence ids the player has joined with
  /// string on the Evidence Board, in any order.
  AccusationResult check({
    required Accusation accusation,
    required Solution solution,
    required Iterable<ClueLink> clueLinks,
    Iterable<(String, String)> boardConnections = const [],
    int previousWrongAttempts = 0,
    int hintsUsed = 0,
  }) {
    final linksRequired = solution.requiredLinkIds.length;
    final linksMade = countRequiredLinksMade(
      solution: solution,
      clueLinks: clueLinks,
      boardConnections: boardConnections,
    );

    if (!accusation.isComplete) {
      final missing = accusation.missingParts;
      return AccusationResult(
        verdict: AccusationVerdict.incomplete,
        correctParts: 0,
        linksMade: linksMade,
        linksRequired: linksRequired,
        score: 0,
        missingParts: missing,
        message: 'Fill in the missing ${missing.length == 1 ? 'part' : 'parts'}: '
            '${missing.join(', ')}.',
      );
    }

    var correct = 0;
    if (accusation.suspectId == solution.culpritId) correct++;
    if (accusation.methodId == solution.methodId) correct++;
    if (accusation.motiveId == solution.motiveId) correct++;

    if (correct == AccusationResult.totalParts) {
      return AccusationResult(
        verdict: AccusationVerdict.solved,
        correctParts: correct,
        linksMade: linksMade,
        linksRequired: linksRequired,
        score: scoreFor(
          previousWrongAttempts: previousWrongAttempts,
          hintsUsed: hintsUsed,
        ),
        message: 'Case closed. You named the culprit, the method and the motive.',
      );
    }

    return AccusationResult(
      verdict: AccusationVerdict.notQuite,
      correctParts: correct,
      linksMade: linksMade,
      linksRequired: linksRequired,
      score: 0,
      message: correct == 0
          ? 'Not quite. None of your theory holds up yet. Keep investigating.'
          : 'Not quite. $correct of ${AccusationResult.totalParts} parts of '
              'your theory hold up. Keep investigating.',
    );
  }

  /// Score for a solved case: 100, minus 10 for each earlier wrong
  /// accusation and 5 for each hint used, never below 10.
  static int scoreFor({int previousWrongAttempts = 0, int hintsUsed = 0}) {
    final score = maxScore -
        wrongAttemptPenalty * previousWrongAttempts -
        hintPenalty * hintsUsed;
    return score < minSolvedScore ? minSolvedScore : score;
  }

  /// How many of the solution's required links the player has drawn.
  static int countRequiredLinksMade({
    required Solution solution,
    required Iterable<ClueLink> clueLinks,
    required Iterable<(String, String)> boardConnections,
  }) {
    final byId = {for (final l in clueLinks) l.id: l};
    var made = 0;
    for (final id in solution.requiredLinkIds) {
      final link = byId[id];
      if (link == null) continue;
      final drawn = boardConnections.any((c) => link.joins(c.$1, c.$2));
      if (drawn) made++;
    }
    return made;
  }
}
