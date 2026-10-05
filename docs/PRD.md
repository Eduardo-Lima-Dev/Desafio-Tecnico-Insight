# Especificação Técnica de Requisitos (PRD)

Este documento descreve os requisitos funcionais, não funcionais, a arquitetura técnica, as decisões técnicas e as limitações do cliente de mensageria desktop com Matrix, baseado no [desafio-tecnico.md](desafio-tecnico.md). Os diagramas de fluxo estão em [FLUXOS.md](FLUXOS.md).

---

## 1. Pedido do Cliente

Cliente de mensageria desktop em Flutter, com a comunicação Matrix em Rust (Matrix Rust SDK e Flutter Rust Bridge), para macOS, Windows e Linux. Não se espera um produto completo: o foco é arquitetura, qualidade, segurança, priorização e preparo para evoluir.

---

## 2. Stack Técnica

| Camada              | Tecnologia                                                                 |
| ------------------- | -------------------------------------------------------------------------- |
| Interface           | Flutter (desktop)                                                          |
| Estado              | Riverpod (`flutter_riverpod` e `riverpod_generator`), ver DT-001            |
| Integração Matrix   | Rust + Matrix Rust SDK (`matrix-sdk` e `matrix-sdk-ui` 0.19.1)             |
| Ponte Dart <-> Rust | Flutter Rust Bridge 2.13.0                                                 |
| Persistência local  | Sessão e senha do banco no cofre do sistema (`flutter_secure_storage`), servidor salvo em `shared_preferences` e cache do SDK em SQLite, ver DT-002 |
| Criptografia        | E2EE do `matrix-sdk` (chaves no banco SQLite cifrado); backup e recuperação pelo armazenamento de segredos da conta, ver DT-010 |
| Plataformas         | Linux, macOS, Windows                                                      |
| Janela e tema       | `window_manager` (tamanho inicial e mínimo da janela); fonte Inter embutida; tema claro e escuro conforme o sistema |
| CI e distribuição   | GitHub Actions: CI (análise, testes e build nos três sistemas) e Release (executáveis), ver DT-009 |
| Testes              | `flutter_test` (unidade e widget) e `cargo test` (unidade e integração opcional contra o Synapse local) |
| Qualidade estática  | `very_good_analysis` no Dart e `cargo clippy` no Rust, ver DT-004          |
| Homeserver de teste | Synapse via Docker Compose                                                 |

---

## 3. Requisitos Funcionais

Os identificadores (RF-xx) são estáveis e não seguem a ordem de leitura: os mais recentes aparecem junto do assunto a que pertencem.

### 3.1. Sessão

| ID    | Requisito                                                                                              |
| ----- | ------------------------------------------------------------------------------------------------------ |
| RF-01 | O usuário informa homeserver, usuário e senha para autenticar. O campo de senha começa oculto e tem um botão (ícone de olho) para mostrá-la ou ocultá-la.                                         |
| RF-02 | O homeserver informado é validado (URL válida e servidor Matrix alcançável) antes do login.            |
| RF-03 | Após login bem-sucedido, a sessão é persistida de forma segura.                                        |
| RF-04 | Ao abrir o app, a sessão salva é restaurada automaticamente, sem pedir login de novo.                  |
| RF-05 | Se o servidor deixar de aceitar o token da sessão, o app apaga os dados locais e volta ao login com o aviso "Sua sessão expirou". Isso é detectado na restauração ou durante a sincronização. Uma falha de restauração por outro motivo volta ao login sem apagar os dados salvos. |
| RF-06 | O logout invalida a sessão no homeserver, apaga os dados locais e volta ao login. O logout apaga os dados locais mesmo que o servidor não responda. O botão Sair, com ícone de logout, fica no rodapé da lista de salas, ao lado do usuário logado. |
| RF-21 | O login oferece a opção "Salvar servidor": se marcada, o servidor informado é lembrado e já vem preenchido no próximo login. Usuário e senha nunca são salvos. |

### 3.2. Salas

| ID    | Requisito                                                                                      |
| ----- | ---------------------------------------------------------------------------------------------- |
| RF-07 | O app lista as salas em que o usuário participa, com avatar, nome, última mensagem e horário (hora no mesmo dia, "Ontem", dia da semana na última semana, ou dd/mm). |
| RF-08 | A lista é ordenada pela atividade mais recente.                                                |
| RF-09 | A lista se atualiza sozinha quando chegam novas mensagens ou salas.                            |
| RF-10 | O usuário seleciona uma sala para abrir a conversa.                                            |
| RF-11 | Salas com mensagens não lidas são destacadas na lista, com um indicador de não lidas.          |
| RF-22 | O avatar de cada sala é um círculo com a inicial do nome, em uma cor escolhida a partir do identificador da sala (a mesma sala tem sempre a mesma cor). O app não carrega imagens de avatar. |
| RF-28 | A lista tem um campo "Buscar conversas" que filtra as salas pelo nome, sem diferenciar maiúsculas nem acentos. |
| RF-29 | O cabeçalho da conversa mostra o nome da sala e a quantidade de membros. O menu do cabeçalho abre os detalhes da sala (participantes e ID) e copia o ID da sala. |

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
| RF-24 | Em janela larga (a partir de 720 px), a tela principal mostra salas e conversa lado a lado. Em janela estreita, mostra só a lista, e a conversa abre por cima dela. |
| RF-25 | Quando nenhuma sala está selecionada, o painel da conversa mostra a mensagem "Selecione uma sala". |
| RF-26 | O usuário cria uma conversa direta pelo botão "Nova conversa", informando o identificador de outro usuário (por exemplo `@bob:localhost` ou só `bob`). Se já existir uma conversa direta com essa pessoa, ela é reaberta em vez de duplicada. |
| RF-27 | Convites recebidos aparecem em uma seção "Convites" no topo da lista, com as ações Aceitar e Recusar. Aceitar abre a conversa. |
| RF-30 | Atalhos de teclado: Ctrl+K (⌘K no macOS) foca a busca, Ctrl+N (⌘N) abre "Nova conversa" e Esc fecha a conversa aberta ou limpa a busca. |

### 3.5. Criptografia

| ID    | Requisito |
| ----- | --------- |
| RF-31 | O app lê e envia mensagens em salas com criptografia ponta a ponta, e as conversas diretas que cria são criptografadas. |
| RF-32 | Uma mensagem que não pôde ser decifrada mostra o motivo: aguardando a chave, anterior a este dispositivo, ou indisponível (por exemplo, enviada antes de o usuário entrar na sala). |
| RF-33 | O botão de chave no rodapé abre o backup das mensagens. Se a conta já tem backup mas este dispositivo não tem as chaves (estado incompleto), o app pede a chave de recuperação e, com ela, passa a ler o histórico; uma chave incorreta é recusada. Se a conta não tem backup, o app oferece ativá-lo e mostra a chave de recuperação uma única vez, com botão de copiar. No estado incompleto, uma conversa com mensagens ilegíveis mostra o aviso "Recuperar chaves". Ao sair da conta sem backup ativo, o app avisa que as mensagens criptografadas recebidas neste dispositivo não poderão ser lidas depois. |

---

## 4. Requisitos Não Funcionais

- **Multiplataforma:** o projeto deve estar preparado para macOS, Windows e Linux.
- **Segurança:** credenciais e tokens não devem ser armazenados em texto puro nem aparecer em logs. A sessão e a senha do banco local ficam no cofre do sistema operacional (Keychain, libsecret ou Credential Manager), ver DT-002.
- **Arquitetura:** separação clara entre UI, estado, acesso ao Matrix e código Rust.
- **Tratamento de erros:** erros do Rust devem chegar ao Dart tipados e ser traduzidos em mensagens ao usuário.
- **Desempenho:** a UI não deve travar durante sync ou carregamento de histórico.
- **Manutenibilidade:** estrutura de pastas clara, facilitando a evolução do projeto.
- **Testes:** cobertura dos pontos mais relevantes (lógica de estado, camada Rust, fluxos críticos).

### 4.1. Resumo de segurança

| Tema | Como é tratado |
| ---- | -------------- |
| Senha | Digitada no login, enviada ao servidor e descartada: o campo é limpo ao enviar e a senha não é gravada em lugar nenhum. |
| Token e sessão | Só no cofre do sistema (DT-002). Nunca em arquivo, `shared_preferences` ou log. |
| Banco local do SDK | SQLite cifrado com uma passphrase aleatória guardada no cofre. Ele guarda também as chaves de criptografia das conversas. |
| Chave de recuperação | Nunca é gravada nem registrada em log. Só aparece na tela uma vez, quando o backup é ativado, ou é digitada pelo usuário para recuperar o histórico (DT-010). |
| Rede | HTTPS obrigatório. `http://` só é aceito para `localhost`, `127.0.0.1` e `::1`, para o homeserver de desenvolvimento. URLs com usuário e senha embutidos são recusadas. |
| Logout | Invalida a sessão no servidor e apaga cofre e dados locais, mesmo que o servidor não responda (RF-06). |
| Token recusado | Apaga os dados locais e volta ao login com aviso (RF-05). |
| Mensagens | As conversas criadas pelo app são criptografadas ponta a ponta (DT-010). |
| Erros | O Rust devolve erros tipados; a interface mostra mensagens em português, sem detalhes técnicos, URLs com token ou credenciais (RF-20). |
| Logs | O código de produção não registra senha, token nem corpo de mensagens. |

---

## 5. Interface e Fluxos

O app tem três telas, com tema claro e escuro conforme o sistema e a fonte Inter. A janela abre em 1100 x 720 e não encolhe abaixo de 480 x 600.

| Tela | Conteúdo | Requisitos |
| ---- | -------- | ---------- |
| Login | Servidor, usuário e senha, com a opção de salvar o servidor | RF-01 a RF-03, RF-21 |
| Lista de salas | Busca, "Nova conversa", convites, salas por atividade e rodapé com o usuário e o botão Sair | RF-07 a RF-11, RF-26 a RF-28 |
| Conversa | Cabeçalho da sala, mensagens com histórico e campo de envio | RF-10, RF-12 a RF-17, RF-29 |

A estrutura parte do [wireframe](img/wireframe.png) inicial (lista à esquerda, conversa à direita, inspirado no Telegram). O visual atual evoluiu a partir dele e vale como referência de organização, não de aparência.

Decisões de interface:

- **Layout responsivo (RF-24):** janela larga mostra salas e conversa lado a lado; janela estreita mostra só a lista, e a conversa abre por cima dela, com a seta de voltar.
- **Usuário e logout (RF-06):** o rodapé da lista mostra o usuário logado (avatar, nome e identificador completo) e o botão **Sair**.
- **Mensagens:** cada mensagem mostra o horário, e as de outros participantes mostram o nome de quem enviou acima da bolha (RF-12, RF-23). As próprias mostram o estado: enviando, enviada ou falhou (RF-14).
- **Nenhuma sala selecionada:** o painel da conversa mostra "Selecione uma sala" (RF-25).
- **Avatares só com letras (RF-22):** não são carregadas imagens.
- **Carregamento, vazio e offline** seguem o RF-18 e o RF-19. O aviso de conexão ("Sem conexão. Tentando reconectar..." ou "Não foi possível sincronizar." com o botão "Tentar de novo") fica fixo no topo da tela principal.

Os diagramas de fluxo, estados e sequência estão em [FLUXOS.md](FLUXOS.md).

---

## 6. Decisões Técnicas

### DT-001 — Gerenciamento de estado: Riverpod

- **Contexto:** o app consome streams vindos do Rust (sync, salas, timeline) e precisa de estados de carregamento, vazio e erro (RF-18), além de testes de lógica de estado.
- **Decisão:** `flutter_riverpod` com `riverpod_generator` (`AsyncNotifier`/`Notifier`). Repositórios são expostos como providers.
- **Alternativas consideradas:** BLoC (mais código para fluxos baseados em stream); Provider (DI e testes mais fracos); `setState` (não escala); GetX (mistura responsabilidades).
- **Consequências:** `AsyncValue` cobre carregando/erro/dados; `autoDispose` cancela subscriptions de stream; fakes entram via `overrides` nos testes, sem pacote de DI extra. Exige `build_runner` para gerar os providers.

### DT-002 — Armazenamento seguro da sessão: cofre do sistema (flutter_secure_storage)

- **Contexto:** credenciais e tokens não podem ficar em texto puro nem em logs (RNF de segurança, RF-03). Era preciso decidir onde guardar a sessão entre execuções do app.
- **Decisão:** `flutter_secure_storage` guarda duas chaves no cofre do sistema: a sessão serializada (`matrix_session`: usuário, servidor, dispositivo e token de acesso) e uma passphrase aleatória de 32 bytes (`matrix_store_passphrase`, gerada com `Random.secure`) que cifra o banco SQLite do Matrix SDK. No Linux o cofre é o libsecret; no macOS, o Keychain; no Windows, o Credential Manager. A senha do usuário nunca é gravada: só vai ao servidor no login. Logout e sessão recusada pelo servidor apagam as duas chaves e a pasta de dados do SDK (RF-05, RF-06).
- **Ajuste no macOS:** por padrão o plugin usa o Keychain "data protection", que exige o entitlement `keychain-access-groups`, disponível só em builds assinados com um Apple Developer Team. No build local (assinatura ad-hoc), a gravação falhava com o erro -34018 e o login terminava em "Algo deu errado". O app usa então o Keychain tradicional (`usesDataProtectionKeychain: false`, em `app_secure_storage.dart`), que funciona no sandbox com a assinatura ad-hoc. Em uma distribuição assinada com Team, o "data protection" poderia voltar a ser usado.
- **Alternativas consideradas:** `shared_preferences` ou arquivo JSON (texto puro, rejeitado); arquivo cifrado com chave própria (a chave teria de ficar em algum lugar, e o cofre do sistema já resolve isso); guardar tudo só no Rust (a restauração via Dart ficaria mais acoplada ao SDK).
- **Consequências:** o Linux depende de um serviço de segredos (libsecret) disponível na máquina. O banco só é legível com a passphrase guardada no cofre, e ele guarda também as chaves de criptografia das conversas (DT-010), o que torna essa passphrase ainda mais importante. O servidor escolhido no login (que não é segredo) fica à parte, em `shared_preferences`. No macOS, o Keychain tradicional protege menos que o "data protection" em apps distribuídos, o que é aceitável para este escopo.

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
- **Decisão:** a conversa direta é criada com o `create_dm` do SDK (`is_direct`, preset de conversa privada confiável, convite à outra pessoa e criptografia ativada, DT-010). Antes de criar, o Rust consulta o perfil da outra pessoa e procura uma conversa direta existente (inclusive com convite pendente) para não duplicar. Os convites vêm de um segundo stream do `RoomListService` filtrado por salas convidadas; aceitar usa `join` e recusar usa `leave`.
- **Alternativas consideradas:** criar a sala sem checar o perfil (o servidor aceita convidar usuários inexistentes e deixaria uma sala órfã); criar a sala sem criptografia (era a decisão original, quando o app ainda não tratava mensagens criptografadas).
- **Consequências:** só conversas diretas 1:1; não há criação de grupos, busca de usuários nem lista de contatos. O identificador é normalizado (`bob` vira `@bob:<servidor do usuário>`). Quem recebe a conversa precisa de um cliente com criptografia para lê-la.

### DT-008 — Estado compartilhado no Rust: cliente, sincronização e conversa aberta

- **Contexto:** o app tem uma conta logada por vez, e chamadas independentes vindas do Dart (login, sincronização, abrir sala, enviar, histórico, convites) precisam usar o mesmo cliente Matrix, o mesmo serviço de sincronização e a mesma conversa aberta.
- **Decisão:** três módulos internos (`client_holder`, `sync_holder` e `timeline_holder`) guardam o `Client`, o `SyncService` e o `Timeline` da sala aberta em variáveis globais protegidas por `RwLock`. Ficam fora de `api/` de propósito, porque tudo que é público ali vira função exposta ao Dart. Cada um tem um sinal de parada (`tokio::sync::watch`) que encerra os fluxos ativos. Fechar uma conversa só tem efeito se ela ainda for a aberta, para que trocar de sala rápido não feche a nova.
- **Alternativas consideradas:** devolver ao Dart um objeto opaco do cliente (`RustOpaque`) a cada chamada, o que permitiria várias contas, mas espalharia o objeto pelo estado e pelos repositórios; ou criar um objeto de sessão a cada login, com mais código de ciclo de vida.
- **Consequências:** simples e suficiente para uma conta e uma conversa por vez. Os testes Rust de integração compartilham esse estado e precisam rodar **em série** (`--test-threads=1`). Para várias contas, seria preciso migrar para o objeto opaco, mudança restrita ao Rust e aos repositórios.

---

### DT-009 — Tema próprio, janela e distribuição por GitHub Actions

- **Contexto:** o Flutter desktop não compila de um sistema para outro, e um avaliador precisa conseguir abrir o app sem montar o ambiente. A interface também precisava de aparência consistente nos três sistemas.
- **Decisão:** tema próprio (claro e escuro conforme o sistema) com a fonte Inter embutida, para o texto ficar igual em todos os sistemas, e `window_manager` para definir título, tamanho inicial e tamanho mínimo da janela. Dois workflows do GitHub Actions: **CI**, que roda só quando algo em `app/` muda e executa formatação, análise, testes e o build em Linux, Windows e macOS; e **Release**, que ao receber uma tag `v*` gera um AppImage (Linux x86_64), um zip (Windows x64) e um dmg (macOS Apple Silicon) e os publica na aba Releases. O CI usa o Flutter 3.47.6, enquanto o desenvolvimento local usou o 3.44.4.
- **Alternativas consideradas:** usar as fontes do sistema (aparência diferente em cada plataforma); distribuir só o código-fonte (exige o ambiente completo para quem avalia).
- **Consequências:** os executáveis **não são assinados**. No macOS, o Gatekeeper impede abrir o app baixado sem passos manuais (veja o README), e por isso a instalação do app gerado no Mac ainda traz problemas até haver assinatura com um Apple Developer Team. No Windows, o SmartScreen avisa. O build do macOS é só para Apple Silicon. O CI garante que o app compila nos três sistemas, mas não que ele foi executado no Windows.

---

### DT-010 — Criptografia ponta a ponta: chaves, backup e recuperação

- **Contexto:** o `matrix-sdk` já traz a criptografia (feature `e2e-encryption`, ativa por padrão) e o banco cifrado (DT-002) já guarda as chaves, mas o app só mostrava "Mensagem criptografada". Faltava criar conversas criptografadas, explicar por que uma mensagem não abre e permitir ler o histórico anterior a este dispositivo.
- **Decisão:** (1) o cliente é criado com `EncryptionSettings`: assinatura cruzada automática no login por senha (se falhar, o erro só é registrado e o login segue), download de todas as chaves do backup depois da recuperação (`OneShot`) e nenhum backup criado sem o usuário pedir. (2) As conversas diretas usam o `create_dm`, que criptografa (DT-007). (3) O Rust classifica a causa da falha de decifragem em três tipos (aguardando a chave, anterior ao dispositivo, indisponível). (4) O backup e a recuperação usam o `recovery()` do SDK, com `watch_recovery_status`, `recover_keys` e `enable_recovery` e erros tipados. A chave de recuperação nunca é guardada nem registrada: é digitada pelo usuário ou mostrada uma única vez ao ativar o backup. (5) A interface tem o botão de chave no rodapé, o aviso na conversa e o aviso ao sair. (6) Dependência direta nova, `matrix-sdk-crypto`, porque o `matrix-sdk` não reexporta o tipo da causa de falha; ela já estava na árvore e nada novo é compilado.
- **Alternativas consideradas:** verificação interativa de dispositivos (emojis ou QR) para receber as chaves de outro dispositivo, que exige muito mais telas e estados e ficou como próximo passo; guardar a chave de recuperação no cofre (aumenta a superfície, pois ela abre todo o histórico); criar o backup automaticamente no login (geraria uma chave que o usuário nunca viu, inútil para recuperar); baixar uma chave por vez (`AfterDecryptionFailure`), com o histórico aparecendo aos poucos.
- **Consequências:** mensagens novas em salas criptografadas são lidas se o remetente compartilhar a chave com este dispositivo, o que exige que o dispositivo já tenha publicado as suas chaves, ou seja, que o app já tenha sincronizado. O histórico anterior só abre com a chave de recuperação. Sem verificação, os outros clientes mostram esta sessão como não verificada. O logout apaga as chaves locais (RF-06), por isso o app avisa quando não há backup. Os testes de integração usam dois dispositivos da mesma conta e **alteram o estado do backup da conta `alice`**, então devem rodar em um Synapse separado (README). Os fluxos de criptografia só foram testados no Synapse local, não no `matrix.org`.

---

## 7. Configuração e Execução

O passo a passo (pré-requisitos por sistema, homeserver local, execução, testes e regeneração da ponte) está no [README](../README.md).

Versões usadas no desenvolvimento: Flutter 3.44.4 (Dart 3.12), Rust 1.99.0 e `flutter_rust_bridge_codegen` 2.13.0, que precisa ser a mesma versão do pacote `flutter_rust_bridge`. Os executáveis prontos e o CI estão descritos na DT-009 e no README.

Homeserver de testes: Synapse local, subido por `docker compose up -d`, com os usuários `alice`, `bob`, `carol` e `dave` (senha `senha123`) e doze salas de teste, uma delas com 80 mensagens para exercitar a paginação.

---

## 8. Limitações e Itens Não Concluídos

**Escopo**

- Só é possível criar conversas diretas 1:1, sem grupos e sem busca de usuários.
- Só é possível enviar texto simples: não há edição, exclusão, resposta nem anexos. Imagens, arquivos, enquetes e demais tipos recebidos aparecem como "Mensagem não suportada", e os avatares são só letras (RF-22).
- O reenvio de uma mensagem que falhou é manual (toque no ícone de erro); o app não tenta de novo sozinho.
- O contador de não lidas considera apenas as últimas 20 mensagens de cada sala.
- Uma conversa recém-criada é selecionada na hora, mas só aparece na lista quando a sincronização a traz; até lá, o painel mostra "Selecione uma sala".

**Segurança**

- Criptografia ponta a ponta: o app lê e envia mensagens em salas criptografadas, e as conversas que cria são criptografadas (DT-010). O histórico anterior a este dispositivo só abre com a chave de recuperação da conta. Não há verificação de dispositivos (emojis ou QR), então os outros clientes mostram esta sessão como não verificada. Mensagens cuja chave ninguém compartilhou com este dispositivo continuam ilegíveis, e o app mostra o motivo.
- Sem backup ativo, sair da conta apaga as chaves locais e as mensagens criptografadas recebidas deixam de poder ser lidas. O app avisa antes de sair.
- Contas que entram só por login único (SSO) não são suportadas, porque o app autentica por senha.
- Os executáveis das Releases não são assinados (DT-009). **No macOS, a instalação do app gerado ainda traz problemas:** o Gatekeeper bloqueia um app sem assinatura da Apple e é preciso liberá-lo manualmente (passos no README). No Windows, o SmartScreen avisa. O build do macOS é só para Apple Silicon.
- Dependências: o `cargo audit` não aponta vulnerabilidades. Restam três avisos de pacotes sem manutenção (`adler`, `anymap2` e `derivative`), vindos de dependências transitivas que o projeto não controla. No Dart, as dependências de execução estão atualizadas; só `very_good_analysis` (salto de versão principal) e `build_runner` têm versão mais nova, e ficaram como estão para não trazer regras de lint novas perto da entrega.

**Verificação**

- Plataformas: o desenvolvimento e os testes manuais foram feitos no Linux, e o app também foi executado no macOS a partir do código-fonte, sem ajustes além do Keychain (DT-002). No Windows, o CI só compila o app; ele ainda não foi executado.
- Homeservers: o app foi testado no Synapse local do Docker e, manualmente no macOS, no `matrix.org`, com uma conta criada com e-mail e senha (login, sincronização das salas e criação de uma conversa direta). Os fluxos de criptografia (DT-010) foram testados só no Synapse local. Outros servidores não foram testados; o servidor precisa suportar o sliding sync.

---

## 9. Próximos Passos

Em ordem de prioridade, com o que cada passo exige:

1. **Verificação de dispositivos e gestão de chaves.** Verificação interativa (emojis ou QR) entre dispositivos, para que as outras pessoas vejam esta sessão como confiável e para receber chaves de outro dispositivo; troca ou redefinição da chave de recuperação; e testes dos fluxos de criptografia no `matrix.org`. A base (backup e recuperação) já existe (DT-010).
2. **Grupos e busca de usuários.** Criar salas com vários participantes, pesquisar usuários no diretório e convidar para uma sala existente. A camada de conversas (DT-007) já isola esse acréscimo.
3. **Mídia.** Exibir e enviar imagens e arquivos, e carregar os avatares reais. Muda o modelo de mensagem do domínio e a política de cache em disco.
4. **Mais ações na mensagem.** Editar, apagar, responder e reações. O Timeline do SDK já expõe essas operações.
5. **Várias contas.** Trocar os módulos globais do Rust por um objeto opaco do cliente (DT-008). A mudança fica restrita ao Rust e aos repositórios.
6. **Notificações do sistema e reenvio automático.** Avisar de mensagens novas com a janela em segundo plano e tentar de novo, sozinho, as mensagens que falharam.