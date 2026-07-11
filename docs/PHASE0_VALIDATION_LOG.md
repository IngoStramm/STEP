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
| Produção e fila de produção | Produção simples, interrupção e fila automática validadas nas rodadas 5 e 6. |
| Mineração, Herborismo e Esfolamento | Mineração validada na rodada 4; Herborismo e Esfolamento permanecem pendentes. |
| Pesca | Parcialmente validada na rodada 8. |
| Ganho real de perícia | Validado para Defesa e Machado de Duas Mãos na rodada 3. |
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

## Rodada 3 — Ganhos reais de Defesa e arma

| Campo | Valor |
| --- | --- |
| Data | 2026-07-11 |
| Build | `0.1.0-alpha` |
| Ganhos observados | Defesa e Machado de Duas Mãos |
| Resultado geral | Aprovado |

### Ganho de Defesa

O cliente mostrou e STEP detectou:

```text
Your skill in Defense has increased to 112.
[STEP] skill: gain combat.defense 111->112/115 (+1)
```

O valor `112/115` foi confirmado na janela de perícias.

### Ganho de Machado de Duas Mãos

O cliente mostrou e STEP detectou:

```text
Your skill in Two-Handed Axes has increased to 113.
[STEP] skill: gain combat.two_handed_axes 112->113/115 (+1)
```

O valor `113/115` foi confirmado na janela de perícias.

### Sequência de atualização

O buffer registrou:

```text
[147440.819] system: SKILL_LINES_CHANGED
[147440.919] scan: reason=SKILL_LINES_CHANGED recognized=12 unknown=8 baseline=false
```

Conclusões:

- o ganho real dispara `SKILL_LINES_CHANGED`;
- o debounce executou a varredura exatamente `0,10` segundo depois;
- `baseline=false` permitiu comparar o retrato anterior com o atual;
- um único ponto resultou em `gainedPoints = 1`;
- o scanner não confundiu as oito linhas excluídas com alterações elegíveis.

### Resultado adicional de Defesa

Também foi observado `SWING_MISSED` recebido com `missType = "IMMUNE"`. Isso confirma mais um resultado físico possível no conjunto de tentativas recebidas. A política definitiva deve tratá-lo como tentativa para a janela de atividade, sem afirmar que o evento isolado foi a causa direta do ganho de Defesa.

### Evidências

- `WoWScrnShot_071126_124502.jpg`: mensagens imediatas dos dois ganhos.
- `WoWScrnShot_071126_124525.jpg`: evento, debounce e comparação do Machado de Duas Mãos.
- `WoWScrnShot_071126_124534.jpg`: valores finais na janela de perícias e fim do combate.

Arquivos originais em `World of Warcraft/_anniversary_/Screenshots/`.

### Atualização da matriz

| Cenário | Estado após a rodada 3 |
| --- | --- |
| Ganho real de perícia de arma | Validado. |
| Ganho real de Defesa | Validado. |
| `SKILL_LINES_CHANGED` após ganho | Validado. |
| Debounce de `0,10` segundo | Validado. |
| Comparação incremental de um ponto | Validada. |
| Correspondência com a janela de perícias | Validada. |
| `SWING_MISSED` recebido com `IMMUNE` | Validado como tentativa observável. |
| Ganho múltiplo na mesma varredura | Pendente. |

## Rodada 4 — Mineração concluída e interrompida

| Campo | Valor |
| --- | --- |
| Data | 2026-07-11 |
| Build | `0.1.0-alpha` |
| Recurso | Copper Vein |
| Spell ID observado | `2576` |
| Resultado geral | Aprovado para início, sucesso e interrupção de Mineração |

### Identificador da ação

`UNIT_SPELLCAST_SENT` apresentou:

```text
unit=player
target=Copper Vein
castGUID=Cast-3-6261-1-36-2576-...
spellID=2576
```

Conclusão: a ação de minerar usa `2576` no cliente `20506`. O valor `2575` encontrado em referências locais não corresponde ao lançamento observado e não deve ser usado como identificador principal da tentativa.

### Tentativa bem-sucedida

Foram capturadas várias sequências bem-sucedidas com GUIDs distintos:

```text
UNIT_SPELLCAST_SENT
UNIT_SPELLCAST_START
UNIT_SPELLCAST_SUCCEEDED
UNIT_SPELLCAST_STOP
```

O loot de `Copper Ore` e `Rough Stone` apareceu depois das sequências concluídas.

### Tentativa interrompida

Foram capturadas sequências interrompidas:

```text
UNIT_SPELLCAST_SENT
UNIT_SPELLCAST_START
UNIT_SPELLCAST_STOP
UNIT_SPELLCAST_INTERRUPTED
UNIT_SPELLCAST_INTERRUPTED
UNIT_SPELLCAST_INTERRUPTED
```

Os três eventos `UNIT_SPELLCAST_INTERRUPTED` repetiram o mesmo `castGUID`. Isso exige fechamento idempotente: a tentativa e sua duração só podem ser registradas uma vez.

`UNIT_SPELLCAST_STOP` não distingue sucesso de interrupção isoladamente. O tracker deve usar o resultado já observado ou aceitar uma atualização terminal posterior para o mesmo GUID sem criar outro intervalo.

### Evidências

- `WoWScrnShot_071126_133526.jpg`: primeira interrupção e primeira conclusão.
- `WoWScrnShot_071126_133535.jpg`: nova interrupção e nova conclusão.
- `WoWScrnShot_071126_133541.jpg`: repetição das sequências e loot.

Arquivos originais em `World of Warcraft/_anniversary_/Screenshots/`.

### Atualização da matriz

| Cenário | Estado após a rodada 4 |
| --- | --- |
| `spellID` da ação de Mineração | Validado como `2576`. |
| Alvo da coleta em `UNIT_SPELLCAST_SENT` | Validado. |
| Início exato da tentativa | Validado por `UNIT_SPELLCAST_START`. |
| Conclusão bem-sucedida | Validada. |
| Interrupção | Validada. |
| Novo `castGUID` por tentativa | Validado. |
| Eventos terminais duplicados | Confirmados; deduplicação obrigatória. |
| Ganho de Mineração | Não ocorreu nesta rodada; pendente. |

## Rodada 5 — Produção de Engenharia

| Campo | Valor |
| --- | --- |
| Data | 2026-07-11 |
| Build | `0.1.0-alpha` |
| Profissão | Engineering 75/150 |
| Receita | Rough Blasting Powder |
| Spell ID observado | `3918` |
| Resultado geral | Aprovado para contexto, sucesso e interrupção |

### Associação à profissão

O cast apresentou:

```text
UNIT_SPELLCAST_SENT
target=nil
spellID=3918
```

Depois da produção, o contexto apresentou:

```text
TRADE_SKILL_UPDATE trade=Engineering 75/150
TRADE_SKILL_UPDATE trade=Engineering 75/150
```

Conclusões:

- `3918` identifica a receita Rough Blasting Powder, não Engenharia como um todo;
- o alvo do cast pode ser `nil` em produção;
- o tracker deve associar a tentativa ao contexto ativo `Engineering`;
- `TRADE_SKILL_UPDATE` pode repetir e não deve criar tentativas ou ganhos duplicados.

### Produção bem-sucedida

Foi observada:

```text
UNIT_SPELLCAST_SENT
UNIT_SPELLCAST_START
UNIT_SPELLCAST_SUCCEEDED
UNIT_SPELLCAST_STOP
TRADE_SKILL_UPDATE
TRADE_SKILL_UPDATE
```

`SUCCEEDED` e `STOP` compartilharam o mesmo instante na captura, e o item Rough Blasting Powder foi criado.

### Produção interrompida

Foi observada:

```text
UNIT_SPELLCAST_SENT
UNIT_SPELLCAST_START
UNIT_SPELLCAST_INTERRUPTED
UNIT_SPELLCAST_STOP
UNIT_SPELLCAST_INTERRUPTED
UNIT_SPELLCAST_INTERRUPTED
UNIT_SPELLCAST_INTERRUPTED
```

Ao contrário da Mineração interrompida observada anteriormente, o primeiro `INTERRUPTED` ocorreu antes de `STOP`. Portanto, o fechamento não pode depender de uma ordem fixa. Todos os terminais do mesmo `castGUID` pertencem à mesma tentativa.

### Fila

As capturas mostram tentativas diferentes com novos `castGUID`, mas a quantidade da interface estava em `1`. Isso não comprova uma fila automática com quantidade maior que um. O cenário permanece pendente.

### Evidências

- `WoWScrnShot_071126_134100.jpg`: interrupção e conclusão.
- `WoWScrnShot_071126_134108.jpg`: terminais duplicados e nova tentativa.
- `WoWScrnShot_071126_134121.jpg`: ordem da interrupção e sucesso.
- `WoWScrnShot_071126_134126.jpg`: contexto `Engineering 75/150` após produção.

Arquivos originais em `World of Warcraft/_anniversary_/Screenshots/`.

### Atualização da matriz

| Cenário | Estado após a rodada 5 |
| --- | --- |
| Contexto `TRADE_SKILL` de Engenharia | Validado. |
| Receita com `spellID` próprio | Validada. |
| Produção simples concluída | Validada. |
| Produção interrompida | Validada. |
| Ordem variável entre `STOP` e `INTERRUPTED` | Validada. |
| Terminais duplicados por `castGUID` | Confirmados. |
| `TRADE_SKILL_UPDATE` duplicado | Confirmado. |
| Fila automática com quantidade maior que um | Pendente. |
| Janela alternativa `CRAFT` | Pendente. |

## Rodada 6 — Fila automática de Engenharia

| Campo | Valor |
| --- | --- |
| Data | 2026-07-11 |
| Build | `0.1.0-alpha` |
| Profissão | Engineering 375/375 |
| Receita | Coarse Blasting Powder |
| Spell ID observado | `3929` |
| Execuções consecutivas visíveis | 6, com contadores de `12` a `17` |
| Resultado geral | Aprovado |

### Comportamento da fila

Cada unidade apresentou a sequência completa:

```text
UNIT_SPELLCAST_SENT
UNIT_SPELLCAST_START
UNIT_SPELLCAST_SUCCEEDED
UNIT_SPELLCAST_STOP
```

As capturas mostram execuções consecutivas cujos quartos argumentos avançam de `12` a `17`. Cada unidade recebeu um `castGUID` diferente e produziu sua própria mensagem `You create: [Coarse Blasting Powder]`.

Não foi observado um evento adicional que representasse a fila como um todo. Portanto:

- cada unidade é uma tentativa independente;
- o tempo ativo da fila é a soma das tentativas;
- não deve existir um segundo cronômetro abrangendo toda a fila;
- `castGUID` é a chave de deduplicação;
- o quarto argumento crescente pode auxiliar o diagnóstico, mas não substitui o GUID.

### Receita diferente na mesma profissão

Coarse Blasting Powder usa `spellID = 3929`, enquanto Rough Blasting Powder da rodada anterior usou `3918`. Isso confirma que o tracker não pode identificar Engenharia por um único spell ID de produção; a profissão vem do contexto `TRADE_SKILL`.

### Evidências

- `WoWScrnShot_071126_135746.jpg`: unidades com contadores `12` e `13`.
- `WoWScrnShot_071126_135808.jpg`: continuação com `14`, `15` e início de `16`.
- `WoWScrnShot_071126_135816.jpg`: conclusão de `16` e `17`.

Arquivos originais em `World of Warcraft/_anniversary_/Screenshots/`.

### Atualização da matriz

| Cenário | Estado após a rodada 6 |
| --- | --- |
| Fila automática com várias unidades | Validada. |
| Novo `castGUID` por unidade | Validado. |
| Ciclo completo por unidade | Validado. |
| Soma unitária como modelo de tempo | Validada como decisão técnica. |
| Evento global de fila | Não observado e não necessário para o modelo. |
| IDs diferentes para receitas da mesma profissão | Validado. |

## Rodada 7 — Segundo personagem e preparação para Pesca

| Campo | Valor |
| --- | --- |
| Data | 2026-07-11 |
| Build | `0.1.0-alpha` |
| Classe | Druida |
| Nível | 70 |
| Perícias reconhecidas | 11 |
| Linhas numéricas desconhecidas | 8 |
| Resultado geral | Aprovado |

### Perícias elegíveis reconhecidas

O segundo personagem confirmou:

```text
combat.daggers 49/350
combat.defense 350/350
combat.maces 1/350
combat.staves 113/350
combat.two_handed_maces 154/350
combat.unarmed 7/350
primary.enchanting 375/375
primary.engineering 375/375
secondary.cooking 375/375
secondary.first_aid 375/375
secondary.fishing 325/375
```

Conclusões:

- o scanner funcionou em uma segunda classe e personagem;
- perícias completas e incompletas foram lidas corretamente;
- `secondary.fishing` foi reconhecida com tracker `fishing`;
- máximos de combate `350` e profissão `375` foram preservados sem confusão.

### Linhas excluídas

As oito linhas desconhecidas foram:

- Balance;
- Cloth;
- Feral Combat;
- Language: Common;
- Language: Darnassian;
- Leather;
- Restoration;
- Riding.

Todas são especializações, armaduras, idiomas ou Montaria e permanecem fora do escopo conforme o PRD. Em particular, `Riding 300/300` confirma que uma linha numérica completa pode continuar corretamente excluída.

### Evidências

- `WoWScrnShot_071126_140250.jpg`: contagem e primeira parte do retrato.
- `WoWScrnShot_071126_140258.jpg`: Pesca, linhas excluídas e fim do retrato.

Arquivos originais em `World of Warcraft/_anniversary_/Screenshots/`.

### Atualização da matriz

| Cenário | Estado após a rodada 7 |
| --- | --- |
| Scanner `enUS` em segunda classe | Validado. |
| Perícias completas | Validadas no retrato. |
| Pesca aprendida | Validada como descoberta. |
| Montaria numérica excluída | Validada. |
| Eventos de Pesca | Pendente para a próxima rodada. |

## Rodada 8 — Ciclo canalizado de Pesca

| Campo | Valor |
| --- | --- |
| Data | 2026-07-11 |
| Build | `0.1.0-alpha` |
| Perícia | Fishing 325/375 |
| Spell ID principal observado | `33095` |
| Spell ID de acessório observado | `45731` — `Sharpened Fish Hook` |
| Resultado geral | Parcialmente aprovado; ciclo bem-sucedido e acessório identificados, terminais ainda pendentes |

### Identificador e ciclo principal

As tentativas concluídas de Pesca emitiram:

```text
UNIT_SPELLCAST_SENT
UNIT_SPELLCAST_CHANNEL_START
UNIT_SPELLCAST_SUCCEEDED
UNIT_SPELLCAST_CHANNEL_STOP
loot
```

O `spellID` principal foi `33095`, resolvido pelo cliente como `Fishing`. O alvo em `UNIT_SPELLCAST_SENT` veio `nil` e cada tentativa recebeu novo `castGUID`. Foram observadas capturas consecutivas de `Barbed Gill Trout`, sempre depois de `CHANNEL_STOP`.

No teste isolado, os tempos monotônicos foram:

```text
152919.264 SENT / CHANNEL_START
152919.265 SUCCEEDED
152933.032 CHANNEL_STOP
152933.281 LOOT_OPENED
152933.348 LOOT_CLOSED
```

Portanto, `SUCCEEDED` ocorre no início do canal e não confirma captura nem encerramento da tentativa. O canal observado durou aproximadamente `13,768` segundos, e o loot abriu cerca de `0,249` segundo depois de `CHANNEL_STOP`.

Isso invalida o uso de `7620` como identificador universal da ação: o tracker de Pesca precisa considerar os IDs associados aos graus da profissão ou outra identificação validada pelo nome resolvido no cliente.

### Falha e acessório de Pesca

Uma tentativa inicial com `spellID = 33095` terminou em `UNIT_SPELLCAST_FAILED`. As capturas também mostraram, antes de uma tentativa, um ciclo separado com `spellID = 45731`:

```text
UNIT_SPELLCAST_SENT
UNIT_SPELLCAST_START
UNIT_SPELLCAST_SUCCEEDED
UNIT_SPELLCAST_STOP
```

O usuário confirmou que `45731` pertence ao item `Sharpened Fish Hook`, aplicado à vara para aumentar Pesca em `100` por `10` minutos. O ciclo representa a aplicação do acessório, não uma tentativa de Pesca. Ele não apareceu no teste isolado seguinte porque o item não foi reaplicado.

Consequência: o tracker deve aceitar como tentativa apenas o ciclo canalizado cuja magia é resolvida como a linha de Pesca. `45731` e outras aplicações de melhorias na vara ficam fora do cronômetro, ainda que sejam usadas imediatamente antes de pescar.

### Evidências

- `WoWScrnShot_071126_140956.jpg`: falha inicial, ciclo auxiliar e primeira captura concluída.
- `WoWScrnShot_071126_141003.jpg`: capturas canalizadas consecutivas e loot posterior.
- `WoWScrnShot_071126_141631.jpg`: nome `Fishing` resolvido pelo cliente e início do retrato temporal.
- `WoWScrnShot_071126_141637.jpg`: ciclo completo, `LOOT_OPENED` e `LOOT_CLOSED` com tempos monotônicos.

Arquivos originais em `World of Warcraft/_anniversary_/Screenshots/`.

### Atualização da matriz

| Cenário | Estado após a rodada 8 |
| --- | --- |
| `spellID` principal da Pesca neste grau | Validado como `33095`. |
| Nome de `33095` | Validado como `Fishing` pelo cliente. |
| Ciclo canalizado bem-sucedido | Validado. |
| Novo `castGUID` por tentativa | Validado. |
| Loot posterior a `CHANNEL_STOP` | Validado. |
| `SUCCEEDED` como encerramento | Rejeitado; ocorre no início do canal. |
| Tentativa com `UNIT_SPELLCAST_FAILED` | Observada. |
| Nome e função de `45731` | Validado como aplicação de `Sharpened Fish Hook`; excluído das tentativas. |
| Cancelamento deliberado | Pendente de distinção. |
| Timeout sem interação | Pendente. |
