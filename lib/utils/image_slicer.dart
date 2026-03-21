import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/puzzle_piece.dart';

class ImageSlicer {
  /// Slices a ui.Image into a grid of [rows] x [cols] PuzzlePieces.
  /// Pieces are shuffled randomly, placed in a sidebar tray area.
  ///
  /// [boardRect]  - the on-screen rectangle where solved puzzle lives
  /// [trayRect]   - area where shuffled pieces start
  static List<PuzzlePiece> slice({
    required ui.Image image,
    required int rows,
    required int cols,
    required Rect boardRect,
    required Rect trayRect,
    int? seed,
  }) {
    final rng = Random(seed);
    final pieces = <PuzzlePiece>[];

    final pieceBoardW = boardRect.width / cols;
    final pieceBoardH = boardRect.height / rows;

    int id = 0;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        // Correct snapping position on board
        final correctPos = Offset(
          boardRect.left + c * pieceBoardW,
          boardRect.top + r * pieceBoardH,
        );

        // Random starting position inside tray
        final startPos = _randomTrayPosition(
          trayRect: trayRect,
          pieceW: pieceBoardW,
          pieceH: pieceBoardH,
          rng: rng,
        );

        pieces.add(PuzzlePiece(
          id: id++,
          row: r,
          col: c,
          totalRows: rows,
          totalCols: cols,
          sourceImage: image,
          currentPosition: startPos,
          correctPosition: correctPos,
        ));
      }
    }

    // Shuffle list order (z-order randomness)
    pieces.shuffle(rng);
    return pieces;
  }

  /// Returns a random position within [trayRect] that fits a piece of [pieceW] x [pieceH].
  static Offset _randomTrayPosition({
    required Rect trayRect,
    required double pieceW,
    required double pieceH,
    required Random rng,
  }) {
    final maxX = (trayRect.width - pieceW).clamp(0.0, double.infinity);
    final maxY = (trayRect.height - pieceH).clamp(0.0, double.infinity);
    return Offset(
      trayRect.left + rng.nextDouble() * maxX,
      trayRect.top + rng.nextDouble() * maxY,
    );
  }

  /// Checks if [currentPos] is close enough to [correctPos] to snap.
  /// [threshold] is in logical pixels.
  static bool shouldSnap({
    required Offset currentPos,
    required Offset correctPos,
    double threshold = 30.0,
  }) {
    return (currentPos - correctPos).distance <= threshold;
  }
}
