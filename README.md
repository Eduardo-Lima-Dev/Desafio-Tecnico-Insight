# Cliente de mensageria desktop com Matrix

Aplicação desktop de mensageria feita com **Flutter**, que conversa com um homeserver **Matrix**. A comunicação com o Matrix é implementada em **Rust**, usando o **Matrix Rust SDK**, e exposta ao Flutter pelo **Flutter Rust Bridge**.

Alvos: Linux, macOS e Windows.

## Status

Projeto em desenvolvimento. O que existe hoje:

- [x] Projeto Flutter com a ponte Flutter Rust Bridge configurada (exemplo `greet` funcionando)
- [x] Homeserver Matrix local com Docker
- [ ] Integração com o Matrix Rust SDK (login, sessão, salas, mensagens)
- [ ] Interface

O detalhamento de escopo, requisitos e fluxos está em [docs/PRD.md](docs/PRD.md). O enunciado do desafio está em [docs/desafio-tecnico.md](docs/desafio-tecnico.md).

## Como as peças se encaixam

```
Flutter (Dart)  <-- Flutter Rust Bridge -->  Rust + Matrix SDK  <-- HTTPS -->  Homeserver Matrix
```

Não existe back-end próprio. O homeserver Matrix cumpre esse papel, e o código Rust roda dentro do próprio aplicativo.

## Estrutura do repositório

```
.
├── app/                 Projeto Flutter
│   ├── lib/             Código Dart (UI e estado)
│   ├── rust/            Crate Rust (Matrix SDK + funções expostas ao Dart)
│   └── rust_builder/    Cargokit: compila o Rust junto com o app em cada sistema
├── docker/synapse/      Dados do homeserver local (gerados, fora do repositório)
├── docker-compose.yml   Homeserver Matrix (Synapse) para desenvolvimento
└── docs/                PRD e enunciado do desafio
```

## Pré-requisitos

Instale uma vez em cada máquina em que for rodar o app.

**Em todos os sistemas**

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (estável, com Dart 3.3 ou superior)
- [Rust](https://rustup.rs) via rustup
- [Docker](https://docs.docker.com/get-docker/) com o plugin Compose, para o homeserver
- `flutter_rust_bridge_codegen` (a versão precisa ser a **2.13.0**, a mesma do `pubspec.yaml`):
  ```bash
  cargo install flutter_rust_bridge_codegen --version 2.13.0 --locked
  ```

**Linux**

```bash
# Arch
sudo pacman -S --needed clang cmake ninja pkgconf gtk3 libsecret
# Debian/Ubuntu
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev libsecret-1-dev
```

**macOS**

- Xcode (abra uma vez para aceitar a licença) e CocoaPods (`brew install cocoapods`)

**Windows**

- Visual Studio 2022 com a carga de trabalho "Desenvolvimento para desktop com C++"
- Toolchain MSVC do Rust: `rustup default stable-msvc`
- Mantenha o projeto em um caminho curto e sem acentos (por exemplo `C:\dev\desafio`)

Confira o ambiente com:

```bash
flutter doctor -v
```

Só a linha da plataforma desktop que você vai usar precisa estar correta.

## Homeserver Matrix local

O app precisa de um homeserver. Este repositório traz um Synapse via Docker. Como a configuração contém segredos gerados, ela **não** é versionada e você a gera uma vez.

1. **Gerar a configuração** (uma vez só):

   ```bash
   docker compose run --rm -e UID=$(id -u) -e GID=$(id -g) synapse generate
   ```

   No Windows (PowerShell) e no macOS com Docker Desktop, pode rodar sem os `-e`:

   ```bash
   docker compose run --rm synapse generate
   ```

2. **Relaxar os limites de requisição** (somente para desenvolvimento). Adicione ao final de `docker/synapse/homeserver.yaml`:

   ```yaml
   rc_login:
     address:
       per_second: 1000
       burst_count: 1000
     account:
       per_second: 1000
       burst_count: 1000
     failed_attempts:
       per_second: 1000
       burst_count: 1000
   rc_message:
     per_second: 1000
     burst_count: 1000
   ```

3. **Subir o servidor:**

   ```bash
   docker compose up -d
   ```

   Confira se está saudável:

   ```bash
   docker compose ps
   curl http://localhost:8008/health
   ```

   A resposta do `curl` deve ser `OK`.

4. **Criar usuários de teste:**

   ```bash
   docker compose exec synapse register_new_matrix_user -c /data/homeserver.yaml -u alice -p senha123 --no-admin http://localhost:8008
   docker compose exec synapse register_new_matrix_user -c /data/homeserver.yaml -u bob -p senha123 --no-admin http://localhost:8008
   ```

   Os usuários ficam `@alice:localhost` e `@bob:localhost`.

No app, use o homeserver `http://localhost:8008`. As senhas acima são só para teste local.

Comandos do dia a dia:

```bash
docker compose up -d     # liga
docker compose down      # desliga (os dados continuam em docker/synapse/)
```

Se o contêiner reiniciar em loop com `Permission denied`, o seu usuário não tem uid 1000. Defina `SYNAPSE_UID` e `SYNAPSE_GID` com o resultado de `id -u` e `id -g` antes do `docker compose up`.

Alternativa sem Docker: usar uma conta em `https://matrix.org`, informando `https://matrix.org` como homeserver.

## Rodar o app

```bash
cd app
flutter pub get
flutter run -d linux     # ou: macos, windows
```

A primeira execução é lenta, porque compila o Rust.

### Quando alterar o código Rust exposto ao Dart

Depois de mudar funções públicas em `app/rust/src/api/`, regenere as ligações:

```bash
cd app
flutter_rust_bridge_codegen generate
```

## Plataformas

| Sistema | Situação |
| ------- | -------- |
| Linux   | Desenvolvido e testado |
| macOS   | Configurado, ainda não testado |
| Windows | Configurado, ainda não testado |

O Flutter desktop não compila de um sistema para outro: para rodar no macOS é preciso estar em um Mac, e no Windows, em um Windows.

**macOS:** o app roda em sandbox e precisa da permissão de rede de saída. Em `app/macos/Runner/DebugProfile.entitlements` e `app/macos/Runner/Release.entitlements` deve existir:

```xml
<key>com.apple.security.network.client</key>
<true/>
```

## Limitações conhecidas

- A integração com o Matrix Rust SDK ainda não foi implementada.
- macOS e Windows não foram testados.
- O registro completo de limitações será mantido em [docs/PRD.md](docs/PRD.md).
