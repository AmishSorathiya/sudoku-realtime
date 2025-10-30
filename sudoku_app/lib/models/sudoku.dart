import 'dart:math';

class SudokuBoard {
  /// Current grid values (0 = empty)
  late List<List<int>> grid;

  /// True if the cell was part of the initial puzzle (locked)
  late List<List<bool>> fixed;

  // ----------------- Constructors -----------------

  /// Single-player: pick a random puzzle from the pool.
  SudokuBoard() {
    final rnd = Random();
    final src = _defaultPuzzles[rnd.nextInt(_defaultPuzzles.length)];
    grid = _deepCopy(src);
    fixed = List.generate(9, (r) =>
        List.generate(9, (c) => grid[r][c] != 0)
    );
  }

  /// Multiplayer: create a board from a server-sent 9×9 list.
  factory SudokuBoard.fromGrid(List<List<int>> g) {
    if (g.length != 9 || g.any((row) => row.length != 9)) {
      throw ArgumentError('fromGrid expects a 9×9 list');
    }
    final copied = _deepCopy(g);
    final fx = List.generate(9, (r) =>
        List.generate(9, (c) => copied[r][c] != 0)
    );
    final b = SudokuBoard._internal(copied, fx);
    return b;
  }

  SudokuBoard._internal(this.grid, this.fixed);

  // ----------------- Core ops -----------------

  bool isFixedCell(int r, int c) => fixed[r][c];

  /// Set a value (1–9) or 0 to clear. Ignored for fixed cells.
  void setCell(int r, int c, int value) {
    if (fixed[r][c]) return;
    if (value < 0 || value > 9) return;
    grid[r][c] = value;
  }

  /// Validates if [value] at (r,c) doesn’t conflict with row/col/box.
  /// Note: this ignores the current cell itself when checking.
  bool isValidMove(int r, int c, int value) {
    if (value == 0) return true;

    // row
    for (int cc = 0; cc < 9; cc++) {
      if (cc == c) continue;
      if (grid[r][cc] == value) return false;
    }

    // col
    for (int rr = 0; rr < 9; rr++) {
      if (rr == r) continue;
      if (grid[rr][c] == value) return false;
    }

    // 3x3 box
    final br = (r ~/ 3) * 3;
    final bc = (c ~/ 3) * 3;
    for (int rr = br; rr < br + 3; rr++) {
      for (int cc = bc; cc < bc + 3; cc++) {
        if (rr == r && cc == c) continue;
        if (grid[rr][cc] == value) return false;
      }
    }

    return true;
  }

  /// Returns true only if there are no zeros and all rows/cols/boxes are 1..9.
  bool get isComplete {
    // no zeros
    for (final row in grid) {
      for (final v in row) {
        if (v == 0) return false;
      }
    }

    const want = '123456789';

    // rows
    for (int r = 0; r < 9; r++) {
      final sorted = [...grid[r]]..sort();
      if (sorted.join() != want) return false;
    }

    // cols
    for (int c = 0; c < 9; c++) {
      final col = <int>[];
      for (int r = 0; r < 9; r++) col.add(grid[r][c]);
      col.sort();
      if (col.join() != want) return false;
    }

    // boxes
    for (int br = 0; br < 3; br++) {
      for (int bc = 0; bc < 3; bc++) {
        final box = <int>[];
        for (int r = br * 3; r < br * 3 + 3; r++) {
          for (int c = bc * 3; c < bc * 3 + 3; c++) {
            box.add(grid[r][c]);
          }
        }
        box.sort();
        if (box.join() != want) return false;
      }
    }

    return true;
  }

  bool get hasAnyConflict {
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final v = grid[r][c];
        if (v != 0 && !isValidMove(r, c, v)) return true;
      }
    }
    return false;
  }

  // ----------------- Utils -----------------

  static List<List<int>> _deepCopy(List<List<int>> src) =>
      List<List<int>>.generate(9, (r) => List<int>.from(src[r]));

  // A small pool of valid puzzles (0 = empty).
  static final List<List<List<int>>> _defaultPuzzles = [
    [
      [0, 0, 0, 2, 6, 0, 7, 0, 1],
      [6, 8, 0, 0, 7, 0, 0, 9, 0],
      [1, 9, 0, 0, 0, 4, 5, 0, 0],
      [8, 2, 0, 1, 0, 0, 0, 4, 0],
      [0, 0, 4, 6, 0, 2, 9, 0, 0],
      [0, 5, 0, 0, 0, 3, 0, 2, 8],
      [0, 0, 9, 3, 0, 0, 0, 7, 4],
      [0, 4, 0, 0, 5, 0, 0, 3, 6],
      [7, 0, 3, 0, 1, 8, 0, 0, 0],
    ],
    [
      [0, 2, 0, 0, 0, 6, 0, 0, 9],
      [0, 0, 0, 0, 9, 0, 0, 5, 0],
      [8, 0, 0, 0, 0, 5, 0, 0, 2],
      [0, 0, 8, 0, 0, 0, 0, 2, 0],
      [0, 7, 0, 4, 0, 1, 0, 9, 0],
      [0, 3, 0, 0, 0, 0, 6, 0, 0],
      [5, 0, 0, 6, 0, 0, 0, 0, 7],
      [0, 4, 0, 0, 1, 0, 0, 0, 0],
      [9, 0, 0, 3, 0, 0, 0, 1, 0],
    ],
    [
      [0, 0, 6, 0, 0, 0, 2, 8, 0],
      [0, 0, 0, 0, 0, 3, 0, 0, 6],
      [7, 0, 0, 0, 8, 0, 0, 0, 4],
      [0, 0, 0, 9, 0, 0, 1, 0, 0],
      [5, 0, 0, 0, 0, 0, 0, 0, 2],
      [0, 0, 2, 0, 0, 4, 0, 0, 0],
      [2, 0, 0, 0, 1, 0, 0, 0, 7],
      [6, 0, 0, 4, 0, 0, 0, 0, 0],
      [0, 5, 1, 0, 0, 0, 8, 0, 0],
    ],
  ];

}
