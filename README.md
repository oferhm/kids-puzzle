# Kids Puzzle App — Flutter

A kids jigsaw puzzle app for Android tablets with drag-and-drop piece mechanics.

## Project Structure

```
lib/
├── models/
│   └── puzzle_piece.dart         # Data model for each puzzle piece
├── utils/
│   └── image_slicer.dart         # Slices ui.Image into a grid of pieces + snap logic
├── painters/
│   └── puzzle_piece_painter.dart # CustomPainter: renders piece with jigsaw clip path
├── widgets/
│   └── puzzle_board.dart         # Main game board with drag-and-drop state
├── screens/
│   └── game_screen.dart          # Loads asset image → launches PuzzleBoard
└── main.dart                     # App entry point
```

1. download dependencies, open terminal in project:
flutter pub get  

2. run the app
flutter run

flutter run -d chrome --verbose

create web support
flutter create --platforms web .

flutter devices

flutter run -d chrome

## How Slicing Works

```
ui.Image (loaded from asset at 2560×1600 px)
        ↓
ImageSlicer.slice(rows: 3, cols: 4)
        ↓
12 × PuzzlePiece objects, each holding:
  - sourceRect   → which part of the original image to draw
  - correctPos   → where it belongs on the board
  - currentPos   → shuffled random start in the tray
        ↓
PuzzlePiecePainter clips each piece to a jigsaw path
  - Cubic bezier tabs/blanks per edge
  - Clips image fragment to that shape
        ↓
GestureDetector (onPanUpdate) moves piece
        ↓
ImageSlicer.shouldSnap() checks distance ≤ 35px
  → snaps to correctPos, marks isPlaced = true
        ↓
All pieces placed → solved animation plays
```

## Recommended Image Specs

| Use case         | Resolution    | Format |
|------------------|---------------|--------|
| Master artwork   | 2560×1600 px  | PNG    |
| In-app asset     | 2560×1600 px  | WebP   |
| Thumbnail/icon   | 512×320 px    | WebP   |

Always design in **landscape 16:10** ratio.  
Keep key content in the **center 80%** to avoid notch/edge cutoffs.

## Adding a New Puzzle

1. Add your image to `assets/images/my_puzzle.webp`
2. Register it in `pubspec.yaml` under `assets:`
3. Navigate to `GameScreen`:

```dart
GameScreen(
  imageAssetPath: 'assets/images/my_puzzle.webp',
  rows: 3,
  cols: 4,
)
```

## Difficulty Levels

| Level    | Grid   | Pieces |
|----------|--------|--------|
| Easy     | 2 × 3  | 6      |
| Medium   | 3 × 4  | 12     |
| Hard     | 4 × 5  | 20     |
| Expert   | 5 × 6  | 30     |

## Next Steps

- [ ] Add `audioplayers` snap sound on piece placement
- [ ] Add Lottie confetti on puzzle solved
- [ ] Persist completed levels with `shared_preferences`
- [ ] Add difficulty selector on home screen
- [ ] Add hint button (ghost image overlay)
- [ ] Add timer / star rating system
