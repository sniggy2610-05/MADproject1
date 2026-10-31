class EvidenceNote {
  final int? id;
  final int caseId;
  final String clueKey;
  final String type;
  final String text;
  final String createdAt;

  const EvidenceNote({
    this.id,
    required this.caseId,
    required this.clueKey,
    required this.type,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'caseId': caseId,
    'clueKey': clueKey,
    'type': type,
    'text': text,
    'createdAt': createdAt,
  };

  factory EvidenceNote.fromMap(Map<String, dynamic> map) {
    return EvidenceNote(
      id: map['id'] as int?,
      caseId: map['caseId'] as int,
      clueKey: map['clueKey'],
      type: map['type'],
      text: map['text'],
      createdAt: map['createdAt'],
    );
  }
}
