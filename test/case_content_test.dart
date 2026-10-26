import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_manor/domain/models/case_content.dart';

void main() {
  late CaseContent content;

  setUpAll(() {
    final text = File('assets/cases/the_last_toast.json').readAsStringSync();
    content = CaseContent.fromJson(jsonDecode(text) as Map<String, dynamic>);
  });

  group('The Last Toast content', () {
    test('passes its own validation', () {
      expect(content.validate(), isEmpty);
    });

    test('has three rooms in order', () {
      expect(content.scenes.map((s) => s.name), [
        'The Study',
        'The Dining Room',
        'The Conservatory',
      ]);
      expect(content.scenes.map((s) => s.orderIndex), [1, 2, 3]);
    });

    test('has about twelve pieces of evidence with key clues and red herrings',
        () {
      expect(content.evidence.length, inInclusiveRange(10, 14));
      final keys = content.evidence.where((e) => e.isKey).length;
      final herrings = content.evidence.length - keys;
      expect(keys, greaterThanOrEqualTo(3));
      expect(herrings, greaterThanOrEqualTo(3));
    });

    test('every room has at least three clues', () {
      for (final scene in content.scenes) {
        final count =
            content.evidence.where((e) => e.sceneId == scene.id).length;
        expect(count, greaterThanOrEqualTo(3), reason: scene.name);
      }
    });

    test('has five suspects with statements', () {
      expect(content.suspects.length, 5);
      for (final s in content.suspects) {
        expect(s.statement, isNotEmpty);
        expect(s.motiveHint, isNotEmpty);
      }
    });

    test('solution is Isabelle, poisoned brandy, embezzlement', () {
      expect(content.solution.culpritId, 'sus_isabelle');
      expect(content.solution.methodId, 'm_poisoned_brandy');
      expect(content.solution.motiveId, 'mo_embezzlement');
    });

    test('required links join only key evidence', () {
      final keyIds = content.keyEvidence.map((e) => e.id).toSet();
      for (final id in content.solution.requiredLinkIds) {
        final link = content.clueLinks.singleWhere((l) => l.id == id);
        expect(keyIds, contains(link.evidenceAId), reason: id);
        expect(keyIds, contains(link.evidenceBId), reason: id);
      }
    });

    test('accusation screen has several methods and motives', () {
      final methods = content.accusationOptions
          .where((o) => o.kind == AccusationOption.kindMethod);
      final motives = content.accusationOptions
          .where((o) => o.kind == AccusationOption.kindMotive);
      expect(methods.length, greaterThanOrEqualTo(4));
      expect(motives.length, greaterThanOrEqualTo(4));
    });

    test('clue link stages are 1 to 3', () {
      for (final l in content.clueLinks) {
        expect(l.stage, inInclusiveRange(1, 3), reason: l.id);
      }
    });

    test('models round-trip through toMap and fromMap', () {
      final e = content.evidence.first;
      expect(Evidence.fromMap(e.toMap()).toMap(), e.toMap());
      final s = content.suspects.first;
      expect(Suspect.fromMap(s.toMap()).toMap(), s.toMap());
      final sol = content.solution;
      expect(Solution.fromMap(sol.toMap()).requiredLinkIds, sol.requiredLinkIds);
    });
  });

  group('validation catches broken content', () {
    test('reports a link to unknown evidence', () {
      final broken = CaseContent(
        info: content.info,
        scenes: content.scenes,
        evidence: content.evidence,
        suspects: content.suspects,
        accusationOptions: content.accusationOptions,
        solution: content.solution,
        clueLinks: [
          ...content.clueLinks,
          ClueLink(
            id: 'link_bad',
            caseId: content.info.id,
            evidenceAId: 'ev_decanter',
            evidenceBId: 'ev_does_not_exist',
            description: 'broken',
            stage: 1,
          ),
        ],
      );
      expect(broken.validate(), contains(contains('ev_does_not_exist')));
    });

    test('reports a culprit who is not a suspect', () {
      final broken = CaseContent(
        info: content.info,
        scenes: content.scenes,
        evidence: content.evidence,
        suspects: content.suspects,
        accusationOptions: content.accusationOptions,
        solution: Solution(
          caseId: content.info.id,
          culpritId: 'sus_nobody',
          methodId: content.solution.methodId,
          motiveId: content.solution.motiveId,
          requiredLinkIds: content.solution.requiredLinkIds,
        ),
        clueLinks: content.clueLinks,
      );
      expect(broken.validate(), contains(contains('sus_nobody')));
    });
  });
}
