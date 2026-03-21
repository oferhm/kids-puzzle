import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/puzzle_piece.dart';
import '../painters/puzzle_piece_painter.dart';
import '../painters/puzzle_template_painter.dart';
import '../utils/image_slicer.dart';

// ── Layout constants ──────────────────────────────────────────────────────────
//
//  Full screen (landscape)
//  ┌─────────────────────────────────┬──────────────────┐
//  │        LEFT PANEL (65%)         │  RIGHT PANEL(35%) │
//  │  ┌─────────────────────────┐    │  ┌──────────────┐ │
//  │  │   PUZZLE TEMPLATE       │    │  │  PIECE TRAY  │ │
//  │  │   80% of left panel     │    │  │  (scrollable)│ │
//  │  │   centred with margin   │    │  └──────────────┘ │
//  │  └─────────────────────────┘    │                   │
//  └─────────────────────────────────┴───────────────────┘

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
    with SingleTickerProviderStateMixin {
  List<PuzzlePiece> _pieces = [];
  late AnimationController _solvedController;
  bool _solved = false;

  // Computed once in _initLayout
  late Rect _templateRect; // where the ghost template lives on screen
  late double _baseW;       // piece display width  (= templateRect.width  / cols)
  late double _baseH;       // piece display height (= templateRect.height / rows)
  late double _tabPadding;  // widget padding to accommodate tab overflow

  static const double _leftFraction  = 0.65;
  static const double _templateScale = 0.80; // template = 80% of left panel
  static const double _tabDepth      = 0.22;

  @override
  void initState() {
    super.initState();
    _solvedController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initLayout();
  }

  void _initLayout() {
    final screen = MediaQuery.of(context).size;
    final leftW  = screen.width * _leftFraction;
    final leftH  = screen.height;

    // Template is 80% of the left panel, centred
    final tmplW  = leftW  * _templateScale;
    final tmplH  = leftH  * _templateScale;
    final tmplL  = (leftW  - tmplW)  / 2;      // horizontal margin
    final tmplT  = (leftH  - tmplH)  / 2;      // vertical margin

    _templateRect = Rect.fromLTWH(tmplL, tmplT, tmplW, tmplH);
    _baseW        = tmplW / widget.cols;
    _baseH        = tmplH / widget.rows;
    _tabPadding   = (_baseW * _tabDepth).clamp(_baseH * _tabDepth, double.infinity) + 10.0;

    // Tray area (right 35%)
    final trayRect = Rect.fromLTWH(
      leftW, 0, screen.width * (1 - _leftFraction), leftH,
    );

    setState(() {
      _pieces = ImageSlicer.slice(
        image: widget.image,
        rows:  widget.rows,
        cols:  widget.cols,
        boardRect: _templateRect,  // correct positions aligned to template
        trayRect:  trayRect,
      );
      _solved = false;
    });
  }

  void _onPieceMoved(PuzzlePiece piece, Offset newPos) {
    setState(() {
      piece.currentPosition = newPos;
      piece.isDragging = false;

      // Compare centers, not top-left corners — gives consistent feel
      // regardless of where the user grabbed the piece.
      final currentCenter = newPos + Offset(_baseW / 2, _baseH / 2);
      final correctCenter  = piece.correctPosition + Offset(_baseW / 2, _baseH / 2);

      if (ImageSlicer.shouldSnap(
        currentPos: currentCenter,
        correctPos: correctCenter,
        threshold:  _baseW * 0.30, // snap if center within 20% of piece width
      )) {
        piece.currentPosition = piece.correctPosition;
        piece.isPlaced = true;
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final leftW  = screen.width * _leftFraction;

    return Stack(
      children: [
        // ── Background panels ───────────────────────────────────────────────
        _buildLeftPanel(leftW, screen.height),
        _buildRightPanel(leftW, screen.width, screen.height),

        // ── Ghost template ──────────────────────────────────────────────────
        _buildTemplate(),

        // ── Placed pieces (bottom z-order) ──────────────────────────────────
        ..._pieces.where((p) => p.isPlaced && !p.isDragging)
            .map(_buildDraggablePiece),

        // ── Unplaced, non-dragging pieces ───────────────────────────────────
        ..._pieces.where((p) => !p.isPlaced && !p.isDragging)
            .map(_buildDraggablePiece),

        // ── Currently dragged piece (top z-order) ───────────────────────────
        ..._pieces.where((p) => p.isDragging)
            .map(_buildDraggablePiece),

        // ── Solved overlay ──────────────────────────────────────────────────
        if (_solved) _buildSolvedOverlay(),
      ],
    );
  }

  // ── Panels ────────────────────────────────────────────────────────────────

  Widget _buildLeftPanel(double w, double h) => Positioned(
    left: 0, top: 0, width: w, height: h,
    child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
        color: Colors.white.withOpacity(0.15),
        border: Border(left: BorderSide(color: Colors.white38, width: 1.5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'PIECES',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Drag pieces\nto the board →',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  // ── Ghost template ─────────────────────────────────────────────────────────

  Widget _buildTemplate() => Positioned(
    left:   _templateRect.left,
    top:    _templateRect.top,
    width:  _templateRect.width,
    height: _templateRect.height,
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CustomPaint(
          painter: PuzzleTemplatePainter(
            rows: widget.rows,
            cols: widget.cols,
          ),
          size: Size(_templateRect.width, _templateRect.height),
        ),
      ),
    ),
  );

  // ── Draggable piece ────────────────────────────────────────────────────────

  Widget _buildDraggablePiece(PuzzlePiece piece) {
    return Positioned(
      left:   piece.currentPosition.dx - _tabPadding,
      top:    piece.currentPosition.dy - _tabPadding,
      width:  _baseW + _tabPadding * 2,
      height: _baseH + _tabPadding * 2,
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onPanStart: piece.isPlaced
            ? null
            : (_) => setState(() => piece.isDragging = true),
        onPanUpdate: piece.isPlaced
            ? null
            : (details) => setState(() {
                  piece.currentPosition += details.delta;
                }),
        onPanEnd: piece.isPlaced
            ? null
            : (_) => _onPieceMoved(piece, piece.currentPosition),
        child: CustomPaint(
          painter: PuzzlePiecePainter(
            piece:      piece,
            baseWidth:  _baseW,
            baseHeight: _baseH,
            tabPadding: _tabPadding,
          ),
          size: Size(_baseW + _tabPadding * 2, _baseH + _tabPadding * 2),
        ),
      ),
    );
  }

  // ── Solved overlay ─────────────────────────────────────────────────────────

  Widget _buildSolvedOverlay() => AnimatedBuilder(
    animation: _solvedController,
    builder: (context, _) => Opacity(
      opacity: _solvedController.value,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF56AB2F), Color(0xFFA8E063)],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.45),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🎉', style: TextStyle(fontSize: 52)),
              SizedBox(height: 10),
              Text(
                'Puzzle Solved!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black26)],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  void dispose() {
    _solvedController.dispose();
    super.dispose();
  }
}