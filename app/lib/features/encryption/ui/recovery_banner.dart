import 'package:app/features/encryption/ui/encryption_dialog.dart';
import 'package:flutter/material.dart';

class RecoveryBanner extends StatelessWidget {
  const RecoveryBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.key_outlined,
              size: 18,
              color: scheme.onTertiaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Algumas mensagens só podem ser lidas com a chave de '
                'recuperação.',
                style: TextStyle(color: scheme.onTertiaryContainer),
              ),
            ),
            TextButton(
              onPressed: () => showEncryptionDialog(context),
              child: const Text('Recuperar chaves'),
            ),
          ],
        ),
      ),
    );
  }
}
