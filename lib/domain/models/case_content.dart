/// Plain Dart models for the authored content of a case.
///
/// These mirror the content tables in SQLite and the structure of the JSON
/// files in `assets/cases/`. No Flutter imports, so they are easy to test.
library;

class CaseInfo {
  const CaseInfo({
    required this.id,
    required this.title,
    required this.synopsis,
    required this.intro,
    required this.epilogue,
    required this.difficulty,
    required this.contentVersion,
  });

  final String id;
  final String title;
  final String synopsis;
  final String intro;
  final String epilogue;
  final String difficulty;
  final int contentVersion;

  factory CaseInfo.fromJson(Map<String, dynamic> json) => CaseInfo(
        id: json['id'] as String,
        title: json['title'] as String,
        synopsis: json['synopsis'] as String,
        intro: json['intro'] as String,
        epilogue: json['epilogue'] as String,
        difficulty: json['difficulty'] as String,
        contentVersion: json['content_version'] as int,
      );

  factory CaseInfo.fromMap(Map<String, Object?> row) => CaseInfo(
        id: row['id'] as String,
        title: row['title'] as String,
        synopsis: row['synopsis'] as String,
        intro: row['intro'] as String,
        epilogue: row['epilogue'] as String,
        difficulty: row['difficulty'] as String,
        contentVersion: row['content_version'] as int,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'synopsis': synopsis,
        'intro': intro,
        'epilogue': epilogue,
        'difficulty': difficulty,
        'content_version': contentVersion,
      };
}

class Scene {
  const Scene({
    required this.id,
    required this.caseId,
    required this.name,
    required this.description,
    required this.orderIndex,
  });

  final String id;
  final String caseId;
  final String name;
  final String description;
  final int orderIndex;

  factory Scene.fromJson(Map<String, dynamic> json, String caseId) => Scene(
        id: json['id'] as String,
        caseId: caseId,
        name: json['name'] as String,
        description: json['description'] as String,
        orderIndex: json['order_index'] as int,
      );

  factory Scene.fromMap(Map<String, Object?> row) => Scene(
        id: row['id'] as String,
        caseId: row['case_id'] as String,
        name: row['name'] as String,
        description: row['description'] as String,
        orderIndex: row['order_index'] as int,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'case_id': caseId,
        'name': name,
        'description': description,
        'order_index': orderIndex,
      };
}

class Evidence {
  const Evidence({
    required this.id,
    required this.caseId,
    required this.sceneId,
    required this.title,
    required this.description,
    required this.kind,
    required this.isKey,
  });

  final String id;
  final String caseId;
  final String sceneId;
  final String title;
  final String description;

  /// One of `object`, `document`, `trace`.
  final String kind;

  /// Key clues are needed to solve the case; the rest are red herrings.
  final bool isKey;

  factory Evidence.fromJson(Map<String, dynamic> json, String caseId) =>
      Evidence(
        id: json['id'] as String,
        caseId: caseId,
        sceneId: json['scene_id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        kind: json['kind'] as String,
        isKey: json['is_key'] as bool,
      );

  factory Evidence.fromMap(Map<String, Object?> row) => Evidence(
        id: row['id'] as String,
        caseId: row['case_id'] as String,
        sceneId: row['scene_id'] as String,
        title: row['title'] as String,
        description: row['description'] as String,
        kind: row['kind'] as String,
        isKey: (row['is_key'] as int) == 1,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'case_id': caseId,
        'scene_id': sceneId,
        'title': title,
        'description': description,
        'kind': kind,
        'is_key': isKey ? 1 : 0,
      };
}

class Suspect {
  const Suspect({
    required this.id,
    required this.caseId,
    required this.name,
    required this.role,
    required this.bio,
    required this.statement,
    required this.motiveHint,
  });

  final String id;
  final String caseId;
  final String name;
  final String role;
  final String bio;
  final String statement;
  final String motiveHint;

  factory Suspect.fromJson(Map<String, dynamic> json, String caseId) => Suspect(
        id: json['id'] as String,
        caseId: caseId,
        name: json['name'] as String,
        role: json['role'] as String,
        bio: json['bio'] as String,
        statement: json['statement'] as String,
        motiveHint: json['motive_hint'] as String,
      );

  factory Suspect.fromMap(Map<String, Object?> row) => Suspect(
        id: row['id'] as String,
        caseId: row['case_id'] as String,
        name: row['name'] as String,
        role: row['role'] as String,
        bio: row['bio'] as String,
        statement: row['statement'] as String,
        motiveHint: row['motive_hint'] as String,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'case_id': caseId,
        'name': name,
        'role': role,
        'bio': bio,
        'statement': statement,
        'motive_hint': motiveHint,
      };
}

/// A method or motive the player can pick on the accusation screen.
class AccusationOption {
  const AccusationOption({
    required this.id,
    required this.caseId,
    required this.kind,
    required this.label,
    required this.orderIndex,
  });

  static const kindMethod = 'method';
  static const kindMotive = 'motive';

  final String id;
  final String caseId;

  /// [kindMethod] or [kindMotive].
  final String kind;
  final String label;
  final int orderIndex;

  factory AccusationOption.fromMap(Map<String, Object?> row) =>
      AccusationOption(
        id: row['id'] as String,
        caseId: row['case_id'] as String,
        kind: row['kind'] as String,
        label: row['label'] as String,
        orderIndex: row['order_index'] as int,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'case_id': caseId,
        'kind': kind,
        'label': label,
        'order_index': orderIndex,
      };
}

class Solution {
  const Solution({
    required this.caseId,
    required this.culpritId,
    required this.methodId,
    required this.motiveId,
    required this.requiredLinkIds,
  });

  final String caseId;
  final String culpritId;
  final String methodId;
  final String motiveId;

  /// Clue links the player must have made before an accusation counts as
  /// fully solved. Stored as a comma-separated list in SQLite.
  final List<String> requiredLinkIds;

  factory Solution.fromJson(Map<String, dynamic> json, String caseId) =>
      Solution(
        caseId: caseId,
        culpritId: json['culprit_id'] as String,
        methodId: json['method_id'] as String,
        motiveId: json['motive_id'] as String,
        requiredLinkIds: (json['required_links'] as List<dynamic>)
            .map((e) => e as String)
            .toList(),
      );

  factory Solution.fromMap(Map<String, Object?> row) => Solution(
        caseId: row['case_id'] as String,
        culpritId: row['culprit_id'] as String,
        methodId: row['method'] as String,
        motiveId: row['motive'] as String,
        requiredLinkIds: (row['required_links'] as String)
            .split(',')
            .where((s) => s.isNotEmpty)
            .toList(),
      );

  Map<String, Object?> toMap() => {
        'id': 'sol_$caseId',
        'case_id': caseId,
        'culprit_id': culpritId,
        'method': methodId,
        'motive': motiveId,
        'required_links': requiredLinkIds.join(','),
      };
}

/// An authored connection between two pieces of evidence. The hint engine
/// uses these to suggest what the player should compare next.
class ClueLink {
  const ClueLink({
    required this.id,
    required this.caseId,
    required this.evidenceAId,
    required this.evidenceBId,
    required this.description,
    required this.stage,
  });

  final String id;
  final String caseId;
  final String evidenceAId;
  final String evidenceBId;
  final String description;

  /// 1 = early (rules things out), 2 = middle (builds the case),
  /// 3 = late (pins down the culprit).
  final int stage;

  factory ClueLink.fromJson(Map<String, dynamic> json, String caseId) =>
      ClueLink(
        id: json['id'] as String,
        caseId: caseId,
        evidenceAId: json['evidence_a_id'] as String,
        evidenceBId: json['evidence_b_id'] as String,
        description: json['description'] as String,
        stage: json['stage'] as int,
      );

  factory ClueLink.fromMap(Map<String, Object?> row) => ClueLink(
        id: row['id'] as String,
        caseId: row['case_id'] as String,
        evidenceAId: row['evidence_a_id'] as String,
        evidenceBId: row['evidence_b_id'] as String,
        description: row['description'] as String,
        stage: row['stage'] as int,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'case_id': caseId,
        'evidence_a_id': evidenceAId,
        'evidence_b_id': evidenceBId,
        'description': description,
        'stage': stage,
      };

  /// True if this link joins the two given evidence ids, in either order.
  bool joins(String a, String b) =>
      (evidenceAId == a && evidenceBId == b) ||
      (evidenceAId == b && evidenceBId == a);
}

/// Everything in one case file, parsed from JSON.
class CaseContent {
  const CaseContent({
    required this.info,
    required this.scenes,
    required this.evidence,
    required this.suspects,
    required this.accusationOptions,
    required this.solution,
    required this.clueLinks,
  });

  final CaseInfo info;
  final List<Scene> scenes;
  final List<Evidence> evidence;
  final List<Suspect> suspects;
  final List<AccusationOption> accusationOptions;
  final Solution solution;
  final List<ClueLink> clueLinks;

  factory CaseContent.fromJson(Map<String, dynamic> json) {
    final info = CaseInfo.fromJson(json['case'] as Map<String, dynamic>);
    final caseId = info.id;

    List<T> parseList<T>(
      String key,
      T Function(Map<String, dynamic>) parse,
    ) =>
        (json[key] as List<dynamic>)
            .map((e) => parse(e as Map<String, dynamic>))
            .toList();

    final options = <AccusationOption>[];
    final optionsJson = json['accusation_options'] as Map<String, dynamic>;
    void addOptions(String key, String kind) {
      final list = optionsJson[key] as List<dynamic>;
      for (var i = 0; i < list.length; i++) {
        final item = list[i] as Map<String, dynamic>;
        options.add(AccusationOption(
          id: item['id'] as String,
          caseId: caseId,
          kind: kind,
          label: item['label'] as String,
          orderIndex: i,
        ));
      }
    }

    addOptions('methods', AccusationOption.kindMethod);
    addOptions('motives', AccusationOption.kindMotive);

    return CaseContent(
      info: info,
      scenes: parseList('scenes', (e) => Scene.fromJson(e, caseId)),
      evidence: parseList('evidence', (e) => Evidence.fromJson(e, caseId)),
      suspects: parseList('suspects', (e) => Suspect.fromJson(e, caseId)),
      accusationOptions: options,
      solution:
          Solution.fromJson(json['solution'] as Map<String, dynamic>, caseId),
      clueLinks: parseList('clue_links', (e) => ClueLink.fromJson(e, caseId)),
    );
  }

  Iterable<Evidence> get keyEvidence => evidence.where((e) => e.isKey);

  /// Checks that every id referenced inside the case points at something
  /// that exists. Returns a list of problems; empty means the case is valid.
  List<String> validate() {
    final problems = <String>[];
    final sceneIds = scenes.map((s) => s.id).toSet();
    final evidenceIds = evidence.map((e) => e.id).toSet();
    final suspectIds = suspects.map((s) => s.id).toSet();
    final linkIds = clueLinks.map((l) => l.id).toSet();
    final methodIds = accusationOptions
        .where((o) => o.kind == AccusationOption.kindMethod)
        .map((o) => o.id)
        .toSet();
    final motiveIds = accusationOptions
        .where((o) => o.kind == AccusationOption.kindMotive)
        .map((o) => o.id)
        .toSet();

    if (evidenceIds.length != evidence.length) {
      problems.add('duplicate evidence ids');
    }
    if (suspectIds.length != suspects.length) {
      problems.add('duplicate suspect ids');
    }
    if (linkIds.length != clueLinks.length) {
      problems.add('duplicate clue link ids');
    }
    for (final e in evidence) {
      if (!sceneIds.contains(e.sceneId)) {
        problems.add('evidence ${e.id} points at unknown scene ${e.sceneId}');
      }
    }
    for (final l in clueLinks) {
      if (!evidenceIds.contains(l.evidenceAId)) {
        problems.add('link ${l.id} points at unknown evidence ${l.evidenceAId}');
      }
      if (!evidenceIds.contains(l.evidenceBId)) {
        problems.add('link ${l.id} points at unknown evidence ${l.evidenceBId}');
      }
      if (l.evidenceAId == l.evidenceBId) {
        problems.add('link ${l.id} joins evidence to itself');
      }
    }
    if (!suspectIds.contains(solution.culpritId)) {
      problems.add('solution culprit ${solution.culpritId} is not a suspect');
    }
    if (!methodIds.contains(solution.methodId)) {
      problems.add('solution method ${solution.methodId} is not an option');
    }
    if (!motiveIds.contains(solution.motiveId)) {
      problems.add('solution motive ${solution.motiveId} is not an option');
    }
    for (final id in solution.requiredLinkIds) {
      if (!linkIds.contains(id)) {
        problems.add('solution requires unknown link $id');
      }
    }
    if (solution.requiredLinkIds.length < 3) {
      problems.add('solution must require at least three links');
    }
    return problems;
  }
}
