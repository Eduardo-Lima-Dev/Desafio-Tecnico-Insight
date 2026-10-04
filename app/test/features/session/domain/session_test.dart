import 'package:app/features/session/domain/session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Session.username', () {
    test('extrai o nome antes do servidor', () {
      const session = Session(
        userId: '@alice:localhost',
        homeserverUrl: 'http://x',
      );

      expect(session.username, 'alice');
    });

    test('aceita identificador sem servidor', () {
      const session = Session(userId: '@bob', homeserverUrl: 'http://x');

      expect(session.username, 'bob');
    });

    test('aceita identificador sem arroba', () {
      const session = Session(userId: 'carol:matrix.org', homeserverUrl: 'x');

      expect(session.username, 'carol');
    });
  });
}
