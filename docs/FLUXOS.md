# Fluxos do sistema

Diagramas do cliente, organizados pelo tipo de diagrama, com o comportamento atual e ligados aos requisitos do [PRD](PRD.md). Só entram os fluxos que mostram algo não óbvio (decisões, ramos de erro, comportamento assíncrono ou mais de um ator); o resto está descrito nos requisitos.

## Legenda dos participantes

| Nome | O que é |
| ---- | ------- |
| Flutter | Interface e estado do aplicativo (Dart) |
| Rust | Biblioteca nativa com o Matrix Rust SDK, ligada ao Flutter pelo Flutter Rust Bridge |
| Homeserver | Servidor Matrix (por exemplo, o Synapse local do Docker) |
| Cofre do sistema | Armazenamento seguro do sistema operacional (Keychain, libsecret ou Credential Manager) |

---

## 1. Diagramas de atividade

### 1.1. Inicialização e restauração da sessão

Requisitos: [RF-04](PRD.md#rf-04), [RF-05](PRD.md#rf-05).

A restauração é local, sem validar o token no servidor. Um token recusado só aparece depois, já na tela principal (veja 1.3).

```mermaid
flowchart LR
    A([Abre o app]) --> B{"Há sessão salva?"}
    B -- Não --> L([Login])
    B -- Sim --> C["Restaura a sessão no Rust"]
    C --> D{"Restaurou?"}
    D -- Sim --> P(["Principal e sincronização"])
    D -- "Token inválido" --> E["Apaga os dados locais"] --> L
    D -- "Outra falha" --> F["Mantém os dados salvos"] --> L
```

### 1.2. Login

Requisitos: [RF-01](PRD.md#rf-01), [RF-02](PRD.md#rf-02), [RF-03](PRD.md#rf-03), [RF-20](PRD.md#rf-20), [RF-21](PRD.md#rf-21).

```mermaid
flowchart LR
    A[Preenche servidor, usuário e senha] --> B{"Campos preenchidos?"}
    B -- Não --> E1[Destaca os campos]
    B -- Sim --> C{"URL válida e segura?"}
    C -- Não --> E2["Erro: endereço inválido ou use https"]
    C -- Sim --> D["Rust conecta e autentica"]
    D -- "Servidor inalcançável" --> E3[Erro de conexão]
    D -- "Credenciais inválidas" --> E4[Erro de credenciais]
    D -- "Muitas tentativas" --> E5[Aguardar e tentar de novo]
    D -- Ok --> S["Salva a sessão no cofre do sistema"]
    S -- Falha --> E6["Desfaz o login e mostra erro"]
    S -- Ok --> V["Lembra ou esquece o servidor"]
    V --> P([Principal])
```

O endereço precisa ser `https`, exceto para `localhost`. Sem esquema, o app completa.

### 1.3. Sessão expirada durante o uso

Requisito: [RF-05](PRD.md#rf-05).

```mermaid
flowchart LR
    A["Sincronização em andamento"] --> B{"O servidor recusa o token?"}
    B -- Não --> A
    B -- Sim --> C["Logout silencioso apaga os dados locais"]
    C --> D["Registra o aviso de sessão expirada"]
    D --> L(["Login com o aviso Sua sessão expirou"])
```

### 1.4. Enviar mensagem

Requisitos: [RF-13](PRD.md#rf-13), [RF-14](PRD.md#rf-14), [RF-15](PRD.md#rf-15).

```mermaid
flowchart LR
    A["Digita no campo"] --> B{"Como envia?"}
    B -- "Shift e Enter" --> A
    B -- "Enter ou botão Enviar" --> C{"Só espaços?"}
    C -- Sim --> A
    C -- Não --> D["Limpa o campo e mantém o foco"]
    D --> E["Mensagem aparece como enviando"]
    E --> F{"Servidor confirmou?"}
    F -- Sim --> G["Estado: enviada"]
    F -- Não --> H["Estado: falhou, com ícone de erro"]
    H -->|"Toca no ícone"| E
```

### 1.5. Carregar o histórico

Requisito: [RF-17](PRD.md#rf-17).

```mermaid
flowchart LR
    A["Lista perto do topo ou curta demais"] --> B{"Já carregando ou no início?"}
    B -- Sim --> Z([Nada a fazer])
    B -- Não --> C["Mostra o indicador e pede 30 mensagens"]
    C --> D{"Resultado"}
    D -- "Chegou ao início" --> E["Mostra Início da conversa"]
    D -- "Há mais" --> F["Mensagens antigas entram no topo"] --> A
    D -- Falha --> G["Mostra Tentar de novo"]
    G -->|Toca| C
```

A posição de leitura não pula: as mensagens antigas entram acima do que o usuário está vendo.

### 1.6. Nova conversa

Requisito: [RF-26](PRD.md#rf-26).

```mermaid
flowchart LR
    A([Toca em Nova conversa]) --> B["Informa o usuário"]
    B --> C{"Formato válido?"}
    C -- Não --> E1[Erro no diálogo]
    C -- Sim --> D{"É o próprio usuário?"}
    D -- Sim --> E2[Erro no diálogo]
    D -- Não --> F{"Já existe conversa com ele?"}
    F -- Sim --> R1(["Abre a conversa existente"])
    F -- Não --> G{"O usuário existe?"}
    G -- Não --> E3[Erro: usuário não encontrado]
    G -- Sim --> H["Cria a conversa e convida a pessoa"]
    H --> R2(["Abre a nova conversa"])
```

O app consulta o perfil antes de criar, porque o servidor aceita convidar usuários que não existem e deixaria uma sala órfã.

### 1.7. Backup e recuperação das mensagens

Requisito: [RF-33](PRD.md#rf-33).

```mermaid
flowchart LR
    A([Toca no botão de chave]) --> B{"Estado do backup"}
    B -- Incompleto --> C["Informa a chave de recuperação"]
    C --> D{"Chave correta?"}
    D -- Não --> E1[Erro no diálogo]
    D -- Sim --> F["Chaves importadas e histórico baixado"]
    F --> R1(["Mensagens antigas passam a abrir"])
    B -- Desativado --> G["Ativa o backup"]
    G --> H["Mostra a chave uma única vez"]
    H --> R2(["Backup ativo"])
    B -- Ativo --> R3(["Informa que o backup está ativo"])
```

"Incompleto" quer dizer que a conta já tem backup, mas este dispositivo ainda não tem as chaves. "Desativado" quer dizer que a conta não tem backup.

---

## 2. Diagrama de estados

### 2.1. Sincronização

Requisitos: [RF-09](PRD.md#rf-09), [RF-19](PRD.md#rf-19).

```mermaid
stateDiagram-v2
    [*] --> Conectando
    Conectando --> Sincronizado: primeiro sync ok
    Conectando --> Offline: sem rede
    Sincronizado --> Offline: perde a rede
    Offline --> Sincronizado: a rede volta
    Conectando --> SessaoExpirada: token recusado
    Sincronizado --> SessaoExpirada: token recusado
    Offline --> SessaoExpirada: token recusado
    Conectando --> Falha: erro sem recuperação
    Sincronizado --> Falha: erro sem recuperação
    Falha --> Conectando: Tentar de novo
    SessaoExpirada --> [*]: logout e login com aviso
```

No estado Offline, o SDK tenta reconectar sozinho. Para distinguir "sem rede" de "token recusado", o Rust consulta o servidor (`whoami`) ao entrar em Offline.

---

## 3. Diagramas de sequência

### 3.1. Login

Requisitos: [RF-01](PRD.md#rf-01) a [RF-03](PRD.md#rf-03).

```mermaid
sequenceDiagram
    actor U as Usuário
    participant UI as Flutter
    participant C as Cofre do sistema
    participant R as Rust
    participant H as Homeserver
    U->>UI: informa servidor, usuário e senha
    UI->>UI: valida os campos e normaliza a URL
    UI->>C: lê ou cria a senha do banco local
    UI->>R: login com servidor, usuário, senha e senha do banco
    R->>H: POST login
    H-->>R: sessão com token de acesso
    R-->>UI: dados da sessão
    UI->>C: grava a sessão
    UI->>UI: lembra ou esquece o servidor
    UI-->>U: abre a tela principal
```

### 3.2. Abrir uma sala e receber mensagens em tempo real

Requisitos: [RF-09](PRD.md#rf-09), [RF-10](PRD.md#rf-10), [RF-12](PRD.md#rf-12), [RF-16](PRD.md#rf-16), [RF-19](PRD.md#rf-19).

```mermaid
sequenceDiagram
    actor U as Usuário
    participant UI as Flutter
    participant R as Rust
    participant H as Homeserver
    U->>UI: seleciona uma sala
    UI->>R: abrir a sala
    R->>H: inscreve a sala na sincronização
    R-->>UI: sala aberta
    UI->>R: observar as mensagens
    R-->>UI: mensagens atuais
    loop enquanto a sala está aberta
        H-->>R: sync com novos eventos
        R-->>UI: mensagens novas, salas, convites e status da conexão
        R->>H: marca como lida quando chegam mensagens de outros
    end
    U->>UI: seleciona outra sala
    UI->>R: fechar a sala anterior
```

### 3.3. Enviar e reenviar uma mensagem

Requisitos: [RF-13](PRD.md#rf-13), [RF-14](PRD.md#rf-14), [RF-15](PRD.md#rf-15).

```mermaid
sequenceDiagram
    actor U as Usuário
    participant UI as Flutter
    participant R as Rust
    participant H as Homeserver
    U->>UI: Enter
    UI->>R: enviar o texto
    R-->>UI: mensagem local, no estado enviando
    R->>H: PUT mensagem
    alt o servidor confirma
        H-->>R: confirmado
        R-->>UI: estado enviada
    else sem rede ou erro
        R-->>UI: estado falhou
        U->>UI: toca no ícone de erro
        UI->>R: reenviar
        R->>H: PUT mensagem
        H-->>R: confirmado
        R-->>UI: estado enviada
    end
```

### 3.4. Nova conversa e convite

Requisitos: [RF-26](PRD.md#rf-26), [RF-27](PRD.md#rf-27).

```mermaid
sequenceDiagram
    actor A as Alice
    participant PA as App da Alice
    participant H as Homeserver
    participant PB as App do Bob
    actor B as Bob
    A->>PA: informa bob em Nova conversa
    PA->>PA: normaliza para @bob:localhost
    PA->>H: GET perfil de @bob
    H-->>PA: o perfil existe
    PA->>H: POST criar sala direta e convidar o Bob
    H-->>PA: identificador da sala
    PA-->>A: abre a conversa
    H-->>PB: sync traz o convite
    PB-->>B: seção Convites
    B->>PB: Aceitar
    PB->>H: POST entrar na sala
    PB-->>B: a conversa abre
```

---

## 4. Diagrama de componentes

### 4.1. Camadas da aplicação

Cada camada só conhece a de baixo. Todo acesso ao Matrix acontece no Rust, e o Dart nunca fala HTTP com o servidor.

```mermaid
flowchart LR
    subgraph App["Aplicativo desktop"]
        direction LR
        UI["Interface Flutter"] --> ST["Estado com Riverpod"]
        ST --> RP["Repositórios em Dart"]
        RP --> BR["Flutter Rust Bridge"]
        BR --> RU["Rust com Matrix Rust SDK"]
    end
    RU <-->|HTTPS| HS[("Homeserver Matrix")]
    RP --> CF["Cofre do sistema e preferências"]
```

| Camada | Responsabilidade |
| ------ | ---------------- |
| Interface | Telas e widgets; só falam com o estado |
| Estado | Providers e notifiers do Riverpod; modelam carregando, vazio, erro e dados |
| Repositórios | Única camada que conhece os tipos da ponte; converte para modelos de domínio |
| Ponte | Código gerado pelo Flutter Rust Bridge |
| Rust | Login, sessão, sincronização, salas, conversa, envio, histórico, criação de conversa, convites, criptografia e recuperação de chaves |
| Cofre e preferências | Sessão e senha do banco no cofre do sistema; servidor salvo em `shared_preferences` |
