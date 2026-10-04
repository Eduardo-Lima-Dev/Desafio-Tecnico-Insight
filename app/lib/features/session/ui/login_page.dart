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

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Login',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Image.asset(
                      'assets/icon/app_icon.png',
                      width: 120,
                      height: 120,
                      semanticLabel: 'Logotipo do aplicativo',
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _username,
                    enabled: !isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Usuário',
                      border: OutlineInputBorder(),
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
                      border: const OutlineInputBorder(),
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
                      border: OutlineInputBorder(),
                    ),
                    validator: _required,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  CheckboxListTile(
                    value: _saveServer,
                    onChanged: isLoading
                        ? null
                        : (value) =>
                              setState(() => _saveServer = value ?? false),
                    title: const Text('Salvar servidor'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  if (error == null && notice != null) ...[
                    const SizedBox(height: 16),
                    Text(notice.message, textAlign: TextAlign.center),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      error is SessionFailure
                          ? error.message
                          : SessionFailure.unknown.message,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: isLoading ? null : _submit,
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Entrar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
