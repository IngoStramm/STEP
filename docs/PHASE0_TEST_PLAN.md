# STEP — Plano de testes da Fase 0

## Objetivo

Validar no cliente `20506` os nomes, payloads e sequências de eventos que sustentarão os rastreadores definitivos. A Fase 0 não mede ainda o tempo ativo nem cria o painel final.

## Preparação

1. Entre no jogo com STEP habilitado.
2. Ative erros Lua, se necessário:

```text
/console scriptErrors 1
```

3. Execute `/reload`.
4. Confirme a mensagem de carregamento da Fase 0.
5. Execute:

```text
/step status
/step debug on
/step debug snapshot
/step debug equipment
```

## 1. Descoberta de perícias

Verificar:

- armas aprendidas aparecem com chave `combat.*`;
- Defesa e Desarmado são reconhecidos;
- profissões aprendidas aparecem na categoria correta;
- armaduras, idiomas, Montaria e outras linhas aparecem apenas como desconhecidas ou são ignoradas;
- valor atual e máximo correspondem à janela de perícias do jogo.

Registrar qualquer linha elegível apresentada como `unknown`.

## 2. Equipamento

Executar `/step debug equipment` nos seguintes casos disponíveis:

1. arma apenas na mão principal;
2. duas armas da mesma categoria;
3. duas armas de categorias diferentes;
4. arma de duas mãos;
5. mão principal vazia;
6. arma de punho;
7. arco, besta, arma de fogo, arremesso ou varinha.

Confirmar item, `classID`, `subclassID` e `skillKey`.

## 3. Combate

Antes de um teste curto:

```text
/step debug combat on
```

Depois de alguns ataques:

```text
/step debug combat off
/step debug events
```

Executar quando possível:

- ataque da mão principal;
- ataque da mão secundária;
- erro, esquiva, aparo ou bloqueio;
- ataque à distância;
- Varinha;
- ataque sem arma;
- receber ataques para validar Defesa;
- troca de arma durante o combate.

O payload capturado deve permitir identificar mão, origem, destino e tipo da tentativa. Não deixar a saída ao vivo ligada durante uma sessão longa.

## 4. Produção e coleta

Ativar:

```text
/step debug casts on
```

Realizar tentativas curtas de:

- uma produção simples;
- uma pequena fila de produção;
- produção interrompida;
- Mineração;
- Herborismo;
- Esfolamento;
- coleta falha ou interrompida.

Depois:

```text
/step debug casts off
/step debug events
```

Registrar os `spellID`, `castGUID`, eventos de início e eventos de encerramento.

## 5. Pesca

Capturar separadamente:

1. lançamento com loot;
2. lançamento cancelado;
3. lançamento interrompido;
4. tentativa encerrada sem coleta.

Verificar a sequência entre `UNIT_SPELLCAST_*`, `LOOT_OPENED` e `LOOT_CLOSED`.

## 6. Alterações de perícia

Quando for possível obter um ponto:

1. deixar `/step debug on` ativo;
2. treinar até o ganho;
3. executar `/step debug events`;
4. confirmar a linha `skill: gain` com valor anterior, novo valor e máximo.

Também validar:

- level up aumentando o máximo sem criar ganho falso;
- treinamento de novo rank de profissão;
- profissão abandonada e reaprendida.

## Critérios para encerrar a Fase 0

- nenhuma perícia elegível do personagem permanece desconhecida nos idiomas canônicos;
- equipamento comum resolve para a chave correta;
- mão secundária, Varinha, arma de punho e Desarmado têm evidência suficiente;
- Defesa possui conjunto comprovado de eventos recebidos;
- produção, coleta, Esfolamento e Pesca possuem inícios e encerramentos comprovados;
- a Arquitetura Técnica registra os resultados e substitui parâmetros provisórios por decisões validadas.

## Limpeza do buffer

O buffer mantém no máximo 120 eventos e mostra os 20 mais recentes. Para começar um cenário limpo:

```text
/step debug clear
```
