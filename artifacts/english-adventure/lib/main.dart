import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/providers.dart';
import 'app/theme.dart';
import 'presentation/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final overrides = await buildOverrides();
  runApp(ProviderScope(overrides: overrides, child: const EnglishAdventureApp()));
}

class EnglishAdventureApp extends ConsumerWidget {
  const EnglishAdventureApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(readingPrefsProvider);
    return MaterialApp(
      title: 'English Adventure',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(prefs),
      home: const HomeScreen(),
    );
  }
}
