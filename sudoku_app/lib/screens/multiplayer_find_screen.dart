import 'dart:async';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../net/server_config.dart';
import 'game_room_screen.dart';

/// Simple, clean matchmaking screen:
/// - Auto connects to server in background (tries a few candidates)
/// - Shows only friendly status text + spinner
/// - On match found -> navigates to GameRoomScreen
/// - Cancel button to back out
class MultiplayerFindScreen extends StatefulWidget {
  final String playerName;



  const MultiplayerFindScreen({super.key, required this.playerName});

  @override
  State<MultiplayerFindScreen> createState() => _MultiplayerFindScreenState();
}

class _MultiplayerFindScreenState extends State<MultiplayerFindScreen> {
  IO.Socket? _socket;
  bool _finding = false;
  String _status = 'Connecting…';
  Timer? _connectTimeout;
  bool _navigated = false;

  bool _handedOff = false; // NEW
  static const List<String> _candidates = ServerConfig.socketCandidates;

  // Keep your candidates PRIVATE. We never show them in the UI.
  // Put your LAN/WAN server URL(s) here. Example:
  // - Local dev (same Wi-Fi): 'http://192.168.1.23:3000'
  // - Emulator shortcut: 'http://10.0.2.2:3000' (Android emulator only)
  // - Genymotion: 'http://10.0.3.2:3000'
  // - Public (when deployed): 'https://your-domain.com'
  // static const List<String> _candidates = [
  //   'http://10.0.2.2:3000',     // Android emulator
  //   'http://10.0.3.2:3000',  // Genymotion (uncomment if you use it)
  //   'http://192.168.73.100:3000', // Your LAN IP (edit to your PC IP if testing on phones)
  //   'https://your-prod-domain.com', // Production
  // ];

  @override
  void initState() {
    super.initState();
    _begin();
  }

  @override
  void dispose() {
    _connectTimeout?.cancel();
    if (!_handedOff) {
      _socket?.dispose(); // keep socket alive if handed off
    }
    super.dispose();
  }


  // ---------- Flow ----------
  Future<void> _begin() async {
    setState(() => _status = 'Connecting…');

    final sock = await _connectToAny();
    if (!mounted) return;

    if (sock == null) {
      setState(() => _status = 'Unable to connect. Check internet or server.');
      return;
    }

    _socket = sock;

    // Identify to server (quietly)
    _socket!.emit('client:hello', {'name': widget.playerName});

    // Listen for matchmaking results
    _socket!
      ..on('match:status', (data) {
        final finding = data?['finding'] == true;
        if (mounted) {
          setState(() {
            _finding = finding;
            _status = finding ? 'Finding opponent…' : 'Idle';
          });
        }
      })
      ..on('match:found', (data) {
        if (_navigated) return;
        _navigated = true;

        final roomId = data?['roomId'] as String? ?? 'room';
        final opp = data?['opponentName'] as String? ?? 'Opponent';

        _handedOff = true; // NEW: do not dispose socket in our dispose()

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => GameRoomScreen(
              playerName: widget.playerName,
              opponentName: opp,
              roomId: roomId,
              socket: _socket!,
            ),
          ),
        );
      })
      ..onConnectError((_) {
        if (!mounted) return;
        setState(() => _status = 'Reconnecting…');
      })
      ..onReconnectAttempt((_) {
        if (!mounted) return;
        setState(() => _status = 'Reconnecting…');
      });

    // Start finding a match (quietly)
    setState(() {
      _finding = true;
      _status = 'Finding opponent…';
    });
    _socket!.emit('match:find', {'name': widget.playerName});
  }

  /// Try each candidate URL until one connects.
  Future<IO.Socket?> _connectToAny() async {
    for (final url in _candidates) {
      final sock = IO.io(
        url,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(999)
            .setReconnectionDelay(800)
            .build(),
      );

      final c = Completer<bool>();
      late void Function(dynamic) onConnect;
      late void Function(dynamic) onError;

      onConnect = (_) {
        if (!c.isCompleted) c.complete(true);
      };
      onError = (_) {
        if (!c.isCompleted) c.complete(false);
      };

      sock.once('connect', onConnect);
      sock.once('connect_error', onError);
      sock.connect();

      // Give each candidate a short window to connect
      final ok = await c.future.timeout(const Duration(seconds: 3), onTimeout: () => false);
      if (ok) {
        // Clean listeners (Socket.IO will keep standard listeners)
        sock.off('connect', onConnect);
        sock.off('connect_error', onError);
        return sock;
      } else {
        sock.dispose();
      }
    }
    return null;
  }

  void _cancelFinding() {
    _socket?.emit('match:cancel');
    _socket?.dispose();
    Navigator.pop(context);
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Multiplayer'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _cancelFinding,
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              // Friendly, simple status
              Text(
                _status,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              // Spinner only (no dev logs)
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 22),
              // Cancel button
              OutlinedButton.icon(
                onPressed: _cancelFinding,
                icon: const Icon(Icons.close),
                label: const Text('Cancel'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.onSurface,
                  minimumSize: const Size(180, 48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
