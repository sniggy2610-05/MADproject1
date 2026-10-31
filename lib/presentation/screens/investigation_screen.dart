import 'dart:convert';

import 'package:flutter/material.dart';

import '../../domain/models/case_record.dart';
import '../../domain/services/lantern_guide.dart';
import '../../data/repositories/case_repository.dart';
import '../theme/manor_theme.dart';
import 'notebook_screen.dart';

class InvestigationScreen extends StatefulWidget {
  final CaseRecord record;

  const InvestigationScreen({super.key, required this.record});

  @override
  State<InvestigationScreen> createState() => _InvestigationScreenState();
}

class _InvestigationScreenState extends State<InvestigationScreen> {
  final repository = CaseRepository();
  late CaseRecord record;
  List<String> shownHints = [];
  HintResult? hint;

  @override
  void initState() {
    super.initState();
    record = widget.record;
  }

  Future<void> refreshRecord() async {
    final records = await repository.getAll();
    final updated = records.where((c) => c.id == record.id).firstOrNull;
    if (updated != null && mounted) {
      setState(() => record = updated);
    }
  }

  Future<void> inspect(String clueId) async {
    await repository.inspectClue(record.id!, clueId);
    await refreshRecord();
  }

  void getHint() {
    setState(() {
      hint = LanternGuide.suggest(
        inspectedClues: record.inspectedClueKeys,
        lastGuess: record.lastGuess,
        previouslyShown: shownHints,
        difficulty: 1,
      );
      if (hint != null) shownHints.add(hint!.hintId);
    });

    if (hint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inspect another clue first.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = jsonDecode(record.contentJson) as Map<String, dynamic>;
    final clues = content['clues'] as List? ?? [];
    final suspects = content['suspects'] as List? ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('INVESTIGATION')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            record.title,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: ManorColors.ivory,
            ),
          ),
          const SizedBox(height: 10),
          Text(record.synopsis),
          const SizedBox(height: 25),
          const Text('INSPECT THE CLUES'),
          ...clues.map((clue) {
            final id = clue['id'] as String;
            final inspected = record.inspectedClueKeys.contains(id);
            return Card(
              child: ListTile(
                title: Text(clue['name']),
                subtitle: Text(clue['description']),
                trailing: Icon(
                  inspected ? Icons.check_circle : Icons.search,
                  color: ManorColors.gold,
                ),
                onTap: () => inspect(id),
              ),
            );
          }),
          const SizedBox(height: 25),
          const Text('SUSPECTS'),
          ...suspects.map(
            (suspect) => Card(
              child: ListTile(
                title: Text(suspect['name']),
                subtitle: Text(suspect['role']),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () => submitGuess(suspect['id']),
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: getHint,
            icon: const Icon(Icons.lightbulb_outline),
            label: const Text('ASK THE LANTERN GUIDE'),
          ),
          if (hint != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('YOUR HINT'),
                    const SizedBox(height: 10),
                    Text(hint!.text),
                    const SizedBox(height: 10),
                    Text('Why this hint? ${hint!.reason}'),
                    TextButton(
                      onPressed: () => setState(() => hint = null),
                      child: const Text('Not now'),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NotebookScreen(caseId: record.id),
                ),
              );
            },
            child: const Text('OPEN NOTEBOOK'),
          ),
          OutlinedButton(
            onPressed: () async {
              await repository.reset(record.id!);
              await refreshRecord();
              if (mounted) {
                setState(() {
                  hint = null;
                  shownHints.clear();
                });
              }
            },
            child: const Text('RESET INVESTIGATION'),
          ),
        ],
      ),
    );
  }

  Future<void> submitGuess(String suspectId) async {
    final correct = await repository.submitGuess(record.id!, suspectId);
    await refreshRecord();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(correct ? 'Case Solved!' : 'Not Quite'),
        content: Text(
          correct
              ? 'Your explanation matches the authored solution.'
              : 'Keep investigating. Your evidence may tell you more.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CONTINUE'),
          ),
        ],
      ),
    );
  }
}
