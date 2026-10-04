import 'package:app/features/chat/domain/chat_message.dart';
import 'package:app/features/rooms/ui/room_time.dart';
import 'package:app/shared/ui/seeded_avatar.dart';
import 'package:flutter/material.dart';

const _avatarRadius = 16.0;
const _bigRadius = Radius.circular(18);
const _smallRadius = Radius.circular(4);

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.message,
    this.onRetry,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
    this.animateIn = false,
    super.key,
  });

  final ChatMessage message;
  final VoidCallback? onRetry;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final bool animateIn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final own = message.isOwn;
    final foreground = own ? scheme.onPrimary : scheme.onSurface;

    final bubble = Flexible(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: own ? null : scheme.surfaceContainerHigh,
            gradient: own
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scheme.primary,
                      Color.lerp(scheme.primary, scheme.tertiary, 0.35)!,
                    ],
                  )
                : null,
            borderRadius: _radius(own),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!own && isFirstInGroup)
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
                        formatClockTime(message.sentAt),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: foreground.withValues(alpha: 0.75),
                        ),
                      ),
                      if (own) ...[
                        const SizedBox(width: 4),
                        _DeliveryIcon(
                          state: message.delivery,
                          color: foreground.withValues(alpha: 0.75),
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
      ),
    );

    final row = Padding(
      padding: EdgeInsets.only(top: isFirstInGroup ? 8 : 2),
      child: Row(
        mainAxisAlignment: own
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!own) ...[
            if (isLastInGroup)
              SeededAvatar(
                seed: message.senderId,
                initial: _initial(message.senderName),
                radius: _avatarRadius,
              )
            else
              const SizedBox(width: _avatarRadius * 2),
            const SizedBox(width: 8),
          ],
          bubble,
        ],
      ),
    );

    if (!animateIn) return row;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 12),
          child: child,
        ),
      ),
      child: row,
    );
  }

  BorderRadius _radius(bool own) {
    final senderSide = isFirstInGroup ? _bigRadius : _smallRadius;
    return BorderRadius.only(
      topLeft: own ? _bigRadius : senderSide,
      topRight: own ? senderSide : _bigRadius,
      bottomLeft: own ? _bigRadius : _smallRadius,
      bottomRight: own ? _smallRadius : _bigRadius,
    );
  }

  String _initial(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return String.fromCharCode(trimmed.runes.first).toUpperCase();
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
