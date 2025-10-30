import 'dart:async';
import 'package:flutter/material.dart';
import '../models/sudoku.dart';
import '../widgets/sudoku_grid.dart';
import '../widgets/animated_bg.dart';
import '../widgets/board_entrance.dart';

class SinglePlayerScreen extends StatefulWidget {
  final String playerName;

  const SinglePlayerScreen({
    super.key,
    required this.playerName,
  });

  @override
  State<SinglePlayerScreen> createState() => _SinglePlayerScreenState();
}

class _SinglePlayerScreenState extends State<SinglePlayerScreen> {
  late SudokuBoard board;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _startNewGame();
  }

  void _startNewGame() {
    board = SudokuBoard();          // fresh random puzzle
    _finished = false;
    _elapsed = Duration.zero;

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_finished) {
        setState(() => _elapsed += const Duration(seconds: 1));
      }
    });
    setState(() {});
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  String _fmt(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Future<void> _onBoardChanged() async {
    if (_finished) return;

    final solved = board.isComplete && !board.hasAnyConflict;
    if (!solved) return;

    setState(() => _finished = true); // lock board
    _stopTimer();

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        title: const Text('Completed!'),
        content: Text(
          'Great job, ${widget.playerName}!\nTime: ${_fmt(_elapsed)}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startNewGame();
            },
            child: const Text('Restart'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  bool _shouldConfirmLeave() {
    // If already finished, no dialog.
    if (_finished) return false;

    // If timer > 0 or any cell filled, treat as in-progress.
    final hasTime = _elapsed.inSeconds > 0;
    final hasAnyMove = board.grid.any((row) => row.any((v) => v != 0));

    return hasTime || hasAnyMove;
  }


  Future<bool> _confirmLeave(BuildContext context) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        title: const Text('Leave game?'),
        content: const Text('Your current progress will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Leave')),
        ],
      ),
    );
    return res ?? false;
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBg(
      child: PopScope(
        canPop: false,
        onPopInvoked: (didPop) async {
          if (didPop) return;
          if (!_shouldConfirmLeave()) {
            if (mounted) Navigator.pop(context);
            return;
          }
          final leave = await _confirmLeave(context);
          if (leave && mounted) Navigator.pop(context);
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () async {
                if (!_shouldConfirmLeave()) {
                  if (mounted) Navigator.pop(context);
                  return;
                }
                final leave = await _confirmLeave(context);
                if (leave && mounted) Navigator.pop(context);
              },
            ),
            title: const Text('Single-Player Sudoku'),
            actions: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(
                    _fmt(_elapsed),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Player: ${widget.playerName}', style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 8),
                  BoardEntrance(
                    key: ValueKey(board),
                    child: SudokuGrid(
                      board: board,
                      locked: _finished,
                      showPad: true,
                      onChanged: _onBoardChanged,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _startNewGame,
                    icon: const Icon(Icons.refresh),
                    label: const Text('New Puzzle'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
