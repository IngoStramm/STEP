# STEP — Registro de validação da Fase 1

Validação executada no cliente `20506` em 2026-07-11 com o build `0.2.0-alpha` e um Paladino de nível 23.

## Resultado geral

A Fase 1 foi aprovada para os cenários previstos em `PHASE1_TEST_PLAN.md`:

- inicialização e migração para o schema `2` sem erro Lua;
- banco compatível, sessão iniciada e preferências preservadas;
- 12 perícias elegíveis reconhecidas e 8 linhas numéricas excluídas corretamente;
- equipamento principal associado a `combat.two_handed_axes`;
- defaults incrementais corretos para arma equipada, outra arma, Defesa, Desarmado e profissões;
- barramento interno respondeu com zero listeners permanentes, conforme esperado nesta fase;
- leitura de grupo recolhido preservou seu estado visual e manteve todas as perícias no snapshot.

## Estado observado

```text
version=0.2.0-alpha
phase=phase1
schema=2/2
ready=true
blocked=false
compatible=true
known=12
skillConfigs=12
```

O equipamento observado foi:

```text
mainHand[16]: item=1461 class=2 subclass=1 (Two-Handed Axes) skill=combat.two_handed_axes
offHand[17]: empty
ranged[18]: empty
```

## Defaults validados

| Perícia | Visibilidade | Log | Notificação |
| --- | --- | --- | --- |
| `combat.two_handed_axes` | `compact` | `true` | `true` |
| `combat.two_handed_maces` | `expanded` | `true` | `true` |
| `combat.defense` | `hidden` | `false` | `false` |
| `combat.unarmed` | `hidden` | `false` | `false` |
| `primary.engineering` | `hidden` | `false` | `false` |
| `secondary.cooking` | `hidden` | `false` | `false` |

## Cabeçalhos recolhidos

O primeiro procedimento proposto usava `/reload`, mas o cliente fecha a janela de perícias e recria os grupos expandidos. O procedimento foi corrigido para executar o snapshot com a janela aberta.

Com `Weapon Skills` recolhido, `/step debug snapshot`:

- manteve o botão `+` e o grupo visualmente recolhido;
- reconheceu as 12 perícias, incluindo todas as armas daquele grupo;
- não gerou erro, loop de eventos ou abandono falso.

## Evidências

- `WoWScrnShot_071126_165751.jpg`: carregamento, versão, fase, schema e banco.
- `WoWScrnShot_071126_165918.jpg` e `WoWScrnShot_071126_165925.jpg`: snapshot completo.
- `WoWScrnShot_071126_170014.jpg`: equipamento resolvido.
- `WoWScrnShot_071126_170054.jpg`: default da arma equipada.
- `WoWScrnShot_071126_170135.jpg`: default de arma aprendida não equipada.
- `WoWScrnShot_071126_170213.jpg`: default de Defesa.
- `WoWScrnShot_071126_170252.jpg`: default de Desarmado.
- `WoWScrnShot_071126_170326.jpg`: default de profissão primária.
- `WoWScrnShot_071126_170354.jpg`: default de profissão secundária.
- `WoWScrnShot_071126_170425.jpg`: `EventBus listeners=0`.
- `WoWScrnShot_071126_170834.jpg` e `WoWScrnShot_071126_170838.jpg`: grupo recolhido preservado durante a varredura.

Arquivos originais em `World of Warcraft/_anniversary_/Screenshots/`.
