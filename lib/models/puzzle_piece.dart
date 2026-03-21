import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Represents a single puzzle piece with its image fragment,
/// correct position, and current drag position.
class PuzzlePiece {
  final int id;
  final int row;
  final int col;
  final int totalRows;
  final int totalCols;
  final ui.Image sourceImage;

  Offset currentPosition;
  Offset correctPosition;
  bool isPlaced;
  bool isDragging;

  PuzzlePiece({
    required this.id,
    required this.row,
    required this.col,
    required this.totalRows,
    required this.totalCols,
    required this.sourceImage,
    required this.currentPosition,
    required this.correctPosition,
    this.isPlaced = false,
    this.isDragging = false,
  });

  /// Width of each piece as fraction of total image
  double get pieceWidth => sourceImage.width / totalCols;

  /// Height of each piece as fraction of total image
  double get pieceHeight => sourceImage.height / totalRows;

  /// Source rect in the original image
  Rect get sourceRect => Rect.fromLTWH(
        col * pieceWidth,
        row * pieceHeight,
        pieceWidth,
        pieceHeight,
      );
}
