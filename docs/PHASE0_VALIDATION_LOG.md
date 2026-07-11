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
| Eventos de ataque e Defesa | Parcialmente validados na rodada 2; off-hand, ataques à distância e outros resultados permanecem pendentes. |
| Produção e fila de produção | Pendente. |
| Mineração, Herborismo e Esfolamento | Pendente. |
| Pesca | Pendente. |
| Ganho real de perícia | Pendente. |
| Mudança apenas do máximo | Pendente. |
| Abandono e reaprendizado | Pendente. |

## Rodada 2 — Ataque físico e tentativas recebidas

| Campo | Valor |
| --- | --- |
| Data | 2026-07-11 |
| Build | `0.1.0-alpha` |
| Arma | Machado de Duas Mãos já resolvido como `combat.two_handed_axes` |
| Alvo | Young Moonkin |
| Resultado geral | Aprovado para ataque da mão principal e tentativas físicas recebidas observadas |

### Ataque da mão principal

Foi observado:

```text
SWING_DAMAGE src=player dst=other
payload={12=108, 13=-1, 14=1, ..., 21=false}
```

Interpretação:

- o golpe físico comum usa `SWING_DAMAGE`;
- `isOffHand` está no campo absoluto `21`, décimo campo específico do payload;
- `false` confirma mão principal;
- combinado ao equipamento da rodada anterior, o pulso deve ser atribuído a `combat.two_handed_axes`.

### Tentativas recebidas para Defesa

Foram observados:

```text
SWING_DAMAGE src=other dst=player
payload={12=13, 13=-1, 14=1, ..., 21=false}

SWING_MISSED src=other dst=player
payload={12=PARRY, 13=false}
```

Interpretação:

- `SWING_DAMAGE` confirma uma tentativa física recebida com dano;
- `SWING_MISSED` confirma uma tentativa recebida aparada;
- em `SWING_MISSED`, `missType` está no campo absoluto `12` e `isOffHand` no `13`;
- ambos podem renovar a janela de atividade de `combat.defense` quando o destino for o jogador.

### Separação de dano mágico

No mesmo combate foram observados `SPELL_DAMAGE` do Paladino:

```text
spellID=20281 Judgement of Righteousness
spellID=25739 Seal of Righteousness
```

Esses eventos não identificam a tentativa da arma. O rastreador ofensivo comum deve ignorar `SPELL_DAMAGE`, preservando-o no diagnóstico apenas para a futura validação específica de Varinhas.

### Ciclo de combate e loot

- `PLAYER_REGEN_ENABLED` confirmou o encerramento do combate.
- `LOOT_OPENED` e `LOOT_CLOSED` apareceram mais de uma vez, reforçando que correlações futuras de coleta e Pesca devem tolerar eventos duplicados.

### Evidências

- `WoWScrnShot_071126_123236.jpg`: golpes recebidos, aparo e eventos de lançamento.
- `WoWScrnShot_071126_123255.jpg`: golpe da mão principal, dano mágico separado e encerramento do combate.

Arquivos originais em `World of Warcraft/_anniversary_/Screenshots/`.

### Atualização da matriz

| Cenário | Estado após a rodada 2 |
| --- | --- |
| Ataque físico da mão principal com dano | Validado. |
| Associação do ataque ao Machado de Duas Mãos equipado | Validada. |
| `SWING_DAMAGE` recebido para Defesa | Validado. |
| `SWING_MISSED` recebido com `PARRY` para Defesa | Validado. |
| Separação entre golpe de arma e magias do Paladino | Validada. |
| Encerramento por `PLAYER_REGEN_ENABLED` | Validado. |
| Ataque da mão principal que erra | Pendente. |
| Ataque da mão secundária com `isOffHand = true` | Pendente. |
| Outros resultados recebidos: dodge, block e miss | Pendente. |
| Ataques à distância e Varinhas | Pendente. |
