# STEP — Registro de validação da Fase 2

Este documento registra as validações visuais e funcionais do painel principal no cliente `20506`.

## Rodada 1 — Primeira fatia do painel principal

| Campo | Valor |
| --- | --- |
| Data | 2026-07-11 |
| Build | `0.2.0-alpha` |
| Idioma observado | `enUS` |
| Classe observada | Paladino |
| Resultado geral | Aprovado para a primeira fatia visual |

### Estado compacto

O painel carregou sem erro Lua e exibiu somente `Two-Handed Axes`, a perícia correspondente à arma equipada. Foram confirmados:

- ícone específico da arma;
- nome localizado;
- valor `114/115`;
- valor atual amarelo por estar acima de 90% e ainda incompleto;
- valor máximo e separador brancos;
- destaque azul discreto para a arma equipada;
- resumo estável `6 skills need training`;
- controle `+` para expansão.

### Estado expandido

O controle do cabeçalho expandiu o painel para as seis perícias de armas habilitadas. A ordem observada seguiu o menor percentual primeiro:

1. Axes `1/115`;
2. Maces `1/115`;
3. Swords `1/115`;
4. Two-Handed Maces `110/115`;
5. Two-Handed Swords `110/115`;
6. Two-Handed Axes `114/115`.

Os ícones foram distintos, as cores vermelha e amarela respeitaram os limiares e somente a arma equipada recebeu o fundo azul.

### Posição, persistência e bloqueio

- o painel foi arrastado do centro para a região inferior esquerda;
- posição e estado expandido sobreviveram a `/reload`;
- `/step lock` exibiu `Panel locked`;
- o painel permaneceu imóvel durante uma tentativa de arraste bloqueada;
- duas execuções de `/step` ocultaram e mostraram o painel corretamente.

### Tooltip

O tooltip de `Two-Handed Axes` apresentou:

```text
Skill             114/115
Progress              99%
Points missing           1
Matches an equipped weapon
```

Os dados coincidiram com o valor da linha e com o equipamento resolvido.

### Evidências

- `WoWScrnShot_071126_172339.jpg`: painel compacto.
- `WoWScrnShot_071126_172422.jpg`: painel expandido.
- `WoWScrnShot_071126_172520.jpg`: posição e expansão preservadas após reload.
- `WoWScrnShot_071126_172558.jpg`: bloqueio confirmado.
- `WoWScrnShot_071126_172645.jpg`: tooltip da arma equipada.

Arquivos originais em `World of Warcraft/_anniversary_/Screenshots/`.

## Rodada 2 — Primeira fatia das configurações

| Campo | Valor |
| --- | --- |
| Data | 2026-07-11 |
| Build | `0.2.0-alpha` |
| Idioma observado | `enUS` |
| Classe observada | Paladino |
| Resultado geral | Aprovado para a primeira fatia das configurações |

### Janela independente

O comando `/step config` abriu uma janela independente, arrastável e com rolagem. A interface apresentou os controles gerais em duas colunas e a lista de perícias aprendidas separada nas categorias `Combat Skills`, `Primary Professions` e `Secondary Professions`.

Foram confirmados:

- fechamento com `Esc`;
- posição preservada ao fechar e reabrir;
- atualização imediata do painel ao mudar a visibilidade de uma perícia;
- escala do painel alterada de `100%` para `125%` sem reload;
- clique direito no cabeçalho do painel abrindo a janela independente.

### Painel nativo e sincronização

O comando `/step options` abriu `Opções > AddOns > STEP`. A mesma configuração foi compartilhada pelas duas superfícies:

1. `Engineering` foi alterada de oculta para compacta na janela independente;
2. o painel passou de seis para sete perícias e exibiu `Primary Professions`;
3. o painel nativo refletiu `Engineering` como compacta;
4. `Cooking` foi alterada para compacta no painel nativo;
5. o painel passou de sete para oito perícias e exibiu `Secondary Professions`;
6. a janela independente refletiu `Cooking` como compacta.

Isso validou a sincronização bidirecional entre as superfícies e o painel principal.

### Comportamento em combate

Com `Behavior in combat` definido como `Compact`, o início do combate reduziu automaticamente o painel expandido de oito para três perícias compactas: `Two-Handed Axes`, `Engineering` e `Cooking`. O controle do cabeçalho permaneceu com `+`, sem sobrescrever o estado expandido persistido.

Após o combate, o painel retornou automaticamente às oito perícias expandidas. A restauração foi confirmada diretamente pelo usuário.

### Evidências

- `WoWScrnShot_071126_175153.jpg`: topo e controles gerais da janela independente.
- `WoWScrnShot_071126_175205.jpg`: lista categorizada de perícias na janela independente.
- `WoWScrnShot_071126_175428.jpg`: `Engineering` habilitada e painel atualizado imediatamente.
- `WoWScrnShot_071126_183111.jpg`: painel nativo em `Opções > AddOns > STEP`.
- `WoWScrnShot_071126_183114.jpg`: parte inferior da lista no painel nativo.
- `WoWScrnShot_071126_183252.jpg`: `Cooking` habilitada pelo painel nativo.
- `WoWScrnShot_071126_183352.jpg`: sincronização de `Cooking` na janela independente.
- `WoWScrnShot_071126_183554.jpg`: escala do painel aplicada em `125%`.
- `WoWScrnShot_071126_183718.jpg`: compactação automática durante o combate.

Arquivos originais em `World of Warcraft/_anniversary_/Screenshots/`.

## Pendências da Fase 2

- ações em massa por categoria;
- presets e confirmação de sobrescrita;
- testes visuais das opções de ordenação e ocultação de perícias completas;
- refinamentos visuais que surgirem nos próximos testes;
- notificações visuais e sonoras de ganho de perícia.
