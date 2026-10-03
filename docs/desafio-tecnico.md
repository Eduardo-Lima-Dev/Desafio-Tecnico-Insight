# Desafio técnico - Cliente de mensageria desktop

## Objetivo

Desenvolver uma aplicação desktop de mensageria utilizando Flutter, com foco em arquitetura, qualidade de código, segurança e experiência do usuário.

A aplicação deverá se comunicar com um homeserver Matrix e estar preparada para execução em macOS, Windows e Linux.

## Escopo esperado

A solução deve contemplar os principais fluxos de um cliente de mensagens:

- autenticação em um homeserver Matrix;
- listagem e seleção de salas;
- visualização e envio de mensagens;
- atualização das conversas;
- encerramento e restauração da sessão.

A organização da arquitetura, gerenciamento de estado, persistência, tratamento de erros e experiência da interface ficam a critério do candidato.

## Integração nativa

A comunicação com o Matrix deve ser implementada em Rust utilizando:

- [Matrix Rust SDK](https://github.com/matrix-org/matrix-rust-sdk)
- [Flutter Rust Bridge](https://github.com/fzyzcjy/flutter_rust_bridge)

## Entrega

O projeto deve ser disponibilizado em um repositório Git contendo:

- código-fonte;
- instruções de configuração e execução;
- testes considerados relevantes;
- breve documentação das principais decisões técnicas;
- registro de limitações ou itens não concluídos.

**Não esperamos um produto completo. O objetivo é compreender como o candidato estrutura o problema, define prioridades e prepara a solução para evoluir.**
