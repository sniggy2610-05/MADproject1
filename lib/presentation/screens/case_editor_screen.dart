import 'package:flutter/material.dart';

import '../../domain/models/case_record.dart';
import '../../data/repositories/case_repository.dart';

class CaseEditorScreen extends StatefulWidget {
  const CaseEditorScreen({super.key});

  @override
  State<CaseEditorScreen> createState() => _CaseEditorScreenState();
}

class _CaseEditorScreenState extends State<CaseEditorScreen> {
  final title = TextEditingController();
  final synopsis = TextEditingController();
  final solution = TextEditingController();

  @override
  void dispose() {
    title.dispose();
    synopsis.dispose();
    solution.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (title.text.trim().isEmpty ||
        synopsis.text.trim().isEmpty ||
        solution.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Complete every field.')));
      return;
    }

    await CaseRepository().create(
      CaseRecord(
        title: title.text.trim(),
        synopsis: synopsis.text.trim(),
        solutionKey: solution.text.trim(),
        contentJson: '{"suspects":[],"clues":[],"hints":[]}',
      ),
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create a Case')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: title,
            decoration: const InputDecoration(labelText: 'Case title'),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: synopsis,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Case synopsis'),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: solution,
            decoration: const InputDecoration(
              labelText: 'Solution key (suspect ID)',
            ),
          ),
          const SizedBox(height: 25),
          ElevatedButton(onPressed: save, child: const Text('SAVE CASE')),
        ],
      ),
    );
  }
}
