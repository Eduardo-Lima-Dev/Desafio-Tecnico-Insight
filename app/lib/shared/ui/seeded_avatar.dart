import 'package:flutter/material.dart';

const _palette = [
  Color(0xFFE17076),
  Color(0xFFFAA774),
  Color(0xFF7BC862),
  Color(0xFF65AADD),
  Color(0xFFA695E7),
  Color(0xFFEE7AAE),
  Color(0xFF6EC9CB),
];

class SeededAvatar extends StatelessWidget {
  const SeededAvatar({
    required this.seed,
    required this.initial,
    this.radius = 24,
    super.key,
  });

  final String seed;
  final String initial;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final hash = seed.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    final background = _palette[hash % _palette.length];
    final foreground = background.computeLuminance() > 0.4
        ? const Color(0xFF1B1B1F)
        : Colors.white;

    return CircleAvatar(
      radius: radius,
      backgroundColor: background,
      child: Text(
        initial,
        style: TextStyle(
          color: foreground,
          fontSize: radius * 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
