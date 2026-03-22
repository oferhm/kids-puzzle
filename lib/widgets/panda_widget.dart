import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

enum _PandaState { idle, walking, waving, scratch, dance }

/// Panda mascot — renders the FULL original image unclipped.
/// Movement is achieved by animating the whole image:
///   - body sway (rotation around bottom-centre)
///   - vertical bob
///   - horizontal drift
///   - squash & stretch scale
/// This keeps the image 100% intact with no cutting.
class PandaWidget extends StatefulWidget {
  final double size;
  const PandaWidget({super.key, required this.size});

  @override
  State<PandaWidget> createState() => PandaWidgetState();
}

class PandaWidgetState extends State<PandaWidget>
    with TickerProviderStateMixin {

  late AnimationController _clock;
  double get _t => _clock.value;

  _PandaState _state   = _PandaState.idle;
  bool        _dancing = false;
  double      _danceT  = 0;
  late AnimationController _danceCtrl;

  final _rng = Random();
  double _nextBehaviourAt = 0.5;

  // Animation values — applied to whole image
  double _rotation = 0;   // body tilt (radians)
  double _bobY     = 0;   // vertical offset (px)
  double _driftX   = 0;   // horizontal drift (px)
  double _scaleX   = 1;   // squash/stretch
  double _scaleY   = 1;

  ui.Image? _pandaImage;

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _clock.addListener(_tick);

    _danceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _danceCtrl.addListener(() => setState(() => _danceT = _danceCtrl.value));
    _danceCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        setState(() { _dancing = false; _danceT = 0; _state = _PandaState.idle; });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadImage();
  }

  Future<void> _loadImage() async {
    if (_pandaImage != null) return;
    try {
      final data  = await DefaultAssetBundle.of(context)
          .load('assets/images/dancing-panda.png');
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: (widget.size * 3).toInt(),
      );
      final frame = await codec.getNextFrame();
      if (mounted) setState(() => _pandaImage = frame.image);
    } catch (_) {}
  }

  @override
  void dispose() {
    _clock.removeListener(_tick);
    _clock.dispose();
    _danceCtrl.dispose();
    super.dispose();
  }

  void triggerDance() {
    setState(() { _dancing = true; _state = _PandaState.dance; });
    _danceCtrl.forward(from: 0);
  }

  void _pickNextBehaviour() {
    _nextBehaviourAt = (_t + 0.4 + _rng.nextDouble() * 1.2) % 1.0;
    if (_dancing) return;
    final options = [
      _PandaState.idle,
      _PandaState.idle,
      _PandaState.idle,
      _PandaState.waving,
      _PandaState.walking,
      _PandaState.scratch,
    ];
    setState(() => _state = options[_rng.nextInt(options.length)]);
  }

  void _tick() {
    if (!mounted) return;
    // Check behaviour switch
    final diff = (_t - _nextBehaviourAt).abs();
    if (!_dancing && diff < 0.015) _pickNextBehaviour();
    _computeAnim();
    setState(() {});
  }

  void _computeAnim() {
    final t = _t * 2 * pi;
    if (_dancing) { _computeDance(_danceT, t); return; }
    switch (_state) {
      case _PandaState.idle:    _computeIdle(t);    break;
      case _PandaState.walking: _computeWalk(t);    break;
      case _PandaState.waving:  _computeWave(t);    break;
      case _PandaState.scratch: _computeScratch(t); break;
      default:                  _computeIdle(t);
    }
  }

  // ── Idle: slow gentle sway, micro-breathe ────────────────────────────────
  void _computeIdle(double t) {
    _rotation = 0.04 * sin(t * 0.5);           // very slow side tilt
    _bobY     = -3   * sin(t * 1.0).abs();      // subtle breathing bob
    _driftX   =  2   * sin(t * 0.5);            // tiny sway left/right
    _scaleX   =  1.0 + 0.008 * sin(t);          // micro breathe
    _scaleY   =  1.0 - 0.008 * sin(t);
  }

  // ── Walk: bounce + lean side to side ────────────────────────────────────
  void _computeWalk(double t) {
    _rotation =  0.07 * sin(t * 2.0);           // lean with each step
    _bobY     = -8   * sin(t * 4.0).abs();      // bouncy step
    _driftX   =  3   * sin(t * 2.0);
    _scaleX   =  1.0;
    _scaleY   =  1.0;
  }

  // ── Wave: lean to one side, bounce rhythmically ──────────────────────────
  void _computeWave(double t) {
    _rotation =  0.12 * sin(t * 0.8);           // friendly lean
    _bobY     = -5   * sin(t * 1.6).abs();      // gentle bounce
    _driftX   =  4   * sin(t * 0.8);
    _scaleX   =  1.0;
    _scaleY   =  1.0;
  }

  // ── Scratch: fast twitchy micro-movements ───────────────────────────────
  void _computeScratch(double t) {
    _rotation =  0.08 * sin(t * 0.4) + 0.015 * sin(t * 7); // slow lean + twitch
    _bobY     = -2   * sin(t * 0.6).abs();
    _driftX   =  1.5 * sin(t * 7);              // fast horizontal twitch
    _scaleX   =  1.0;
    _scaleY   =  1.0;
  }

  // ── Dance: big choreographed moves ──────────────────────────────────────
  void _computeDance(double dt, double t) {
    final fast = t * 2.5;

    if (dt < 0.20) {
      // Jump up
      final p = dt / 0.20;
      _bobY     = -40 * sin(p * pi);
      _rotation =  0.15 * sin(fast);
      _driftX   =  5   * sin(fast * 0.5);
      _scaleX   =  1.0 - 0.12 * sin(p * pi);
      _scaleY   =  1.0 + 0.12 * sin(p * pi);
    } else if (dt < 0.45) {
      // Spin — rotate full circle via fast oscillation
      final p = (dt - 0.20) / 0.25;
      _rotation =  pi * 2 * p;               // full 360
      _bobY     = -12 * sin(fast * 2).abs();
      _driftX   =  0;
      _scaleX   =  1.0;
      _scaleY   =  1.0;
    } else if (dt < 0.72) {
      // Groove: fast side-to-side wiggle with squash
      _rotation =  0.22 * sin(fast * 2);
      _bobY     = -10  * sin(fast * 2).abs();
      _driftX   =  8   * sin(fast * 2);
      _scaleX   =  1.0 + 0.07 * sin(fast * 4);
      _scaleY   =  1.0 - 0.07 * sin(fast * 4);
    } else {
      // Wind down
      final p = (dt - 0.72) / 0.28;
      _rotation =  0.22 * (1 - p) * sin(fast * 2);
      _bobY     = -10  * (1 - p) * sin(fast * 2).abs();
      _driftX   =  8   * (1 - p) * sin(fast * 2);
      _scaleX   =  1.0;
      _scaleY   =  1.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width:  s,
      height: s,
      child: CustomPaint(
        painter: _PandaFullPainter(
          rotation:   _rotation,
          bobY:       _bobY,
          driftX:     _driftX,
          scaleX:     _scaleX,
          scaleY:     _scaleY,
          pandaImage: _pandaImage,
        ),
      ),
    );
  }
}

// ── Painter: draws FULL image, no cropping ────────────────────────────────────

class _PandaFullPainter extends CustomPainter {
  final double rotation, bobY, driftX, scaleX, scaleY;
  final ui.Image? pandaImage;

  const _PandaFullPainter({
    required this.rotation,
    required this.bobY,
    required this.driftX,
    required this.scaleX,
    required this.scaleY,
    required this.pandaImage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final img = pandaImage;
    if (img == null) {
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        size.width * 0.3,
        Paint()..color = Colors.black26,
      );
      return;
    }

    final cx = size.width  / 2 + driftX;
    final cy = size.height / 2 + bobY;

    // Pivot around bottom-centre for natural standing sway
    final pivotX = size.width  / 2;
    final pivotY = size.height * 0.92;

    canvas.save();
    // Translate to pivot, rotate, translate back
    canvas.translate(pivotX, pivotY);
    canvas.scale(scaleX, scaleY);
    canvas.rotate(rotation);
    canvas.translate(-pivotX, -pivotY);

    // Draw full image centred, filling the widget
    final dst = Rect.fromCenter(
      center: Offset(cx, cy),
      width:  size.width,
      height: size.height,
    );
    final src = Rect.fromLTWH(
      0, 0,
      img.width.toDouble(),
      img.height.toDouble(),
    );

    canvas.drawImageRect(img, src, dst,
        Paint()..filterQuality = FilterQuality.high);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_PandaFullPainter old) => true;
}