# Cliente de mensageria desktop com Matrix

Aplicação desktop de mensageria feita com **Flutter**, que conversa com um homeserver **Matrix**. A comunicação com o Matrix é implementada em **Rust**, usando o **Matrix Rust SDK**, e exposta ao Flutter pelo **Flutter Rust Bridge**.

Alvos: Linux, macOS e Windows.

## O que o app faz

- Login em um homeserver Matrix, com a opção de lembrar o servidor e botão para mostrar a senha
- Sessão guardada no cofre do sistema, restaurada ao abrir o app e encerrada no logout
- Lista de salas ordenada por atividade, com última mensagem, horário e mensagens não lidas
- Conversa com mensagens em tempo real, envio (Enter envia, Shift+Enter quebra linha), reenvio de mensagens que falharam e histórico ao rolar até o topo
- Nova conversa (conversa direta com outro usuário) e convites, com aceitar e recusar
- Avisos de falta de conexão e de sessão expirada
- Layout responsivo: lista e conversa lado a lado em janela larga, uma de cada vez em janela estreita
- Homeserver Matrix local com Docker, já com usuários e conversas de teste

O escopo e os requisitos estão em [docs/PRD.md](docs/PRD.md), e os diagramas de fluxo em [docs/FLUXOS.md](docs/FLUXOS.md). O enunciado do desafio está em [docs/desafio-tecnico.md](docs/desafio-tecnico.md).

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
└── docs/                PRD, fluxos (diagramas) e enunciado do desafio
```

## Início rápido

Com os [pré-requisitos](#pré-requisitos) instalados, na raiz do repositório:

```bash
docker compose up -d                 # 1. sobe o homeserver de teste (cerca de 30 s)
cd app
flutter pub get                      # 2. baixa as dependências do Dart
flutter run -d linux                 # 3. roda o app (ou: macos, windows)
```

Na tela de login, use `http://localhost:8008`, usuário `alice` e senha `senha123`. A primeira execução é lenta, porque compila o Rust.

## Pré-requisitos

Instale uma vez em cada máquina em que for rodar o app.

**Em todos os sistemas**

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (canal estável; o projeto exige Dart 3.12.2 ou superior, que já vem no Flutter 3.44)
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

| Sala | Assunto | Participantes | Mensagens |
| ---- | ------- | ------------- | --------- |
| Alice e Bob | conversa do dia a dia (futebol) | alice, bob | 6 |
| Equipe Insight | equipe de back-end (NestJS, JWT, Prisma) | alice, bob, carol, dave | 7 |
| API de Pedidos | projeto de back-end em NestJS | carol, alice, bob | 4 |
| Bob e Carol | vôlei | bob, carol | 3 |
| Almoço de sexta | combinados do almoço | dave, alice, carol | 4 |
| Futebol de quinta | racha semanal | dave, alice, bob, carol | 6 |
| Vôlei da turma | treinos de vôlei | carol, alice, bob, dave | 5 |
| Dúvidas de NestJS | validação com DTOs e pipes | bob, alice, carol, dave | 5 |
| Churrasco do fim de semana | organização do churrasco | alice, bob, carol, dave | 6 |
| Filmes e séries | indicações e maratona | carol, alice, dave | 4 |
| Pipeline e deploy | CI/CD, Docker e Postgres | dave, alice, bob | 4 |
| Histórico longo | mensagens numeradas, para testar a paginação | alice, bob | 80 |

Entrando como `alice`, aparecem 11 salas; como `bob`, 10; como `carol`, 9; e como `dave`, 8. O seed é idempotente: rodar `docker compose up -d` de novo não duplica nada, e salas que já existem são mantidas. Para recriar tudo do zero, use `docker compose down -v` e suba de novo.

Se você já tinha o Docker rodando de uma versão anterior do repositório, basta `docker compose down` e `docker compose up -d`: a configuração é atualizada e as salas novas são criadas por cima do que já existe. Salas que já existem **não** têm o texto atualizado; para ver as conversas novas desde o início, use `docker compose down -v` e suba de novo (isso apaga os dados do servidor de teste e as sessões salvas no app).

Comandos do dia a dia:

```bash
docker compose up -d       # liga
docker compose down        # desliga (os dados ficam no volume do Docker)
docker compose down -v     # desliga e apaga tudo, voltando ao estado inicial
```

Os dados ficam em um volume nomeado do Docker (`synapse-data`), então não há pastas nem permissões para ajustar no Linux, macOS ou Windows. Se a porta 8008 já estiver em uso, suba em outra com `SYNAPSE_PORT=18008 docker compose up -d` e use essa porta no app.

Para usar um homeserver real em vez do local, veja [Usar outro homeserver](#usar-outro-homeserver).

## Rodar o app

```bash
cd app
flutter pub get
flutter run -d linux     # ou: macos, windows
```

A primeira execução é lenta, porque compila o Rust. Para gerar o binário de produção, troque `flutter run` por `flutter build linux` (ou `macos`, `windows`).

### Quando alterar o código

- Funções públicas em `app/rust/src/api/` mudaram: regenere as ligações com `flutter_rust_bridge_codegen generate` (em `app/`).
- Providers do Riverpod mudaram: rode `dart run build_runner build --delete-conflicting-outputs` (em `app/`).

Os arquivos gerados (`app/lib/src/rust/` e `*.g.dart`) já estão no repositório e não devem ser editados à mão.

## Como usar o app

1. **Login:** informe servidor, usuário e senha. O botão com o ícone de olho mostra ou oculta a senha. Marque "Salvar servidor" para que ele já venha preenchido na próxima vez.
2. **Sessão:** ao fechar e abrir o app, você continua logado, sem digitar a senha de novo.
3. **Conversas:** a lista à esquerda mostra as salas por atividade recente, com a última mensagem e um indicador de não lidas. Clique em uma para abri-la. Em janela estreita, a lista e a conversa aparecem uma de cada vez, e a seta de voltar retorna à lista.
4. **Mensagens:** digite no campo de baixo. Enter envia e Shift+Enter quebra a linha. Role até o topo para carregar mensagens mais antigas. Se uma mensagem falhar, toque no ícone de erro para reenviar.
5. **Nova conversa:** o botão "Nova conversa" pede o identificador do outro usuário, como `@bob:localhost`, ou só `bob`, que usa o servidor em que você está logado. Se já existir uma conversa com essa pessoa, ela é reaberta.
6. **Convites:** convites recebidos aparecem em "Convites", no topo da lista, com Aceitar e Recusar.
7. **Sair:** o botão "Sair", no rodapé da lista, encerra a sessão no servidor e apaga os dados locais.

## Usar outro homeserver

O app funciona com servidores além do Synapse local, desde que suportem o *sliding sync* (MSC4186). Já foi testado no `matrix.org`, no macOS:

1. Crie uma conta de teste com **e-mail e senha** (por exemplo, em https://app.element.io, escolhendo o servidor `matrix.org`). Contas que entram só por login único (Google, GitHub) não funcionam, porque o app autentica por senha.
2. No login do app, use `https://matrix.org`, o usuário **sem** `@` e **sem** `:matrix.org`, e a senha.
3. Para criar uma conversa, informe o usuário do outro lado (`bob` vira `@bob:matrix.org`).

Limites do uso fora do ambiente local: o app não decifra salas criptografadas (as criadas em outros clientes costumam ser), e servidores públicos têm limite de requisições mais rígido que o Synapse local.

## Solução de problemas

| Sintoma | O que verificar |
| ------- | --------------- |
| `docker compose up` falha ou o `curl` não responde | Confira com `docker compose ps -a` e `docker compose logs synapse`. Se a porta 8008 estiver ocupada, use `SYNAPSE_PORT=18008 docker compose up -d` e informe `http://localhost:18008` no app. |
| "Não foi possível conectar" no login | O servidor precisa estar ligado e ser HTTPS (só `localhost` aceita `http`). Confira o endereço e a conexão. |
| "Algo deu errado" ou "Não foi possível acessar os dados locais" no macOS | Confira a permissão de rede de saída (seção Plataformas) e o acesso ao Keychain. O app usa o Keychain tradicional, por causa da assinatura local do build (DT-002 no PRD). |
| Erro de versão ao gerar a ponte | `flutter_rust_bridge_codegen --version` precisa ser 2.13.0, igual ao do `pubspec.yaml`. |
| Falha de build no Linux por biblioteca faltando | Instale os pacotes da seção Pré-requisitos (`gtk3` e `libsecret` são os mais esquecidos). |
| Quer voltar ao estado inicial | `docker compose down -v` apaga o servidor de teste; no app, saia da conta para apagar os dados locais. |

## Testes e verificações

```bash
# em app/
dart format lib test
flutter analyze
flutter test

# em app/rust/
cargo fmt --check
cargo clippy --all-targets -- -D warnings
cargo test
```

Os testes Rust de integração são opcionais, exigem o homeserver local ligado e rodam em série, porque compartilham o estado global do cliente (DT-008 no PRD):

```bash
cargo test -- --ignored --test-threads=1
```

## Executáveis prontos (Releases)

Dois workflows do GitHub Actions cuidam da compilação, já que o Flutter desktop não compila de um sistema para outro:

- **CI** (`.github/workflows/ci.yml`): a cada push na `main` e em pull requests, roda formatação, `flutter analyze`, `flutter test`, `cargo test` e compila o app em Linux, Windows e macOS.
- **Release** (`.github/workflows/release.yml`): ao enviar uma tag `v*`, gera os três executáveis e os publica na aba **Releases**.

```bash
git tag v1.0.0
git push origin v1.0.0
```

Também dá para rodar o workflow Release manualmente na aba **Actions**. Nesse caso os arquivos ficam como artefatos da execução, sem criar uma Release.

| Sistema | Arquivo | Como abrir |
| ------- | ------- | ---------- |
| Windows | `insight-matrix-<versão>-windows-x64.zip` | Extraia e execute `app.exe`. Sem assinatura, o SmartScreen avisa: clique em "Mais informações" e "Executar assim mesmo". |
| macOS (Apple Silicon) | `insight-matrix-<versão>-macos-arm64.dmg` | Arraste para Aplicativos. Sem assinatura da Apple, o Gatekeeper bloqueia com "não foi aberto". No macOS 15 ou mais novo, abra **Ajustes do Sistema > Privacidade e Segurança**, role até o aviso do Insight Matrix e clique em **Abrir Mesmo Assim**. Ou, no Terminal: `xattr -dr com.apple.quarantine "/Applications/Insight Matrix.app"`. |
| Linux (x86_64) | `insight-matrix-<versão>-linux-x86_64.AppImage` | `chmod +x` no arquivo e execute. É preciso ter `libsecret` e GTK 3 instalados no sistema. |

Os executáveis não são assinados. O build do macOS é só para Apple Silicon.

## Plataformas

| Sistema | Situação |
| ------- | -------- |
| Linux   | Desenvolvido e testado |
| macOS   | Testado, inclusive contra o `matrix.org` |
| Windows | Configurado, ainda não testado |

O Flutter desktop não compila de um sistema para outro: para rodar no macOS é preciso estar em um Mac, e no Windows, em um Windows.

**macOS:** o app roda em sandbox e precisa da permissão de rede de saída. Em `app/macos/Runner/DebugProfile.entitlements` e `app/macos/Runner/Release.entitlements` deve existir:

```xml
<key>com.apple.security.network.client</key>
<true/>
```

## Limitações conhecidas

- **Windows** configurado, mas ainda não executado.
- **Homeservers:** testado no Synapse local e no `matrix.org`; outros servidores não foram testados.
- **Criptografia ponta a ponta** não suportada: mensagens de salas criptografadas aparecem como "Mensagem criptografada".
- **Escopo das mensagens:** só texto simples, em conversas diretas 1:1.

A lista completa está na seção 8 do [PRD](docs/PRD.md), e o plano de evolução, na seção 9.
