import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_manor/domain/accusation_checker.dart';
import 'package:midnight_manor/domain/models/case_content.dart';

void main() {
  const checker = AccusationChecker();

  const solution = Solution(
    caseId: 'c1',
    culpritId: 'sus_isabelle',
    methodId: 'm_poisoned_brandy',
    motiveId: 'mo_embezzlement',
    requiredLinkIds: ['l1', 'l2', 'l3'],
  );

  const links = [
    ClueLink(
      id: 'l1',
      caseId: 'c1',
      evidenceAId: 'ev_decanter',
      evidenceBId: 'ev_foxglove',
      description: '',
      stage: 2,
    ),
    ClueLink(
      id: 'l2',
      caseId: 'c1',
      evidenceAId: 'ev_ledger',
      evidenceBId: 'ev_letter',
      description: '',
      stage: 2,
    ),
    ClueLink(
      id: 'l3',
      caseId: 'c1',
      evidenceAId: 'ev_logbook',
      evidenceBId: 'ev_clock',
      description: '',
      stage: 3,
    ),
    ClueLink(
      id: 'l_herring',
      caseId: 'c1',
      evidenceAId: 'ev_iou',
      evidenceBId: 'ev_letter',
      description: '',
      stage: 1,
    ),
  ];

  const right = Accusation(
    suspectId: 'sus_isabelle',
    methodId: 'm_poisoned_brandy',
    motiveId: 'mo_embezzlement',
  );

  group('verdicts', () {
    test('all three right is solved with full score', () {
      final r = checker.check(
        accusation: right,
        solution: solution,
        clueLinks: links,
      );
      expect(r.verdict, AccusationVerdict.solved);
      expect(r.correctParts, 3);
      expect(r.score, 100);
      expect(r.message, contains('Case closed'));
    });

    test('wrong culprit is not quite, with a count but no detail', () {
      final r = checker.check(
        accusation: const Accusation(
          suspectId: 'sus_julian',
          methodId: 'm_poisoned_brandy',
          motiveId: 'mo_embezzlement',
        ),
        solution: solution,
        clueLinks: links,
      );
      expect(r.verdict, AccusationVerdict.notQuite);
      expect(r.correctParts, 2);
      expect(r.score, 0);
      expect(r.message, contains('Not quite'));
      expect(r.message, contains('2 of 3'));
      // The message must never name the real culprit, method or motive.
      expect(r.message.toLowerCase(), isNot(contains('isabelle')));
      expect(r.message.toLowerCase(), isNot(contains('brandy')));
    });

    test('everything wrong says none of the theory holds', () {
      final r = checker.check(
        accusation: const Accusation(
          suspectId: 'sus_thomas',
          methodId: 'm_poisoned_champagne',
          motiveId: 'mo_jealousy',
        ),
        solution: solution,
        clueLinks: links,
      );
      expect(r.verdict, AccusationVerdict.notQuite);
      expect(r.correctParts, 0);
      expect(r.message, contains('None'));
    });

    test('a blank part is incomplete and names what is missing', () {
      final r = checker.check(
        accusation: const Accusation(suspectId: 'sus_isabelle'),
        solution: solution,
        clueLinks: links,
      );
      expect(r.verdict, AccusationVerdict.incomplete);
      expect(r.missingParts, ['method', 'motive']);
      expect(r.message, contains('method, motive'));
      expect(r.score, 0);
    });

    test('an empty string counts as missing too', () {
      final r = checker.check(
        accusation: const Accusation(
          suspectId: 'sus_isabelle',
          methodId: '',
          motiveId: 'mo_embezzlement',
        ),
        solution: solution,
        clueLinks: links,
      );
      expect(r.verdict, AccusationVerdict.incomplete);
      expect(r.missingParts, ['method']);
      expect(r.message, contains('missing part:'));
    });
  });

  group('score', () {
    test('loses 10 per wrong attempt and 5 per hint', () {
      expect(AccusationChecker.scoreFor(), 100);
      expect(AccusationChecker.scoreFor(previousWrongAttempts: 2), 80);
      expect(AccusationChecker.scoreFor(hintsUsed: 3), 85);
      expect(
        AccusationChecker.scoreFor(previousWrongAttempts: 1, hintsUsed: 2),
        80,
      );
    });

    test('never drops below 10 when solved', () {
      expect(
        AccusationChecker.scoreFor(previousWrongAttempts: 20, hintsUsed: 20),
        10,
      );
    });

    test('is applied inside check', () {
      final r = checker.check(
        accusation: right,
        solution: solution,
        clueLinks: links,
        previousWrongAttempts: 1,
        hintsUsed: 1,
      );
      expect(r.score, 85);
    });
  });

  group('required links', () {
    test('counts drawn links in either direction and ignores extras', () {
      final r = checker.check(
        accusation: right,
        solution: solution,
        clueLinks: links,
        boardConnections: const [
          ('ev_foxglove', 'ev_decanter'), // l1, reversed
          ('ev_ledger', 'ev_letter'), // l2
          ('ev_iou', 'ev_letter'), // red herring link, not required
          ('ev_clock', 'ev_gloves'), // not an authored link at all
        ],
      );
      expect(r.linksMade, 2);
      expect(r.linksRequired, 3);
    });

    test('reports zero when the board is empty', () {
      final r = checker.check(
        accusation: right,
        solution: solution,
        clueLinks: links,
      );
      expect(r.linksMade, 0);
      expect(r.linksRequired, 3);
    });
  });
}
