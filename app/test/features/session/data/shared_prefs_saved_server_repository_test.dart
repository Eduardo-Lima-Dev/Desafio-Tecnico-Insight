import 'package:app/features/session/data/shared_prefs_saved_server_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  late SharedPrefsSavedServerRepository repository;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    repository = SharedPrefsSavedServerRepository(SharedPreferencesAsync());
  });

  test('retorna nulo quando nada foi salvo', () async {
    expect(await repository.read(), isNull);
  });

  test('salva e lê o servidor', () async {
    await repository.save('https://matrix.org');

    expect(await repository.read(), 'https://matrix.org');
  });

  test('limpa o servidor salvo', () async {
    await repository.save('https://matrix.org');
    await repository.clear();

    expect(await repository.read(), isNull);
  });
}
