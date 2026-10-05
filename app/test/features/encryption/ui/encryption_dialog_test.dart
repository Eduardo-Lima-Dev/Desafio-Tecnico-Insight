import 'package:app/features/encryption/domain/encryption_failure.dart';
import 'package:app/features/encryption/domain/recovery_status.dart';
import 'package:app/features/encryption/state/encryption_providers.dart';
import 'package:app/features/encryption/ui/encryption_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_encryption_repository.dart';

Future<void> _open(
  WidgetTester tester,
  FakeEncryptionRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        encryptionRepositoryProvider.overrideWithValue(repository),
        recoveryStatusProvider.overrideWith(
          (ref) => ref.watch(encryptionRepositoryProvider).watchStatus(),
        ),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showEncryptionDialog(context),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('incompleto pede a chave e fecha ao recuperar', (tester) async {
    final repository = FakeEncryptionRepository(
      status: RecoveryStatus.incomplete,
    );
    await _open(tester, repository);

    expect(find.text('Recuperar mensagens'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'EsTx 9999');
    await tester.tap(find.widgetWithText(FilledButton, 'Recuperar'));
    await tester.pumpAndSettle();

    expect(repository.recovered, ['EsTx 9999']);
    expect(find.text('Recuperar mensagens'), findsNothing);
    expect(
      find.text('Chaves recuperadas. Carregando as mensagens antigas.'),
      findsOneWidget,
    );
  });

  testWidgets('chave incorreta mostra o erro e mantém o diálogo', (
    tester,
  ) async {
    final repository = FakeEncryptionRepository(
      status: RecoveryStatus.incomplete,
      recoverError: EncryptionFailure.invalidKey,
    );
    await _open(tester, repository);

    await tester.enterText(find.byType(TextField), 'errada');
    await tester.tap(find.widgetWithText(FilledButton, 'Recuperar'));
    await tester.pumpAndSettle();

    expect(
      find.text('Chave de recuperação incorreta. Confira e tente de novo.'),
      findsOneWidget,
    );
    expect(find.text('Recuperar mensagens'), findsOneWidget);
  });

  testWidgets('desativado oferece o backup e mostra a chave uma vez', (
    tester,
  ) async {
    final repository = FakeEncryptionRepository(
      status: RecoveryStatus.disabled,
      generatedKey: 'ABCD 1234',
    );
    await _open(tester, repository);

    await tester.tap(find.widgetWithText(FilledButton, 'Ativar backup'));
    await tester.pumpAndSettle();

    expect(repository.enables, 1);
    expect(find.text('Guarde a chave de recuperação'), findsOneWidget);
    expect(find.text('ABCD 1234'), findsOneWidget);
    expect(find.byTooltip('Copiar chave'), findsOneWidget);

    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();

    expect(find.text('ABCD 1234'), findsNothing);
  });

  testWidgets('falha ao ativar o backup mostra o erro', (tester) async {
    final repository = FakeEncryptionRepository(
      status: RecoveryStatus.disabled,
      enableError: EncryptionFailure.network,
    );
    await _open(tester, repository);

    await tester.tap(find.widgetWithText(FilledButton, 'Ativar backup'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Não foi possível conectar ao servidor. Verifique sua conexão.',
      ),
      findsOneWidget,
    );
    expect(find.text('Guarde a chave de recuperação'), findsNothing);
  });

  testWidgets('com o backup ativo apenas informa', (tester) async {
    await _open(tester, FakeEncryptionRepository());

    expect(find.textContaining('O backup está ativo'), findsOneWidget);
    expect(find.text('Ativar backup'), findsNothing);
    expect(find.text('Recuperar'), findsNothing);
  });
}
