import 'dart:async';

import 'package:app/features/chat/domain/chat_message.dart';
import 'package:app/features/chat/domain/history_state.dart';
import 'package:app/features/chat/state/chat_providers.dart';
import 'package:app/features/chat/ui/message_bubble.dart';
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
      return const Center(child: Text('Nenhuma mensagem ainda.'));
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
        final message = messages[messages.length - 1 - index];
        final onRetry = widget.onRetry;
        return MessageBubble(
          key: ValueKey(message.id),
          message: message,
          onRetry: onRetry == null ? null : () => onRetry(message),
        );
      },
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
