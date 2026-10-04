import 'package:app/features/conversations/domain/conversation_failure.dart';
import 'package:app/features/conversations/state/conversations_providers.dart';
import 'package:app/features/conversations/ui/conversation_failure_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<String?> showNewConversationDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (context) => const NewConversationDialog(),
  );
}

class NewConversationDialog extends ConsumerStatefulWidget {
  const NewConversationDialog({super.key});

  @override
  ConsumerState<NewConversationDialog> createState() =>
      _NewConversationDialogState();
}

class _NewConversationDialogState extends ConsumerState<NewConversationDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final roomId = await ref
        .read(conversationCreatorProvider.notifier)
        .create(_controller.text);
    if (roomId != null && mounted) Navigator.of(context).pop(roomId);
  }

  @override
  Widget build(BuildContext context) {
    final creator = ref.watch(conversationCreatorProvider);
    final loading = creator.isLoading;
    final error = creator.error;

    return AlertDialog(
      title: const Text('Nova conversa'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              enabled: !loading,
              decoration: const InputDecoration(
                labelText: 'Usuário',
                hintText: '@bob:localhost ou bob',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error is ConversationFailure
                    ? error.message
                    : ConversationFailure.unknown.message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: loading ? null : _submit,
          child: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Criar'),
        ),
      ],
    );
  }
}
