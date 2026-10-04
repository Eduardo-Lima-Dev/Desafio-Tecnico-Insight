const _weekdays = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];

String _two(int value) => value.toString().padLeft(2, '0');

DateTime _dayOf(DateTime time) => DateTime(time.year, time.month, time.day);

String formatClockTime(DateTime time) =>
    '${_two(time.hour)}:${_two(time.minute)}';

String formatRoomTime(DateTime time, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final days = _dayOf(current).difference(_dayOf(time)).inDays;

  if (days == 0) return formatClockTime(time);
  if (days == 1) return 'Ontem';
  if (days > 1 && days < 7) return _weekdays[time.weekday - 1];
  return '${_two(time.day)}/${_two(time.month)}';
}
