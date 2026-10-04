import 'dart:async';

import 'package:app/features/chat/state/chat_providers.dart';
import 'package:app/features/chat/ui/message_composer.dart';
import 'package:app/features/chat/ui/message_list.dart';
import 'package:app/features/rooms/state/rooms_providers.dart';
import 'package:app/features/session/domain/session_failure.dart';
import 'package:app/features/session/ui/failure_message.dart';
import 'package:app/shared/ui/empty_state.dart';
import 'package:app/shared/ui/error_state.dart';
import 'package:app/shared/ui/seeded_avatar.dart';
import 'package:app/shared/ui/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConversationPanel extends ConsumerWidget {
  const ConversationPanel({this.onBack, super.key});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(selectedRoomProvider);

    if (room == null) {
      return const EmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'Selecione uma sala',
        hint: 'Escolha uma conversa ou crie uma nova.',
      );
    }

    final messages = ref.watch(chatMessagesProvider(room.id));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              if (onBack != null)
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Voltar',
                  onPressed: onBack,
                )
              else
                const SizedBox(width: 8),
              SeededAvatar(seed: room.id, initial: room.initial, radius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  room.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: messages.when(
            loading: () => const MessageListSkeleton(),
            error: (error, _) => ErrorState(
              message: error is SessionFailure
                  ? error.message
                  : SessionFailure.unknown.message,
              onRetry: () => ref.invalidate(openChatProvider(room.id)),
            ),
            data: (items) => MessageList(
              roomId: room.id,
              messages: items,
              onRetry: (message) => unawaited(
                ref
                    .read(messageSenderProvider.notifier)
                    .retry(room.id, message.id),
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        MessageComposer(key: ValueKey(room.id), roomId: room.id),
      ],
    );
  }
}
