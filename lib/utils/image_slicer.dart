import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/puzzle_piece.dart';

class ImageSlicer {
  /// Slices a ui.Image into a grid of [rows] x [cols] PuzzlePieces.
  ///
  /// Tray layout:
  ///   - Pieces fill the tray in a [trayGridCols] × [trayGridRows] grid.
  ///   - Piece display size is AUTO-CALCULATED so the grid fills the tray
  ///     with equal padding on all sides (≈ half a piece-width from each edge).
  ///   - No jitter — clean, organised layout matching your reference image.
  ///   - Slot assignment is shuffled so which piece lands where is random.
  static List<PuzzlePiece> slice({
    required ui.Image image,
    required int rows,
    required int cols,
    required Rect boardRect,
    required Rect trayRect,
    double trayScale    = 0.60,   // kept for scale-animation reference
    int trayGridCols    = 3,
    int trayGridRows    = 4,
    int? seed,
  }) {
    final rng = Random(seed);

    final pieceBoardW = boardRect.width  / cols;
    final pieceBoardH = boardRect.height / rows;

    // ── Auto-fit: calculate piece size so the grid fills the tray ────────────
    //
    // We want:
    //   trayGridCols * pieceW + (trayGridCols + 1) * margin = trayRect.width
    //   trayGridRows * pieceH + (trayGridRows + 1) * margin = trayRect.height
    //
    // where margin ≈ 0.4 * pieceW  (roughly half a piece as padding/gap).
    // Solving for pieceW:
    //   pieceW * (trayGridCols + (trayGridCols+1)*0.4) = trayRect.width
    //   pieceW = trayRect.width / (trayGridCols + (trayGridCols+1)*0.4)
    //
    // We compute both axes and take the smaller to preserve aspect ratio.

    const double marginRatio = 0.6; // gap = 60% of piece width
    final fitW = trayRect.width  / (trayGridCols + (trayGridCols + 1) * marginRatio);
    final fitH = trayRect.height / (trayGridRows + (trayGridRows + 1) * marginRatio);

    // Use the smaller dimension so pieces fit without overflow
    final pieceDisplayW = fitW < fitH * (pieceBoardW / pieceBoardH)
        ? fitW
        : fitH * (pieceBoardW / pieceBoardH);
    final pieceDisplayH = pieceDisplayW * (pieceBoardH / pieceBoardW);

    // Gap between pieces (and from tray edges)
    final gapX = (trayRect.width  - trayGridCols * pieceDisplayW) / (trayGridCols + 1);
    final gapY = (trayRect.height - trayGridRows * pieceDisplayH) / (trayGridRows + 1);

    // Shift the whole grid toward top-left so it feels balanced in the tray.
    // 0.0 = perfectly centred, 1.0 = flush to top/left edge of the gap.
    // 0.35 means the grid sits 35% closer to the top-left than centre.
    const double topLeftBias = 0.75;
    final shiftX = gapX * topLeftBias;
    final shiftY = gapY * topLeftBias;

    // ── Build slot positions (row-major, then shuffle assignment) ─────────────
    final slotPositions = <Offset>[];
    for (int sr = 0; sr < trayGridRows; sr++) {
      for (int sc = 0; sc < trayGridCols; sc++) {
        slotPositions.add(Offset(
          trayRect.left + gapX + sc * (pieceDisplayW + gapX) - shiftX,
          trayRect.top  + gapY + sr * (pieceDisplayH + gapY) - shiftY,
        ));
      }
    }
    // Shuffle which piece gets which slot
    slotPositions.shuffle(rng);

    final pieces = <PuzzlePiece>[];
    int id = 0;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final correctPos = Offset(
          boardRect.left + c * pieceBoardW,
          boardRect.top  + r * pieceBoardH,
        );

        // currentPosition = top-left of the BASE (full-size) piece rect.
        // Since the piece renders at trayScale in the tray, we adjust so the
        // visual centre matches the slot centre.
        final slotOrigin = slotPositions[id % slotPositions.length];

        // The piece is rendered at `trayScale` of its board size, but
        // currentPosition is always in board-size coordinates.
        // So we back-calculate: where should currentPosition be so that the
        // rendered (scaled) piece sits centred in the slot?
        final renderedW = pieceBoardW * trayScale;
        final renderedH = pieceBoardH * trayScale;
        final startPos = Offset(
          slotOrigin.dx + (pieceDisplayW - renderedW) / 2,
          slotOrigin.dy + (pieceDisplayH - renderedH) / 2,
        );

        pieces.add(PuzzlePiece(
          id:              id++,
          row:             r,
          col:             c,
          totalRows:       rows,
          totalCols:       cols,
          sourceImage:     image,
          currentPosition: startPos,
          correctPosition: correctPos,
        ));
      }
    }

    // Shuffle z-order only
    pieces.shuffle(rng);
    return pieces;
  }

  /// Checks if [currentPos] is close enough to [correctPos] to snap.
  static bool shouldSnap({
    required Offset currentPos,
    required Offset correctPos,
    double threshold = 30.0,
  }) {
    return (currentPos - correctPos).distance <= threshold;
  }
}