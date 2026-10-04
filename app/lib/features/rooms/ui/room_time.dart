String formatRoomTime(DateTime time, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final sameDay =
      time.year == current.year &&
      time.month == current.month &&
      time.day == current.day;
  String two(int value) => value.toString().padLeft(2, '0');
  if (sameDay) return '${two(time.hour)}:${two(time.minute)}';
  return '${two(time.day)}/${two(time.month)}';
}
