import 'package:app/features/chat/ui/day_label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 4, 15);

  test('o dia atual vira "Hoje"', () {
    expect(formatDayLabel(DateTime(2026, 10, 4, 1), now: now), 'Hoje');
  });

  test('o dia anterior vira "Ontem"', () {
    expect(formatDayLabel(DateTime(2026, 10, 3, 23), now: now), 'Ontem');
  });

  test('outros dias do ano mostram dia e mês abreviado', () {
    expect(formatDayLabel(DateTime(2026, 9, 12), now: now), '12 de set');
  });

  test('anos anteriores incluem o ano', () {
    expect(formatDayLabel(DateTime(2025, 1, 5), now: now), '5 de jan de 2025');
  });
}
