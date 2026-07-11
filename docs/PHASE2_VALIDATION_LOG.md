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

## Pendências da Fase 2

- painel nativo em `Opções > AddOns`;
- janela independente de configurações;
- seletores por perícia e ações em massa;
- validação visual de múltiplas categorias e separadores;
- escala, ordenação, ocultar completas e comportamento em combate configuráveis pela interface;
- presets e confirmação de sobrescrita.
