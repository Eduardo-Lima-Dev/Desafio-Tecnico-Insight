import 'package:app/features/rooms/domain/search_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ignora maiúsculas e acentos', () {
    expect(matchesSearch('Coordenação Geral', 'coordenacao'), isTrue);
    expect(matchesSearch('Equipe Insight', 'INSIGHT'), isTrue);
  });

  test('busca vazia combina com tudo', () {
    expect(matchesSearch('Qualquer', '   '), isTrue);
  });

  test('texto ausente não combina', () {
    expect(matchesSearch('Equipe Insight', 'fantasma'), isFalse);
  });
}
