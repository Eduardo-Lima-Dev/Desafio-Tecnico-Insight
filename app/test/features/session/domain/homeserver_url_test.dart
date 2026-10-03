import 'package:app/features/session/domain/homeserver_url.dart';
import 'package:app/features/session/domain/session_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeHomeserverUrl', () {
    test('mantém https e remove caminho e barra final', () {
      expect(
        normalizeHomeserverUrl('https://matrix.org/'),
        'https://matrix.org',
      );
    });

    test('assume https quando não há esquema', () {
      expect(normalizeHomeserverUrl('matrix.org'), 'https://matrix.org');
    });

    test('assume http para localhost sem esquema e preserva a porta', () {
      expect(normalizeHomeserverUrl('localhost:8008'), 'http://localhost:8008');
    });

    test('assume http para loopback IPv6 sem esquema', () {
      expect(normalizeHomeserverUrl('[::1]:8008'), 'http://[::1]:8008');
    });

    test('aceita http em loopback', () {
      expect(
        normalizeHomeserverUrl('http://127.0.0.1:8008'),
        'http://127.0.0.1:8008',
      );
    });

    test('rejeita http fora do loopback', () {
      expect(
        () => normalizeHomeserverUrl('http://matrix.org'),
        throwsA(SessionFailure.insecureHomeserver),
      );
    });

    test('rejeita entrada vazia, esquema estranho e credenciais na URL', () {
      for (final input in [
        '',
        '   ',
        'ftp://matrix.org',
        'https://a:b@x.org',
      ]) {
        expect(
          () => normalizeHomeserverUrl(input),
          throwsA(SessionFailure.invalidHomeserver),
          reason: input,
        );
      }
    });
  });
}
