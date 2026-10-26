import 'package:flutter/material.dart';

void main() {
  runApp(const MidnightManorApp());
}

/// Warm candle-light palette from the proposal.
class ManorColors {
  static const burgundy = Color(0xFF6B1F2A);
  static const ivory = Color(0xFFFBF7EE);
  static const parchment = Color(0xFFEADFC8);
  static const ink = Color(0xFF2B2320);
}

class MidnightManorApp extends StatelessWidget {
  const MidnightManorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Midnight Manor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: ManorColors.burgundy,
          primary: ManorColors.burgundy,
          surface: ManorColors.ivory,
        ),
        scaffoldBackgroundColor: ManorColors.ivory,
        useMaterial3: true,
      ),
      home: const PlaceholderHome(),
    );
  }
}

/// Temporary home screen. Replaced by the real case library in Milestone 1.
class PlaceholderHome extends StatelessWidget {
  const PlaceholderHome({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 64, color: ManorColors.burgundy),
            SizedBox(height: 16),
            Text(
              'Midnight Manor',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: ManorColors.ink,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'A cozy offline detective mystery',
              style: TextStyle(color: ManorColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}
