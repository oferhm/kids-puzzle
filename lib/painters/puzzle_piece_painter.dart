import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/puzzle_piece.dart';

/// Describes whether an edge has a tab (bump OUT) or blank (indent IN).
/// Flat = no tab (border edges of the full puzzle).
enum EdgeType { flat, tab, blank }

/// Paints a single puzzle piece clipped to an accurate jigsaw shape.
///
/// ── The tab-overflow problem & fix ──────────────────────────────────────────
/// When a tab protrudes OUTSIDE the piece's base rectangle (right tab, bottom
/// tab) the canvas widget boundary clips it — leaving a shape-only hole with
/// no image inside.
///
/// Fix: the widget is made LARGER than the base piece by [tabPadding] on every
/// side. The painter receives this padded [Size]. It:
///   1. Offsets every coordinate by [tabPadding] so the base rect starts at
///      (padding, padding) inside the canvas.
///   2. Draws the image into a dst rect that also covers the padding area,
///      mapping the correct pixel region of the source image (including the
///      neighbouring slice that fills the tab bump).
///   3. Clips to the jigsaw path — the tab bumps now have full image content.
///
/// The board widget must position the Positioned widget [tabPadding] earlier
/// (left - padding, top - padding) and size it (baseW + 2*padding, baseH + 2*padding).
///
/// Tab/blank assignment — guarantees perfect interlock between neighbours:
///   Top edge:    flat if row==0,       else BLANK  (row above owns the TAB)
///   Bottom edge: flat if last row,      else TAB
///   Left edge:   flat if col==0,       else BLANK  (col to left owns the TAB)
///   Right edge:  flat if last col,      else TAB
class PuzzlePiecePainter extends CustomPainter {
  final PuzzlePiece piece;

  /// Base display size of the piece (without padding).
  final double baseWidth;
  final double baseHeight;

  /// Extra padding added around the widget on all sides to accommodate tabs.
  final double tabPadding;

  /// How far the tab protrudes, as a fraction of the BASE piece dimension.
  final double tabDepth;

  /// Tab width as a fraction of the BASE piece dimension (centred at 50%).
  final double tabWidth;

  const PuzzlePiecePainter({
    required this.piece,
    required this.baseWidth,
    required this.baseHeight,
    required this.tabPadding,
    this.tabDepth = 0.22,
    this.tabWidth = 0.32,
  });

  // ─── Edge type helpers ────────────────────────────────────────────────────

  EdgeType get _topEdge =>
      piece.row == 0 ? EdgeType.flat : EdgeType.blank;

  EdgeType get _bottomEdge =>
      piece.row == piece.totalRows - 1 ? EdgeType.flat : EdgeType.tab;

  EdgeType get _leftEdge =>
      piece.col == 0 ? EdgeType.flat : EdgeType.blank;

  EdgeType get _rightEdge =>
      piece.col == piece.totalCols - 1 ? EdgeType.flat : EdgeType.tab;

  // ─── Edge builders (coordinates relative to padded canvas) ───────────────

  /// [ox], [oy] = top-left origin of the BASE rect inside the padded canvas.
  void _addHorizontalEdge(
    Path path, {
    required double fromX,
    required double toX,
    required double y,
    required EdgeType edge,
    required double ox, // base rect left
    required double w,  // base width
    required double h,  // base height
  }) {
    if (edge == EdgeType.flat) {
      path.lineTo(toX, y);
      return;
    }

    final bool ltr = toX > fromX;
    final double halfTab = w * tabWidth / 2;
    final double midX = ox + w / 2;

    // tab protrudes AWAY from piece interior:
    // top-blank → upward (−y), bottom-tab drawn R→L → downward (+y)
    final double bumpDir = (edge == EdgeType.tab)
        ? (ltr ? 1.0 : -1.0)
        : (ltr ? -1.0 : 1.0);
    final double bumpY = y + bumpDir * h * tabDepth;

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

  void _addVerticalEdge(
    Path path, {
    required double fromY,
    required double toY,
    required double x,
    required EdgeType edge,
    required double oy, // base rect top
    required double w,
    required double h,
  }) {
    if (edge == EdgeType.flat) {
      path.lineTo(x, toY);
      return;
    }

    final bool ttb = toY > fromY;
    final double halfTab = h * tabWidth / 2;
    final double midY = oy + h / 2;

    final double bumpDir = (edge == EdgeType.tab)
        ? (ttb ? 1.0 : -1.0)
        : (ttb ? -1.0 : 1.0);
    final double bumpX = x + bumpDir * w * tabDepth;

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

  // ─── Jigsaw path (in padded-canvas coordinates) ───────────────────────────

  Path _buildJigsawPath() {
    final p = tabPadding;
    final w = baseWidth;
    final h = baseHeight;

    // corners of the BASE rect inside the padded canvas
    final l = p;       // left
    final t = p;       // top
    final r = p + w;   // right
    final b = p + h;   // bottom

    final path = Path()..moveTo(l, t);

    // → Top edge
    _addHorizontalEdge(path,
        fromX: l, toX: r, y: t, edge: _topEdge, ox: l, w: w, h: h);
    // ↓ Right edge
    _addVerticalEdge(path,
        fromY: t, toY: b, x: r, edge: _rightEdge, oy: t, w: w, h: h);
    // ← Bottom edge
    _addHorizontalEdge(path,
        fromX: r, toX: l, y: b, edge: _bottomEdge, ox: l, w: w, h: h);
    // ↑ Left edge
    _addVerticalEdge(path,
        fromY: b, toY: t, x: l, edge: _leftEdge, oy: t, w: w, h: h);

    path.close();
    return path;
  }

  // ─── Paint ────────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildJigsawPath();

    // Drop shadow when dragging
    if (piece.isDragging) {
      canvas.drawPath(
        path.shift(const Offset(5, 5)),
        Paint()
          ..color = Colors.black.withOpacity(0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }

    // ── Image drawing ────────────────────────────────────────────────────────
    // The dst rect must cover the FULL padded canvas so that the image pixels
    // extend into the tab bumps.  We calculate which region of the source
    // image corresponds to the padded canvas area.
    //
    // Source image dimensions per piece (in image pixels):
    final double srcPieceW = piece.pieceWidth;   // = image.width  / totalCols
    final double srcPieceH = piece.pieceHeight;  // = image.height / totalRows
    //
    // Scale factor: image pixels → display pixels
    final double scaleX = baseWidth  / srcPieceW;
    final double scaleY = baseHeight / srcPieceH;
    //
    // The padding in display px maps back to source px:
    final double srcPadX = tabPadding / scaleX;
    final double srcPadY = tabPadding / scaleY;
    //
    // Expanded source rect (may go slightly outside image bounds — Flutter
    // clamps automatically when drawing):
    final srcRect = Rect.fromLTWH(
      piece.col * srcPieceW - srcPadX,
      piece.row * srcPieceH - srcPadY,
      srcPieceW + 2 * srcPadX,
      srcPieceH + 2 * srcPadY,
    );
    // Dst rect = full padded canvas
    final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);

    canvas.save();
    canvas.clipPath(path);

    canvas.drawImageRect(piece.sourceImage, srcRect, dstRect, Paint());

    // Subtle gloss
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withOpacity(0.06)
        ..style = PaintingStyle.fill,
    );

    canvas.restore();

    // Piece outline
    canvas.drawPath(
      path,
      Paint()
        ..color = piece.isPlaced
            ? Colors.white.withOpacity(0.95)
            : Colors.white.withOpacity(0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = piece.isPlaced ? 2.2 : 1.6
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(PuzzlePiecePainter old) =>
      old.piece.isDragging != piece.isDragging ||
      old.piece.isPlaced != piece.isPlaced ||
      old.piece.currentPosition != piece.currentPosition;
}