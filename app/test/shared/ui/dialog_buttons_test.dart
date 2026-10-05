import 'package:app/shared/ui/dialog_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, {bool loading = false}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
      ),
      home: Scaffold(
        body: AlertDialog(
          title: const Text('Título'),
          actions: [
            DialogCancelButton(label: 'Cancelar', onPressed: () {}),
            DialogConfirmButton(
              label: 'Confirmar',
              loading: loading,
              onPressed: () {},
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('cancelar e confirmar ficam lado a lado, com formas diferentes', (
    tester,
  ) async {
    await _pump(tester);

    final cancel = tester.getCenter(find.text('Cancelar'));
    final confirm = tester.getCenter(find.text('Confirmar'));

    expect(cancel.dy, confirm.dy);
    expect(cancel.dx, lessThan(confirm.dx));
    expect(find.byType(OutlinedButton), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets('em carregamento mostra o indicador no lugar do texto', (
    tester,
  ) async {
    await _pump(tester, loading: true);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Confirmar'), findsNothing);
  });
}
