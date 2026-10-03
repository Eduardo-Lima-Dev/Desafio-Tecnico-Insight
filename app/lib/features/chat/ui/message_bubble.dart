import 'package:app/features/chat/domain/chat_message.dart';
import 'package:app/features/rooms/ui/room_time.dart';
import 'package:flutter/material.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({required this.message, this.onRetry, super.key});

  final ChatMessage message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final own = message.isOwn;
    final background = own
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest;
    final foreground = own ? scheme.onPrimaryContainer : scheme.onSurface;

    return Align(
      alignment: own ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!own)
                Text(
                  message.senderName,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              _Content(message: message, color: foreground),
              const SizedBox(height: 2),
              Align(
                alignment: Alignment.centerRight,
                widthFactor: 1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatRoomTime(message.sentAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: foreground.withValues(alpha: 0.7),
                      ),
                    ),
                    if (own) ...[
                      const SizedBox(width: 4),
                      _DeliveryIcon(
                        state: message.delivery,
                        color: foreground.withValues(alpha: 0.7),
                        onRetry: onRetry,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.message, required this.color});

  final ChatMessage message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(color: color);

    if (message.kind == MessageKind.encrypted) {
      return Text(
        'Mensagem criptografada',
        style: style.copyWith(fontStyle: FontStyle.italic),
      );
    }

    return SelectableText(message.text, style: style);
  }
}

class _DeliveryIcon extends StatelessWidget {
  const _DeliveryIcon({
    required this.state,
    required this.color,
    this.onRetry,
  });

  final DeliveryState state;
  final Color color;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final canRetry = state == DeliveryState.failed && onRetry != null;
    final (icon, tint, label) = switch (state) {
      DeliveryState.sending => (Icons.schedule, color, 'Enviando'),
      DeliveryState.sent => (Icons.done, color, 'Enviada'),
      DeliveryState.failed => (
        Icons.error_outline,
        Theme.of(context).colorScheme.error,
        canRetry ? 'Falhou. Toque para reenviar' : 'Falhou',
      ),
    };

    final iconWidget = Icon(icon, size: 14, color: tint);

    return Tooltip(
      message: label,
      child: canRetry ? InkWell(onTap: onRetry, child: iconWidget) : iconWidget,
    );
  }
}
