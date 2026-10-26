/// Smart Hints: a rule-based recommender that reads the player's progress
/// and suggests one next step, with an explanation of why.
///
/// This is the "AI learning component" from section 7 of the proposal. It is
/// honestly a scoring model, not a neural network: every candidate hint gets
/// points from four fixed rules, the highest wins, and ties always break the
/// same way. Pure Dart, no database, no Flutter, no network.
///
/// Scoring rules (section 7):
///   +4 if the hint relates to a key clue
///   +2 if the clue or link is still unresolved
///   +1 if it fits the player's current stage
///   -3 if the same hint was shown recently
library;

import 'accusation_checker.dart';
import 'models/case_content.dart';

/// Where the player is in the case. Drives the "+1 stage fit" rule.
enum PlayerStage {
  /// Fewer than half of the key clues found: keep exploring rooms.
  investigate(1, 'exploring the rooms'),

  /// Half or more of the key clues found: pin and connect them.
  connect(2, 'connecting clues on the board'),

  /// Every required link drawn: time to accuse.
  accuse(3, 'ready to accuse');

  const PlayerStage(this.number, this.label);
  final int number;
  final String label;
}

/// Order matters: it is the tie-break when scores are equal. When the player
/// can finish the case, saying so beats any other suggestion.
enum HintKind { accuse, link, pin, find }

/// A snapshot of everything the engine looks at. The data layer builds it
/// from the repositories; tests build it by hand.
class HintState {
  const HintState({
    required this.caseId,
    required this.scenes,
    required this.evidence,
    required this.clueLinks,
    required this.solution,
    this.collectedIds = const {},
    this.pinnedIds = const {},
    this.connectedPairs = const [],
    this.notedEvidenceIds = const {},
    this.recentHintIds = const [],
    this.completedHintIds = const {},
    this.wrongAccusations = 0,
    this.solved = false,
  });

  final String caseId;
  final List<Scene> scenes;
  final List<Evidence> evidence;
  final List<ClueLink> clueLinks;
  final Solution solution;

  /// Evidence the player has found.
  final Set<String> collectedIds;

  /// Evidence currently pinned on the board.
  final Set<String> pinnedIds;

  /// Pairs of evidence ids joined with string, in any order.
  final List<(String, String)> connectedPairs;

  /// Evidence the player has written a note about.
  final Set<String> notedEvidenceIds;

  /// Ids of hints shown, newest first.
  final List<String> recentHintIds;

  /// Ids of hints the player acted on.
  final Set<String> completedHintIds;

  final int wrongAccusations;
  final bool solved;

  int get keyTotal => evidence.where((e) => e.isKey).length;
  int get keyFound =>
      evidence.where((e) => e.isKey && collectedIds.contains(e.id)).length;

  int get requiredLinksTotal => solution.requiredLinkIds.length;
  int get requiredLinksMade => AccusationChecker.countRequiredLinksMade(
        solution: solution,
        clueLinks: clueLinks,
        boardConnections: connectedPairs,
      );

  bool isConnected(String a, String b) =>
      connectedPairs.any((p) => (p.$1 == a && p.$2 == b) || (p.$1 == b && p.$2 == a));

  bool hasAnyConnection(String evidenceId) =>
      connectedPairs.any((p) => p.$1 == evidenceId || p.$2 == evidenceId);
}

/// One scoring rule that applied to a hint, for the "Why this hint?" box.
class HintReason {
  const HintReason(this.points, this.text);
  final int points;
  final String text;

  String get line => '${points >= 0 ? '+' : ''}$points  $text';
}

class Hint {
  const Hint({
    required this.id,
    required this.kind,
    required this.text,
    required this.score,
    required this.reasons,
  });

  final String id;
  final HintKind kind;

  /// What to show the player. Never names the culprit, method or motive.
  final String text;
  final int score;
  final List<HintReason> reasons;
}

enum HintOutcome { hint, noHintsLeft, caseSolved }

class HintResult {
  const HintResult({
    required this.outcome,
    required this.stage,
    required this.summary,
    required this.message,
    this.hint,
    this.candidates = const [],
  });

  final HintOutcome outcome;
  final PlayerStage stage;

  /// One line describing the state the hint was chosen from.
  final String summary;

  /// The hint text, or the friendly message when there is none.
  final String message;
  final Hint? hint;

  /// Every scored candidate, best first. Handy for the hint screen's
  /// debug view and for tests.
  final List<Hint> candidates;

  /// Lines for the "Why this hint?" box.
  List<String> get whyLines => [
        summary,
        'You are ${stage.label}.',
        if (hint != null) ...hint!.reasons.map((r) => r.line),
        if (hint != null)
          'Total: ${hint!.score} points, the highest of ${candidates.length}.',
      ];
}

class HintEngine {
  const HintEngine({this.recentWindow = 3});

  /// How many of the most recent hints count as "shown recently".
  final int recentWindow;

  static const keyCluePoints = 4;
  static const unresolvedPoints = 2;
  static const stageFitPoints = 1;
  static const recentlyShownPoints = -3;

  PlayerStage stageOf(HintState s) {
    if (s.requiredLinksTotal > 0 && s.requiredLinksMade >= s.requiredLinksTotal) {
      return PlayerStage.accuse;
    }
    if (s.keyTotal > 0 && s.keyFound * 2 >= s.keyTotal) {
      return PlayerStage.connect;
    }
    return PlayerStage.investigate;
  }

  String summaryOf(HintState s) {
    final total = s.evidence.length;
    return 'Found ${s.collectedIds.length} of $total clues '
        '(${s.keyFound} of ${s.keyTotal} key). '
        'Pinned ${s.pinnedIds.length}. '
        'Key connections: ${s.requiredLinksMade} of ${s.requiredLinksTotal}.';
  }

  /// Picks the next hint. Same input always gives the same output.
  HintResult next(HintState s) {
    final stage = stageOf(s);
    final summary = summaryOf(s);

    if (s.solved) {
      return HintResult(
        outcome: HintOutcome.caseSolved,
        stage: stage,
        summary: summary,
        message: 'Case closed. There is nothing left to hint at. '
            'Try the case again from the library if you want another run.',
      );
    }

    final ranked = candidates(s, stage: stage);
    if (ranked.isEmpty) {
      return HintResult(
        outcome: HintOutcome.noHintsLeft,
        stage: stage,
        summary: summary,
        message: 'No new hints right now. Re-read the suspects\' statements '
            'against what you have found, or make your accusation.',
      );
    }

    final best = ranked.first;
    return HintResult(
      outcome: HintOutcome.hint,
      stage: stage,
      summary: summary,
      message: best.text,
      hint: best,
      candidates: ranked,
    );
  }

  /// Every possible hint for this state, scored and sorted best first.
  /// Hints the player already completed are left out.
  List<Hint> candidates(HintState s, {PlayerStage? stage}) {
    stage ??= stageOf(s);
    final recent = s.recentHintIds.take(recentWindow).toSet();
    final byId = {for (final e in s.evidence) e.id: e};
    final out = <Hint>[];

    void add({
      required String id,
      required HintKind kind,
      required String text,
      required bool keyClue,
      required String keyReason,
      required bool unresolved,
      required String unresolvedReason,
      required bool stageFit,
    }) {
      if (s.completedHintIds.contains(id)) return;
      final reasons = <HintReason>[];
      var score = 0;
      if (keyClue) {
        score += keyCluePoints;
        reasons.add(HintReason(keyCluePoints, keyReason));
      }
      if (unresolved) {
        score += unresolvedPoints;
        reasons.add(HintReason(unresolvedPoints, unresolvedReason));
      }
      if (stageFit) {
        score += stageFitPoints;
        reasons.add(HintReason(
          stageFitPoints,
          'It fits where you are: ${stage!.label}.',
        ));
      }
      if (recent.contains(id)) {
        score += recentlyShownPoints;
        reasons.add(const HintReason(
          recentlyShownPoints,
          'You were shown this hint recently.',
        ));
      }
      out.add(Hint(id: id, kind: kind, text: text, score: score, reasons: reasons));
    }

    // ----- link hints: both clues found, not yet connected -----
    for (final link in s.clueLinks) {
      final a = byId[link.evidenceAId];
      final b = byId[link.evidenceBId];
      if (a == null || b == null) continue;
      if (!s.collectedIds.contains(a.id) || !s.collectedIds.contains(b.id)) {
        continue;
      }
      if (s.isConnected(a.id, b.id)) continue;
      final touched = s.hasAnyConnection(a.id) || s.hasAnyConnection(b.id);
      add(
        id: 'link:${link.id}',
        kind: HintKind.link,
        text: 'Compare the ${a.title} with the ${b.title}. '
            'Pin both and draw a string between them if they connect.',
        keyClue: a.isKey || b.isKey,
        keyReason: 'It involves a key clue.',
        unresolved: !touched,
        unresolvedReason: 'Neither clue is connected to anything on the board yet.',
        stageFit: link.stage == stage.number,
      );
    }

    // ----- pin hints: found but not on the board -----
    for (final e in s.evidence) {
      if (!s.collectedIds.contains(e.id) || s.pinnedIds.contains(e.id)) continue;
      add(
        id: 'pin:${e.id}',
        kind: HintKind.pin,
        text: 'Pin the ${e.title} to the Evidence Board so you can connect it to other clues.',
        keyClue: e.isKey,
        keyReason: 'The ${e.title} is a key clue.',
        unresolved: !s.notedEvidenceIds.contains(e.id),
        unresolvedReason: 'You have not written a note about it yet.',
        stageFit: stage == PlayerStage.connect,
      );
    }

    // ----- find hints: one per room that still holds something -----
    for (final scene in s.scenes) {
      final inRoom = s.evidence.where((e) => e.sceneId == scene.id).toList();
      final missing = inRoom.where((e) => !s.collectedIds.contains(e.id)).toList();
      if (missing.isEmpty) continue;
      final foundHere = inRoom.length - missing.length;
      add(
        id: 'find:${scene.id}',
        kind: HintKind.find,
        text: 'Search ${scene.name} again. '
            '${missing.length == 1 ? 'One item' : '${missing.length} items'} there '
            '${missing.length == 1 ? 'has' : 'have'} not been examined yet.',
        keyClue: missing.any((e) => e.isKey),
        keyReason: 'Something important is still hidden in ${scene.name}.',
        unresolved: foundHere == 0,
        unresolvedReason: 'You have not found anything in ${scene.name} yet.',
        stageFit: stage == PlayerStage.investigate,
      );
    }

    // ----- accuse hint: every required link drawn -----
    if (s.requiredLinksTotal > 0 && s.requiredLinksMade >= s.requiredLinksTotal) {
      add(
        id: 'accuse',
        kind: HintKind.accuse,
        text: 'You have connected the key clues. Open the accusation file '
            'from the board and name who, how and why.',
        keyClue: true,
        keyReason: 'Every key connection is on the board.',
        unresolved: s.wrongAccusations == 0,
        unresolvedReason: 'You have not made an accusation yet.',
        stageFit: stage == PlayerStage.accuse,
      );
    }

    out.sort(_compare);
    return out;
  }

  /// Highest score first; ties go accuse, link, pin, find; then by id so the
  /// order is identical every run.
  static int _compare(Hint a, Hint b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    final byKind = a.kind.index.compareTo(b.kind.index);
    if (byKind != 0) return byKind;
    return a.id.compareTo(b.id);
  }
}
