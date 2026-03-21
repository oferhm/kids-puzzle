import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../widgets/puzzle_board.dart';

class GameScreen extends StatefulWidget {
  final String imageAssetPath;
  final int rows;
  final int cols;

  const GameScreen({
    super.key,
    required this.imageAssetPath,
    this.rows = 3,
    this.cols = 4,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  ui.Image? _image;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      // Load from assets — swap with NetworkImage loader if using URLs
      final data = await rootBundle.load(widget.imageAssetPath);
      final bytes = data.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(
        bytes,
        // Downscale to 2560×1600 max for memory efficiency
        targetWidth: 2560,
        targetHeight: 1600,
      );
      final frame = await codec.getNextFrame();
      setState(() {
        _image = frame.image;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFD6E0),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _image == null) {
      return Scaffold(
        body: Center(child: Text('Error: $_error')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFD6E0), // Pink background like reference
      body: SafeArea(
        child: PuzzleBoard(
          image: _image!,
          rows: widget.rows,
          cols: widget.cols,
          onPuzzleSolved: () {
            // Play sound, show stars, navigate to next level, etc.
            debugPrint('🎉 Puzzle solved!');
          },
        ),
      ),
    );
  }
}
