import 'package:flutter/material.dart';
import 'screens/game_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kids Puzzle',
      debugShowCheckedModeBanner: false,
      home: const GameScreen(
        imageAssetPath: 'assets/images/Savanna_giraffe.png',
        rows: 3,
        cols: 4,
      ),
    );
  }
}