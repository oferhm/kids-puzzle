import 'package:flutter/material.dart';
import '../models/theme_data.dart';
import '../widgets/lightning_border.dart';
import 'game_screen.dart';
import 'home_screen.dart' show PuzzleCardRow;

class GalleryScreen extends StatefulWidget {
  final PuzzleTheme theme;
  const GalleryScreen({super.key, required this.theme});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<String> _paths   = [];
  bool         _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final paths = await widget.theme.loadPuzzlePaths();
    if (mounted) setState(() { _paths = paths; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFD6E0),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 32, 8),
              child: Row(children: [
                const AppBackButton(),
                const SizedBox(width: 14),
                Text(widget.theme.emoji, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 8),
                Text(widget.theme.name, style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w800,
                    color: Color(0xFF9B4B6B))),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Choose a puzzle to solve',
                  style: TextStyle(fontSize: 15,
                      color: const Color(0xFF9B4B6B).withOpacity(0.65))),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _paths.isEmpty
                      ? Center(child: Text('No puzzles yet!',
                          style: TextStyle(fontSize: 16,
                              color: const Color(0xFF9B4B6B).withOpacity(0.6))))
                      : Center(
                          child: PuzzleCardRow(
                            itemCount: _paths.length,
                            builder: (i) => _NativePuzzleCard(
                              assetPath: _paths[i],
                              index:     i,
                              onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => GameScreen(
                                  imageAssetPath: _paths[i],
                                  rows: 3, cols: 4))),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Puzzle card with native aspect ratio ──────────────────────────────────────

class _NativePuzzleCard extends StatefulWidget {
  final String       assetPath;
  final VoidCallback onTap;
  final int          index;
  const _NativePuzzleCard({required this.assetPath, required this.onTap,
      required this.index});

  @override
  State<_NativePuzzleCard> createState() => _NativePuzzleCardState();
}

class _NativePuzzleCardState extends State<_NativePuzzleCard> {
  ImageInfo? _info;

  @override
  void initState() {
    super.initState();
    AssetImage(widget.assetPath)
        .resolve(ImageConfiguration.empty)
        .addListener(ImageStreamListener((info, _) {
      if (mounted) setState(() => _info = info);
    }));
  }

  @override
  Widget build(BuildContext context) {
    final sw    = MediaQuery.of(context).size.width;
    final cardW = (sw - PuzzleCardRow.hPad * 2 -
        PuzzleCardRow.gap * (PuzzleCardRow.visibleCount - 1)) /
        PuzzleCardRow.visibleCount;
    final imgW  = _info?.image.width.toDouble()  ?? 1.0;
    final imgH  = _info?.image.height.toDouble() ?? 1.0;
    final cardH = _info != null ? cardW * (imgH / imgW) : cardW * 1.2;

    return GestureDetector(
      onTap: widget.onTap,
      child: LightningBorder(
        borderRadius: 16,
        color:       const Color(0xFF44EEFF),
        color2:      const Color(0xFF9966FF),
        strokeWidth: 4.0,
        duration: Duration(milliseconds: 2200 + widget.index * 350),
        child: SizedBox(
          width:  cardW,
          height: cardH,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(fit: StackFit.expand, children: [

              Image.asset(widget.assetPath, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFFFFB6C1),
                  child: const Icon(Icons.image_not_supported,
                      color: Colors.white54, size: 32))),

              // Subtle bottom vignette
              Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.25)],
                  stops: const [0.65, 1.0])))),

              // Play badge
              Positioned(top: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.90),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Color(0xFF9B4B6B), size: 16))),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Back button ───────────────────────────────────────────────────────────────

class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.maybePop(context),
      child: Container(
        width: 58, height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF4CAF50),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.4),
              blurRadius: 10, offset: const Offset(0, 3))]),
        child: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white, size: 22),
      ),
    );
  }
}