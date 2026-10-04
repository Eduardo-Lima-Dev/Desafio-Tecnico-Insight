import 'dart:async';

import 'package:app/features/chat/domain/chat_message.dart';
import 'package:app/features/chat/domain/history_state.dart';
import 'package:app/features/chat/state/chat_providers.dart';
import 'package:app/features/chat/ui/day_label.dart';
import 'package:app/features/chat/ui/message_bubble.dart';
import 'package:app/shared/ui/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _loadThreshold = 300.0;

class MessageList extends ConsumerStatefulWidget {
  const MessageList({
    required this.roomId,
    required this.messages,
    this.onRetry,
    super.key,
  });

  final String roomId;
  final List<ChatMessage> messages;
  final ValueChanged<ChatMessage>? onRetry;

  @override
  ConsumerState<MessageList> createState() => _MessageListState();
}

class _MessageListState extends ConsumerState<MessageList> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_loadIfNearTop);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_loadIfNearTop)
      ..dispose();
    super.dispose();
  }

  void _loadIfNearTop() {
    if (!mounted || !_controller.hasClients) return;
    if (_controller.position.extentAfter >= _loadThreshold) return;
    unawaited(
      ref.read(historyLoaderProvider(widget.roomId).notifier).loadOlder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(historyLoaderProvider(widget.roomId));
    final messages = widget.messages;

    if (messages.isEmpty) {
      return const EmptyState(
        icon: Icons.forum_outlined,
        title: 'Nenhuma mensagem ainda.',
        hint: 'Envie a primeira mensagem para começar a conversa.',
      );
    }

    if (!history.reachedStart && !history.failed && !history.loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadIfNearTop());
    }

    return ListView.builder(
      controller: _controller,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: messages.length + 1,
      itemBuilder: (context, index) {
        if (index == messages.length) {
          return _HistoryHeader(
            history: history,
            onRetry: () => unawaited(
              ref
                  .read(historyLoaderProvider(widget.roomId).notifier)
                  .loadOlder(),
            ),
          );
        }
        final position = messages.length - 1 - index;
        final message = messages[position];
        final older = position > 0 ? messages[position - 1] : null;
        final newer = position < messages.length - 1
            ? messages[position + 1]
            : null;
        final startsDay =
            older == null || !isSameDay(older.sentAt, message.sentAt);
        final endsDay =
            newer == null || !isSameDay(newer.sentAt, message.sentAt);
        final onRetry = widget.onRetry;

        return Column(
          key: ValueKey(message.id),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (startsDay) _DaySeparator(day: message.sentAt),
            MessageBubble(
              message: message,
              isFirstInGroup: startsDay || older.senderId != message.senderId,
              isLastInGroup: endsDay || newer.senderId != message.senderId,
              animateIn: index == 0,
              onRetry: onRetry == null ? null : () => onRetry(message),
            ),
          ],
        );
      },
    );
  }
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              formatDayLabel(day),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({required this.history, required this.onRetry});

  final HistoryState history;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (history.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (history.failed) {
      return Center(
        child: TextButton(
          onPressed: onRetry,
          child: const Text(
            'Não foi possível carregar o histórico. Tentar de novo',
          ),
        ),
      );
    }

    if (history.reachedStart) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            'Início da conversa',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
