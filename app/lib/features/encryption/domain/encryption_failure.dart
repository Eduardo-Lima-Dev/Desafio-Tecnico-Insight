enum EncryptionFailure implements Exception {
  invalidKey,
  backupExists,
  network,
  sessionExpired,
  unknown,
}
