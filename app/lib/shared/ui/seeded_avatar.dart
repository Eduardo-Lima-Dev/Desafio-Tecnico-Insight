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

class RoomAvatar extends StatelessWidget {
  const RoomAvatar({
    required this.roomId,
    required this.initial,
    this.radius = 24,
    super.key,
  });

  final String roomId;
  final String initial;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final seed = roomId.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    return CircleAvatar(
      radius: radius,
      backgroundColor: _palette[seed % _palette.length],
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
