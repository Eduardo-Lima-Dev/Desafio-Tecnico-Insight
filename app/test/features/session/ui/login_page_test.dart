import 'package:app/features/session/data/saved_server_repository.dart';
import 'package:app/features/session/data/session_repository.dart';
import 'package:app/features/session/domain/session.dart';
import 'package:app/features/session/state/saved_server_providers.dart';
import 'package:app/features/session/state/session_providers.dart';
import 'package:app/features/session/ui/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSessionRepository implements SessionRepository {
  @override
  Future<Session?> restore() async => null;

  @override
  Future<Session> login({
    required String homeserver,
    required String username,
    required String password,
  }) async => const Session(userId: '@alice:localhost', homeserverUrl: 'x');

  @override
  Future<void> logout() async {}
}

class _FakeSavedServerRepository implements SavedServerRepository {
  _FakeSavedServerRepository([this.value]);

  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> save(String url) async => value = url;

  @override
  Future<void> clear() async => value = null;
}

Future<void> _pump(
  WidgetTester tester,
  _FakeSavedServerRepository saved,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionRepositoryProvider.overrideWithValue(_FakeSessionRepository()),
        savedServerRepositoryProvider.overrideWithValue(saved),
      ],
      child: const MaterialApp(home: LoginPage()),
    ),
  );
  await tester.pumpAndSettle();
}

String _serverText(WidgetTester tester) => tester
    .widget<TextFormField>(find.widgetWithText(TextFormField, 'Servidor'))
    .controller!
    .text;

void main() {
  testWidgets('sem servidor salvo, o campo começa vazio e desmarcado', (
    tester,
  ) async {
    await _pump(tester, _FakeSavedServerRepository());

    expect(_serverText(tester), isEmpty);
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isFalse,
    );
  });

  testWidgets('com servidor salvo, o campo vem preenchido e marcado', (
    tester,
  ) async {
    await _pump(tester, _FakeSavedServerRepository('https://matrix.org'));

    expect(_serverText(tester), 'https://matrix.org');
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isTrue,
    );
  });

  testWidgets('entrar com a opção marcada salva o servidor digitado', (
    tester,
  ) async {
    final saved = _FakeSavedServerRepository();
    await _pump(tester, saved);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Usuário'),
      'alice',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Senha'),
      'senha123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Servidor'),
      'localhost:8008',
    );
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle();

    expect(saved.value, 'http://localhost:8008');
  });
}
