import '../domain/hint_engine.dart';
import '../domain/models/player_data.dart';
import 'repositories/repositories.dart';

/// Feeds the [HintEngine] from the repositories and records what was shown.
///
/// The hint screen calls [request] when the player taps "Give me a hint" and
/// [markFollowed] when they act on it. [peek] computes without recording,
/// for previews and tests.
class HintService {
  HintService(this._repos, {this.engine = const HintEngine()});

  final Repositories _repos;
  final HintEngine engine;

  /// Gathers everything the engine needs from the database.
  Future<HintState> stateFor(String caseId) async {
    final solution = await _repos.cases.solution(caseId);
    if (solution == null) {
      throw RuleViolation('No solution is stored for case $caseId.');
    }
    final notes = await _repos.notes.list(caseId);
    final progress = await _repos.progress.get(caseId);
    return HintState(
      caseId: caseId,
      scenes: await _repos.cases.scenes(caseId),
      evidence: await _repos.cases.evidence(caseId),
      clueLinks: await _repos.cases.clueLinks(caseId),
      solution: solution,
      collectedIds: await _repos.evidence.collectedIds(caseId),
      pinnedIds: (await _repos.board.nodes(caseId)).map((n) => n.evidenceId).toSet(),
      connectedPairs: await _repos.board.connectedEvidencePairs(caseId),
      notedEvidenceIds: notes.map((n) => n.evidenceId).whereType<String>().toSet(),
      recentHintIds: await _repos.hints.recentHintIds(caseId, count: engine.recentWindow),
      completedHintIds: await _repos.hints.completedHintIds(caseId),
      wrongAccusations: await _repos.accusations.wrongAttempts(caseId),
      solved: progress.status == CaseStatus.solved,
    );
  }

  /// Computes the next hint without recording it.
  Future<HintResult> peek(String caseId) async =>
      engine.next(await stateFor(caseId));

  /// Computes the next hint and records it as shown (which also counts it
  /// against the score). Nothing is recorded when there is no hint.
  Future<HintResult> request(String caseId) async {
    final result = await peek(caseId);
    final hint = result.hint;
    if (hint != null) {
      await _repos.hints.recordShown(caseId, hint.id);
    }
    return result;
  }

  /// The player did what the hint said. It will not be offered again.
  Future<void> markFollowed(String caseId, String hintId) =>
      _repos.hints.markCompleted(caseId, hintId);
}
