import 'package:flutter/material.dart';
import 'puzzle_piece_painter.dart'; // reuse EdgeType + edge helpers

/// Paints the full puzzle template as a ghost grid —
/// each cell drawn with the same jigsaw path as the real pieces,
/// filled with a semi-transparent colour so the player can see
/// exactly where each piece belongs.
class PuzzleTemplatePainter extends CustomPainter {
  final int rows;
  final int cols;
  final double tabDepth;
  final double tabWidth;

  const PuzzleTemplatePainter({
    required this.rows,
    required this.cols,
    this.tabDepth = 0.22,
    this.tabWidth = 0.32,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / cols;
    final cellH = size.height / rows;

    final fillPaint = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final path = _buildCellPath(
          row: r,
          col: c,
          cellW: cellW,
          cellH: cellH,
        );
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, borderPaint);
      }
    }
  }

  /// Builds the jigsaw path for a single cell at grid position [row],[col].
  /// Coordinates are in the full-board canvas space.
  Path _buildCellPath({
    required int row,
    required int col,
    required double cellW,
    required double cellH,
  }) {
    final ox = col * cellW; // left of this cell
    final oy = row * cellH; // top of this cell
    final rx = ox + cellW;  // right
    final by = oy + cellH;  // bottom

    // Edge types — same rule as PuzzlePiecePainter
    final topEdge    = row == 0        ? EdgeType.flat : EdgeType.blank;
    final bottomEdge = row == rows - 1 ? EdgeType.flat : EdgeType.tab;
    final leftEdge   = col == 0        ? EdgeType.flat : EdgeType.blank;
    final rightEdge  = col == cols - 1 ? EdgeType.flat : EdgeType.tab;

    final path = Path()..moveTo(ox, oy);

    // → Top
    _hEdge(path, fromX: ox, toX: rx, y: oy,
        edge: topEdge, ox: ox, cellW: cellW, cellH: cellH);
    // ↓ Right
    _vEdge(path, fromY: oy, toY: by, x: rx,
        edge: rightEdge, oy: oy, cellW: cellW, cellH: cellH);
    // ← Bottom
    _hEdge(path, fromX: rx, toX: ox, y: by,
        edge: bottomEdge, ox: ox, cellW: cellW, cellH: cellH);
    // ↑ Left
    _vEdge(path, fromY: by, toY: oy, x: ox,
        edge: leftEdge, oy: oy, cellW: cellW, cellH: cellH);

    path.close();
    return path;
  }

  void _hEdge(
    Path path, {
    required double fromX,
    required double toX,
    required double y,
    required EdgeType edge,
    required double ox,
    required double cellW,
    required double cellH,
  }) {
    if (edge == EdgeType.flat) { path.lineTo(toX, y); return; }

    final ltr = toX > fromX;
    final halfTab = cellW * tabWidth / 2;
    final midX = ox + cellW / 2;

    final bumpDir = (edge == EdgeType.tab)
        ? (ltr ? 1.0 : -1.0)
        : (ltr ? -1.0 : 1.0);
    final bumpY = y + bumpDir * cellH * tabDepth;

    if (ltr) {
      path.lineTo(midX - halfTab, y);
      path.cubicTo(midX - halfTab, bumpY, midX + halfTab, bumpY, midX + halfTab, y);
      path.lineTo(toX, y);
    } else {
      path.lineTo(midX + halfTab, y);
      path.cubicTo(midX + halfTab, bumpY, midX - halfTab, bumpY, midX - halfTab, y);
      path.lineTo(toX, y);
    }
  }

  void _vEdge(
    Path path, {
    required double fromY,
    required double toY,
    required double x,
    required EdgeType edge,
    required double oy,
    required double cellW,
    required double cellH,
  }) {
    if (edge == EdgeType.flat) { path.lineTo(x, toY); return; }

    final ttb = toY > fromY;
    final halfTab = cellH * tabWidth / 2;
    final midY = oy + cellH / 2;

    final bumpDir = (edge == EdgeType.tab)
        ? (ttb ? 1.0 : -1.0)
        : (ttb ? -1.0 : 1.0);
    final bumpX = x + bumpDir * cellW * tabDepth;

    if (ttb) {
      path.lineTo(x, midY - halfTab);
      path.cubicTo(bumpX, midY - halfTab, bumpX, midY + halfTab, x, midY + halfTab);
      path.lineTo(x, toY);
    } else {
      path.lineTo(x, midY + halfTab);
      path.cubicTo(bumpX, midY + halfTab, bumpX, midY - halfTab, x, midY - halfTab);
      path.lineTo(x, toY);
    }
  }

  @override
  bool shouldRepaint(PuzzleTemplatePainter old) =>
      old.rows != rows || old.cols != cols;
}