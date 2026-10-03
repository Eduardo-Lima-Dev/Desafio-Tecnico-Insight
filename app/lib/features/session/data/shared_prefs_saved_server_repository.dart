import 'package:app/features/session/data/saved_server_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'saved_homeserver_url';

class SharedPrefsSavedServerRepository implements SavedServerRepository {
  SharedPrefsSavedServerRepository([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> read() => _preferences.getString(_key);

  @override
  Future<void> save(String url) => _preferences.setString(_key, url);

  @override
  Future<void> clear() => _preferences.remove(_key);
}
