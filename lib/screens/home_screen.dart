import 'package:flutter/material.dart';
import '../models/theme_data.dart';
import '../widgets/lightning_border.dart';
import 'gallery_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final unlocked = allThemes.where((t) => !t.locked).toList();
    final locked   = allThemes.where((t) =>  t.locked).toList();
    final sorted   = [...unlocked, ...locked];

    return Scaffold(
      backgroundColor: const Color(0xFFFFD6E0),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 28, 32, 8),
              child: Row(children: [
                const Text('🧩', style: TextStyle(fontSize: 34)),
                const SizedBox(width: 10),
                Text('Puzzle World', style: TextStyle(
                  fontSize: 30, fontWeight: FontWeight.w800,
                  color: const Color(0xFF9B4B6B),
                  shadows: [Shadow(color: Colors.white.withOpacity(0.6),
                      offset: const Offset(1, 2), blurRadius: 4)])),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Choose a theme to start puzzling!',
                  style: TextStyle(fontSize: 15,
                      color: const Color(0xFF9B4B6B).withOpacity(0.65))),
              ),
            ),
            Expanded(
              child: Center(
                child: PuzzleCardRow(
                  itemCount: sorted.length,
                  builder:   (i) => _ThemeCard(theme: sorted[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared horizontal row ─────────────────────────────────────────────────────

class PuzzleCardRow extends StatelessWidget {
  final int itemCount;
  final Widget Function(int) builder;

  // Show 5 cards — smaller with good spacing
  static const int    visibleCount = 5;
  static const double gap          = 28.0;
  static const double hPad         = 36.0;

  const PuzzleCardRow({super.key, required this.itemCount, required this.builder});

  @override
  Widget build(BuildContext context) {
    final sw    = MediaQuery.of(context).size.width;
    final cardW = (sw - hPad * 2 - gap * (visibleCount - 1)) / visibleCount;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(itemCount, (i) => Padding(
          padding: EdgeInsets.only(right: i < itemCount - 1 ? gap : 0),
          // Width fixed, height determined by image native ratio via _NativeCard
          child: SizedBox(width: cardW, child: builder(i)),
        )),
      ),
    );
  }
}

// ── Theme card with native image aspect ratio ─────────────────────────────────

class _ThemeCard extends StatefulWidget {
  final PuzzleTheme theme;
  const _ThemeCard({required this.theme});
  @override
  State<_ThemeCard> createState() => _ThemeCardState();
}

class _ThemeCardState extends State<_ThemeCard> {
  String? _coverPath;
  ImageInfo? _imageInfo;

  @override
  void initState() { super.initState(); _loadCover(); }

  Future<void> _loadCover() async {
    final paths = await widget.theme.loadPuzzlePaths();
    if (!mounted || paths.isEmpty) return;
    setState(() => _coverPath = paths.first);
    // Load image to get native dimensions
    final img = AssetImage(paths.first);
    final stream = img.resolve(ImageConfiguration.empty);
    stream.addListener(ImageStreamListener((info, _) {
      if (mounted) setState(() => _imageInfo = info);
    }));
  }

  @override
  Widget build(BuildContext context) {
    final theme     = widget.theme;
    final imgW      = _imageInfo?.image.width.toDouble()  ?? 1.0;
    final imgH      = _imageInfo?.image.height.toDouble() ?? 1.0;
    final sw        = MediaQuery.of(context).size.width;
    final cardW     = (sw - PuzzleCardRow.hPad * 2 -
        PuzzleCardRow.gap * (PuzzleCardRow.visibleCount - 1)) /
        PuzzleCardRow.visibleCount;
    final cardH     = _imageInfo != null ? cardW * (imgH / imgW) : cardW * 1.2;

    return GestureDetector(
      onTap: () {
        if (theme.locked) { _showLocked(context); return; }
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => GalleryScreen(theme: theme)));
      },
      child: LightningBorder(
        borderRadius: 16,
        color:    theme.locked ? const Color(0xFF999999) : const Color(0xFFFFE44D),
        color2:   theme.locked ? const Color(0xFF666666) : const Color(0xFFFF6600),
        strokeWidth: 4.0,
        duration: Duration(milliseconds: 2400 + theme.id.hashCode.abs() % 800),
        child: SizedBox(
          width:  cardW,
          height: cardH,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(fit: StackFit.expand, children: [

              _coverPath != null
                  ? Image.asset(_coverPath!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(theme.emoji))
                  : _placeholder(theme.emoji),

              Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.55)],
                  stops: const [0.50, 1.0])))),

              Positioned(left: 6, right: 6, bottom: 8,
                child: Text(theme.name, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 13,
                      fontWeight: FontWeight.w700,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black54)]))),

              if (theme.locked) Positioned.fill(child: Container(
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.50)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white54, width: 1.5)),
                    child: const Icon(Icons.lock_rounded, color: Colors.white, size: 24)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.amber.withOpacity(0.88),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Text('Soon', style: TextStyle(color: Colors.white,
                        fontSize: 11, fontWeight: FontWeight.w700))),
                ]))),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(String emoji) => Container(
    color: const Color(0xFFFFB6C1),
    child: Center(child: Text(emoji, style: const TextStyle(fontSize: 38))));

  void _showLocked(BuildContext context) {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: const Color(0xFFFFD6E0),
      title: const Row(children: [Text('🔒  '),
        Text('Locked', style: TextStyle(fontWeight: FontWeight.w800))]),
      content: Text('${widget.theme.name} is coming soon!\nStay tuned.',
          style: const TextStyle(fontSize: 15)),
      actions: [TextButton(onPressed: () => Navigator.pop(context),
        child: const Text('OK', style: TextStyle(
            fontWeight: FontWeight.w700, color: Color(0xFF9B4B6B))))],
    ));
  }
}