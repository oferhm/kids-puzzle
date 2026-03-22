import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/panda_widget.dart';
import '../widgets/puzzle_board.dart';

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

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  ui.Image? _image;
  bool      _loading  = true;
  String?   _error;
  double    _progress = 0.0;

  @override
  void initState() {
    super.initState();
    // Start with 0% visible, then load
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadImage());
  }

  Future<void> _setProgress(double value, {int delayMs = 120}) async {
    if (!mounted) return;
    setState(() => _progress = value);
    await Future.delayed(Duration(milliseconds: delayMs));
  }

  Future<void> _loadImage() async {
    try {
      await _setProgress(0.05, delayMs: 80);
      await _setProgress(0.15, delayMs: 200); // visible pause at start

      final data = await rootBundle.load(widget.imageAssetPath);
      await _setProgress(0.40, delayMs: 150);

      final bytes = data.buffer.asUint8List();
      await _setProgress(0.55, delayMs: 100);

      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth:  2560,
        targetHeight: 1600,
      );
      await _setProgress(0.75, delayMs: 150);

      final frame = await codec.getNextFrame();
      await _setProgress(0.90, delayMs: 120);
      await _setProgress(1.00, delayMs: 400); // hold at 100% so user sees it

      if (mounted) setState(() { _image = frame.image; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _buildLoadingScreen();

    if (_error != null || _image == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFFD6E0),
        body: Center(child: Text('Error: $_error',
            style: const TextStyle(color: Colors.red))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFD6E0),
      body: SafeArea(
        child: PuzzleBoard(
          image: _image!,
          rows:  widget.rows,
          cols:  widget.cols,
          onPuzzleSolved: () => debugPrint('🎉 Puzzle solved!'),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFFFD6E0),
      body: Center(
        child: LayoutBuilder(builder: (context, constraints) {
          final barW    = constraints.maxWidth * 0.50;
          const pandaSz = 70.0;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Small panda doing idle animation
                  SizedBox(
                    width:  pandaSz,
                    height: pandaSz,
                    child: const PandaWidget(size: pandaSz),
                  ),
                  const SizedBox(width: 20),
                  SizedBox(
                    width: barW,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Loading...',
                          style: TextStyle(
                            fontSize:      18,
                            fontWeight:    FontWeight.w700,
                            color:         Color(0xFF9B6B7A),
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Animated progress bar
                        TweenAnimationBuilder<double>(
                          tween:    Tween(begin: 0.0, end: _progress),
                          duration: const Duration(milliseconds: 250),
                          builder: (context, value, _) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: SizedBox(
                                    height: 22,
                                    child: LinearProgressIndicator(
                                      value:           value,
                                      backgroundColor: Colors.white54,
                                      valueColor:      const AlwaysStoppedAnimation(
                                        Color(0xFFFF6B9D),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${(value * 100).toInt()}%',
                                  style: const TextStyle(
                                    fontSize:   13,
                                    color:      Color(0xFF9B6B7A),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        }),
      ),
    );
  }
}