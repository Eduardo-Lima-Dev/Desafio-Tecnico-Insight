const _months = [
  'jan',
  'fev',
  'mar',
  'abr',
  'mai',
  'jun',
  'jul',
  'ago',
  'set',
  'out',
  'nov',
  'dez',
];

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String formatDayLabel(DateTime day, {DateTime? now}) {
  final current = now ?? DateTime.now();
  if (isSameDay(day, current)) return 'Hoje';
  if (isSameDay(day, current.subtract(const Duration(days: 1)))) {
    return 'Ontem';
  }
  final label = '${day.day} de ${_months[day.month - 1]}';
  return day.year == current.year ? label : '$label de ${day.year}';
}
