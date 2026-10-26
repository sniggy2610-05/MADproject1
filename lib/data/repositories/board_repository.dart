import 'package:sqflite/sqflite.dart';

import '../../domain/models/player_data.dart';
import 'evidence_repository.dart';

/// The Evidence Board: pinned clue cards and the strings between them.
///
/// Rules from the proposal's edge case table are enforced here (and backed
/// by constraints in the schema):
/// - only collected clues can be pinned
/// - a card cannot be linked to itself, and a pair is linked at most once
/// - removing a card removes its strings but keeps the evidence
class BoardRepository {
  BoardRepository(this._db, this._evidence);
  final DatabaseExecutor _db;
  final EvidenceRepository _evidence;

  Future<List<BoardNode>> nodes(String caseId) async {
    final rows = await _db.query(
      'board_nodes',
      where: 'case_id = ?',
      whereArgs: [caseId],
      orderBy: 'id',
    );
    return rows.map(BoardNode.fromMap).toList();
  }

  Future<List<BoardLink>> links(String caseId) async {
    final rows = await _db.query(
      'board_links',
      where: 'case_id = ?',
      whereArgs: [caseId],
      orderBy: 'id',
    );
    return rows.map(BoardLink.fromMap).toList();
  }

  Future<BoardNode?> nodeById(int id) async {
    final rows =
        await _db.query('board_nodes', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : BoardNode.fromMap(rows.first);
  }

  Future<BoardLink?> linkById(int id) async {
    final rows =
        await _db.query('board_links', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : BoardLink.fromMap(rows.first);
  }

  /// Pins a collected clue to the board. If it is already pinned, the
  /// existing card is returned unchanged.
  Future<BoardNode> pin(
    String caseId,
    String evidenceId, {
    double x = 0,
    double y = 0,
  }) async {
    if (!await _evidence.isCollected(caseId, evidenceId)) {
      throw const RuleViolation(
        'You can only pin clues you have already found.',
      );
    }
    final existing = await _db.query(
      'board_nodes',
      where: 'case_id = ? AND evidence_id = ?',
      whereArgs: [caseId, evidenceId],
    );
    if (existing.isNotEmpty) return BoardNode.fromMap(existing.first);

    final id = await _db.insert('board_nodes', {
      'case_id': caseId,
      'evidence_id': evidenceId,
      'x': x,
      'y': y,
    });
    return (await nodeById(id))!;
  }

  /// Saves a card's new position after a drag.
  Future<void> move(int nodeId, double x, double y) => _db.update(
        'board_nodes',
        {'x': x, 'y': y},
        where: 'id = ?',
        whereArgs: [nodeId],
      );

  /// Removes a card. Its strings go with it (ON DELETE CASCADE); the clue
  /// itself stays in the inventory.
  Future<void> unpin(int nodeId) =>
      _db.delete('board_nodes', where: 'id = ?', whereArgs: [nodeId]);

  /// Draws a string between two cards with an optional label.
  Future<BoardLink> connect(
    String caseId,
    int fromNode,
    int toNode, {
    String label = '',
  }) async {
    if (fromNode == toNode) {
      throw const RuleViolation('A clue cannot be connected to itself.');
    }
    final a = await nodeById(fromNode);
    final b = await nodeById(toNode);
    if (a == null || b == null || a.caseId != caseId || b.caseId != caseId) {
      throw const RuleViolation('Both cards must be on this board.');
    }
    if (await _linkExists(caseId, fromNode, toNode)) {
      throw const RuleViolation('Those two clues are already connected.');
    }
    final id = await _db.insert('board_links', {
      'case_id': caseId,
      'from_node': fromNode,
      'to_node': toNode,
      'label': label.trim(),
    });
    return (await linkById(id))!;
  }

  Future<bool> _linkExists(String caseId, int a, int b) async {
    final rows = await _db.query(
      'board_links',
      columns: ['id'],
      where: 'case_id = ? AND ((from_node = ? AND to_node = ?) '
          'OR (from_node = ? AND to_node = ?))',
      whereArgs: [caseId, a, b, b, a],
    );
    return rows.isNotEmpty;
  }

  Future<void> setLabel(int linkId, String label) => _db.update(
        'board_links',
        {'label': label.trim()},
        where: 'id = ?',
        whereArgs: [linkId],
      );

  Future<void> disconnect(int linkId) =>
      _db.delete('board_links', where: 'id = ?', whereArgs: [linkId]);

  /// Every connected pair as evidence ids, for the accusation checker and
  /// the hint engine.
  Future<List<(String, String)>> connectedEvidencePairs(String caseId) async {
    final rows = await _db.rawQuery('''
      SELECT a.evidence_id AS ev_a, b.evidence_id AS ev_b
      FROM board_links l
      JOIN board_nodes a ON a.id = l.from_node
      JOIN board_nodes b ON b.id = l.to_node
      WHERE l.case_id = ?
    ''', [caseId]);
    return rows
        .map((r) => (r['ev_a'] as String, r['ev_b'] as String))
        .toList();
  }
}
