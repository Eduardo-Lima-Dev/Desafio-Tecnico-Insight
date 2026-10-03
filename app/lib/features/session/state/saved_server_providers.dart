import 'package:app/features/session/data/saved_server_repository.dart';
import 'package:app/features/session/data/shared_prefs_saved_server_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'saved_server_providers.g.dart';

@Riverpod(keepAlive: true)
SavedServerRepository savedServerRepository(Ref ref) =>
    SharedPrefsSavedServerRepository();

@Riverpod(keepAlive: true)
class SavedServerController extends _$SavedServerController {
  @override
  Future<String?> build() async {
    try {
      return await ref.read(savedServerRepositoryProvider).read();
    } on Object {
      return null;
    }
  }

  Future<void> save(String url) async {
    await ref.read(savedServerRepositoryProvider).save(url);
    state = AsyncData(url);
  }

  Future<void> clear() async {
    await ref.read(savedServerRepositoryProvider).clear();
    state = const AsyncData(null);
  }
}
