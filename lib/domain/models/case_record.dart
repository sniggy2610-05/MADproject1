import 'dart:convert';

class CaseRecord {
  final int? id;
  final String title;
  final String synopsis;
  final String contentJson;
  final String solutionKey;
  final String status;
  final String? lastGuess;
  final String inspectedClueKeysJson;

  const CaseRecord({
    this.id,
    required this.title,
    required this.synopsis,
    required this.contentJson,
    required this.solutionKey,
    this.status = 'New',
    this.lastGuess,
    this.inspectedClueKeysJson = '[]',
  });

  List<String> get inspectedClueKeys =>
      List<String>.from(jsonDecode(inspectedClueKeysJson));

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'synopsis': synopsis,
    'contentJson': contentJson,
    'solutionKey': solutionKey,
    'status': status,
    'lastGuess': lastGuess,
    'inspectedClueKeysJson': inspectedClueKeysJson,
  };

  factory CaseRecord.fromMap(Map<String, dynamic> map) {
    return CaseRecord(
      id: map['id'] as int?,
      title: map['title'],
      synopsis: map['synopsis'],
      contentJson: map['contentJson'],
      solutionKey: map['solutionKey'],
      status: map['status'],
      lastGuess: map['lastGuess'],
      inspectedClueKeysJson: map['inspectedClueKeysJson'],
    );
  }

  CaseRecord copyWith({
    int? id,
    String? title,
    String? synopsis,
    String? contentJson,
    String? solutionKey,
    String? status,
    String? lastGuess,
    String? inspectedClueKeysJson,
  }) {
    return CaseRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      synopsis: synopsis ?? this.synopsis,
      contentJson: contentJson ?? this.contentJson,
      solutionKey: solutionKey ?? this.solutionKey,
      status: status ?? this.status,
      lastGuess: lastGuess ?? this.lastGuess,
      inspectedClueKeysJson:
          inspectedClueKeysJson ?? this.inspectedClueKeysJson,
    );
  }
}
