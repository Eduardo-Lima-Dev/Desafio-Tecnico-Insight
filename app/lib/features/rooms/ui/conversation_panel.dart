import 'dart:async';

import 'package:app/features/chat/state/chat_providers.dart';
import 'package:app/features/chat/ui/message_composer.dart';
import 'package:app/features/chat/ui/message_list.dart';
import 'package:app/features/encryption/domain/recovery_status.dart';
import 'package:app/features/encryption/state/encryption_providers.dart';
import 'package:app/features/encryption/ui/recovery_banner.dart';
import 'package:app/features/rooms/state/rooms_providers.dart';
import 'package:app/features/rooms/ui/conversation_header.dart';
import 'package:app/features/session/domain/session_failure.dart';
import 'package:app/features/session/ui/failure_message.dart';
import 'package:app/shared/ui/empty_state.dart';
import 'package:app/shared/ui/error_state.dart';
import 'package:app/shared/ui/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConversationPanel extends ConsumerWidget {
  const ConversationPanel({this.roomId, this.onBack, super.key});

  final String? roomId;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = roomId;
    final room = id == null ? null : ref.watch(roomByIdProvider(id));

    if (room == null) {
      return const EmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'Selecione uma sala',
        hint: 'Escolha uma conversa ou crie uma nova.',
      );
    }

    final messages = ref.watch(chatMessagesProvider(room.id));
    final needsRecovery =
        ref.watch(recoveryStatusProvider).value == RecoveryStatus.incomplete &&
        (messages.value?.any((message) => message.kind.isUndecryptable) ??
            false);

    return Column(
      children: [
        ConversationHeader(room: room, onBack: onBack),
        const Divider(height: 1),
        if (needsRecovery) const RecoveryBanner(),
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
