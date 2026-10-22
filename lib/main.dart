import 'package:flutter/material.dart';

import 'screens/browser_screen.dart';
import 'services/store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await AppStore.load();
  runApp(DJapanLabApp(store: store));
}

class DJapanLabApp extends StatelessWidget {
  const DJapanLabApp({super.key, required this.store});

  final AppStore store;

  static const seed = Color(0xFFBC002D); // rosso Giappone

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'D. Japan Lab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: BrowserScreen(store: store),
    );
  }
}
