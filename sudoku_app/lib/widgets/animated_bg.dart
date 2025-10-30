import 'dart:math';
import 'package:flutter/material.dart';

class AnimatedBg extends StatefulWidget {
  final Widget child;
  const AnimatedBg({super.key, required this.child});

  @override
  State<AnimatedBg> createState() => _AnimatedBgState();
}

class _AnimatedBgState extends State<AnimatedBg>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 10))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        final a = sin(2 * pi * t);
        final b = cos(2 * pi * t);

        // two moving gradient centers
        final g = RadialGradient(
          center: Alignment(0.6 * a, 0.6 * b),
          radius: 1.2,
          colors: [
            cs.primary.withOpacity(0.20),
            cs.secondary.withOpacity(0.20),
            cs.surface,
          ],
          stops: const [0.0, 0.5, 1.0],
        );

        return Container(
          decoration: BoxDecoration(gradient: g),
          child: widget.child,
        );
      },
    );
  }
}
