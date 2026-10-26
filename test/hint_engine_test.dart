import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_manor/domain/hint_engine.dart';
import 'package:midnight_manor/domain/models/case_content.dart';

/// Preset player states from section 7 of the proposal, built on the real
/// Case 1 content so the tests also guard the story file.
void main() {
  late CaseContent content;
  const engine = HintEngine();

  setUpAll(() {
    final text = File('assets/cases/the_last_toast.json').readAsStringSync();
    content = CaseContent.fromJson(jsonDecode(text) as Map<String, dynamic>);
  });

  HintState state({
    Set<String> collected = const {},
    Set<String> pinned = const {},
    List<(String, String)> connected = const [],
    Set<String> noted = const {},
    List<String> recent = const [],
    Set<String> completed = const {},
    int wrongAccusations = 0,
    bool solved = false,
  }) =>
      HintState(
        caseId: content.info.id,
        scenes: content.scenes,
        evidence: content.evidence,
        clueLinks: content.clueLinks,
        solution: content.solution,
        collectedIds: collected,
        pinnedIds: pinned,
        connectedPairs: connected,
        notedEvidenceIds: noted,
        recentHintIds: recent,
        completedHintIds: completed,
        wrongAccusations: wrongAccusations,
        solved: solved,
      );

  Set<String> allEvidenceIds() => content.evidence.map((e) => e.id).toSet();

  // The three required links from the solution, as board connections.
  List<(String, String)> allRequiredConnections() => content.solution.requiredLinkIds
      .map((id) => content.clueLinks.singleWhere((l) => l.id == id))
      .map((l) => (l.evidenceAId, l.evidenceBId))
      .toList();

  group('preset states', () {
    test('no evidence: tells the player to search a room', () {
      final r = engine.next(state());
      expect(r.outcome, HintOutcome.hint);
      expect(r.stage, PlayerStage.investigate);
      expect(r.hint!.kind, HintKind.find);
      expect(r.message, contains('Search'));
      // Untouched room with a key clue, stage fit: 4 + 2 + 1.
      expect(r.hint!.score, 7);
    });

    test('one key clue found: still exploring, scores shift sensibly', () {
      final none = engine.next(state());
      final one = engine.next(state(collected: {'ev_decanter'}));
      expect(one.stage, PlayerStage.investigate);
      expect(one.hint!.kind, HintKind.find);
      // The Study has been visited, so its room hint loses the +2 for being
      // untouched, while untouched rooms keep the lead.
      int study(HintResult r) =>
          r.candidates.singleWhere((c) => c.id == 'find:sc_study').score;
      expect(study(one), study(none) - 2);
      expect(one.hint!.id, isNot('find:sc_study'));
      // A pin hint for the decanter now exists, and it is a key clue.
      final pin = one.candidates.singleWhere((c) => c.id == 'pin:ev_decanter');
      expect(pin.reasons.map((r) => r.points), contains(4));
      expect(none.candidates.map((c) => c.id), isNot(contains('pin:ev_decanter')));
    });

    test('clues placed but not linked: suggests the connection', () {
      final s = state(
        collected: allEvidenceIds(),
        pinned: allEvidenceIds(),
      );
      final r = engine.next(s);
      expect(r.stage, PlayerStage.connect);
      expect(r.hint!.kind, HintKind.link);
      expect(r.message, startsWith('Compare the'));
      // Key link, untouched, stage-2 link fits stage 2: 4 + 2 + 1.
      expect(r.hint!.score, 7);
      // No pin hints remain because everything is pinned.
      expect(r.candidates.where((c) => c.kind == HintKind.pin), isEmpty);
    });

    test('hint completed: that hint is never offered again', () {
      final s = state(collected: allEvidenceIds(), pinned: allEvidenceIds());
      final first = engine.next(s);
      final after = engine.next(state(
        collected: allEvidenceIds(),
        pinned: allEvidenceIds(),
        completed: {first.hint!.id},
      ));
      expect(after.hint!.id, isNot(first.hint!.id));
      expect(after.candidates.map((c) => c.id), isNot(contains(first.hint!.id)));
    });

    test('hint ignored: a recently shown hint loses 3 points and drops', () {
      final s = state(collected: allEvidenceIds(), pinned: allEvidenceIds());
      final first = engine.next(s);
      final again = engine.next(state(
        collected: allEvidenceIds(),
        pinned: allEvidenceIds(),
        recent: [first.hint!.id],
      ));
      expect(again.hint!.id, isNot(first.hint!.id));
      final demoted = again.candidates.singleWhere((c) => c.id == first.hint!.id);
      expect(demoted.score, first.hint!.score - 3);
      expect(demoted.reasons.map((r) => r.points), contains(-3));
    });

    test('all key links drawn: moves to the accuse stage', () {
      final r = engine.next(state(
        collected: allEvidenceIds(),
        pinned: allEvidenceIds(),
        connected: allRequiredConnections(),
      ));
      expect(r.stage, PlayerStage.accuse);
      expect(r.hint!.kind, HintKind.accuse);
      expect(r.message, contains('accusation'));
    });

    test('case solved: completion message and no hint', () {
      final r = engine.next(state(
        collected: allEvidenceIds(),
        pinned: allEvidenceIds(),
        connected: allRequiredConnections(),
        solved: true,
      ));
      expect(r.outcome, HintOutcome.caseSolved);
      expect(r.hint, isNull);
      expect(r.message, contains('Case closed'));
    });

    test('nothing left to suggest: friendly no-hint message', () {
      // Everything found, pinned and connected, and the accuse hint done.
      final every = content.clueLinks.map((l) => (l.evidenceAId, l.evidenceBId)).toList();
      final r = engine.next(state(
        collected: allEvidenceIds(),
        pinned: allEvidenceIds(),
        connected: every,
        completed: {'accuse'},
      ));
      expect(r.outcome, HintOutcome.noHintsLeft);
      expect(r.hint, isNull);
      expect(r.message, contains('No new hints'));
    });
  });

  group('rules', () {
    test('same input always gives the same output', () {
      final s = state(collected: {'ev_decanter', 'ev_foxglove', 'ev_clock'});
      final a = engine.next(s);
      final b = engine.next(s);
      expect(a.hint!.id, b.hint!.id);
      expect(a.candidates.map((c) => c.id), b.candidates.map((c) => c.id));
    });

    test('a red herring link scores lower than a key link', () {
      final s = state(
        collected: {'ev_medical_bag', 'ev_prescription_note', 'ev_decanter', 'ev_foxglove'},
        pinned: {'ev_medical_bag', 'ev_prescription_note', 'ev_decanter', 'ev_foxglove'},
      );
      final c = engine.candidates(s);
      final herring = c.singleWhere((h) => h.id == 'link:link_bag_note');
      final key = c.singleWhere((h) => h.id == 'link:link_decanter_foxglove');
      expect(key.score, greaterThan(herring.score));
      expect(herring.reasons.map((r) => r.points), isNot(contains(4)));
    });

    test('a clue with a note is less unresolved than one without', () {
      final s = state(
        collected: {'ev_decanter', 'ev_ledger_page'},
        noted: {'ev_decanter'},
      );
      final c = engine.candidates(s);
      final noted = c.singleWhere((h) => h.id == 'pin:ev_decanter');
      final fresh = c.singleWhere((h) => h.id == 'pin:ev_ledger_page');
      expect(fresh.score, noted.score + 2);
    });

    test('hints never name the culprit, method or motive', () {
      final states = [
        state(),
        state(collected: {'ev_gloves', 'ev_logbook'}),
        state(collected: allEvidenceIds()),
        state(collected: allEvidenceIds(), pinned: allEvidenceIds()),
        state(
          collected: allEvidenceIds(),
          pinned: allEvidenceIds(),
          connected: allRequiredConnections(),
        ),
      ];
      for (final s in states) {
        for (final h in engine.candidates(s)) {
          final text = h.text.toLowerCase();
          expect(text, isNot(contains('isabelle')), reason: h.id);
          expect(text, isNot(contains('crane')), reason: h.id);
          expect(text, isNot(contains('poison')), reason: h.id);
          expect(text, isNot(contains('embezzl')), reason: h.id);
        }
      }
    });
  });

  group('why this hint', () {
    test('explanation is built from the same data as the choice', () {
      final r = engine.next(state(collected: allEvidenceIds(), pinned: allEvidenceIds()));
      final why = r.whyLines;
      expect(why.first, contains('Found 12 of 12 clues'));
      expect(why[1], contains('connecting clues'));
      expect(why, contains(contains('+4  It involves a key clue.')));
      expect(why, contains(contains('+2  Neither clue is connected')));
      expect(why, contains(contains('+1  It fits where you are')));
      expect(why.last, contains('Total: 7 points'));
      final sum = r.hint!.reasons.fold<int>(0, (t, x) => t + x.points);
      expect(sum, r.hint!.score);
    });

    test('summary counts match the state', () {
      final r = engine.next(state(
        collected: {'ev_decanter', 'ev_foxglove', 'ev_champagne_tray'},
        pinned: {'ev_decanter'},
      ));
      expect(r.summary, 'Found 3 of 12 clues (2 of 7 key). Pinned 1. Key connections: 0 of 3.');
    });
  });
}
