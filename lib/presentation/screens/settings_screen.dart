import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool assistance = true;
  bool reducedMotion = false;
  double difficulty = 1;

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      assistance = prefs.getBool('assistance') ?? true;
      reducedMotion = prefs.getBool('reducedMotion') ?? false;
      difficulty = prefs.getDouble('difficulty') ?? 1;
    });
  }

  Future<void> save(String key, Object value) async {
    final prefs = await SharedPreferences.getInstance();

    if (value is bool) await prefs.setBool(key, value);
    if (value is double) await prefs.setDouble(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'INVESTIGATION PREFERENCES',
          style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        SwitchListTile(
          title: const Text('Hint assistance'),
          subtitle: const Text('Allow the Lantern Guide to help.'),
          value: assistance,
          onChanged: (value) {
            setState(() => assistance = value);
            save('assistance', value);
          },
        ),
        SwitchListTile(
          title: const Text('Reduced motion'),
          subtitle: const Text('Reduce animated transitions.'),
          value: reducedMotion,
          onChanged: (value) {
            setState(() => reducedMotion = value);
            save('reducedMotion', value);
          },
        ),
        const SizedBox(height: 20),
        const Text('HINT DIFFICULTY'),
        Slider(
          value: difficulty,
          min: 0,
          max: 2,
          divisions: 2,
          label: ['Gentle', 'Balanced', 'Challenging'][difficulty.round()],
          onChanged: (value) {
            setState(() => difficulty = value);
            save('difficulty', value);
          },
        ),
        Text(['Gentle', 'Balanced', 'Challenging'][difficulty.round()]),
      ],
    );
  }
}
