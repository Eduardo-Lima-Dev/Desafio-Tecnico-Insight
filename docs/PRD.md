# Especificação Técnica de Requisitos (PRD)

Este documento descreve os requisitos funcionais, não funcionais, a arquitetura técnica, as decisões técnicas e as limitações do cliente de mensageria desktop com Matrix, baseado no desafio técnico (ver [desafio-tecnico.md](desafio-tecnico.md)). Os diagramas de fluxo estão em [FLUXOS.md](FLUXOS.md).

---

## 1. Pedido do Cliente

> Desenvolver uma aplicação desktop de mensageria utilizando Flutter, com foco em arquitetura, qualidade de código, segurança e experiência do usuário.
> A aplicação deverá se comunicar com um homeserver Matrix e estar preparada para execução em macOS, Windows e Linux.
> A comunicação com o Matrix deve ser implementada em Rust utilizando Matrix Rust SDK e Flutter Rust Bridge.
> Não esperamos um produto completo. O objetivo é compreender como o candidato estrutura o problema, define prioridades e prepara a solução para evoluir.

---

## 2. Stack Técnica

| Camada              | Tecnologia                                                                 |
| ------------------- | -------------------------------------------------------------------------- |
| Interface           | Flutter (desktop)                                                          |
| Estado              | Riverpod (`flutter_riverpod` e `riverpod_generator`), ver DT-001            |
| Integração Matrix   | Rust + Matrix Rust SDK (`matrix-sdk` e `matrix-sdk-ui` 0.19.1)             |
| Ponte Dart <-> Rust | Flutter Rust Bridge 2.13.0                                                 |
| Persistência local  | Sessão e senha do banco no cofre do sistema (`flutter_secure_storage`), servidor salvo em `shared_preferences` e cache do SDK em SQLite, ver DT-002 |
| Plataformas         | Linux, macOS, Windows                                                      |
| Testes              | `flutter_test` (unidade e widget) e `cargo test` (unidade e integração opcional contra o Synapse local) |
| Qualidade estática  | `very_good_analysis` no Dart e `cargo clippy` no Rust, ver DT-004          |
| Homeserver de teste | Synapse via Docker Compose                                                 |

---

## 3. Requisitos Funcionais

### 3.1. Sessão

| ID    | Requisito                                                                                              |
| ----- | ------------------------------------------------------------------------------------------------------ |
| RF-01 | O usuário informa homeserver, usuário e senha para autenticar. O campo de senha começa oculto e tem um botão (ícone de olho) para mostrá-la ou ocultá-la.                                         |
| RF-02 | O homeserver informado é validado (URL válida e servidor Matrix alcançável) antes do login.            |
| RF-03 | Após login bem-sucedido, a sessão é persistida de forma segura.                                        |
| RF-04 | Ao abrir o app, a sessão salva é restaurada automaticamente, sem pedir login de novo.                  |
| RF-05 | Se o servidor deixar de aceitar o token da sessão, o app apaga os dados locais e volta ao login com o aviso "Sua sessão expirou". Isso é detectado na restauração ou durante a sincronização. Uma falha de restauração por outro motivo volta ao login sem apagar os dados salvos. |
| RF-06 | O logout invalida a sessão no homeserver, apaga os dados locais e volta ao login. O botão Sair, com ícone de logout, fica no rodapé da lista de salas, ao lado do usuário logado. |
| RF-21 | O login oferece a opção "Salvar servidor": se marcada, o servidor informado é lembrado e já vem preenchido no próximo login. Usuário e senha nunca são salvos. |

### 3.2. Salas

| ID    | Requisito                                                                                      |
| ----- | ---------------------------------------------------------------------------------------------- |
| RF-07 | O app lista as salas em que o usuário participa, com avatar, nome e última mensagem.           |
| RF-08 | A lista é ordenada pela atividade mais recente.                                                |
| RF-09 | A lista se atualiza sozinha quando chegam novas mensagens ou salas.                            |
| RF-10 | O usuário seleciona uma sala para abrir a conversa.                                            |
| RF-11 | Salas com mensagens não lidas são destacadas na lista, com um indicador de não lidas.          |
| RF-22 | O avatar de cada sala é um círculo com a inicial do nome. O app não carrega imagens de avatar. |

### 3.3. Mensagens

| ID    | Requisito                                                                                                 |
| ----- | --------------------------------------------------------------------------------------------------------- |
| RF-12 | A conversa exibe as mensagens de texto da sala, com o horário de cada mensagem.                           |
| RF-13 | O usuário envia mensagens de texto pelo campo de envio (Enter envia, Shift+Enter quebra linha).           |
| RF-14 | A mensagem enviada aparece imediatamente com estado "enviando" e muda para "enviada" ou "falhou".         |
| RF-15 | Mensagens com falha podem ser reenviadas.                                                                 |
| RF-16 | Novas mensagens recebidas aparecem na conversa aberta sem ação do usuário.                                |
| RF-17 | Ao rolar até o topo, mensagens mais antigas são carregadas (paginação).                                   |
| RF-23 | As mensagens de outros participantes mostram o nome de quem enviou, acima da bolha.                       |

### 3.4. Estados da interface

| ID    | Requisito                                                                                          |
| ----- | -------------------------------------------------------------------------------------------------- |
| RF-18 | Telas exibem estados de carregamento, vazio e erro (ex.: "nenhuma sala", "sem conexão").           |
| RF-19 | Perda de conexão é sinalizada por um aviso fixo no topo da tela principal, visível em qualquer largura e com qualquer conversa aberta. A sincronização retoma sozinha quando a rede volta. Se a sincronização falhar de forma irrecuperável, o aviso oferece o botão "Tentar de novo". |
| RF-20 | Erros vindos do Rust são traduzidos em mensagens claras, sem expor detalhes técnicos ou tokens.    |
| RF-24 | Em janela larga, a tela principal mostra salas e conversa lado a lado. Em janela estreita, mostra só a lista, e a conversa abre por cima dela. |
| RF-25 | Quando nenhuma sala está selecionada, o painel da conversa mostra a mensagem "Selecione uma sala". |
| RF-26 | O usuário cria uma conversa direta pelo botão "Nova conversa", informando o identificador de outro usuário (por exemplo `@bob:localhost` ou só `bob`). Se já existir uma conversa direta com essa pessoa, ela é reaberta em vez de duplicada. |
| RF-27 | Convites recebidos aparecem em uma seção "Convites" no topo da lista, com as ações Aceitar e Recusar. Aceitar abre a conversa. |

### 3.5. Camada Rust (exposta ao Dart)

O código Rust expõe ao Flutter, via Flutter Rust Bridge:

| Capacidade             | Descrição                                                                 |
| ---------------------- | ------------------------------------------------------------------------- |
| Login / logout         | Autentica e encerra a sessão no homeserver.                               |
| Restaurar sessão       | Reconstrói o cliente a partir da sessão persistida.                       |
| Sync                   | Mantém a sincronização, emite o status da conexão e detecta token recusado. |
| Salas                  | Lista as salas ordenadas por atividade, com última mensagem e não lidas.  |
| Conversa               | Abre e fecha a conversa de uma sala e entrega as mensagens em tempo real. |
| Envio                  | Envia texto e reenvia mensagens que falharam, pela fila de envio do SDK.  |
| Histórico              | Carrega mensagens antigas, em páginas, e informa quando chegou ao início. |
| Nova conversa          | Cria uma conversa direta 1:1 com outro usuário, sem duplicar.             |
| Convites               | Lista os convites recebidos e permite aceitar ou recusar.                 |

---------------------- | ------------------------------------------------------------------ |
| Login / logout         | Autentica e encerra a sessão no homeserver.                        |
| Restaurar sessão       | Reconstrói o cliente a partir da sessão persistida.                |
| Sync                   | Mantém a sincronização e emite eventos ao Dart por stream.         |
| Salas                  | Lista as salas e notifica mudanças.                                |
| Timeline e envio       | Carrega mensagens de uma sala, pagina o histórico e envia texto.   |

---

## 4. Requisitos Não Funcionais

- **Multiplataforma:** o projeto deve estar preparado para macOS, Windows e Linux.
- **Segurança:** credenciais e tokens não devem ser armazenados em texto puro nem aparecer em logs. A sessão e a senha do banco local ficam no cofre do sistema operacional (Keychain, libsecret ou Credential Manager), ver DT-002.
- **Arquitetura:** separação clara entre UI, estado, acesso ao Matrix e código Rust.
- **Tratamento de erros:** erros do Rust devem chegar ao Dart tipados e ser traduzidos em mensagens ao usuário.
- **Desempenho:** a UI não deve travar durante sync ou carregamento de histórico.
- **Manutenibilidade:** estrutura de pastas clara, facilitando a evolução do projeto.
- **Testes:** cobertura dos pontos mais relevantes (lógica de estado, camada Rust, fluxos críticos).

---

## 5. Interface e Fluxos

### Referência visual

O wireframe abaixo é a base de estrutura das telas: Login, lista de Salas e Chat (lista de salas à esquerda e conversa à direita). É uma referência de organização e fluxo, não uma especificação visual final.

Ele foi desenhado tendo o **Telegram** como inspiração: lista de conversas em uma coluna e conversa aberta ao lado, com as mensagens próprias à direita e as dos outros à esquerda.

![Wireframe das telas: Login, Salas e Chat](img/wireframe.png)

| Tela do wireframe | Papel no app | Requisitos |
| ----------------- | ------------ | ---------- |
| Login | Servidor, usuário e senha, com a opção de salvar o servidor | RF-01 a RF-03 |
| Salas | Lista de conversas em tela cheia, usada quando a janela é estreita | RF-07 a RF-11 |
| Chat | Lista de salas à esquerda e conversa à direita, usada quando a janela é larga | RF-10, RF-12 a RF-17 |

Decisões de interface que complementam o wireframe:

- **Layout responsivo (RF-24):** janela larga mostra as duas colunas (salas e conversa); janela estreita mostra só a lista, e a conversa abre por cima dela.
- **Usuário e logout (RF-06):** o rodapé da lista de salas mostra o usuário logado (avatar com a inicial, nome e identificador completo) e o botão **Sair** com ícone de logout. Em janela larga o rodapé fica sempre visível; em janela estreita, ele aparece na tela da lista.
- **Lista de salas:** cada item mostra o avatar, o nome, a última mensagem e, quando houver, um indicador de mensagens não lidas (RF-07, RF-11).
- **Mensagens:** cada mensagem mostra o horário, e as de outros participantes mostram o nome de quem enviou acima da bolha (RF-12, RF-23). As mensagens próprias mostram o estado: enviando, enviada ou falhou (RF-14).
- **Nenhuma sala selecionada:** o painel da conversa mostra a mensagem "Selecione uma sala" (RF-25).
- **Avatares só com letras (RF-22):** não são carregadas imagens. O avatar é um círculo com a inicial do nome (por exemplo, "Alice" aparece como "A").
- **Estados de carregamento, vazio e offline** seguem o RF-18 e o RF-19. O aviso de conexão ("Sem conexão. Tentando reconectar..." ou "Não foi possível sincronizar." com o botão "Tentar de novo") fica fixo no topo da tela principal, acima da lista e da conversa, tanto em janela larga quanto estreita.

### Fluxos

Os diagramas de fluxo (atividade, estados e sequência) e o diagrama de componentes ficam no documento [FLUXOS.md](FLUXOS.md), organizados por tipo de diagrama.

---

## 6. Decisões Técnicas

Registrar aqui as principais decisões, no formato abaixo.

### DT-001 — Gerenciamento de estado: Riverpod

- **Contexto:** o app consome streams vindos do Rust (sync, salas, timeline) e precisa de estados de carregamento, vazio e erro (RF-18), além de testes de lógica de estado.
- **Decisão:** `flutter_riverpod` com `riverpod_generator` (`AsyncNotifier`/`Notifier`). Repositórios são expostos como providers.
- **Alternativas consideradas:** BLoC (mais código para fluxos baseados em stream); Provider (DI e testes mais fracos); `setState` (não escala); GetX (mistura responsabilidades).
- **Consequências:** `AsyncValue` cobre carregando/erro/dados; `autoDispose` cancela subscriptions de stream; fakes entram via `overrides` nos testes, sem pacote de DI extra. Exige `build_runner` para gerar os providers.

### DT-002 — Armazenamento seguro da sessão: flutter_secure_storage

- **Contexto:** credenciais e tokens não podem ficar em texto puro nem em logs (RNF de segurança, RF-03).
- **Decisão:** `flutter_secure_storage` guarda a sessão serializada e uma passphrase aleatória que protege o banco SQLite do Matrix SDK. No Linux usa o libsecret; no macOS, o Keychain; no Windows, o Credential Manager. Logout e sessão inválida apagam sessão e passphrase (RF-05, RF-06).
- **Alternativas consideradas:** `shared_preferences` ou arquivo JSON (texto puro, rejeitado); guardar tudo só no Rust (a restauração via Dart ficaria mais acoplada ao SDK).
- **Consequências:** o Linux depende de um serviço de segredos (libsecret) disponível na máquina. O banco só é legível com a passphrase guardada no cofre do SO.

### DT-003 — Arquitetura em camadas por feature

- **Contexto:** o PRD exige separação clara entre UI, estado, acesso ao Matrix e Rust.
- **Decisão:** cada feature em `ui / state / data / domain`. Todo acesso ao Matrix acontece no Rust; o repositório Dart é o único ponto que conhece os tipos gerados pelo FRB e os converte em modelos de domínio. Erros do Rust chegam tipados (enum) e a UI os traduz em mensagens (RF-20).
- **Alternativas consideradas:** organização por tipo de arquivo (menos coesa); chamar a bridge direto dos widgets (acopla UI ao FRB).
- **Consequências:** mais arquivos por feature, em troca de testes simples (repositório falso) e facilidade para evoluir.

### DT-004 — Qualidade estática: very_good_analysis e clippy

- **Contexto:** o desafio valoriza qualidade de código e verificação objetiva.
- **Decisão:** `very_good_analysis` no Dart (com `public_member_api_docs` desligada, pois é app e não biblioteca) e `cargo clippy --all-targets -- -D warnings` no Rust.
- **Alternativas consideradas:** `flutter_lints` (regras mais brandas).
- **Consequências:** o analyzer é mais rigoroso; código gerado (FRB, `*.g.dart`) é excluído da análise.

### DT-005 — Sincronização e lista de salas: SyncService e RoomListService

- **Contexto:** o app precisa manter as salas atualizadas sem polling próprio e detectar quando o token deixa de valer (RF-05, RF-09, RF-19).
- **Decisão:** `SyncService` e `RoomListService` do `matrix-sdk-ui` (sliding sync), com modo offline ligado para reconectar sozinho. Ao entrar em offline, o Rust chama `whoami`: se o servidor responder "token desconhecido", o status vira sessão expirada e o app volta ao login com um aviso. O Rust expõe a lista e o status como streams pela ponte.
- **Alternativas consideradas:** `/sync` clássico com `Client::sync` (mais simples, mas exigiria calcular a última mensagem e a ordenação por conta própria).
- **Consequências:** a lista já vem ordenada por atividade. As não lidas usam o contador calculado no cliente (mensagens depois da última do próprio usuário, limitado às últimas 20 por sala), porque o contador do servidor vem zerado nesse protocolo. Os watchers terminam por um sinal de parada, para não ficarem pendurados após o logout.

### DT-006 — Conversa: Timeline do matrix-sdk-ui

- **Contexto:** a conversa precisa mostrar as mensagens em tempo real, com remetente, horário e, depois, estado de envio e histórico (RF-12, RF-14, RF-16, RF-17, RF-23).
- **Decisão:** um `Timeline` por sala aberta, guardado no Rust. O Dart pede para abrir e fechar a sala e observa um stream de mensagens já convertidas (`ChatMessage`). Cada mensagem usa o identificador único do item da timeline, que continua o mesmo quando uma mensagem local vira remota. Mensagens de outros participantes marcam a sala como lida.
- **Alternativas consideradas:** montar a conversa a partir dos eventos do sync (reimplementaria agrupamento, edições e mensagens locais).
- **Consequências:** mensagens que não são texto aparecem como "Mensagem não suportada", e as que não puderam ser decifradas aparecem como "Mensagem criptografada". O envio usa a fila de envio do SDK: a mensagem aparece na hora como "enviando" (eco local) e muda para "enviada"; sem rede, ela fica como "falhou" até o usuário tocar no ícone de erro, que reativa a fila e reenvia (RF-14, RF-15). O campo de envio usa Enter para enviar e Shift+Enter para quebrar linha (RF-13). O histórico é carregado em páginas de 30 mensagens quando a lista se aproxima do topo (RF-17): o Rust usa `paginate_backwards` e informa quando a sala chegou ao início, e a tela mostra um indicador de carregamento, o aviso "Início da conversa" ou, se falhar, um botão para tentar de novo.

### DT-007 — Nova conversa e convites

- **Contexto:** sem criar conversas, o usuário só enxergaria as salas que já existem no servidor; e quem recebe uma conversa nova só a vê depois de aceitar o convite (RF-26, RF-27).
- **Decisão:** a conversa direta é criada com `create_room` (`is_direct`, preset de conversa privada confiável e convite à outra pessoa), **sem criptografia**, em vez do `create_dm` do SDK, que criptografa por padrão. Antes de criar, o Rust consulta o perfil da outra pessoa e procura uma conversa direta existente (inclusive com convite pendente) para não duplicar. Os convites vêm de um segundo stream do `RoomListService` filtrado por salas convidadas; aceitar usa `join` e recusar usa `leave`.
- **Alternativas consideradas:** `create_dm` (conversas criptografadas, que o app não exibe como texto); criar a sala sem checar o perfil (o servidor aceita convidar usuários inexistentes e deixaria uma sala órfã).
- **Consequências:** só conversas diretas 1:1; não há criação de grupos, busca de usuários nem lista de contatos. O identificador é normalizado (`bob` vira `@bob:<servidor do usuário>`).

---

## 7. Configuração e Execução

- **Pré-requisitos e versões usadas no desenvolvimento:** Flutter 3.44.4 (Dart 3.12), Rust 1.99.0 com `cargo`, `flutter_rust_bridge_codegen` 2.13.0 (precisa ser a mesma versão do pacote `flutter_rust_bridge`) e Docker com o Compose. Por sistema: Linux precisa de `clang`, `cmake`, `ninja`, `pkg-config`, `gtk3` e `libsecret`; macOS, de Xcode e CocoaPods; Windows, do Visual Studio com a carga de trabalho de C++ e do toolchain `stable-msvc` do Rust.
- **Execução:** `docker compose up -d` na raiz sobe o homeserver de teste; depois, em `app/`, `flutter pub get` e `flutter run -d linux` (ou `macos`, `windows`). A ponte e os providers já vêm gerados no repositório: só é preciso rodar `flutter_rust_bridge_codegen generate` ao mudar a API do Rust, e `dart run build_runner build` ao mudar providers.
- **Verificações:** `flutter analyze` e `flutter test` em `app/`; `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings` e `cargo test` em `app/rust/`. Os testes Rust de integração são opcionais e exigem o Docker ligado: `cargo test -- --ignored`.
- **Passo a passo completo:** README, seções "Pré-requisitos", "Homeserver Matrix local" e "Rodar o app".
- **Homeserver para testes:** Synapse local via `docker compose up -d`, que gera a configuração, cria os usuários `alice`, `bob`, `carol` e `dave` (senha `senha123`) e doze salas de teste com conversas de assuntos variados (back-end com NestJS, futebol, vôlei, churrasco, filmes e outros), inclusive uma com 80 mensagens para testar a paginação. Detalhes no README.

---

## 8. Limitações e Itens Não Concluídos

- Não são carregadas imagens: os avatares das salas são só a inicial do nome (RF-22), e não há envio nem exibição de anexos.
- Plataformas: o desenvolvimento e os testes manuais foram feitos no Linux. macOS e Windows estão configurados (permissão de rede do macOS, ícones e dependências), mas não foram executados.
- Salas com criptografia ponta a ponta: o app não decifra mensagens, e mostra "Mensagem criptografada" no lugar do texto. Na lista de salas, a última mensagem de uma sala criptografada aparece como "Sem mensagens".
- Só é possível criar conversas diretas 1:1 (sem grupos, sem busca de usuários); as conversas criadas pelo app não são criptografadas.
- Só é possível enviar texto simples: não há edição, exclusão, resposta nem anexos.
- O reenvio de uma mensagem que falhou é manual (toque no ícone de erro); o app não tenta de novo sozinho.
- O contador de não lidas considera apenas as últimas 20 mensagens de cada sala.
- Só mensagens de texto são exibidas; imagens, arquivos, enquetes e demais tipos aparecem como "Mensagem não suportada".
- Dependências Rust (`cargo audit`, 440 pacotes no `Cargo.lock`, banco de avisos do RustSec com 1290 registros): **nenhuma vulnerabilidade**. O aviso de falha de segurança do `anyhow` (RUSTSEC-2026-0190) foi resolvido atualizando-o de 1.0.75 para 1.0.104. Restam três avisos de pacotes **sem manutenção**, que não são vulnerabilidades e vêm de dependências que o projeto não controla: `adler` (RUSTSEC-2025-0056, via `flutter_rust_bridge`), `anymap2` (RUSTSEC-2026-0319, via `matrix-sdk`) e `derivative` (RUSTSEC-2024-0388, que consta no `Cargo.lock`, mas não entra no grafo de dependências compiladas do app). Devem ser revistos quando essas bibliotecas lançarem versões novas.
- Dependências Dart (`flutter pub outdated`): as únicas diretas com versão mais nova são saltos de versão principal (`cupertino_icons` 2.0.0, `very_good_analysis` 11.0.0 e `build_runner` 2.16.1). Foram mantidas por não trazerem correções de segurança e para evitar regras de lint novas perto da entrega. As demais pendências são dependências transitivas fixadas pelo Flutter e pelos pacotes usados.
