enum SessionFailure implements Exception {
  invalidHomeserver,
  insecureHomeserver,
  invalidCredentials,
  network,
  rateLimited,
  sessionExpired,
  storage,
  unknown,
}
