import 'package:app/shared/ui/seeded_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Color _textColor(WidgetTester tester) =>
    tester.widget<Text>(find.byType(Text)).style!.color!;

void main() {
  testWidgets('a cor do texto contrasta com o fundo', (tester) async {
    for (final seed in ['a', 'b', 'c', 'd', 'e', 'f', 'g']) {
      await tester.pumpWidget(
        MaterialApp(
          home: SeededAvatar(seed: seed, initial: 'A'),
        ),
      );
      final background = tester
          .widget<CircleAvatar>(find.byType(CircleAvatar))
          .backgroundColor!;
      final text = _textColor(tester);

      final lighter = background.computeLuminance() > text.computeLuminance()
          ? background
          : text;
      final darker = lighter == background ? text : background;
      final ratio =
          (lighter.computeLuminance() + 0.05) /
          (darker.computeLuminance() + 0.05);
      expect(ratio, greaterThan(2.5), reason: 'semente $seed');
    }
  });
}
