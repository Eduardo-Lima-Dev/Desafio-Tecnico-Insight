import 'package:app/features/encryption/domain/encryption_failure.dart';
import 'package:app/features/encryption/domain/recovery_status.dart';
import 'package:app/features/encryption/state/encryption_providers.dart';
import 'package:app/features/encryption/ui/encryption_failure_message.dart';
import 'package:app/shared/ui/dialog_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> showEncryptionDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const EncryptionDialog(),
  );
}

class EncryptionDialog extends ConsumerStatefulWidget {
  const EncryptionDialog({super.key});

  @override
  ConsumerState<EncryptionDialog> createState() => _EncryptionDialogState();
}

class _EncryptionDialogState extends ConsumerState<EncryptionDialog> {
  final _keyController = TextEditingController();
  String? _generatedKey;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _recover() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final recovered = await ref
        .read(recoveryActionsProvider.notifier)
        .recover(_keyController.text);
    if (!recovered || !mounted) return;
    _keyController.clear();
    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Chaves recuperadas. Carregando as mensagens antigas.'),
      ),
    );
  }

  Future<void> _enable() async {
    final key = await ref.read(recoveryActionsProvider.notifier).enable();
    if (key != null && mounted) setState(() => _generatedKey = key);
  }

  Future<void> _copyKey(String key) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: key));
    messenger.showSnackBar(const SnackBar(content: Text('Chave copiada.')));
  }

  @override
  Widget build(BuildContext context) {
    final status =
        ref.watch(recoveryStatusProvider).value ?? RecoveryStatus.unknown;
    final actions = ref.watch(recoveryActionsProvider);
    final loading = actions.isLoading;
    final error = actions.error;
    final key = _generatedKey;

    final (title, body, buttons) = key != null
        ? ('Guarde a chave de recuperação', _generatedKeyBody(key), _done())
        : switch (status) {
            RecoveryStatus.incomplete => (
              'Recuperar mensagens',
              _recoverBody(loading),
              _recoverButtons(loading),
            ),
            RecoveryStatus.disabled => (
              'Backup das mensagens',
              _enableBody(),
              _enableButtons(loading),
            ),
            RecoveryStatus.enabled => (
              'Backup das mensagens',
              const Text(
                'O backup está ativo. Para ler o histórico em outro '
                'dispositivo, use a chave de recuperação que você guardou.',
              ),
              _done(),
            ),
            RecoveryStatus.unknown => (
              'Backup das mensagens',
              const Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Verificando o estado do backup...'),
                ],
              ),
              _done(),
            ),
          };

    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            body,
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error is EncryptionFailure
                    ? error.message
                    : EncryptionFailure.unknown.message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: buttons,
    );
  }

  Widget _recoverBody(bool loading) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Este dispositivo ainda não tem as chaves das conversas '
        'criptografadas. Informe a chave de recuperação da sua conta para '
        'ler as mensagens antigas.',
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _keyController,
        autofocus: true,
        enabled: !loading,
        autocorrect: false,
        enableSuggestions: false,
        decoration: const InputDecoration(
          labelText: 'Chave de recuperação',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) => _recover(),
      ),
    ],
  );

  List<Widget> _recoverButtons(bool loading) => [
    DialogCancelButton(
      label: 'Cancelar',
      onPressed: loading ? null : () => Navigator.of(context).pop(),
    ),
    DialogConfirmButton(
      label: 'Recuperar',
      loading: loading,
      onPressed: loading ? null : _recover,
    ),
  ];

  Widget _enableBody() => const Text(
    'Ative o backup para não perder o acesso às mensagens criptografadas '
    'ao entrar de novo ou em outro dispositivo. Será criada uma chave de '
    'recuperação, que só aparece uma vez.',
  );

  List<Widget> _enableButtons(bool loading) => [
    DialogCancelButton(
      label: 'Agora não',
      onPressed: loading ? null : () => Navigator.of(context).pop(),
    ),
    DialogConfirmButton(
      label: 'Ativar backup',
      loading: loading,
      onPressed: loading ? null : _enable,
    ),
  ];

  Widget _generatedKeyBody(String key) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Esta chave não será mostrada de novo. Guarde-a em um lugar seguro: '
        'sem ela, não é possível ler as mensagens antigas em outro '
        'dispositivo.',
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(child: SelectableText(key)),
          IconButton(
            tooltip: 'Copiar chave',
            icon: const Icon(Icons.copy_rounded, size: 18),
            onPressed: () => _copyKey(key),
          ),
        ],
      ),
    ],
  );

  List<Widget> _done() => [
    DialogConfirmButton(
      label: 'Concluir',
      onPressed: () => Navigator.of(context).pop(),
    ),
  ];
}
