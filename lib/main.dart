import 'package:flutter/material.dart';

import 'data/database/app_database.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/theme/manor_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppDatabase.instance.database;

  runApp(const MidnightManorApp());
}

class MidnightManorApp extends StatelessWidget {
  const MidnightManorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Midnight Manor',
      debugShowCheckedModeBanner: false,
      theme: ManorTheme.dark,
      home: const HomeScreen(),
    );
  }
}
