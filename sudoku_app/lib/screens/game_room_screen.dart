import 'dart:async';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../models/sudoku.dart';
import '../widgets/sudoku_grid.dart';

class GameRoomScreen extends StatefulWidget {
  final String playerName;
  final String opponentName;
  final String roomId;
  final IO.Socket socket;

  const GameRoomScreen({
    super.key,
    required this.playerName,
    required this.opponentName,
    required this.roomId,
    required this.socket,
  });

  @override
  State<GameRoomScreen> createState() => _GameRoomScreenState();
}

class _GameRoomScreenState extends State<GameRoomScreen> {
  SudokuBoard? board;
  bool _started = false;
  bool _finished = false;

  // main timer
  Duration _elapsed = Duration.zero;
  Timer? _timer;

  // selection for local input
  int? _selR, _selC;

  // opponent leave handling
  bool _oppGone = false;
  int _graceLeft = 0;
  Timer? _graceTimer;

  bool _cleanedUp = false; // prevent double-dispose

  @override
  void initState() {
    super.initState();
    _wireSocket();
    // tell server we’re ready; when both ready, server emits 'game:start'
    widget.socket.emit('game:ready', {'roomId': widget.roomId});
  }

  @override
  void dispose() {
    _cancelTimersOnly();
    super.dispose();
  }

  void _cancelTimersOnly() {
    _timer?.cancel();
    _graceTimer?.cancel();
    _timer = null;
    _graceTimer = null;
  }

  /// Immediate full cleanup (socket + timers); safe to call multiple times.
  void _hardCleanupAndExitToHome() {
    if (_cleanedUp) return;
    _cleanedUp = true;

    _cancelTimersOnly();
    // tell server we’re done with matchmaking/game room
    try {
      widget.socket.emit('match:cancel');
    } catch (_) {}
    // tear down transport so a new Multiplayer can fresh-connect next time
    try {
      widget.socket.disconnect();
    } catch (_) {}
    try {
      widget.socket.dispose();
    } catch (_) {}

    if (mounted) {
      Navigator.popUntil(context, (r) => r.isFirst);
    }
  }

  bool get _shouldConfirmLeave => !_finished && _started;

  void _wireSocket() {
    final s = widget.socket;

    // Remove old listeners in case of resume
    s.off('game:start');
    s.off('game:win');
    s.off('game:finish_rejected');
    s.off('opponent:disconnected');
    s.off('opponent:reconnected');
    s.off('game:rematch_status');
    s.off('game:rematch_denied');

    s.on('game:start', (data) {
      final puzzle = (data?['puzzle'] as List)
          .map<List<int>>((row) => (row as List).map<int>((e) => e as int).toList())
          .toList();

      board = SudokuBoard.fromGrid(puzzle);

      _started = false;
      _finished = false;
      _oppGone = false;
      _graceLeft = 0;
      _graceTimer?.cancel();

      final startAtMs = (data?['startAt'] ?? DateTime.now().millisecondsSinceEpoch) as int;
      final delay = Duration(milliseconds: startAtMs - DateTime.now().millisecondsSinceEpoch);

      Future.delayed(delay > Duration.zero ? delay : Duration.zero, () {
        if (!mounted) return;
        setState(() {
          _started = true;
          _elapsed = Duration.zero;
        });
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!_finished) {
            setState(() => _elapsed += const Duration(seconds: 1));
          }
        });
      });

      setState(() {});
    });

    s.on('game:finish_rejected', (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not solved yet.')),
      );
    });

    s.on('game:win', (data) {
      if (!mounted) return;
      _timer?.cancel();
      _finished = true;
      final winnerId = data?['winnerSocketId'] as String?;
      final iAmWinner = (winnerId == s.id);

      _showResultDialog(
        title: iAmWinner ? 'You win!' : '${widget.opponentName} wins',
        content: 'Time: ${_fmt(_elapsed)}',
        showRematch: true,
      );
      setState(() {});
    });

    s.on('game:rematch_status', (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Waiting for opponent…')),
      );
    });

    s.on('game:rematch_denied', (data) {
      if (!mounted) return;
      final reason = data?['reason'] ?? 'denied';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rematch unavailable ($reason).')),
      );
    });

    // Opponent disconnect flow
    s.on('opponent:disconnected', (data) {
      final ms = (data?['graceMs'] ?? 8000) as int;
      _graceTimer?.cancel();
      setState(() {
        _oppGone = true;
        _graceLeft = (ms / 1000).ceil();
      });
      _graceTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) { t.cancel(); return; }
        if (_graceLeft <= 0) { t.cancel(); return; }
        setState(() => _graceLeft--);
      });
    });

    s.on('opponent:reconnected', (_) {
      _graceTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _oppGone = false;
        _graceLeft = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opponent reconnected')),
      );
    });
  }

  // ---------- helpers ----------
  String _fmt(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Future<bool> _confirmLeave(BuildContext context) async {
    // Safety: if game is already finished, don’t confirm — just leave
    if (!_shouldConfirmLeave) return true;

    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Leave game?'),
        content: const Text('Your opponent will win if you leave now.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Stay')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Leave')),
        ],
      ),
    ) ??
        false;
  }

  void _showResultDialog({
    required String title,
    required String content,
    required bool showRematch,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        title: Text(title),
        content: Text(content),
        actions: [
          if (showRematch)
            TextButton(
              onPressed: _oppGone
                  ? null
                  : () {
                widget.socket.emit('game:rematch_request', {'roomId': widget.roomId});
                Navigator.pop(context);
              },
              child: const Text('Rematch'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: _hardCleanupAndExitToHome, // EXIT: disconnect+dispose socket
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  void _emitFinishIfSolved() {
    if (_finished || board == null) return;
    if (board!.isComplete) {
      widget.socket.emit('game:finish', {
        'roomId': widget.roomId,
        'grid': board!.grid,
      });
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final b = board;

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        // If game already finished, no confirmation; just exit and cleanup
        final ok = await _confirmLeave(context);
        if (ok && mounted) _hardCleanupAndExitToHome();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Multiplayer Sudoku'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final ok = await _confirmLeave(context);
              if (ok && mounted) _hardCleanupAndExitToHome();
            },
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
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
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${widget.playerName}  vs  ${widget.opponentName}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),

                if (_oppGone)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: cs.tertiaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Opponent left — awarding win in $_graceLeft s…',
                      style: TextStyle(
                        color: cs.onTertiaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                if (b == null) ...[
                  const SizedBox(height: 40),
                  const CircularProgressIndicator(),
                  const SizedBox(height: 8),
                  const Text('Waiting for game to start…'),
                ] else ...[
                  SudokuGrid(
                    board: b,
                    locked: !_started || _finished,
                    showPad: false,
                    onCellSelected: (r, c) => setState(() { _selR = r; _selC = c; }),
                    onChanged: _emitFinishIfSolved,
                  ),
                  const SizedBox(height: 10),

                  _DialPad(
                    locked: !_started || _finished,
                    onNumber: (n) {
                      if (_selR == null || _selC == null) return;
                      if (b.isFixedCell(_selR!, _selC!)) return;
                      setState(() {
                        b.setCell(_selR!, _selC!, n);
                      });
                      _emitFinishIfSolved();
                    },
                    onClear: () {
                      if (_selR == null || _selC == null) return;
                      if (b.isFixedCell(_selR!, _selC!)) return;
                      setState(() => b.setCell(_selR!, _selC!, 0));
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// simple round dial pad (3x3 + clear)
class _DialPad extends StatelessWidget {
  final bool locked;
  final void Function(int n) onNumber;
  final VoidCallback onClear;

  const _DialPad({
    required this.locked,
    required this.onNumber,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    Widget key(int n) => Padding(
      padding: const EdgeInsets.all(6),
      child: ElevatedButton(
        onPressed: locked ? null : () => onNumber(n),
        style: ElevatedButton.styleFrom(minimumSize: const Size(64, 56)),
        child: Text('$n', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
            onPressed: locked ? null : onClear,
            style: OutlinedButton.styleFrom(minimumSize: const Size(220, 56)),
            child: const Text('Clear', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}
