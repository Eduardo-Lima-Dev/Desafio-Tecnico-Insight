import 'dart:async';

import 'package:app/features/chat/state/chat_providers.dart';
import 'package:app/features/session/domain/session_failure.dart';
import 'package:app/features/session/ui/failure_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MessageComposer extends ConsumerStatefulWidget {
  const MessageComposer({required this.roomId, super.key});

  final String roomId;

  @override
  ConsumerState<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends ConsumerState<MessageComposer> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    unawaited(
      ref.read(messageSenderProvider.notifier).send(widget.roomId, text),
    );
    _focusNode.requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final isEnter =
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (event is KeyDownEvent &&
        isEnter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      _send();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(messageSenderProvider, (_, next) {
      if (!next.hasError) return;
      final error = next.error;
      final message = error is SessionFailure
          ? error.message
          : SessionFailure.unknown.message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    });

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Focus(
                  onKeyEvent: _onKey,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    autofocus: true,
                    minLines: 1,
                    maxLines: 6,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: 'Digite uma mensagem...',
                      border: _pillBorder,
                      enabledBorder: _pillBorder,
                      focusedBorder: _pillBorder,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _controller,
                builder: (context, value, _) {
                  final canSend = value.text.trim().isNotEmpty;
                  return AnimatedScale(
                    scale: canSend ? 1 : 0.85,
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    child: AnimatedOpacity(
                      opacity: canSend ? 1 : 0.5,
                      duration: const Duration(milliseconds: 150),
                      child: IconButton.filled(
                        tooltip: 'Enviar',
                        icon: const Icon(Icons.send_rounded),
                        onPressed: canSend ? _send : null,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Enter envia · Shift+Enter quebra linha',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

final _pillBorder = OutlineInputBorder(
  borderRadius: BorderRadius.circular(28),
  borderSide: BorderSide.none,
);
