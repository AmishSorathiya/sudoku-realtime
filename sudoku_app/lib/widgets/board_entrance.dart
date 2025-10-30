import 'package:flutter/material.dart';

class BoardEntrance extends StatefulWidget {
  final Widget child;

  const BoardEntrance({super.key, required this.child});

  @override
  State<BoardEntrance> createState() => _BoardEntranceState();
}

class _BoardEntranceState extends State<BoardEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scale = Tween(begin: 0.98, end: 1.0).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic),
    );
    _opacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeOut),
    );
    _c.forward();
  }

  @override
  void didUpdateWidget(covariant BoardEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-trigger the entrance when our widget's key changes (e.g., new puzzle)
    if (widget.key != oldWidget.key) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.scale(
            scale: _scale.value,
            child: widget.child,
          ),
        );
      },
    );
  }
}
