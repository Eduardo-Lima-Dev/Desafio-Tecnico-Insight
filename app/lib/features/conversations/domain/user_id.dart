import 'package:app/features/conversations/domain/conversation_failure.dart';

final _localpart = RegExp(r'^[^\s@:]+$');
final _server = RegExp(r'^[^\s@/]+$');

String normalizeUserId(String input, {required String serverName}) {
  var raw = input.trim();
  if (raw.isEmpty) throw ConversationFailure.invalidUser;

  if (raw.startsWith('@')) raw = raw.substring(1);

  final separator = raw.indexOf(':');
  final localpart = separator == -1 ? raw : raw.substring(0, separator);
  final server = separator == -1 ? serverName : raw.substring(separator + 1);

  if (!_localpart.hasMatch(localpart) || !_server.hasMatch(server)) {
    throw ConversationFailure.invalidUser;
  }

  return '@${localpart.toLowerCase()}:$server';
}
