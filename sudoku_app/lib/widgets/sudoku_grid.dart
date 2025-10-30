// lib/widgets/sudoku_grid.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/sudoku.dart';

class SudokuGrid extends StatefulWidget {
  final SudokuBoard board;
  final VoidCallback? onChanged;
  final bool locked;
  final bool showPad;
  final void Function(int r, int c)? onCellSelected;

  const SudokuGrid({
    super.key,
    required this.board,
    this.onChanged,
    this.locked = false,
    this.showPad = true,
    this.onCellSelected,
  });

  @override
  State<SudokuGrid> createState() => _SudokuGridState();
}

class _SudokuGridState extends State<SudokuGrid> with SingleTickerProviderStateMixin {
  int? _selR;
  int? _selC;

  // Shake animation for last invalid edit
  late final AnimationController _shakeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  int? _shakingId; // r*9+c

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _selectCell(int r, int c) {
    if (widget.locked) return;
    if (widget.board.isFixedCell(r, c)) return;
    setState(() {
      _selR = r;
      _selC = c;
    });
    HapticFeedback.selectionClick();
    widget.onCellSelected?.call(r, c);
  }

  Set<int> _computeConflicts() {
    final s = <int>{};
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final v = widget.board.grid[r][c];
        if (v != 0 && !widget.board.isValidMove(r, c, v)) {
          s.add(r * 9 + c);
        }
      }
    }
    return s;
  }

  void _applyNumber(int value) {
    if (widget.locked) return;
    if (_selR == null || _selC == null) return;
    final r = _selR!, c = _selC!;
    if (widget.board.isFixedCell(r, c)) return;

    setState(() {
      widget.board.setCell(r, c, value);
    });

    final invalid = (value != 0 && !widget.board.isValidMove(r, c, value));
    if (invalid) {
      HapticFeedback.heavyImpact();
      setState(() => _shakingId = r * 9 + c);
      _shakeCtrl.forward(from: 0);
    } else {
      HapticFeedback.lightImpact();
      setState(() => _shakingId = null);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onChanged?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Stronger contrast in dark; subtler in light
    final BorderSide thin = BorderSide(
      color: isDark ? Colors.white24 : Colors.black26,
      width: 0.8,
    );
    final BorderSide thick = BorderSide(
      color: isDark ? Colors.white70 : Colors.black87,
      width: 1.6,
    );

    final conflicts = _computeConflicts();
    final gridSize = MediaQuery.of(context).size.width * 0.9;

    final selR = _selR, selC = _selC;
    final selVal = (selR != null && selC != null) ? widget.board.grid[selR][selC] : 0;

    Color _bgFor(int r, int c, bool selected) {
      final inRow = (selR != null && r == selR);
      final inCol = (selC != null && c == selC);
      final inBox = (selR != null && selC != null)
          ? (r ~/ 3 == selR! ~/ 3 && c ~/ 3 == selC! ~/ 3)
          : false;
      final sameVal = (selVal != 0 && widget.board.grid[r][c] == selVal);

      double op = 0.0;
      if (inRow || inCol || inBox) op = 0.07;
      if (sameVal) op = 0.14;
      if (selected) op = 0.18;

      // Slightly stronger background in dark so selection is clear
      final base = isDark ? cs.primary : cs.primary;
      return base.withOpacity(op);
    }

    Offset _shakeOffset() {
      final t = _shakeCtrl.value;
      final dx = math.sin(t * math.pi * 6) * 3; // subtle (you set this)
      return Offset(dx, 0);
    }

    Widget buildGrid() {
      return SizedBox(
        width: gridSize,
        height: gridSize,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 9,
          ),
          itemCount: 81,
          itemBuilder: (_, i) {
            final r = i ~/ 9;
            final c = i % 9;
            final v = widget.board.grid[r][c];
            final fixed = widget.board.isFixedCell(r, c);
            final selected = (_selR == r && _selC == c);
            final isConflict = conflicts.contains(i);

            final Color textColor = isConflict
                ? cs.error
                : (fixed ? cs.onSurface : (isDark ? Colors.white : cs.primary));

            final cell = Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _bgFor(r, c, selected),
                border: Border(
                  top: (r % 3 == 0) ? thick : thin,
                  left: (c % 3 == 0) ? thick : thin,
                  right: (c == 8) ? thick : thin,
                  bottom: (r == 8) ? thick : thin,
                ),
              ),
              child: AnimatedScale(
                scale: selected ? 1.02 : 1.0,
                duration: const Duration(milliseconds: 120),
                child: Text(
                  v == 0 ? '' : '$v',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: fixed ? FontWeight.w700 : FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
            );

            final needsShake = (_shakingId == i);
            return GestureDetector(
              onTap: () => _selectCell(r, c),
              child: needsShake
                  ? AnimatedBuilder(
                animation: _shakeCtrl,
                builder: (_, __) => Transform.translate(
                  offset: _shakeOffset(),
                  child: cell,
                ),
              )
                  : cell,
            );
          },
        ),
      );
    }

    Widget dialPad() {
      Widget key(int n) => Padding(
        padding: const EdgeInsets.all(6),
        child: ElevatedButton(
          onPressed: widget.locked ? null : () => _applyNumber(n),
          style: ElevatedButton.styleFrom(minimumSize: const Size(64, 56)),
          child: Text('$n',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ),
      );

      return Column(
        children: [
          for (final row in const [
            [1, 2, 3],
            [4, 5, 6],
            [7, 8, 9],
          ])
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [for (final n in row) key(n)],
            ),
          Padding(
            padding: const EdgeInsets.all(6),
            child: OutlinedButton(
              onPressed: widget.locked ? null : () => _applyNumber(0),
              style: OutlinedButton.styleFrom(minimumSize: const Size(220, 56)),
              child: const Text('Clear',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildGrid(),
        const SizedBox(height: 12),
        if (widget.showPad) dialPad(),
      ],
    );
  }
}
