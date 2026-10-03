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
├── docker/synapse/      Configuração extra do homeserver local (dev-overrides.yaml)
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

O app precisa de um homeserver. O repositório traz um Synapse que sobe sozinho com Docker, sem configuração manual:

```bash
docker compose up -d
```

Na primeira vez, o Compose faz tudo em sequência:

1. gera a configuração do Synapse (`synapse-init`), já com os limites de requisição relaxados para desenvolvimento (`docker/synapse/dev-overrides.yaml`);
2. sobe o servidor (`synapse`);
3. cria os usuários e as conversas de teste (`synapse-seed`, com o script `docker/synapse/seed_rooms.py`).

Leva cerca de 30 segundos. Para conferir:

```bash
docker compose ps -a
curl http://localhost:8008/health
```

A resposta do `curl` deve ser `OK`, e `synapse-init` e `synapse-seed` aparecem como `Exited (0)`, o que é o esperado.

No app, use:

| Campo    | Valor                   |
| -------- | ----------------------- |
| Servidor | `http://localhost:8008` |
| Usuário  | `alice`, `bob`, `carol` ou `dave` |
| Senha    | `senha123` (a mesma para todos)   |

Os usuários ficam `@alice:localhost`, `@bob:localhost`, `@carol:localhost` e `@dave:localhost`. As credenciais são só para teste local.

### Conversas de teste

O seed também cria salas com mensagens trocadas entre os usuários, para o app já abrir com conversas, inclusive com mensagens não lidas:

| Sala | Participantes | Mensagens |
| ---- | ------------- | --------- |
| Alice e Bob | alice, bob | 6 |
| Equipe Insight | alice, bob, carol, dave | 7 |
| Projeto Matrix | carol, alice, bob | 4 |
| Bob e Carol | bob, carol | 3 |
| Almoço de sexta | dave, alice, carol | 4 |
| Histórico longo | alice, bob | 80 (para testar a paginação) |

Entrando como `alice`, aparecem 5 salas; como `dave`, 2. O seed é idempotente: rodar `docker compose up -d` de novo não duplica nada, e salas que já existem são mantidas. Para recriar tudo do zero, use `docker compose down -v` e suba de novo.

Se você já tinha o Docker rodando de uma versão anterior do repositório, basta `docker compose down` e `docker compose up -d`: a configuração é atualizada e as salas novas são criadas por cima do que já existe.

Comandos do dia a dia:

```bash
docker compose up -d       # liga
docker compose down        # desliga (os dados ficam no volume do Docker)
docker compose down -v     # desliga e apaga tudo, voltando ao estado inicial
```

Os dados ficam em um volume nomeado do Docker (`synapse-data`), então não há pastas nem permissões para ajustar no Linux, macOS ou Windows. Se a porta 8008 já estiver em uso, suba em outra com `SYNAPSE_PORT=18008 docker compose up -d` e use essa porta no app.

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
