import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/puzzle_piece.dart';
import '../painters/confetti_painter.dart';
import '../painters/particle_burst_painter.dart';
import '../painters/puzzle_piece_painter.dart';
import '../painters/puzzle_template_painter.dart';
import '../utils/image_slicer.dart';
import 'panda_widget.dart';

class PuzzleBoard extends StatefulWidget {
  final ui.Image image;
  final int rows;
  final int cols;
  final VoidCallback? onPuzzleSolved;

  const PuzzleBoard({
    super.key,
    required this.image,
    this.rows = 3,
    this.cols = 4,
    this.onPuzzleSolved,
  });

  @override
  State<PuzzleBoard> createState() => _PuzzleBoardState();
}

class _PuzzleBoardState extends State<PuzzleBoard>
    with TickerProviderStateMixin {

  List<PuzzlePiece> _pieces = [];
  late AnimationController _solvedController;
  bool _solved = false;

  final Map<int, AnimationController> _scaleControllers = {};
  final Map<int, Animation<double>>   _scaleAnimations  = {};

  // Active particle bursts: pieceId → {controller, center}
  final Map<int, AnimationController> _burstControllers = {};
  final Map<int, Offset>              _burstCenters     = {};

  // Confetti rain on solve
  late AnimationController        _confettiCtrl;
  late List<ConfettiParticle>     _confettiParticles;
  double _lastConfettiTime = 0;
  bool   _confettiActive   = false;

  // Panda mascot key — used to trigger dance
  final _pandaKey = GlobalKey<PandaWidgetState>();

  // Single dragged piece — tracked by raw pointer events on the Stack
  PuzzlePiece? _draggedPiece;
  Offset        _lastPointerPos = Offset.zero;

  late Rect   _templateRect;
  late double _baseW;
  late double _baseH;
  late double _tabPadding;
  late double _leftBoundary;

  static const double _leftFraction  = 0.65;
  static const double _templateScale = 0.70;
  static const double _tabDepth      = 0.22;
  static const double _trayScale     = 0.60;

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _solvedController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700),
    );
    _confettiParticles = ConfettiPainter.createParticles(count: 300);
    _confettiCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 12),
    );
    _confettiCtrl.addListener(() {
      final t = _confettiCtrl.lastElapsedDuration?.inMilliseconds ?? 0;
      final dt = (t - _lastConfettiTime) / 1000.0;
      _lastConfettiTime = t.toDouble();
      ConfettiPainter.update(_confettiParticles, dt);
      setState(() {});
    });
    _confettiCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        setState(() => _confettiActive = false);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initLayout();
  }

  void _initLayout() {
    final screen = MediaQuery.of(context).size;
    final leftW  = screen.width  * _leftFraction;
    final leftH  = screen.height;

    _leftBoundary = leftW;

    final tmplW = leftW * _templateScale;
    final tmplH = leftH * _templateScale;

    // Push template to the right — panda gets the left margin space.
    // pandaSpace = 15% of leftW reserved for the panda on the left.
    final pandaSpace = leftW * 0.15;
    final availW     = leftW - pandaSpace;
    final tmplLeft   = pandaSpace + (availW - tmplW) / 2;
    final tmplTop    = (leftH - tmplH) / 2;

    _templateRect = Rect.fromLTWH(tmplLeft, tmplTop, tmplW, tmplH);
    _baseW      = tmplW / widget.cols;
    _baseH      = tmplH / widget.rows;
    _tabPadding = (_baseW * _tabDepth).clamp(_baseH * _tabDepth, double.infinity) + 10.0;

    final trayRect = Rect.fromLTWH(
      leftW, 0, screen.width * (1 - _leftFraction), leftH,
    );

    for (final c in _scaleControllers.values) { c.dispose(); }
    _scaleControllers.clear();
    _scaleAnimations.clear();

    final pieces = ImageSlicer.slice(
      image: widget.image, rows: widget.rows, cols: widget.cols,
      boardRect: _templateRect, trayRect: trayRect, trayScale: _trayScale,
    );

    for (final piece in pieces) {
      final ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200), value: 0.0,
      );
      _scaleControllers[piece.id] = ctrl;
      _scaleAnimations[piece.id]  = Tween<double>(begin: _trayScale, end: 1.0)
          .animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOut));
    }

    setState(() { _pieces = pieces; _solved = false; });
  }

  @override
  void dispose() {
    _solvedController.dispose();
    _confettiCtrl.dispose();
    for (final c in _scaleControllers.values) { c.dispose(); }
    for (final c in _burstControllers.values)  { c.dispose(); }
    super.dispose();
  }

  // ── Hit testing ──────────────────────────────────────────────────────────

  /// Returns the topmost unplaced piece whose visible area contains [pos].
  /// Pieces later in the list are drawn on top (higher z-order).
  PuzzlePiece? _pieceAt(Offset pos) {
    // Iterate in reverse so we pick the topmost rendered piece first
    for (final piece in _pieces.reversed) {
      if (piece.isPlaced) continue;
      final scale          = _scaleAnimations[piece.id]?.value ?? _trayScale;
      final scaledW        = _baseW * scale;
      final scaledH        = _baseH * scale;
      final offsetX        = (_baseW - scaledW) / 2;
      final offsetY        = (_baseH - scaledH) / 2;
      final scaledPad      = _tabPadding * scale;
      final left   = piece.currentPosition.dx + offsetX - scaledPad;
      final top    = piece.currentPosition.dy + offsetY - scaledPad;
      final right  = left + scaledW + scaledPad * 2;
      final bottom = top  + scaledH + scaledPad * 2;
      if (pos.dx >= left && pos.dx <= right &&
          pos.dy >= top  && pos.dy <= bottom) {
        return piece;
      }
    }
    return null;
  }

  // ── Raw pointer handlers (bypass gesture arena entirely) ─────────────────

  void _onPointerDown(PointerDownEvent e) {
    final hit = _pieceAt(e.localPosition);
    if (hit == null) return;
    _lastPointerPos = e.localPosition;
    setState(() {
      // Bring piece to top of z-order
      _pieces.remove(hit);
      _pieces.add(hit);
      hit.isDragging = true;
      hit.isActive   = true;
      _draggedPiece  = hit;
    });
  }

  void _onPointerMove(PointerMoveEvent e) {
    final piece = _draggedPiece;
    if (piece == null) return;
    final delta = e.localPosition - _lastPointerPos;
    _lastPointerPos = e.localPosition;
    setState(() {
      piece.currentPosition += delta;
      _updateScale(piece);
    });
  }

  void _onPointerUp(PointerUpEvent e) {
    final piece = _draggedPiece;
    if (piece == null) return;
    _draggedPiece = null;
    setState(() { piece.isActive = false; });
    _onPieceMoved(piece, piece.currentPosition);
  }

  void _onPointerCancel(PointerCancelEvent e) {
    final piece = _draggedPiece;
    if (piece == null) return;
    _draggedPiece = null;
    setState(() { piece.isActive = false; piece.isDragging = false; });
    _updateScale(piece);
  }

  // ── Scale helpers ────────────────────────────────────────────────────────

  bool _isOnBoard(PuzzlePiece piece) =>
      piece.currentPosition.dx + _baseW / 2 < _leftBoundary;

  void _updateScale(PuzzlePiece piece) {
    final ctrl = _scaleControllers[piece.id];
    if (ctrl == null) return;
    _isOnBoard(piece) ? ctrl.forward() : ctrl.reverse();
  }

  // ── Drop / snap logic ────────────────────────────────────────────────────

  void _onPieceMoved(PuzzlePiece piece, Offset newPos) {
    setState(() {
      piece.currentPosition = newPos;
      piece.isDragging      = false;

      final currentCenter = newPos + Offset(_baseW / 2, _baseH / 2);
      final correctCenter  = piece.correctPosition + Offset(_baseW / 2, _baseH / 2);

      if (ImageSlicer.shouldSnap(
        currentPos: currentCenter,
        correctPos: correctCenter,
        threshold:  _baseW * 0.35,
      )) {
        piece.currentPosition = piece.correctPosition;
        piece.isPlaced        = true;
        _scaleControllers[piece.id]?.forward();
        _triggerBurst(piece);
      } else {
        _updateScale(piece);
      }
      _checkSolved();
    });
  }

  void _triggerBurst(PuzzlePiece piece) {
    // Centre of the snapped piece on screen
    final center = piece.correctPosition + Offset(_baseW / 2, _baseH / 2);

    // Dispose any previous burst for this piece
    _burstControllers[piece.id]?.dispose();

    final ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _burstControllers[piece.id] = ctrl;
    _burstCenters[piece.id]     = center;

    ctrl.addListener(() => setState(() {}));
    ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        _burstControllers.remove(piece.id)?.dispose();
        _burstCenters.remove(piece.id);
        setState(() {});
      }
    });
    ctrl.forward(from: 0);
  }

  void _checkSolved() {
    if (_pieces.every((p) => p.isPlaced)) {
      _solved = true;
      _pandaKey.currentState?.triggerDance();
      _lastConfettiTime = 0;
      _confettiActive   = true;
      _confettiCtrl.forward(from: 0);
      widget.onPuzzleSolved?.call();
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final leftW  = screen.width * _leftFraction;

    return Listener(
      onPointerDown:   _onPointerDown,
      onPointerMove:   _onPointerMove,
      onPointerUp:     _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _buildLeftPanel(leftW, screen.height),
          _buildRightPanel(leftW, screen.width, screen.height),
          _buildTemplate(),
          ..._pieces.map(_buildPiece),
          _buildPanda(),
          ..._burstControllers.entries.map((e) => _buildBurst(e.key)),
          if (_confettiActive) _buildConfetti(),
        ],
      ),
    );
  }

  // ── Panels ───────────────────────────────────────────────────────────────

  Widget _buildLeftPanel(double w, double h) => Positioned(
    left: 0, top: 0, width: w, height: h,
    child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFB6C1).withOpacity(0.3),
            const Color(0xFFFFD6E0).withOpacity(0.2),
          ],
        ),
      ),
    ),
  );

  Widget _buildRightPanel(double left, double screenW, double h) => Positioned(
    left: left, top: 0, width: screenW - left, height: h,
    child: Container(
      decoration: BoxDecoration(
        color:  Colors.white.withOpacity(0.15),
        border: Border(left: BorderSide(color: Colors.white38, width: 1.5)),
      ),
    ),
  );

  // ── Ghost template ───────────────────────────────────────────────────────

  Widget _buildTemplate() => Positioned(
    left: _templateRect.left, top: _templateRect.top,
    width: _templateRect.width, height: _templateRect.height,
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.12), blurRadius: 16,
          offset: const Offset(0, 4),
        )],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CustomPaint(
          painter: PuzzleTemplatePainter(rows: widget.rows, cols: widget.cols),
          size: Size(_templateRect.width, _templateRect.height),
        ),
      ),
    ),
  );

  // ── Single piece (no GestureDetector — input handled by Listener above) ──

  Widget _buildPiece(PuzzlePiece piece) {
    final scaleAnim = _scaleAnimations[piece.id];
    return AnimatedBuilder(
      animation: scaleAnim ?? AlwaysStoppedAnimation(_trayScale),
      builder: (context, _) {
        final scale          = piece.isPlaced ? 1.0 : (scaleAnim?.value ?? _trayScale);
        final scaledW        = _baseW * scale;
        final scaledH        = _baseH * scale;
        final scaledPad      = _tabPadding * scale;
        final offsetX        = (_baseW - scaledW) / 2;
        final offsetY        = (_baseH - scaledH) / 2;

        return Positioned(
          left:   piece.currentPosition.dx + offsetX - scaledPad,
          top:    piece.currentPosition.dy + offsetY - scaledPad,
          width:  scaledW + scaledPad * 2,
          height: scaledH + scaledPad * 2,
          child: CustomPaint(
            painter: PuzzlePiecePainter(
              piece:      piece,
              baseWidth:  scaledW,
              baseHeight: scaledH,
              tabPadding: scaledPad,
            ),
            size: Size(scaledW + scaledPad * 2, scaledH + scaledPad * 2),
          ),
        );
      },
    );
  }

  // ── Panda mascot ─────────────────────────────────────────────────────────

  Widget _buildPanda() {
    final leftMargin = _templateRect.left;
    final pandaSize  = _baseH; // 1 piece height

    // Centre horizontally in left margin, vertically centred on template
    final pandaLeft = (leftMargin - pandaSize) / 2;
    final pandaTop  = _templateRect.top +
        (_templateRect.height - pandaSize * 1.15) / 2;

    return Positioned(
      left:   pandaLeft,
      top:    pandaTop,
      width:  pandaSize,
      height: pandaSize * 1.15,
      child: PandaWidget(
        key:  _pandaKey,
        size: pandaSize,
      ),
    );
  }

  // ── Particle burst overlay ───────────────────────────────────────────────

  Widget _buildBurst(int pieceId) {
    final ctrl   = _burstControllers[pieceId];
    final center = _burstCenters[pieceId];
    if (ctrl == null || center == null) return const SizedBox.shrink();

    final burstRadius = _baseW * 1.4;

    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: ParticleBurstPainter.create(
            progress: ctrl.value,
            center:   center,
            radius:   burstRadius,
            count:    30,
            seed:     pieceId,
          ),
        ),
      ),
    );
  }

  // ── Confetti rain ────────────────────────────────────────────────────────

  Widget _buildConfetti() {
    // Fade out in last 2 seconds of the 8s animation
    final t        = _confettiCtrl.value;
    final opacity  = t < 0.85 ? 1.0 : 1.0 - ((t - 0.85) / 0.15);

    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: ConfettiPainter(
            particles: _confettiParticles,
            opacity:   opacity,
          ),
        ),
      ),
    );
  }
}