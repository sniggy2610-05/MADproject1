import 'package:flutter/material.dart';

import '../../data/repositories/case_repository.dart';
import '../../domain/models/case_record.dart';
import '../theme/manor_theme.dart';
import 'investigation_screen.dart';
import 'case_editor_screen.dart';
import 'notebook_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final repository = CaseRepository();
  List<CaseRecord> cases = [];
  int tab = 0;
  int solved = 0;
  bool loading = true;
  String filter = 'All';

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final result = await repository.getAll();
    final count = await repository.solvedCount();

    if (!mounted) return;

    setState(() {
      cases = result;
      solved = count;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      buildCases(),
      const NotebookScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('MIDNIGHT MANOR'),
        actions: [
          IconButton(onPressed: refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: pages[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.folder_open), label: 'Cases'),
          NavigationDestination(icon: Icon(Icons.menu_book), label: 'Notebook'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
      floatingActionButton: tab == 0
          ? FloatingActionButton(
              backgroundColor: ManorColors.burgundy,
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CaseEditorScreen()),
                );
                refresh();
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget buildCases() {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final visible = filter == 'All'
        ? cases
        : cases.where((c) => c.status == filter).toList();

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Good evening, Detective.',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: ManorColors.ivory,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Every mystery leaves a trail.',
            style: TextStyle(color: ManorColors.muted),
          ),
          const SizedBox(height: 22),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'SOLVED CASES: $solved',
                style: const TextStyle(
                  color: ManorColors.gold,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'YOUR CASE FILES',
            style: TextStyle(
              color: ManorColors.gold,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: filter,
            decoration: const InputDecoration(labelText: 'Filter cases'),
            items: ['All', 'New', 'In Progress', 'Solved']
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
            onChanged: (value) {
              setState(() => filter = value ?? 'All');
            },
          ),
          const SizedBox(height: 15),
          if (visible.isEmpty)
            const Center(child: Text('No cases in this category.')),
          ...visible.map(
            (record) => Card(
              child: ListTile(
                leading: const Icon(
                  Icons.wb_twilight,
                  color: ManorColors.gold,
                  size: 32,
                ),
                title: Text(record.title),
                subtitle: Text(
                  '${record.status}\n${record.synopsis}',
                  maxLines: 3,
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.arrow_forward_ios, size: 15),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InvestigationScreen(record: record),
                    ),
                  );
                  refresh();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
