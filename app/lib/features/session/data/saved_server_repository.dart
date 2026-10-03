abstract interface class SavedServerRepository {
  Future<String?> read();

  Future<void> save(String url);

  Future<void> clear();
}
