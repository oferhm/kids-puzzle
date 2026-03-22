import 'package:flutter/services.dart';

class PuzzleTheme {
  final String id;
  final String name;
  final String emoji;
  final bool   locked;

  const PuzzleTheme({
    required this.id,
    required this.name,
    required this.emoji,
    required this.locked,
  });

  String get folderPath => 'assets/images/themes/$id';

  /// Loads puzzle image paths using Flutter's AssetManifest —
  /// works correctly on all platforms including Flutter Web.
  /// No index.txt needed. Just drop images in the folder + register in pubspec.
  Future<List<String>> loadPuzzlePaths() async {
    try {
      // Use AssetManifest to find all assets in this theme's folder
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final allKeys  = manifest.listAssets();
      final images   = allKeys
          .where((key) =>
              key.startsWith('$folderPath/') &&
              !key.endsWith('index.txt') &&
              (key.endsWith('.png') ||
               key.endsWith('.jpg') ||
               key.endsWith('.jpeg') ||
               key.endsWith('.webp')))
          .toList()
        ..sort(); // consistent order
      return images;
    } catch (_) {
      return [];
    }
  }
}

final List<PuzzleTheme> allThemes = [
  PuzzleTheme(id: 'sea_fishes',  name: 'Sea & Fish',   emoji: '🐠', locked: false),
  PuzzleTheme(id: 'princesses',  name: 'Princesses',   emoji: '👸', locked: false),
  PuzzleTheme(id: 'animals',     name: 'Animals',      emoji: '🦁', locked: true),
  PuzzleTheme(id: 'butterflies', name: 'Butterflies',  emoji: '🦋', locked: true),
];