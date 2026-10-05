# Aplicativo Flutter

Projeto Flutter do cliente de mensageria desktop com Matrix. A visão geral, a configuração do ambiente e a execução estão no [README da raiz do repositório](../README.md).

Estrutura:

- `lib/` – código Dart, organizado por funcionalidade em `features/` (sessão, salas, conversa, conversas e criptografia), com widgets compartilhados em `shared/`, o tema em `theme/` e a ponte gerada em `src/rust/` (não editar à mão).
- `rust/` – biblioteca Rust com o Matrix Rust SDK, exposta ao Dart pelo Flutter Rust Bridge (`rust/src/api/`).
- `rust_builder/` – cola gerada pelo Flutter Rust Bridge para compilar o Rust junto com o app (não editar).
- `test/` – testes Dart, espelhando a estrutura de `lib/`.

Comandos úteis, a partir desta pasta:

```bash
flutter pub get
flutter run -d linux            # ou: macos, windows
flutter analyze
flutter test
dart run build_runner build     # depois de mudar providers
flutter_rust_bridge_codegen generate   # depois de mudar a API do Rust
```
