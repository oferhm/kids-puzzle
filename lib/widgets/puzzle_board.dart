import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/puzzle_piece.dart';
import '../painters/puzzle_piece_painter.dart';
import '../painters/puzzle_template_painter.dart';
import '../utils/image_slicer.dart';

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

  // Single dragged piece — tracked by raw pointer events on the Stack
  PuzzlePiece? _draggedPiece;
  Offset        _lastPointerPos = Offset.zero;

  late Rect   _templateRect;
  late double _baseW;
  late double _baseH;
  late double _tabPadding;
  late double _leftBoundary;

  static const double _leftFraction  = 0.65;
  static const double _templateScale = 0.80;
  static const double _tabDepth      = 0.22;
  static const double _trayScale     = 0.60;

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _solvedController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700),
    );
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
    _templateRect = Rect.fromLTWH(
      (leftW - tmplW) / 2, (leftH - tmplH) / 2, tmplW, tmplH,
    );
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
    for (final c in _scaleControllers.values) { c.dispose(); }
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
      } else {
        _updateScale(piece);
      }
      _checkSolved();
    });
  }

  void _checkSolved() {
    if (_pieces.every((p) => p.isPlaced)) {
      _solved = true;
      _solvedController.forward(from: 0);
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
        children: [
          _buildLeftPanel(leftW, screen.height),
          _buildRightPanel(leftW, screen.width, screen.height),
          _buildTemplate(),
          // Pieces in _pieces order — last = topmost (dragged piece moved to end)
          ..._pieces.map(_buildPiece),
          if (_solved) _buildSolvedOverlay(),
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

  // ── Solved overlay ───────────────────────────────────────────────────────

  Widget _buildSolvedOverlay() => AnimatedBuilder(
    animation: _solvedController,
    builder: (context, _) => Opacity(
      opacity: _solvedController.value,
      child: Center(child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF56AB2F), Color(0xFFA8E063)]),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(
            color: Colors.green.withOpacity(0.45), blurRadius: 24, spreadRadius: 4,
          )],
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🎉', style: TextStyle(fontSize: 52)),
            SizedBox(height: 10),
            Text('Puzzle Solved!', style: TextStyle(
              color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold,
              shadows: [Shadow(blurRadius: 4, color: Colors.black26)],
            )),
          ],
        ),
      )),
    ),
  );
}