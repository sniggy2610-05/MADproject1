class LanternHint {
  final String id;
  final String text;
  final List<String> requires;
  final String? relatedGuess;

  const LanternHint({
    required this.id,
    required this.text,
    required this.requires,
    this.relatedGuess,
  });
}

class HintResult {
  final String text;
  final String reason;
  final String hintId;

  const HintResult({
    required this.text,
    required this.reason,
    required this.hintId,
  });
}

class LanternGuide {
  static const hints = [
    LanternHint(
      id: 'H1',
      text: 'Compare the ribbon with the guests’ belongings.',
      requires: ['C1'],
      relatedGuess: 'S2',
    ),
    LanternHint(
      id: 'H2',
      text: 'Look more closely at the event program.',
      requires: ['C2'],
    ),
    LanternHint(
      id: 'H3',
      text: 'Consider who had access to the entrance.',
      requires: ['C3'],
    ),
  ];

  static HintResult? suggest({
    required List<String> inspectedClues,
    required String? lastGuess,
    required List<String> previouslyShown,
    required int difficulty,
  }) {
    final eligible = hints.where((hint) {
      return hint.requires.every(inspectedClues.contains) &&
          !previouslyShown.contains(hint.id);
    }).toList();

    if (eligible.isEmpty) return null;

    eligible.sort((a, b) {
      final scoreA = a.relatedGuess == lastGuess && lastGuess != null ? 1 : 0;
      final scoreB = b.relatedGuess == lastGuess && lastGuess != null ? 1 : 0;

      if (scoreA != scoreB) return scoreB.compareTo(scoreA);
      return a.id.compareTo(b.id);
    });

    final selected = eligible.first;

    final reason = selected.requires
        .map((clue) => 'inspected $clue')
        .join(' and ');

    return HintResult(
      hintId: selected.id,
      text: selected.text,
      reason:
          'This suggestion is based on $reason'
          '${selected.relatedGuess == lastGuess && lastGuess != null ? ' and your previous guess' : ''}.',
    );
  }
}
