import 'package:flutter/material.dart';

import '../../data/repositories/note_repository.dart';
import '../../domain/models/evidence_note.dart';

class NotebookScreen extends StatefulWidget {
  final int? caseId;

  const NotebookScreen({super.key, this.caseId});

  @override
  State<NotebookScreen> createState() => _NotebookScreenState();
}

class _NotebookScreenState extends State<NotebookScreen> {
  final repository = NoteRepository();

  List<EvidenceNote> notes = [];

  final textController = TextEditingController();
  final clueController = TextEditingController();

  String type = 'Observation';

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    textController.dispose();
    clueController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (widget.caseId == null) return;

    final result = await repository.getAll(widget.caseId!);

    if (mounted) {
      setState(() => notes = result);
    }
  }

  Future<void> addNote() async {
    if (widget.caseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Open a case before adding notes.')),
      );
      return;
    }

    if (textController.text.trim().isEmpty ||
        clueController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a clue ID and note.')),
      );
      return;
    }

    await repository.create(
      EvidenceNote(
        caseId: widget.caseId!,
        clueKey: clueController.text.trim(),
        type: type,
        text: textController.text.trim(),
        createdAt: DateTime.now().toIso8601String(),
      ),
    );

    textController.clear();
    clueController.clear();

    await load();
  }

  Future<void> editNote(EvidenceNote note) async {
    textController.text = note.text;
    clueController.text = note.clueKey;

    String editedType = note.type;

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit note'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: clueController,
              decoration: const InputDecoration(labelText: 'Clue ID'),
            ),
            TextField(
              controller: textController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Your note'),
            ),
            DropdownButton<String>(
              value: editedType,
              items: ['Observation', 'Inference']
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  editedType = value;
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              if (textController.text.trim().isEmpty ||
                  clueController.text.trim().isEmpty) {
                return;
              }

              await repository.update(
                EvidenceNote(
                  id: note.id,
                  caseId: note.caseId,
                  clueKey: clueController.text.trim(),
                  type: editedType,
                  text: textController.text.trim(),
                  createdAt: note.createdAt,
                ),
              );

              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }

              await load();
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  Future<void> deleteNote(EvidenceNote note) async {
    if (note.id == null) return;

    await repository.delete(note.id!);
    await load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DETECTIVE NOTEBOOK')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            'Separate what you observe from what you infer.',
            style: TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 20),

          TextField(
            controller: clueController,
            decoration: const InputDecoration(
              labelText: 'Clue ID (example: C1)',
            ),
          ),

          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            initialValue: type,
            decoration: const InputDecoration(labelText: 'Entry type'),
            items: ['Observation', 'Inference']
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                type = value ?? 'Observation';
              });
            },
          ),

          const SizedBox(height: 12),

          TextField(
            controller: textController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Write your notes',
              alignLabelWithHint: true,
            ),
          ),

          const SizedBox(height: 12),

          ElevatedButton(onPressed: addNote, child: const Text('SAVE NOTE')),

          const SizedBox(height: 25),

          const Text(
            'YOUR ENTRIES',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),

          if (widget.caseId == null)
            const Padding(
              padding: EdgeInsets.all(15),
              child: Text('Open a case to view its notes.'),
            ),

          ...notes.map(
            (note) => Card(
              child: ListTile(
                title: Text(note.type),
                subtitle: Text('${note.clueKey} • ${note.text}'),
                onTap: () => editNote(note),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => deleteNote(note),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
