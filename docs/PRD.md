# Especificação Técnica de Requisitos (PRD)

Requisitos, decisões técnicas e limitações do cliente de mensageria desktop com Matrix, a partir do [desafio técnico](desafio-tecnico.md). Os diagramas estão em [FLUXOS.md](FLUXOS.md).

---

## 1. Pedido do cliente

Cliente de mensageria desktop em Flutter, com a comunicação Matrix em Rust (Matrix Rust SDK e Flutter Rust Bridge), para macOS, Windows e Linux. Não se espera um produto completo: o foco é arquitetura, qualidade, segurança, priorização e preparo para evoluir.

---

## 2. Stack técnica

| Camada              | Tecnologia                                                                 |
| ------------------- | -------------------------------------------------------------------------- |
| Interface           | Flutter (desktop)                                                          |
| Estado              | Riverpod (`flutter_riverpod` e `riverpod_generator`), ver [DT-001](#dt-001)            |
| Integração Matrix   | Rust + Matrix Rust SDK (`matrix-sdk` e `matrix-sdk-ui` 0.19.1)             |
| Ponte Dart <-> Rust | Flutter Rust Bridge 2.13.0                                                 |
| Persistência local  | Sessão e senha do banco no cofre do sistema (`flutter_secure_storage`), servidor salvo em `shared_preferences` e cache do SDK em SQLite, ver [DT-002](#dt-002) |
| Criptografia        | E2EE do `matrix-sdk` (chaves no banco SQLite cifrado); backup e recuperação pelo armazenamento de segredos da conta, ver [DT-010](#dt-010) |
| Plataformas         | Linux, macOS, Windows                                                      |
| Janela e tema       | `window_manager` (tamanho inicial e mínimo da janela); fonte Inter embutida; tema claro e escuro conforme o sistema |
| CI e distribuição   | GitHub Actions: CI (análise, testes e build nos três sistemas) e Release (executáveis), ver [DT-009](#dt-009) |
| Testes              | `flutter_test` (unidade e widget) e `cargo test` (unidade e integração opcional contra o Synapse local) |
| Qualidade estática  | `very_good_analysis` no Dart e `cargo clippy` no Rust, ver [DT-004](#dt-004)          |
| Homeserver de teste | Synapse via Docker Compose                                                 |

Versões usadas no desenvolvimento: Flutter 3.44.4 (Dart 3.12), Rust 1.99.0 e `flutter_rust_bridge_codegen` 2.13.0, que precisa ser igual à do pacote `flutter_rust_bridge`.

---

## 3. Requisitos funcionais

Os números dos requisitos não mudam, então a ordem de leitura nem sempre é sequencial.

### 3.1. Sessão

| ID    | Requisito                                                                                              |
| ----- | ------------------------------------------------------------------------------------------------------ |
| <a id="rf-01"></a>RF-01 | O usuário informa homeserver, usuário e senha para autenticar. O campo de senha começa oculto e tem um botão (ícone de olho) para mostrá-la ou ocultá-la.                                         |
| <a id="rf-02"></a>RF-02 | O homeserver informado é validado (URL válida e servidor Matrix alcançável) antes do login.            |
| <a id="rf-03"></a>RF-03 | Após login bem-sucedido, a sessão é persistida de forma segura.                                        |
| <a id="rf-04"></a>RF-04 | Ao abrir o app, a sessão salva é restaurada automaticamente, sem pedir login de novo.                  |
| <a id="rf-05"></a>RF-05 | Se o servidor deixar de aceitar o token da sessão, o app apaga os dados locais e volta ao login com o aviso "Sua sessão expirou". Isso é detectado na restauração ou durante a sincronização. Uma falha de restauração por outro motivo volta ao login sem apagar os dados salvos. |
| <a id="rf-06"></a>RF-06 | O logout invalida a sessão no homeserver, apaga os dados locais e volta ao login. O logout apaga os dados locais mesmo que o servidor não responda. O botão Sair, com ícone de logout, fica no rodapé da lista de salas, ao lado do usuário logado. |
| <a id="rf-21"></a>RF-21 | O login oferece a opção "Salvar servidor": se marcada, o servidor informado é lembrado e já vem preenchido no próximo login. Usuário e senha nunca são salvos. |

### 3.2. Salas

| ID    | Requisito                                                                                      |
| ----- | ---------------------------------------------------------------------------------------------- |
| <a id="rf-07"></a>RF-07 | O app lista as salas em que o usuário participa, com avatar, nome, última mensagem e horário (hora no mesmo dia, "Ontem", dia da semana na última semana, ou dd/mm). |
| <a id="rf-08"></a>RF-08 | A lista é ordenada pela atividade mais recente.                                                |
| <a id="rf-09"></a>RF-09 | A lista se atualiza sozinha quando chegam novas mensagens ou salas.                            |
| <a id="rf-10"></a>RF-10 | O usuário seleciona uma sala para abrir a conversa.                                            |
| <a id="rf-11"></a>RF-11 | Salas com mensagens não lidas são destacadas na lista, com um indicador de não lidas.          |
| <a id="rf-22"></a>RF-22 | O avatar de cada sala é um círculo com a inicial do nome, em uma cor escolhida a partir do identificador da sala (a mesma sala tem sempre a mesma cor). O app não carrega imagens de avatar. |
| <a id="rf-28"></a>RF-28 | A lista tem um campo "Buscar conversas" que filtra as salas pelo nome, sem diferenciar maiúsculas nem acentos. |
| <a id="rf-29"></a>RF-29 | O cabeçalho da conversa mostra o nome da sala e a quantidade de membros. O menu do cabeçalho abre os detalhes da sala (participantes e ID) e copia o ID da sala. |

### 3.3. Mensagens

| ID    | Requisito                                                                                                 |
| ----- | --------------------------------------------------------------------------------------------------------- |
| <a id="rf-12"></a>RF-12 | A conversa exibe as mensagens de texto da sala, com o horário de cada mensagem.                           |
| <a id="rf-13"></a>RF-13 | O usuário envia mensagens de texto pelo campo de envio (Enter envia, Shift+Enter quebra linha).           |
| <a id="rf-14"></a>RF-14 | A mensagem enviada aparece imediatamente com estado "enviando" e muda para "enviada" ou "falhou".         |
| <a id="rf-15"></a>RF-15 | Mensagens com falha podem ser reenviadas.                                                                 |
| <a id="rf-16"></a>RF-16 | Novas mensagens recebidas aparecem na conversa aberta sem ação do usuário.                                |
| <a id="rf-17"></a>RF-17 | Ao rolar até o topo, mensagens mais antigas são carregadas (paginação).                                   |
| <a id="rf-23"></a>RF-23 | As mensagens de outros participantes mostram o nome de quem enviou, acima da bolha.                       |

### 3.4. Estados da interface

| ID    | Requisito                                                                                          |
| ----- | -------------------------------------------------------------------------------------------------- |
| <a id="rf-18"></a>RF-18 | Telas exibem estados de carregamento, vazio e erro (ex.: "nenhuma sala", "sem conexão").           |
| <a id="rf-19"></a>RF-19 | Perda de conexão é sinalizada por um aviso fixo no topo da tela principal, visível em qualquer largura e com qualquer conversa aberta. A sincronização retoma sozinha quando a rede volta. Se a sincronização falhar de forma irrecuperável, o aviso oferece o botão "Tentar de novo". |
| <a id="rf-20"></a>RF-20 | Erros vindos do Rust são traduzidos em mensagens claras, sem expor detalhes técnicos ou tokens.    |
| <a id="rf-24"></a>RF-24 | Em janela larga (a partir de 720 px), a tela principal mostra salas e conversa lado a lado. Em janela estreita, mostra só a lista, e a conversa abre por cima dela. |
| <a id="rf-25"></a>RF-25 | Quando nenhuma sala está selecionada, o painel da conversa mostra a mensagem "Selecione uma sala". |
| <a id="rf-26"></a>RF-26 | O usuário cria uma conversa direta pelo botão "Nova conversa", informando o identificador de outro usuário (por exemplo `@bob:localhost` ou só `bob`). Se já existir uma conversa direta com essa pessoa, ela é reaberta em vez de duplicada. |
| <a id="rf-27"></a>RF-27 | Convites recebidos aparecem em uma seção "Convites" no topo da lista, com as ações Aceitar e Recusar. Aceitar abre a conversa. |
| <a id="rf-30"></a>RF-30 | Atalhos de teclado: Ctrl+K (⌘K no macOS) foca a busca, Ctrl+N (⌘N) abre "Nova conversa" e Esc fecha a conversa aberta ou limpa a busca. |

### 3.5. Criptografia

| ID    | Requisito |
| ----- | --------- |
| <a id="rf-31"></a>RF-31 | O app lê e envia mensagens em salas com criptografia ponta a ponta, e as conversas diretas que cria são criptografadas. |
| <a id="rf-32"></a>RF-32 | Uma mensagem que não pôde ser decifrada mostra o motivo: aguardando a chave, anterior a este dispositivo, ou indisponível (por exemplo, enviada antes de o usuário entrar na sala). |
| <a id="rf-33"></a>RF-33 | O botão de chave no rodapé abre o backup das mensagens. Se a conta já tem backup mas este dispositivo não tem as chaves (estado incompleto), o app pede a chave de recuperação e, com ela, passa a ler o histórico; uma chave incorreta é recusada. Se a conta não tem backup, o app oferece ativá-lo e mostra a chave de recuperação uma única vez, com botão de copiar. No estado incompleto, uma conversa com mensagens ilegíveis mostra o aviso "Recuperar chaves". Ao sair da conta sem backup ativo, o app avisa que as mensagens criptografadas recebidas neste dispositivo não poderão ser lidas depois. |

---

## 4. Requisitos não funcionais

| Tema | Como é tratado |
| ---- | -------------- |
| Multiplataforma | Preparado para macOS, Windows e Linux. |
| Arquitetura | Separação entre UI, estado, acesso ao Matrix e Rust ([DT-003](#dt-003)). |
| Desempenho | A UI não trava durante a sincronização nem o carregamento do histórico. |
| Manutenibilidade | Estrutura de pastas por feature, que facilita a evolução. |
| Testes | Cobertura da lógica de estado, da camada Rust e dos fluxos críticos. |
| Senha | Digitada no login, enviada ao servidor e descartada: o campo é limpo ao enviar e a senha não é gravada em lugar nenhum. |
| Token e sessão | Só no cofre do sistema ([DT-002](#dt-002)). Nunca em arquivo, `shared_preferences` ou log. |
| Banco local do SDK | SQLite cifrado com uma passphrase aleatória guardada no cofre. Guarda também as chaves de criptografia das conversas. |
| Chave de recuperação | Nunca é gravada nem registrada em log. Só aparece na tela uma vez, quando o backup é ativado, ou é digitada pelo usuário para recuperar o histórico ([DT-010](#dt-010)). |
| Rede | HTTPS obrigatório. `http://` só é aceito para `localhost`, `127.0.0.1` e `::1`, para o homeserver de desenvolvimento. URLs com usuário e senha embutidos são recusadas. |
| Logout | Invalida a sessão no servidor e apaga cofre e dados locais, mesmo que o servidor não responda ([RF-06](#rf-06)). |
| Token recusado | Apaga os dados locais e volta ao login com aviso ([RF-05](#rf-05)). |
| Mensagens | As conversas criadas pelo app são criptografadas ponta a ponta ([DT-010](#dt-010)). |
| Erros | O Rust devolve erros tipados; a interface mostra mensagens em português, sem detalhes técnicos, URLs com token ou credenciais ([RF-20](#rf-20)). |
| Logs | O código de produção não registra senha, token nem corpo de mensagens. |

---

## 5. Interface e fluxos

O app tem três telas, com tema claro e escuro conforme o sistema e a fonte Inter. A janela abre em 1100 x 720 e não encolhe abaixo de 480 x 600.

| Tela | Conteúdo | Requisitos |
| ---- | -------- | ---------- |
| Login | Servidor, usuário e senha, com a opção de salvar o servidor | [RF-01](#rf-01) a [RF-03](#rf-03), [RF-21](#rf-21) |
| Lista de salas | Busca, "Nova conversa", convites, salas por atividade e rodapé com o usuário e o botão Sair | [RF-07](#rf-07) a [RF-11](#rf-11), [RF-26](#rf-26) a [RF-28](#rf-28) |
| Conversa | Cabeçalho da sala, mensagens com histórico e campo de envio | [RF-10](#rf-10), [RF-12](#rf-12) a [RF-17](#rf-17), [RF-29](#rf-29) |

O [wireframe](img/wireframe.png) inicial (lista à esquerda, conversa à direita, inspirado no Telegram) foi o ponto de partida. O visual atual mudou bastante.

- Layout responsivo ([RF-24](#rf-24)): em janela larga, salas e conversa ficam lado a lado. Em janela estreita aparece só a lista, e a conversa abre por cima dela, com a seta de voltar.
- Rodapé ([RF-06](#rf-06)): mostra o usuário logado (avatar, nome e identificador completo) e o botão Sair.
- Mensagens: cada uma mostra o horário, e as de outros participantes mostram o nome de quem enviou acima da bolha ([RF-12](#rf-12), [RF-23](#rf-23)). As próprias mostram o estado: enviando, enviada ou falhou ([RF-14](#rf-14)).
- Sem sala selecionada, o painel mostra "Selecione uma sala" ([RF-25](#rf-25)).
- Os avatares são só letras, sem imagens ([RF-22](#rf-22)).
- Carregamento, vazio e offline seguem o [RF-18](#rf-18) e o [RF-19](#rf-19). O aviso de conexão ("Sem conexão. Tentando reconectar..." ou "Não foi possível sincronizar." com o botão "Tentar de novo") fica fixo no topo da tela principal.

Os diagramas de fluxo estão em [FLUXOS.md](FLUXOS.md).

---

## 6. Decisões técnicas

### <a id="dt-001"></a>DT-001: Gerenciamento de estado com Riverpod

O app consome streams do Rust (sincronização, salas e conversa) e precisa de estados de carregamento, vazio e erro ([RF-18](#rf-18)), com a lógica de estado testável. Ele usa `flutter_riverpod` com `riverpod_generator` (`AsyncNotifier` e `Notifier`), e os repositórios entram como providers. O `AsyncValue` cobre carregando, erro e dados, o `autoDispose` cancela os streams ao descartar, e os testes trocam os repositórios por fakes com `overrides`. O custo é depender do `build_runner` para gerar os providers.

Ficaram de fora o BLoC (mais código para fluxos de stream), o Provider (injeção e testes mais fracos), o `setState` (não escala) e o GetX (mistura responsabilidades).

### <a id="dt-002"></a>DT-002: Sessão no cofre do sistema

Credenciais e tokens não podem ficar em texto puro nem em log ([RF-03](#rf-03)). O `flutter_secure_storage` guarda no cofre do sistema (libsecret no Linux, Keychain no macOS, Credential Manager no Windows) a sessão serializada e uma passphrase aleatória de 32 bytes, que cifra o banco SQLite do Matrix SDK. A senha do usuário nunca é gravada. O logout e a sessão recusada pelo servidor apagam as duas chaves e a pasta de dados do SDK ([RF-05](#rf-05), [RF-06](#rf-06)). O servidor escolhido no login, que não é segredo, fica em `shared_preferences`.

No macOS, o plugin usa por padrão o Keychain "data protection", que exige o entitlement `keychain-access-groups`, só disponível em builds assinados com um Apple Developer Team. Com a assinatura ad-hoc do build local, a gravação falhava com o erro -34018 e o login terminava em "Algo deu errado". Por isso o app usa o Keychain tradicional (`usesDataProtectionKeychain: false`, em `app_secure_storage.dart`). Ele protege um pouco menos, mas serve para este escopo, e um app assinado com um Team poderia voltar ao "data protection".

Foram descartados `shared_preferences` ou um arquivo JSON (texto puro), um arquivo cifrado com chave própria (a chave teria de ficar em algum lugar, e o cofre já resolve isso) e guardar tudo só no Rust (acoplaria mais a restauração ao SDK). No Linux, a solução depende de um serviço de segredos (libsecret) na máquina. A passphrase protege também as chaves de criptografia das conversas ([DT-010](#dt-010)).

### <a id="dt-003"></a>DT-003: Arquitetura em camadas por feature

O PRD pede separação clara entre UI, estado, acesso ao Matrix e Rust. Cada feature se divide em `ui`, `state`, `data` e `domain`. Todo acesso ao Matrix acontece no Rust, e o repositório Dart é o único ponto que conhece os tipos gerados pelo FRB e os converte em modelos de domínio. Os erros chegam do Rust como enums, e a interface os traduz em mensagens ([RF-20](#rf-20)). Isso gera mais arquivos por feature, em troca de testes simples, com repositório falso. Foram descartadas a organização por tipo de arquivo (menos coesa) e a chamada da ponte direto dos widgets (acopla a UI ao FRB).

### <a id="dt-004"></a>DT-004: Qualidade estática

O desafio valoriza qualidade e verificação objetiva. O Dart usa `very_good_analysis`, com `public_member_api_docs` desligada porque é um app e não uma biblioteca, e o Rust usa `cargo clippy --all-targets -- -D warnings`. O código gerado (FRB e `*.g.dart`) fica fora da análise. O `flutter_lints` foi descartado por ter regras mais brandas.

### <a id="dt-005"></a>DT-005: Sincronização e lista de salas

O app precisa manter as salas atualizadas sem polling próprio e detectar quando o token deixa de valer ([RF-05](#rf-05), [RF-09](#rf-09), [RF-19](#rf-19)). Para isso usa o `SyncService` e o `RoomListService` do `matrix-sdk-ui` (sliding sync), com o modo offline ligado para reconectar sozinho. Ao entrar em offline, o Rust chama `whoami`: se o servidor responder "token desconhecido", o status vira sessão expirada e o app volta ao login com um aviso. A lista e o status chegam ao Dart como streams, e a lista já vem ordenada por atividade. Os watchers terminam por um sinal de parada, para não ficarem pendurados depois do logout.

O contador de não lidas é calculado no cliente (mensagens depois da última do próprio usuário, limitado às últimas 20 por sala), porque nesse protocolo o contador do servidor vem zerado. A alternativa, o `/sync` clássico com `Client::sync`, seria mais simples, mas exigiria calcular a última mensagem e a ordenação por conta própria.

### <a id="dt-006"></a>DT-006: Conversa com o Timeline do matrix-sdk-ui

A conversa precisa mostrar mensagens em tempo real, com remetente, horário, estado de envio e histórico ([RF-12](#rf-12), [RF-14](#rf-14), [RF-16](#rf-16), [RF-17](#rf-17), [RF-23](#rf-23)). O Rust guarda um `Timeline` por sala aberta. O Dart pede para abrir e fechar a sala e observa um stream de mensagens já convertidas (`ChatMessage`), cada uma com o identificador único do item da timeline, que continua o mesmo quando uma mensagem local vira remota. Mensagens de outros participantes marcam a sala como lida.

O envio usa a fila do SDK: a mensagem aparece na hora como "enviando" e muda para "enviada". Sem rede, fica como "falhou" até o usuário tocar no ícone de erro, que reativa a fila e reenvia ([RF-14](#rf-14), [RF-15](#rf-15)). O histórico vem em páginas de 30 mensagens, quando a lista chega perto do topo ([RF-17](#rf-17)), com `paginate_backwards`. A tela mostra um indicador de carregamento, o aviso "Início da conversa" ou, se falhar, um botão para tentar de novo. Mensagens que não são texto aparecem como "Mensagem não suportada", e as que não puderam ser decifradas mostram o motivo ([RF-32](#rf-32)). Montar a conversa direto dos eventos do sync foi descartado, porque reimplementaria agrupamento, edições e mensagens locais.

### <a id="dt-007"></a>DT-007: Nova conversa e convites

Sem criar conversas, o usuário só veria as salas que já existem no servidor, e quem recebe uma conversa nova só a vê depois de aceitar o convite ([RF-26](#rf-26), [RF-27](#rf-27)). A conversa direta é criada com o `create_dm` do SDK (`is_direct`, preset de conversa privada confiável, convite e criptografia ativada, [DT-010](#dt-010)). Antes, o Rust consulta o perfil da outra pessoa e procura uma conversa direta existente, inclusive com convite pendente, para não duplicar. Os convites vêm de um segundo stream do `RoomListService`, filtrado por salas convidadas. Aceitar usa `join` e recusar usa `leave`.

Criar a sala sem checar o perfil foi descartado: o servidor aceita convidar usuários inexistentes e deixaria uma sala órfã. Só há conversas diretas 1:1, sem grupos, busca de usuários nem lista de contatos. O identificador é normalizado (`bob` vira `@bob:<servidor do usuário>`), e quem recebe a conversa precisa de um cliente com criptografia para lê-la.

### <a id="dt-008"></a>DT-008: Estado compartilhado no Rust

O app tem uma conta logada por vez, e as chamadas independentes do Dart (login, sincronização, abrir sala, enviar, histórico, convites) precisam usar o mesmo cliente Matrix, o mesmo serviço de sincronização e a mesma conversa aberta. Três módulos internos (`client_holder`, `sync_holder` e `timeline_holder`) guardam o `Client`, o `SyncService` e o `Timeline` da sala aberta em variáveis globais protegidas por `RwLock`. Ficam fora de `api/` de propósito, porque tudo que é público ali vira função exposta ao Dart. Cada um tem um sinal de parada (`tokio::sync::watch`) que encerra os fluxos ativos, e fechar uma conversa só tem efeito se ela ainda for a aberta, para que trocar de sala rápido não feche a nova.

É simples e basta para uma conta e uma conversa por vez. Os testes de integração compartilham esse estado e por isso rodam em série (`--test-threads=1`). As alternativas eram devolver ao Dart um objeto opaco do cliente (`RustOpaque`) a cada chamada, o que permitiria várias contas mas espalharia o objeto pelo estado e pelos repositórios, ou criar um objeto de sessão a cada login, com mais código de ciclo de vida. Para várias contas, a migração para o objeto opaco ficaria restrita ao Rust e aos repositórios.

### <a id="dt-009"></a>DT-009: Tema próprio, janela e distribuição

O Flutter desktop não compila de um sistema para outro, e quem avalia precisa conseguir abrir o app sem montar o ambiente. A interface também precisava ter a mesma aparência nos três sistemas. O app tem tema próprio (claro e escuro conforme o sistema) com a fonte Inter embutida, e usa `window_manager` para definir título, tamanho inicial e tamanho mínimo da janela. Dois workflows do GitHub Actions cuidam do resto. O CI roda só quando algo em `app/` muda e executa formatação, análise, testes e o build em Linux, Windows e macOS. O Release roda depois que o CI passa na `main`: calcula a versão pelos commits que mexem em `app/` (Conventional Commits: `feat` sobe a minor, `fix` e `perf` a patch, e `!` ou `BREAKING CHANGE` a major), gera um AppImage (Linux x86_64), um zip (Windows x64) e um dmg (macOS Apple Silicon), cria a tag e publica a Release com as notas montadas dos commits. Sem commit que gere versão, nada é publicado. O CI usa o Flutter 3.47.6, enquanto o desenvolvimento local usou o 3.44.4.

Os executáveis não são assinados. No macOS, o Gatekeeper bloqueia o app baixado, e a instalação do app gerado ainda traz problemas até haver assinatura com um Apple Developer Team. No Windows, o SmartScreen avisa. Os três executáveis foram testados manualmente e foram as versões mais usadas nos testes. Foram descartados usar as fontes do sistema (aparência diferente em cada plataforma) e distribuir só o código-fonte (exige o ambiente completo).

### <a id="dt-010"></a>DT-010: Criptografia ponta a ponta, backup e recuperação

O `matrix-sdk` já traz a criptografia (feature `e2e-encryption`, ativa por padrão) e o banco cifrado ([DT-002](#dt-002)) já guarda as chaves, mas o app só mostrava "Mensagem criptografada". Faltava criar conversas criptografadas, explicar por que uma mensagem não abre e ler o histórico anterior ao dispositivo.

O cliente é criado com `EncryptionSettings`: assinatura cruzada automática no login por senha (se falhar, o erro só é registrado e o login segue), download de todas as chaves do backup depois da recuperação (`OneShot`) e nenhum backup criado sem o usuário pedir. As conversas diretas usam o `create_dm`, que já criptografa ([DT-007](#dt-007)). O Rust classifica a causa de uma falha de decifragem em três tipos: aguardando a chave, anterior ao dispositivo e indisponível. O backup e a recuperação usam o `recovery()` do SDK, com `watch_recovery_status`, `recover_keys` e `enable_recovery`, e erros tipados. A chave de recuperação nunca é guardada nem registrada: o usuário a digita, ou ela aparece uma única vez ao ativar o backup. Na interface, há o botão de chave no rodapé, o aviso na conversa e o aviso ao sair. A dependência direta `matrix-sdk-crypto` é nova porque o `matrix-sdk` não reexporta o tipo da causa de falha. Ela já estava na árvore, então nada novo é compilado.

Ficaram de fora a verificação interativa de dispositivos (emojis ou QR), que exige muito mais telas e estados, e guardar a chave de recuperação no cofre, o que aumentaria a superfície, já que ela abre todo o histórico. Também foram descartados o backup automático no login (geraria uma chave que o usuário nunca viu) e baixar uma chave por vez (`AfterDecryptionFailure`), que faria o histórico aparecer aos poucos.

Mensagens novas são lidas se o remetente compartilhar a chave com este dispositivo, o que exige que ele já tenha publicado as suas chaves, ou seja, que o app já tenha sincronizado. O histórico anterior só abre com a chave de recuperação, e, sem verificação, os outros clientes mostram esta sessão como não verificada. O logout apaga as chaves locais ([RF-06](#rf-06)), por isso o app avisa quando não há backup. Os testes de integração usam dois dispositivos da mesma conta e alteram o estado do backup da conta `alice`, então devem rodar em um Synapse separado (veja o README). Os fluxos de criptografia só foram testados no Synapse local, não no `matrix.org`.

---

## 7. Limitações e itens não concluídos

### Escopo

- Só conversas diretas 1:1, sem grupos nem busca de usuários.
- Só texto simples: sem edição, exclusão, resposta nem anexos. Os outros tipos de mensagem aparecem como "Mensagem não suportada", e os avatares são só letras ([RF-22](#rf-22)).
- O reenvio de uma mensagem que falhou é manual.
- O contador de não lidas considera só as últimas 20 mensagens de cada sala.
- Uma conversa recém-criada só aparece na lista quando a sincronização a traz; até lá, o painel mostra "Selecione uma sala".

### Segurança

- Criptografia: o app lê e envia em salas criptografadas e cria conversas criptografadas ([DT-010](#dt-010)). O histórico anterior a este dispositivo só abre com a chave de recuperação, e sem backup ativo sair da conta faz perder as chaves locais (o app avisa). Não há verificação de dispositivos, então os outros clientes mostram esta sessão como não verificada.
- Contas que entram só por login único (SSO) não são suportadas, porque o app autentica por senha.
- Os executáveis das Releases não são assinados ([DT-009](#dt-009)). No macOS a instalação ainda traz problemas, porque o Gatekeeper bloqueia o app; no Windows, o SmartScreen avisa.
- Dependências: o `cargo audit` não aponta vulnerabilidades. Restam três avisos de pacotes sem manutenção (`adler`, `anymap2` e `derivative`), vindos de dependências transitivas. No Dart, só `very_good_analysis` e `build_runner` têm versão mais nova, e ficaram como estão para não trazer regras de lint novas perto da entrega.

### Verificação

- Plataformas: o app foi testado manualmente no Linux, no Windows e no macOS, sobretudo com os executáveis da aba Releases. O CI compila nos três sistemas.
- Homeservers: testado no Synapse local e no `matrix.org` (conta com e-mail e senha). Os fluxos de criptografia ([DT-010](#dt-010)) só foram testados no Synapse local. Outros servidores não foram testados, e o servidor precisa suportar o sliding sync.

---

## 8. Próximos passos

Por ordem de prioridade:

1. Verificação de dispositivos e gestão de chaves: verificação interativa (emojis ou QR) entre dispositivos, para que as outras pessoas vejam esta sessão como confiável e para receber chaves de outro dispositivo; troca da chave de recuperação; e testes da criptografia no `matrix.org`. A base (backup e recuperação) já existe ([DT-010](#dt-010)).
2. Grupos e busca de usuários: salas com vários participantes, busca no diretório e convite para uma sala existente. A camada de conversas ([DT-007](#dt-007)) já isola esse acréscimo.
3. Mídia: exibir e enviar imagens e arquivos e carregar os avatares reais. Muda o modelo de mensagem e a política de cache em disco.
4. Mais ações na mensagem: editar, apagar, responder e reagir. O Timeline do SDK já oferece essas operações.
5. Várias contas: trocar os módulos globais do Rust por um objeto opaco do cliente ([DT-008](#dt-008)), mudança restrita ao Rust e aos repositórios.
6. Notificações do sistema e reenvio automático: avisar de mensagens novas com a janela em segundo plano e tentar de novo, sozinho, as mensagens que falharam.
