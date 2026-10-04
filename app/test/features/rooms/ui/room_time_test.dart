import 'package:app/features/rooms/ui/room_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 4, 15, 30);

  test('hoje mostra a hora', () {
    expect(formatRoomTime(DateTime(2026, 10, 4, 9, 5), now: now), '09:05');
  });

  test('ontem mostra "Ontem", mesmo perto da meia-noite', () {
    expect(formatRoomTime(DateTime(2026, 10, 3, 23, 59), now: now), 'Ontem');
  });

  test('nos últimos dias mostra o dia da semana', () {
    expect(formatRoomTime(DateTime(2026, 10, 1, 8), now: now), 'qui');
    expect(formatRoomTime(DateTime(2026, 9, 28, 8), now: now), 'seg');
  });

  test('há uma semana ou mais mostra dia e mês', () {
    expect(formatRoomTime(DateTime(2026, 9, 27, 8), now: now), '27/09');
    expect(formatRoomTime(DateTime(2020, 1, 2), now: now), '02/01');
  });

  test('formatClockTime sempre mostra a hora', () {
    expect(formatClockTime(DateTime(2020, 1, 2, 9, 5)), '09:05');
  });
}
