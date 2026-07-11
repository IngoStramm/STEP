# STEP — Plano de validação da Fase 1

Este plano valida no cliente `20506` o núcleo de dados `0.2.0-alpha`, especialmente a migração real do schema `1` para `2`. Os testes automatizados cobrem a lógica pura; esta rodada confirma a integração com SavedVariables e o ciclo de vida do jogo.

## 1. Carregamento e migração

Após atualizar os arquivos, execute:

```text
/reload
```

Critérios:

- nenhuma janela de erro Lua;
- mensagem `Phase 1 core build 0.2.0-alpha loaded`;
- o estado anterior de `/step debug on` permanece preservado, caso estivesse ativo;
- a primeira varredura não produz mensagens falsas de ganho ou aprendizado.

## 2. Estado do núcleo

Execute:

```text
/step status
/step debug database
```

Esperado:

```text
phase=phase1
schema=2
ready=true
blocked=false
compatible=true
```

O `sessionId` deve existir, `known` deve ser maior que zero e `skillConfigs` deve corresponder às perícias reconhecidas pela primeira varredura.

## 3. Retrato e equipamento

Execute:

```text
/step debug snapshot
/step debug equipment
```

Confirme:

- valores-base, máximos e modificadores continuam iguais aos observados na Fase 0;
- equipamento permanece associado às mesmas chaves canônicas;
- slots vazios e candidatos a Desarmado continuam corretos.

Com a janela de perícias aberta, recolha ao menos um cabeçalho e execute `/step debug snapshot` sem recarregar a interface. Confirme que:

- as perícias daquele grupo continuam presentes em `/step debug snapshot`;
- o cabeçalho continua recolhido na interface padrão do jogo após a varredura;
- nenhuma perícia é anunciada como abandonada durante a leitura transitória.

O `/reload` não deve ser usado para validar a restauração do cabeçalho: o próprio cliente fecha a janela e recria seus grupos expandidos.

## 4. Padrões incrementais de configuração

Escolha uma arma equipada, uma arma aprendida não equipada, Defesa, Desarmado e uma profissão aprendida. Execute uma vez para cada chave:

```text
/step debug config <skillKey>
```

Esperado no primeiro uso do personagem:

| Tipo | Visibilidade | Log | Notificação |
| --- | --- | --- | --- |
| Arma equipada | `compact` | `true` | `true` |
| Outra arma aprendida | `expanded` | `true` | `true` |
| Defesa | `hidden` | `false` | `false` |
| Desarmado | `hidden` | `false` | `false` |
| Profissão | `hidden` | `false` | `false` |

## 5. Barramento

Execute:

```text
/step debug bus
```

O comando deve responder sem erro. Nesta fase é válido haver zero listeners permanentes, pois painel, rastreadores e histórico ainda não foram conectados.

## 6. Evidência a enviar

Uma captura contendo, quando possível:

```text
/step status
/step debug database
```

Se houver divergência em defaults, enviar também a saída dos comandos `/step debug config` afetados. Erros Lua devem ser enviados integralmente antes de novos testes.
