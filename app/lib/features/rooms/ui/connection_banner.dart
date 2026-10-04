import 'package:app/features/rooms/domain/sync_status.dart';
import 'package:app/features/rooms/state/rooms_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectionBanner extends ConsumerWidget {
  const ConnectionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider).value;

    return switch (status) {
      SyncStatus.offline => const _Banner(
        message: 'Sem conexão. Tentando reconectar...',
      ),
      SyncStatus.failed => _Banner(
        message: 'Não foi possível sincronizar.',
        onRetry: () => ref.invalidate(syncServiceProvider),
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const Text('Tentar de novo'),
            ),
        ],
      ),
    );
  }
}
