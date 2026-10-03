import 'package:app/features/chat/domain/chat_message.dart';
import 'package:app/features/chat/ui/message_bubble.dart';
import 'package:flutter/material.dart';

class MessageList extends StatelessWidget {
  const MessageList({required this.messages, super.key});

  final List<ChatMessage> messages;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const Center(child: Text('Nenhuma mensagem ainda.'));
    }

    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[messages.length - 1 - index];
        return MessageBubble(key: ValueKey(message.id), message: message);
      },
    );
  }
}
