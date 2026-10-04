import 'package:app/features/conversations/domain/conversation_failure.dart';
import 'package:app/features/conversations/domain/user_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const server = 'localhost';

  group('normalizeUserId', () {
    test('mantém um identificador completo', () {
      expect(
        normalizeUserId('@bob:matrix.org', serverName: server),
        '@bob:matrix.org',
      );
    });

    test('completa só o nome com o servidor do usuário', () {
      expect(normalizeUserId('bob', serverName: server), '@bob:localhost');
    });

    test('completa o arroba quando falta', () {
      expect(
        normalizeUserId('bob:matrix.org', serverName: server),
        '@bob:matrix.org',
      );
    });

    test('completa o servidor quando só há o arroba e o nome', () {
      expect(normalizeUserId('@bob', serverName: server), '@bob:localhost');
    });

    test('ignora espaços nas pontas e maiúsculas no nome', () {
      expect(
        normalizeUserId('  @Bob:localhost  ', serverName: server),
        '@bob:localhost',
      );
    });

    test('preserva a porta do servidor', () {
      expect(
        normalizeUserId('@bob:localhost:8008', serverName: server),
        '@bob:localhost:8008',
      );
    });

    test('rejeita entradas inválidas', () {
      for (final input in [
        '',
        '   ',
        '@',
        '@:localhost',
        'bo b',
        '@bob:',
        'a@b:c',
      ]) {
        expect(
          () => normalizeUserId(input, serverName: server),
          throwsA(ConversationFailure.invalidUser),
          reason: input,
        );
      }
    });
  });
}
