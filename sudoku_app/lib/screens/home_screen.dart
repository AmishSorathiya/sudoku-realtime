// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/theme_controller.dart';
import 'single_player_screen.dart';
import 'multiplayer_find_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _nameCtrl = TextEditingController();
  String? _nameError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  // Only letters and spaces, length 2..15
  String? _validateName(String raw) {
    final name = raw.trim();
    if (name.isEmpty) return 'Please enter your name';
    final ok = RegExp(r'^[A-Za-z ]+$').hasMatch(name);
    if (!ok) return 'Letters and spaces only (no numbers/symbols)';
    if (name.length < 2) return 'Name must be at least 2 characters';
    if (name.length > 15) return 'Name can be at most 15 characters';

    return null;
  }

  void _runIfValid(void Function(String name) onValid) {
    final err = _validateName(_nameCtrl.text);
    setState(() => _nameError = err);
    if (err != null) return;
    onValid(_nameCtrl.text.trim());
  }

  void _goSingle() {
    _runIfValid((name) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => SinglePlayerScreen(playerName: name)));
    });
  }

  void _goMulti() {
    _runIfValid((name) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => MultiplayerFindScreen(playerName: name)));
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sudoku'),
        actions: [
          IconButton(
            tooltip: 'Toggle theme',
            icon: ValueListenableBuilder(
              valueListenable: ThemeController.mode,
              builder: (_, ThemeMode mode, __) {
                final isLight = mode == ThemeMode.light;
                return Icon(isLight ? Icons.dark_mode_rounded : Icons.light_mode_rounded);
              },
            ),
            onPressed: ThemeController.toggle,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HeroTile(),
              const SizedBox(height: 18),

              Card(
                elevation: 0,
                color: cs.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: cs.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Your player name',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameCtrl,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          hintText: 'e.g., Alex',
                          prefixIcon: const Icon(Icons.person),
                          errorText: _nameError,
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _goSingle(),
                        onChanged: (v) {
                          if (_nameError != null) {
                            final err = _validateName(v);
                            setState(() => _nameError = err);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '2–15 letters, spaces allowed',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _goSingle,
                  icon: const Icon(Icons.sports_esports_rounded),
                  label: const Text('Single Player', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _goMulti,
                  icon: const Icon(Icons.wifi_tethering),
                  label: const Text('Multiplayer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// same hero tile as before
class _HeroTile extends StatefulWidget {
  @override
  State<_HeroTile> createState() => _HeroTileState();
}
class _HeroTileState extends State<_HeroTile> with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
    vsync: this, duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  @override
  void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _ac,
      builder: (_, __) {
        final glow = 0.06 + 0.06 * _ac.value;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [cs.primary.withOpacity(0.10 + glow), cs.secondary.withOpacity(0.08)],
            ),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            children: [
              _MiniGrid(color: cs.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sudoku Arena', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('Play solo or challenge a friend in real-time.',
                        style: GoogleFonts.poppins(fontSize: 13, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
class _MiniGrid extends StatelessWidget {
  final Color color;
  const _MiniGrid({required this.color});
  @override
  Widget build(BuildContext context) {
    final border = BorderSide(color: color.withOpacity(0.6), width: 1.2);
    final thin = BorderSide(color: color.withOpacity(0.35), width: 0.8);
    Widget cell(bool boldR, bool boldC) => Container(
      decoration: BoxDecoration(
        border: Border(top: boldR ? border : thin, left: boldC ? border : thin, right: thin, bottom: thin),
        color: color.withOpacity(0.06),
      ), width: 18, height: 18,
    );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.35)),
        borderRadius: BorderRadius.circular(8),
        color: color.withOpacity(0.04),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [cell(true, true), cell(true, false), cell(true, false)]),
          Row(children: [cell(false, true), cell(false, false), cell(false, false)]),
          Row(children: [cell(false, true), cell(false, false), cell(false, false)]),
        ],
      ),
    );
  }
}
