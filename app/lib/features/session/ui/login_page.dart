import 'package:app/features/session/domain/session_failure.dart';
import 'package:app/features/session/state/saved_server_providers.dart';
import 'package:app/features/session/state/session_providers.dart';
import 'package:app/features/session/ui/failure_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _homeserver = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  var _saveServer = false;
  var _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    ref.listenManual(savedServerControllerProvider, (_, next) {
      final saved = next.value;
      if (saved == null || _homeserver.text.isNotEmpty) return;
      setState(() {
        _homeserver.text = saved;
        _saveServer = true;
      });
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _homeserver.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Campo obrigatório' : null;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final password = _password.text;
    _password.clear();
    setState(() => _obscurePassword = true);

    await ref
        .read(loginControllerProvider.notifier)
        .submit(
          homeserver: _homeserver.text,
          username: _username.text,
          password: password,
          saveServer: _saveServer,
        );
  }

  @override
  Widget build(BuildContext context) {
    final login = ref.watch(loginControllerProvider);
    final isLoading = login.isLoading;
    final error = login.error;
    final notice = ref.watch(sessionNoticeProvider);

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primaryContainer.withValues(alpha: 0.55),
              scheme.surface,
              scheme.tertiaryContainer.withValues(alpha: 0.35),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 6,
                shadowColor: scheme.shadow.withValues(alpha: 0.25),
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.asset(
                              'assets/icon/app_icon.png',
                              width: 72,
                              height: 72,
                              semanticLabel: 'Logotipo do aplicativo',
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Insight Matrix',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Entre com sua conta Matrix',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 28),
                        TextFormField(
                          controller: _username,
                          enabled: !isLoading,
                          decoration: const InputDecoration(
                            labelText: 'Usuário',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: _required,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _password,
                          enabled: !isLoading,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Senha',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              tooltip: _obscurePassword
                                  ? 'Mostrar senha'
                                  : 'Ocultar senha',
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                          validator: _required,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _homeserver,
                          enabled: !isLoading,
                          keyboardType: TextInputType.url,
                          decoration: const InputDecoration(
                            labelText: 'Servidor',
                            hintText: 'https://matrix.org',
                            prefixIcon: Icon(Icons.dns_outlined),
                          ),
                          validator: _required,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        CheckboxListTile(
                          value: _saveServer,
                          onChanged: isLoading
                              ? null
                              : (value) => setState(
                                  () => _saveServer = value ?? false,
                                ),
                          title: const Text('Salvar servidor'),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                        if (error == null && notice != null) ...[
                          const SizedBox(height: 8),
                          _Banner(
                            icon: Icons.info_outline,
                            message: notice.message,
                            background: scheme.secondaryContainer,
                            foreground: scheme.onSecondaryContainer,
                          ),
                        ],
                        if (error != null) ...[
                          const SizedBox(height: 8),
                          _Banner(
                            icon: Icons.error_outline,
                            message: error is SessionFailure
                                ? error.message
                                : SessionFailure.unknown.message,
                            background: scheme.errorContainer,
                            foreground: scheme.onErrorContainer,
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: isLoading ? null : _submit,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: isLoading
                                ? const Row(
                                    key: ValueKey('loading'),
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text('Entrando…'),
                                    ],
                                  )
                                : const Text('Entrar', key: ValueKey('idle')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.message,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String message;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: foreground, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: TextStyle(color: foreground)),
            ),
          ],
        ),
      ),
    );
  }
}
