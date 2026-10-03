import 'package:app/features/session/domain/session_failure.dart';

const _loopbackHosts = {'localhost', '127.0.0.1', '::1', '[::1]'};

String normalizeHomeserverUrl(String input) {
  final raw = input.trim();
  if (raw.isEmpty) throw SessionFailure.invalidHomeserver;

  final withScheme = raw.contains('://') ? raw : _addDefaultScheme(raw);
  final uri = Uri.tryParse(withScheme);

  if (uri == null || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
    throw SessionFailure.invalidHomeserver;
  }

  final isLoopback = _loopbackHosts.contains(uri.host);
  switch (uri.scheme) {
    case 'https':
      break;
    case 'http':
      if (!isLoopback) throw SessionFailure.insecureHomeserver;
    default:
      throw SessionFailure.invalidHomeserver;
  }

  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
  ).toString();
}

String _addDefaultScheme(String raw) {
  final host = raw.startsWith('[')
      ? raw.substring(0, raw.indexOf(']') + 1)
      : raw.split(RegExp('[:/]')).first;
  final scheme = _loopbackHosts.contains(host) ? 'http' : 'https';
  return '$scheme://$raw';
}
