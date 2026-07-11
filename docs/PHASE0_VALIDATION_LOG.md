# STEP — Registro de validação da Fase 0

Este documento registra evidências obtidas no cliente `20506`. Um item só passa de pendente para validado quando o resultado observado for suficiente para sustentar a regra técnica correspondente.

## Rodada 1 — Descoberta de perícias e arma de duas mãos

| Campo | Valor |
| --- | --- |
| Data | 2026-07-11 |
| Build | `0.1.0-alpha` |
| Idioma observado | `enUS` |
| Classe observada | Paladino |
| Perícias reconhecidas | 12 |
| Linhas numéricas desconhecidas | 8 |
| Arma equipada | item `1461`, classe `2`, subclasse `1` |
| Resultado geral | Aprovado para os cenários observados |

### Perícias elegíveis reconhecidas

| Chave canônica | Nome observado | Valor |
| --- | --- | --- |
| `combat.axes` | Axes | 1/115 |
| `combat.defense` | Defense | 111/115 |
| `combat.maces` | Maces | 1/115 |
| `combat.swords` | Swords | 1/115 |
| `combat.two_handed_axes` | Two-Handed Axes | 112/115 |
| `combat.two_handed_maces` | Two-Handed Maces | 110/115 |
| `combat.two_handed_swords` | Two-Handed Swords | 110/115 |
| `combat.unarmed` | Unarmed | 1/115 |
| `primary.engineering` | Engineering | 75/150 |
| `primary.mining` | Mining | 121/150 |
| `secondary.cooking` | Cooking | 1/75 |
| `secondary.first_aid` | First Aid | 91/150 |

Todas as perícias elegíveis visíveis nas capturas foram associadas à chave e ao tracker esperados.

### Linhas desconhecidas analisadas

| Nome observado | Valor | Classificação |
| --- | --- | --- |
| Cloth | 1/1 | Armadura; excluída pelo PRD. |
| Holy | 1/1 | Especialização da classe; excluída. |
| Language: Common | 300/300 | Idioma; excluído pelo PRD. |
| Leather | 1/1 | Armadura; excluída pelo PRD. |
| Mail | 1/1 | Armadura; excluída pelo PRD. |
| Protection | 1/1 | Especialização da classe; excluída. |
| Retribution | 1/1 | Especialização da classe; excluída. |
| Shield | 1/1 | Proficiência sem progressão monitorável; excluída. |

Conclusão: nenhuma linha desconhecida desta rodada representa uma perícia elegível ausente do registro. A saída `unknown` permanece útil durante a Fase 0 e não significa, isoladamente, uma falha.

### Equipamento

O resolver retornou:

```text
mainHand[16]: item=1461 class=2 subclass=1 (Two-Handed Axes) skill=combat.two_handed_axes
offHand[17]: empty
ranged[18]: empty
```

Conclusão: arma de duas mãos da subclasse `1` foi associada corretamente a `combat.two_handed_axes`; os slots vazios também foram reconhecidos.

### Evidências

- `WoWScrnShot_071126_121708.jpg`: contagem e primeira parte do retrato.
- `WoWScrnShot_071126_121720.jpg`: continuação do retrato e linhas desconhecidas.
- `WoWScrnShot_071126_121731.jpg`: equipamento resolvido.

Arquivos originais em `World of Warcraft/_anniversary_/Screenshots/`.

## Estado da matriz

| Cenário | Estado |
| --- | --- |
| Scanner `enUS` | Validado nesta rodada. |
| Defesa e Desarmado no retrato | Validados como linhas descobertas. |
| Arma de duas mãos | Validada para Machado de Duas Mãos. |
| Slots secundário e à distância vazios | Validados. |
| Scanner `ptBR` | Pendente. |
| Mão principal de uma mão | Pendente. |
| Mão secundária com arma | Pendente. |
| Armas de categorias diferentes | Pendente. |
| Arma de punho versus Desarmado | Pendente. |
| Armas à distância e Varinhas | Pendente. |
| Eventos de ataque e Defesa | Pendente. |
| Produção e fila de produção | Pendente. |
| Mineração, Herborismo e Esfolamento | Pendente. |
| Pesca | Pendente. |
| Ganho real de perícia | Pendente. |
| Mudança apenas do máximo | Pendente. |
| Abandono e reaprendizado | Pendente. |
