# STEP — Skill Training & Evolution Panel

## Arquitetura Técnica

| Campo | Valor |
| --- | --- |
| Produto | STEP — Skill Training & Evolution Panel |
| Cliente-alvo | World of Warcraft Anniversary / Burning Crusade Classic 2.5.6 |
| Interface-alvo | 20506 |
| Versão do documento | 1.0 |
| Status | Aprovado como baseline técnica da V1 |
| PRD de referência | `docs/PRD.md`, versão 1.0 |
| Data | 2026-07-11 |
| Data da aprovação | 2026-07-11 |
| Idioma canônico | Português do Brasil |

## 1. Objetivo

Este documento transforma o PRD aprovado em uma arquitetura implementável, testável e compatível com o cliente `20506`.

Ele define:

- limites e responsabilidades dos módulos;
- fontes de dados e eventos do jogo;
- identidade estável das perícias;
- regras de medição de tempo;
- persistência, migração e retenção;
- contratos entre domínio e interface;
- estratégia de notificações, histórico e compartilhamento;
- desempenho, instrumentação e validação dentro do jogo.

O documento não congela dimensões, espaçamentos, animações ou sons. Esses elementos exigem protótipos e testes visuais e podem resultar em revisões do PRD e desta arquitetura.

## 2. Restrições do cliente

1. STEP deve funcionar sem bibliotecas externas.
2. O addon deve usar APIs clássicas disponíveis no cliente `20506`.
3. `C_TradeSkillUI` não é uma dependência válida para esta versão do cliente.
4. A leitura canônica das perícias será feita por `GetNumSkillLines()` e `GetSkillLineInfo(index)`.
5. A implementação deve testar a existência de APIs opcionais antes de usá-las.
6. O addon não pode executar ações protegidas nem automatizar ataques, produção ou coleta.
7. O estado persistido será específico por personagem.
8. Nenhum identificador persistido pode depender do idioma do cliente.
9. O código deve respeitar a versão de Lua embutida no cliente, evitando recursos de versões posteriores sem fallback.
10. Os arquivos compartilharão um namespace recebido por `local addonName, STEP = ...`; não haverá `require` nem variáveis globais de serviço.

## 3. Princípios de arquitetura

### 3.1 Orientada a eventos

STEP reage a eventos do jogo e a ações do usuário. Não deve existir um `OnUpdate` permanente.

Atualizações por quadro são permitidas somente enquanto uma animação estiver visível. Temporizadores periódicos só podem existir enquanto houver uma medição ativa ou uma fila de chat em andamento.

### 3.2 Domínio independente da interface

A descoberta de perícias, a medição, o histórico e as configurações não conhecem frames. A interface recebe modelos de visualização e emite intenções.

O painel principal, o painel nativo, a janela independente, o histórico e os comandos usam os mesmos serviços. Não haverá cópias independentes do mesmo estado.

### 3.3 Identidade canônica

Cada perícia possui uma chave estável definida por STEP, como:

```text
combat.swords
combat.two_handed_swords
combat.defense
combat.unarmed
primary.mining
secondary.fishing
```

Nomes localizados e IDs conhecidos do jogo são metadados de resolução, não chaves de persistência.

### 3.4 Dados derivados não são fonte de verdade

Valores como percentual concluído, cor, texto formatado e médias recentes devem ser calculados a partir do estado canônico. Eles não serão persistidos quando puderem ser reconstruídos com segurança.

### 3.5 Falhar de forma conservadora

Se STEP não puder determinar a perícia correta de uma tentativa, não atribuirá tempo ativo por aproximação. É preferível omitir alguns segundos e registrar a situação no modo de diagnóstico a contaminar o histórico de outra perícia.

## 4. Decisões técnicas principais

| Tema | Decisão |
| --- | --- |
| Fonte de perícias | Varredura de `GetSkillLineInfo` com resolução para chaves canônicas. |
| Persistência | `SavedVariablesPerCharacter: STEPDB`. |
| Comunicação interna | Barramento simples de callbacks, sem AceEvent. |
| Atualização de perícias | Varredura inicial e varreduras agrupadas após `SKILL_LINES_CHANGED`. |
| Combate | `COMBAT_LOG_EVENT_UNFILTERED`, estado de combate e equipamento atual. |
| Produção/coleta | Eventos clássicos de profissão e eventos de lançamento de magia. |
| Cronometragem | Relógio monotônico durante a sessão; horário do servidor para marcos persistidos. |
| Histórico detalhado | Limite global de 2.000 eventos por personagem. |
| Histórico resumido | Agregados persistentes, mesmo após descarte de detalhes antigos. |
| Interface | Frames nativos, linhas reutilizáveis e um único `ViewModel`. |
| Configurações | Um único `ConfigStore` ligado a duas superfícies sincronizadas. |
| Notificações | Fila limitada, efeitos não interativos e modos separados para ganho e máximo. |
| Compartilhamento | Prévia, divisão conservadora e fila temporizada iniciada pelo usuário. |

## 5. Organização futura dos arquivos

```text
STEP/
  STEP.toc
  Core.lua
  Constants.lua
  Util.lua
  Locale/
    enUS.lua
    ptBR.lua
    deDE.lua
    esES.lua
    esMX.lua
    frFR.lua
    itIT.lua
    koKR.lua
    ruRU.lua
    zhCN.lua
    zhTW.lua
  Data/
    SkillRegistry.lua
  Services/
    Database.lua
    ConfigStore.lua
    SkillScanner.lua
    EquipmentResolver.lua
    ActivityTracker.lua
    CombatTracker.lua
    ProfessionTracker.lua
    HistoryStore.lua
    NotificationQueue.lua
    ShareService.lua
  UI/
    ViewModel.lua
    MainPanel.lua
    OptionsControls.lua
    OptionsPanel.lua
    StandaloneConfig.lua
    LogWindow.lua
    NotificationFrame.lua
  SlashCommands.lua
```

Os nomes poderão ser consolidados se a implementação revelar módulos muito pequenos. As fronteiras de responsabilidade devem permanecer, mesmo que dois componentes compartilhem um arquivo.

### 5.1 Ordem de carregamento

1. Constantes e utilitários.
2. Localização.
3. Registro de perícias.
4. Banco e configurações.
5. Serviços de domínio.
6. Modelos e frames de interface.
7. Comandos.
8. Inicialização do núcleo.

## 6. Responsabilidades dos componentes

### 6.1 `Core`

- controla o ciclo de vida do addon;
- registra os eventos globais;
- mantém o barramento interno de callbacks;
- inicia serviços depois de `ADDON_LOADED` e `PLAYER_LOGIN`;
- garante que a primeira varredura não produza notificações ou eventos históricos falsos;
- encerra e descarrega medições em `PLAYER_LOGOUT`.

Eventos internos previstos:

```text
STEP_READY
SKILLS_UPDATED
SKILL_GAINED
SKILL_LEARNED
SKILL_UNLEARNED
CONFIG_CHANGED
ACTIVITY_CHANGED
HISTORY_CHANGED
EQUIPMENT_CHANGED
```

### 6.2 `Database`

- aplica padrões sem substituir valores válidos;
- executa migrações sequenciais e idempotentes;
- valida tipos e enumerações persistidas;
- recupera posições inválidas;
- oferece operações explícitas de limpeza de sessão e histórico.

### 6.3 `ConfigStore`

- é a única fonte de verdade das preferências;
- expõe `Get`, `Set`, `Reset` e operações em lote;
- valida valores antes de persistir;
- emite `CONFIG_CHANGED` com o menor escopo possível;
- impede que os dois painéis de configuração mantenham estados divergentes.

### 6.4 `SkillRegistry`

- define as perícias elegíveis;
- associa nomes localizados às chaves canônicas;
- fornece categoria, ícone, padrão, tipo de rastreador e mapeamento de equipamento;
- exclui armaduras, idiomas, Montaria, especializações e linhas não monitoráveis.

### 6.5 `SkillScanner`

- lê as linhas de perícia do personagem;
- produz um retrato canônico;
- compara o retrato novo com o anterior;
- detecta aprendizado, abandono, reaprendizado, ganho e mudança de máximo;
- nunca interpreta uma mudança inicial como ganho.

### 6.6 `EquipmentResolver`

- mantém um cache das armas equipadas nas mãos principal, secundária e à distância;
- resolve classe e subclasse de item para uma chave de perícia;
- distingue mão vazia de arma de punho;
- invalida o cache em `PLAYER_EQUIPMENT_CHANGED`.

### 6.7 `ActivityTracker`

- mantém os cronômetros por perícia;
- aceita pulsos discretos de combate e intervalos exatos de profissão;
- acumula tempo ativo e tempo online decorrido;
- cria checkpoints enquanto houver medição;
- entrega e reinicia o intervalo quando ocorre um ganho.

### 6.8 `CombatTracker`

- filtra o log de combate antes de interpretar payloads específicos;
- atribui tentativas ofensivas à arma e mão corretas;
- atribui tentativas recebidas a Defesa;
- abre, renova e encerra janelas de atividade;
- não persiste dados diretamente.

### 6.9 `ProfessionTracker`

- identifica a profissão cuja interface está ativa;
- reconhece magias de produção e coleta;
- mede tentativas do início ao sucesso, falha ou interrupção;
- trata Pesca como um estado de duração ampliada;
- não inicia medição apenas pela abertura de uma janela.

### 6.10 `HistoryStore`

- recebe eventos de domínio já normalizados;
- atualiza agregados e o histórico detalhado;
- aplica retenção e compactação;
- fornece consultas para resumo, filtros, detalhes e compartilhamento.

### 6.11 `ViewModel`

- combina retrato das perícias, configuração, equipamento e dados da sessão;
- filtra compacto/expandido, categorias e perícias completas;
- ordena apenas dentro de cada categoria;
- calcula textos, cores, tooltips e o resumo do cabeçalho;
- cria linhas transitórias para notificações discretas quando necessário.

### 6.12 `NotificationQueue`

- transforma ganhos em itens de apresentação;
- aplica modos globais e preferências individuais;
- agrupa ganhos rápidos da mesma perícia;
- descarta itens vencidos;
- entrega um item de cada vez ao frame visual.

### 6.13 `ShareService`

- gera a prévia das mensagens;
- valida destino e destinatário;
- divide mensagens com segurança;
- envia somente após confirmação;
- mantém uma fila curta e cancelável.

### 6.14 `SlashCommands`

- normaliza espaços e o nome do subcomando;
- traduz comandos em chamadas aos mesmos serviços usados pelos botões;
- mostra ajuda localizada para entradas desconhecidas;
- abre a categoria nativa por uma função encapsulada e compatível com o cliente;
- só registra os subcomandos de diagnóstico em compilações de desenvolvimento.

Comandos não alteram o banco diretamente. Por exemplo, `/step lock` chama o `ConfigStore`, e `/step compact` chama o controlador do painel, preservando callbacks e sincronização.

## 7. Registro canônico de perícias

Cada entrada terá estrutura conceitual semelhante a:

```lua
{
  key = "primary.mining",
  category = "primary",
  localizedNameKey = "SKILL_MINING",
  knownSkillLineID = 186,
  icon = 136248,
  tracker = "gather",
  defaultVisibility = "hidden",
  equipmentSubclasses = nil,
}
```

### 7.1 Regras de resolução

1. No carregamento, o registro constrói um mapa `nome localizado -> skillKey`.
2. A varredura consulta o nome retornado pelo cliente.
3. Um nome reconhecido é convertido para a chave canônica.
4. A chave, e nunca o nome, é usada em configuração, histórico e callbacks.
5. Linhas desconhecidas são ignoradas e podem ser registradas no modo de diagnóstico.

IDs conhecidos de linhas de perícia poderão ser armazenados como documentação e auxiliares de teste. A arquitetura não pressupõe que `GetSkillLineInfo` forneça esses IDs nesta versão do cliente.

### 7.2 Nomes localizados

Inglês e português do Brasil serão mantidos diretamente desde a primeira implementação. Os demais idiomas seguirão os arquivos de localização do projeto.

Quando existir uma magia base confiável, `GetSpellInfo` ou `C_Spell.GetSpellName` poderá ajudar a obter o nome localizado. A função deve ser encapsulada com fallback para não tornar APIs modernas obrigatórias.

### 7.3 Ícones

Os ícones são metadados do registro, não do item atualmente equipado. Isso mantém a linha estável quando a arma é trocada.

Antes da versão pública, todos os `fileID` precisam ser validados no cliente. Ausência de textura deve cair em um ícone genérico de perícia, nunca em uma linha invisível.

### 7.4 Armas de punho e Desarmado

O valor `Enum.ItemWeaponSubclass.Unarmed` representa a subclasse de item usada por armas de punho. Ele não significa que o personagem esteja sem arma.

Portanto:

- arma de punho equipada resolve para `combat.fist_weapons`;
- mão principal vazia pode resolver para `combat.unarmed` quando uma tentativa física desarmada for observada;
- mão secundária vazia não gera, por si só, atividade de Desarmado;
- os payloads e ganhos reais desses dois casos devem ser confirmados no cliente.

## 8. Modelo do retrato de perícias

O `SkillScanner` produz em memória:

```lua
snapshot = {
  [skillKey] = {
    current = 125,
    maximum = 150,
    temporary = 0,
    modifier = 0,
    learned = true,
    scanIndex = 14,
  },
}
```

`scanIndex` é efêmero e nunca será persistido.

### 8.1 Comparação de retratos

| Situação | Resultado |
| --- | --- |
| Chave ausente antes e presente agora durante bootstrap | Baseline; sem log e sem notificação. |
| Chave ausente antes e presente depois do bootstrap | Aprendizado ou reaprendizado. |
| `current` aumentou | Um evento de ganho com a diferença total. |
| `current` diminuiu sem abandono | Atualização corretiva; registrar diagnóstico, sem ganho. |
| `maximum` mudou | Atualizar interface e progresso; não criar ganho isolado. |
| Chave presente antes e ausente agora | Abandono; fechar segmento e medições. |
| Apenas bônus/modificador mudou | Atualizar tooltip, sem alterar cor de progresso. |

Um salto de mais de um ponto será um único evento com `gainedPoints > 1`. A interface pode apresentá-lo como `+N`, e os agregados contabilizam os N pontos. Não serão inventados horários individuais para pontos que o cliente informou juntos.

### 8.2 Agrupamento de eventos de varredura

`SKILL_LINES_CHANGED` pode ocorrer várias vezes em sequência. O scanner agendará uma única varredura após aproximadamente `0,10` segundo. Novos eventos enquanto houver uma varredura agendada serão coalescidos.

`PLAYER_LEVEL_UP`, `PLAYER_ENTERING_WORLD` e eventos de profissão podem solicitar uma varredura, mas todos usam o mesmo agrupador.

Validação no cliente `20506` em 2026-07-11:

- o ganho de Machado de Duas Mãos emitiu `SKILL_LINES_CHANGED` no instante monotônico `147440,819`;
- a varredura agrupada ocorreu em `147440,919`, confirmando o atraso de `0,10` segundo;
- a comparação produziu `combat.two_handed_axes 112 -> 113/115 (+1)`;
- um ganho separado de Defesa produziu `combat.defense 111 -> 112/115 (+1)`;
- ambos os novos valores coincidiram com a janela de perícias do jogo.

Com isso, o debounce de `0,10` segundo e a comparação incremental de um ponto ficam validados para a V1. Ganhos múltiplos em uma única varredura continuam pendentes como caso de borda.

## 9. Ciclo de inicialização

```text
ADDON_LOADED: STEP
  -> Carregar e migrar STEPDB
  -> Inicializar localização e registro
  -> Criar serviços e frames ocultos
  -> PLAYER_LOGIN
  -> Resolver equipamento
  -> Varredura baseline das perícias
  -> Aplicar padrões somente às chaves novas
  -> Construir ViewModel e exibir painel
  -> Ativar rastreadores e callbacks
```

O bootstrap só termina depois da primeira varredura bem-sucedida. Até esse momento, ganhos não geram histórico nem notificação.

## 10. Eventos do jogo

### 10.1 Núcleo e perícias

| Evento | Uso |
| --- | --- |
| `ADDON_LOADED` | Inicializar SavedVariables quando o addon for STEP. |
| `PLAYER_LOGIN` | Concluir bootstrap. |
| `PLAYER_ENTERING_WORLD` | Revalidar retrato e sessão. |
| `SKILL_LINES_CHANGED` | Solicitar nova varredura. |
| `LEARNED_SPELL_IN_SKILL_LINE` | Sinal adicional disponível no cliente; nunca fonte única. |
| `PLAYER_LEVEL_UP` | Atualizar máximos e painel. |
| `PLAYER_LOGOUT` | Fechar intervalos e persistir checkpoint. |

### 10.2 Combate e equipamento

| Evento | Uso |
| --- | --- |
| `PLAYER_REGEN_DISABLED` | Abrir o contexto de combate e aplicar comportamento visual. |
| `PLAYER_REGEN_ENABLED` | Encerrar janelas de combate e restaurar o painel. |
| `COMBAT_LOG_EVENT_UNFILTERED` | Observar tentativas ofensivas e recebidas. |
| `PLAYER_EQUIPMENT_CHANGED` | Invalidar mãos, fechar atribuições antigas e resolver novamente. |
| `PLAYER_DEAD` | Encerrar janelas ativas. |

### 10.3 Profissões e lançamento de magia

| Evento | Uso |
| --- | --- |
| `TRADE_SKILL_SHOW` / `TRADE_SKILL_UPDATE` | Manter contexto de produção clássico. |
| `CRAFT_SHOW` / `CRAFT_UPDATE` | Manter contexto da janela clássica alternativa. |
| `UNIT_SPELLCAST_SENT` | Candidato a início de tentativa. |
| `UNIT_SPELLCAST_START` / `UNIT_SPELLCAST_CHANNEL_START` | Confirmar início e horário. |
| `UNIT_SPELLCAST_SUCCEEDED` | Fechar tentativa bem-sucedida ou avançar Pesca. |
| `UNIT_SPELLCAST_STOP` / `UNIT_SPELLCAST_CHANNEL_STOP` | Fechar tentativa. |
| `UNIT_SPELLCAST_FAILED` / `UNIT_SPELLCAST_INTERRUPTED` | Fechar tentativa sem sucesso. |
| `LOOT_OPENED` / `LOOT_CLOSED` | Sinais auxiliares de conclusão de Pesca e coleta. |

Todos os eventos de magia devem ser filtrados para `unit == "player"`.

## 11. Cronometragem

### 11.1 Relógios

- `GetTimePreciseSec()`, quando disponível, ou `GetTime()` mede deltas dentro da sessão.
- `GetServerTime()`, quando disponível, ou `time()` registra data e horário persistidos.
- Valores monotônicos não atravessam reload ou login.
- Tempo offline nunca é inferido pela diferença entre horários de parede.

### 11.2 Estado por perícia

```lua
runtimeActivity = {
  [skillKey] = {
    activeTotal = 0,
    onlineTotal = 0,
    lastPulseAt = nil,
    exactStartedAt = nil,
    mode = nil,
    dirty = false,
  },
}
```

Existem duas formas de medição:

1. `pulse`: tentativas discretas de combate renovam uma pequena janela.
2. `exact`: produção, coleta e pesca possuem início e fim observáveis.

### 11.3 Janela de pulsos

A constante inicial proposta é `ACTIVITY_GAP_SECONDS = 5,0`, sujeita a teste em jogo.

Em cada pulso:

1. o tracker valida que o contexto continua permitido;
2. acumula o intervalo desde o pulso anterior, limitado ao gap;
3. registra o novo pulso;
4. mantém a janela aberta até o próximo pulso, encerramento ou timeout.

Ao ocorrer ganho ou encerramento, o tracker descarrega até o horário atual, também limitado ao gap. Assim, o intervalo normal entre ataques é contado, mas permanecer parado em combate não mantém o cronômetro indefinidamente.

### 11.4 Intervalos exatos

Um intervalo exato possui um token baseado em `castGUID`, quando disponível. Eventos duplicados de encerramento são ignorados.

Uma nova tentativa incompatível fecha conservadoramente a anterior antes de começar. Duração negativa ou excessivamente longa é descartada e registrada no diagnóstico.

### 11.5 Tempo online decorrido

O tempo online desde o último ganho é acumulado por perícia apenas enquanto o log daquela perícia estiver habilitado e ela permanecer aprendida.

Ao desabilitar o log:

- a medição atual é fechada;
- o histórico existente é preservado;
- o intervalo pendente deixa de acumular.

Ao reabilitar o log, um novo baseline temporal é iniciado. O próximo ganho não inclui o período em que o log ficou desabilitado.

### 11.6 Checkpoints

Enquanto qualquer medição estiver ativa, um `C_Timer` de baixa frequência fará checkpoint no máximo a cada 10 segundos. Ele é cancelado quando não há atividade.

Também haverá flush em:

- ganho de perícia;
- fim de tentativa;
- fim de combate;
- troca de equipamento relevante;
- morte;
- reload ou logout.

O checkpoint limita perdas em desconexões abruptas sem introduzir atualização permanente.

## 12. Rastreamento de combate

### 12.1 Filtros rápidos

O handler de `COMBAT_LOG_EVENT_UNFILTERED` deve retornar imediatamente quando:

1. não houver nenhuma perícia de combate com log habilitado;
2. o jogador não estiver em combate;
3. o evento não envolver o GUID do jogador como origem ou destino;
4. o subevento não estiver na lista de interesse.

Subeventos candidatos:

```text
SWING_DAMAGE
SWING_MISSED
RANGE_DAMAGE
RANGE_MISSED
SPELL_DAMAGE
SPELL_MISSED
```

O conjunto final de eventos para Varinhas e Defesa será fechado por instrumentação no cliente.

### 12.2 Tentativas ofensivas

Uma tentativa conta mesmo quando erra, é esquivada, aparada ou bloqueada.

Para `SWING_*`:

- origem deve ser o jogador;
- `isOffHand`, quando presente, seleciona a mão;
- a mão é resolvida pelo cache de equipamento;
- mão principal vazia pode resolver para Desarmado;
- payload não confiável não será atribuído por palpite.

Validação no cliente `20506` em 2026-07-11:

- `SWING_DAMAGE` usa `isOffHand` no décimo campo específico do payload, correspondente ao campo absoluto `21` de `CombatLogGetCurrentEventInfo()`;
- `SWING_MISSED` usa `missType` no primeiro campo específico e `isOffHand` no segundo, correspondentes aos campos absolutos `12` e `13`;
- um ataque da mão principal com Machado de Duas Mãos retornou `isOffHand = false` em `SWING_DAMAGE`;
- o parser deve possuir layouts separados por subevento e nunca reutilizar a posição de `isOffHand` de `SWING_DAMAGE` em `SWING_MISSED`.

Para `RANGE_*`:

- a perícia vem do slot de longo alcance;
- arco, besta, arma de fogo, arremesso e varinha devem ser distinguidos pelo equipamento;
- a forma exata como Varinhas aparece no log precisa de teste.

`SPELL_*` só participa quando uma tabela validada de ataques de arma exigir esse caminho. Magias normais não devem treinar perícia de arma por engano.

O teste com Paladino confirmou `SPELL_DAMAGE` separado para Julgamento e Selo da Retidão durante o mesmo combate em que ocorreu `SWING_DAMAGE`. Esses eventos de magia são ruído para a perícia da arma e devem ser ignorados pelo rastreador ofensivo comum. Varinhas permanecem como a única exceção candidata até validação específica.

### 12.3 Defesa

Defesa recebe pulsos apenas quando:

- o log de Defesa estiver habilitado;
- o jogador estiver em combate;
- o GUID de destino for o jogador;
- o evento representar uma tentativa física relevante recebida.

A proposta inicial inclui `SWING_*` e `RANGE_*`. Eventos `SPELL_*` ficam excluídos até comprovação no cliente de que treinam Defesa.

O cliente `20506` confirmou tentativas físicas recebidas com destino no jogador em:

- `SWING_DAMAGE`, para um golpe que causou dano;
- `SWING_MISSED` com `missType = "PARRY"`, para um ataque aparado pelo jogador.

Ambos são sinais válidos de tentativa recebida para renovar a janela de atividade de Defesa. Outros resultados de erro ainda precisam ser observados, mas usar `SWING_DAMAGE` e `SWING_MISSED` como conjunto inicial deixou de ser apenas uma hipótese.

### 12.4 Troca de equipamento

Em `PLAYER_EQUIPMENT_CHANGED`:

1. fechar a janela associada à mão alterada;
2. invalidar o link e a subclasse antigos;
3. resolver o novo item;
4. emitir `EQUIPMENT_CHANGED`;
5. reconstruir o `ViewModel` e o destaque visual.

Uma janela iniciada com Espadas nunca pode continuar acumulando depois da troca para Maças.

## 13. Rastreamento de profissões

### 13.1 Contexto de produção

Para o cliente clássico, o tracker usa a janela ativa e funções clássicas, como `GetTradeSkillLine()` e `GetCraftDisplaySkillLine()`, encapsuladas e testadas antes do uso.

Abrir `TRADE_SKILL_SHOW` ou `CRAFT_SHOW` apenas identifica o contexto. A medição começa somente com uma tentativa real do jogador.

O teste de Engenharia no cliente `20506` confirmou que o contexto é indispensável:

- a receita Rough Blasting Powder emitiu `spellID = 3918`, um ID da receita e não da profissão;
- `UNIT_SPELLCAST_SENT` apresentou alvo `nil`;
- `TRADE_SKILL_UPDATE` forneceu `Engineering 75/150`;
- o evento `TRADE_SKILL_UPDATE` repetiu após a conclusão.

Assim, uma produção deve ser associada à profissão ativa mantida pelo tracker, e não por uma tabela exaustiva de todos os `spellID` de receitas. Atualizações repetidas da janela devem ser coalescidas.

### 13.2 Produção

Fluxo esperado:

```text
Idle
  -> Casting: SENT ou START reconhecido

Casting
  -> Idle: SUCCEEDED ou STOP
  -> Idle: FAILED ou INTERRUPTED
  -> Casting: próximo item da fila
```

Produções em fila são somadas tentativa a tentativa. O tracker não assume a duração total da fila a partir da quantidade solicitada.

### 13.3 Sequências validadas de produção

Uma produção bem-sucedida de Rough Blasting Powder apresentou:

```text
UNIT_SPELLCAST_SENT
UNIT_SPELLCAST_START
UNIT_SPELLCAST_SUCCEEDED
UNIT_SPELLCAST_STOP
TRADE_SKILL_UPDATE
TRADE_SKILL_UPDATE
```

Uma produção interrompida apresentou variação de ordem:

```text
UNIT_SPELLCAST_SENT
UNIT_SPELLCAST_START
UNIT_SPELLCAST_INTERRUPTED
UNIT_SPELLCAST_STOP
UNIT_SPELLCAST_INTERRUPTED
UNIT_SPELLCAST_INTERRUPTED
UNIT_SPELLCAST_INTERRUPTED
```

Consequências:

- a ordem entre `STOP` e `INTERRUPTED` não é fixa entre tipos de atividade;
- o primeiro evento terminal encerra o relógio monotônico da tentativa;
- eventos posteriores com o mesmo `castGUID` podem refinar o resultado, mas nunca somar nova duração ou novo evento;
- `SUCCEEDED` e `STOP` podem compartilhar o mesmo instante;
- cada tentativa observada recebeu novo `castGUID`;
- a fila de produção ainda precisa ser validada separadamente com quantidade maior que um.

### 13.4 Coleta

O registro manterá uma tabela validada de `spellID -> skillKey` para Mineração, Herborismo e Esfolamento.

Identificadores de ação:

- Mineração: `2576`, validado no cliente `20506`;
- Herborismo: `2366`, ainda pendente de validação;
- Pesca: `7620`, ainda pendente de validação.

Os IDs e ranks alternativos, especialmente Esfolamento, devem ser capturados e confirmados no modo de diagnóstico antes da implementação ser considerada completa.

`2575` identifica a profissão ou habilidade base de Mineração em referências locais, mas não foi o `spellID` emitido pela ação de minerar no cliente testado. STEP deve usar `2576` para reconhecer a tentativa observada.

### 13.5 Sequências validadas de Mineração

Uma tentativa bem-sucedida em Veio de Cobre apresentou:

```text
UNIT_SPELLCAST_SENT
UNIT_SPELLCAST_START
UNIT_SPELLCAST_SUCCEEDED
UNIT_SPELLCAST_STOP
```

Uma tentativa interrompida apresentou:

```text
UNIT_SPELLCAST_SENT
UNIT_SPELLCAST_START
UNIT_SPELLCAST_STOP
UNIT_SPELLCAST_INTERRUPTED
UNIT_SPELLCAST_INTERRUPTED
UNIT_SPELLCAST_INTERRUPTED
```

Todos os eventos da mesma tentativa preservaram o mesmo `castGUID`, e tentativas seguintes receberam novos GUIDs. Consequências para o tracker:

- `UNIT_SPELLCAST_SENT` fornece o alvo localizado, como `Copper Vein`, o `castGUID` e `spellID = 2576`;
- `UNIT_SPELLCAST_START` inicia o intervalo exato;
- `UNIT_SPELLCAST_SUCCEEDED` marca sucesso e pode encerrar o intervalo;
- `UNIT_SPELLCAST_STOP` aparece tanto em sucesso quanto em interrupção;
- `UNIT_SPELLCAST_INTERRUPTED` pode repetir para o mesmo `castGUID` e deve ser idempotente;
- o primeiro terminal fecha o tempo; terminais posteriores apenas refinam o resultado, sem acumular ou registrar uma segunda tentativa;
- um cache curto de GUIDs encerrados impede duplicação.

### 13.6 Pesca

Pesca usa uma pequena máquina de estados própria:

```text
idle -> casting -> waiting -> looting -> idle
                 -> cancelled -> idle
                 -> timeout -> idle
```

O período `waiting` faz parte do tempo ativo. Como os sinais de sucesso e cancelamento podem variar, serão correlacionados lançamento, `UNIT_SPELLCAST_*`, loot e timeout. O timeout deve apenas encerrar a tentativa, nunca inventar sucesso.

### 13.7 Ganho desacoplado da tentativa

O ganho continua sendo detectado pelo `SkillScanner`, não pelo evento de fabricação ou coleta. O `ProfessionTracker` mede atividade; o scanner confirma a alteração numérica. Isso evita registrar sucesso falso quando uma tentativa não aumenta a perícia.

## 14. Evento de domínio de ganho

```lua
gainEvent = {
  eventId = 184,
  type = "gain",
  skillKey = "combat.swords",
  category = "combat",
  oldValue = 124,
  newValue = 125,
  maximum = 150,
  gainedPoints = 1,
  occurredAt = 1783795200,
  sessionId = "1783791000-1",
  segmentId = 1,
  activeSeconds = 42.7,
  onlineSeconds = 183.4,
  reachedMaximum = false,
}
```

Chegar ao máximo continua sendo um ganho e participa normalmente dos agregados. `reachedMaximum = true` seleciona o modo especial de notificação e cria o marco correspondente; não substitui o evento por um tipo incompatível.

O scanner solicita ao `ActivityTracker` os tempos pendentes no momento da criação. Em seguida:

1. `HistoryStore` persiste e atualiza agregados;
2. `NotificationQueue` avalia a apresentação;
3. `ViewModel` atualiza a linha;
4. janelas abertas recebem os callbacks correspondentes.

## 15. Persistência

### 15.1 Estrutura proposta

```lua
STEPDB = {
  schemaVersion = 1,
  config = {
    panel = {
      shown = true,
      locked = false,
      scale = 1,
      point = "CENTER",
      relativePoint = "CENTER",
      x = 0,
      y = 0,
      expanded = false,
      startExpanded = false,
      showHeaderSummary = true,
      sortMode = "progress",
      hideMaxed = false,
      combatBehavior = "keep",
      autoShowEquipped = false,
    },
    notifications = {
      gainMode = "discreet",
      maxMode = "exaggerated",
    },
    skills = {
      ["combat.swords"] = {
        visibility = "expanded",
        logEnabled = true,
        notifyEnabled = true,
      },
    },
    windows = {
      config = {},
      log = {},
    },
  },
  state = {
    sessionCounter = 0,
    known = {},
    activity = {},
    preferencesSeen = {},
  },
  history = {
    nextEventId = 1,
    events = {},
    aggregates = {},
    segments = {},
    archivedSegments = {},
    prunedEventCount = 0,
  },
}
```

### 15.2 Padrões incrementais

Padrões são aplicados por campo ausente, não substituindo tabelas inteiras. Uma perícia recém-descoberta recebe os padrões do PRD somente na primeira vez em que aparece naquele personagem.

Preferências permanecem em `config.skills` após abandono, permitindo restauração ao reaprender.

### 15.3 Sessões

Cada login ou reload cria um `sessionId` único combinando horário e contador. O identificador evita depender de precisão subsegundo do servidor.

Sessões não são mantidas como grandes objetos independentes. Eventos carregam o `sessionId`, e agregados de sessão podem ser construídos ou mantidos de forma compacta.

### 15.4 Segmentos

Aprendizado inicia um segmento; abandono o encerra; reaprendizado inicia outro.

Cada segmento mantém agregados próprios. O limite inicial é de 25 segmentos detalhados por perícia. Segmentos mais antigos são somados em `archivedSegments[skillKey]`, preservando totais sem crescimento indefinido.

### 15.5 Retenção

- máximo de 2.000 eventos detalhados por personagem;
- remoção dos eventos mais antigos quando o limite for excedido;
- agregados vitalícios não são reduzidos pela remoção;
- marcos de máximo, abandono e reaprendizado são priorizados, mas também ficam sujeitos a compactação;
- a interface informa quando detalhes antigos foram resumidos.

O limite será uma constante técnica, não uma opção de usuário na V1.

### 15.6 Agregados

Por perícia e por segmento, manter:

```text
initialValue
latestValue
gainedPoints
gainEvents
activeSeconds
onlineSeconds
bestSecondsPerPoint
slowestSecondsPerPoint
recentSamples
reachedMaxAt
```

`recentSamples` usa uma fila pequena, inicialmente 10 amostras. Em um ganho múltiplo, o tempo por ponto é a duração do evento dividida por `gainedPoints`, com indicação de que se trata de uma amostra agrupada.

### 15.7 Migrações

Migrações seguem funções sequenciais:

```text
migrate_1_to_2
migrate_2_to_3
...
```

Regras:

- validar `schemaVersion` antes de inicializar serviços;
- cada migração deve ser idempotente;
- campos desconhecidos são preservados quando inofensivos;
- valores inválidos voltam ao padrão do campo, sem apagar o restante do banco;
- erros são informados de forma legível e mantêm uma cópia recuperável da tabela antiga durante a sessão.

## 16. Modelo de configuração

### 16.1 Enumerações

```text
visibility: hidden | expanded | compact
sortMode: progress | alphabetical
combatBehavior: keep | compact | hide
notificationMode: exaggerated | discreet | none
```

O valor persistido `compact` significa `Compacto e expandido`, pois o expandido é sempre um superconjunto.

### 16.2 Operações em lote

Presets e ações por categoria são calculados primeiro como uma alteração proposta. Se houver sobrescrita de escolhas personalizadas, a interface solicita confirmação antes de chamar `ConfigStore:ApplyBatch`.

Uma operação em lote emite um único callback com todas as chaves alteradas, evitando múltiplas reconstruções da interface.

### 16.3 Sincronização das superfícies

Os controles nativos e independentes não se atualizam diretamente entre si. Ambos observam `CONFIG_CHANGED` e relêem o valor canônico do `ConfigStore`.

O painel nativo usa:

```text
Settings.RegisterCanvasLayoutCategory
Settings.RegisterAddOnCategory
```

Se essas APIs não estiverem presentes, a integração pode cair para `InterfaceOptions_AddCategory`, sem alterar o restante da interface.

A janela independente usa `BasicFrameTemplateWithInset`, é arrastável, salva posição e entra em `UISpecialFrames` para fechar com `Esc`.

## 17. Interface do painel principal

### 17.1 Construção

- um frame raiz com `BackdropTemplate`;
- cabeçalho curto e clicável;
- pool de linhas reutilizáveis;
- pool pequeno de títulos e separadores;
- altura calculada somente ao reconstruir o conteúdo;
- posição limitada à tela e recuperável.

Cada linha é composta por ícone, nome, valor atual, separador e máximo. Nome e valores usam âncoras separadas para manter alinhamento.

### 17.2 Estados visual e funcional

O estado expandido persistido é separado de um estado temporário imposto pelo combate. Ao sair do combate, STEP restaura exatamente o estado anterior.

Se nenhuma linha estiver visível, o frame raiz é ocultado. Isso não desativa scanners, logs ou notificações habilitados.

### 17.3 Cores

```text
current == maximum       -> verde
current / maximum >= .90 -> amarelo
caso contrário           -> vermelho
maximum e '/'            -> branco
```

`maximum <= 0` usa cor neutra e gera diagnóstico, pois não permite calcular percentual.

### 17.4 Legibilidade e localização

O layout deve aceitar nomes localizados longos. A implementação testará, nesta ordem:

1. largura adaptativa com limite máximo;
2. abreviação localizada conhecida;
3. truncamento visual com nome completo no tooltip.

Não se deve reduzir a fonte a ponto de prejudicar a leitura apenas para manter uma largura rígida.

### 17.5 Tooltips

O tooltip é montado a partir do `ViewModel`. Nenhum cálculo histórico pesado ocorre em `OnEnter`; resumos devem estar em cache ou ser preparados quando os dados mudarem.

## 18. Opções e janela de histórico

### 18.1 Controles compartilhados

`OptionsControls` fornece funções construtoras para checkbox, slider, seletor e linha de perícia. As duas superfícies usam os mesmos formatadores, enumerações, tooltips e callbacks.

Isso não significa reutilizar o mesmo frame simultaneamente; significa reutilizar as regras e os bindings.

### 18.2 Rolagem e densidade

As listas de perícias ficam em `ScrollFrame`. Controles gerais e por categoria são agrupados em blocos colapsáveis somente se os testes de leitura mostrarem necessidade.

A arquitetura permite alterar espaçamento, ordem visual e agrupamento sem mudar o formato persistido.

### 18.3 Histórico

A janela de histórico usa linhas reutilizáveis e duas visões:

- resumo por perícia;
- detalhes da perícia selecionada.

Filtros são estado efêmero da janela, exceto se futuramente houver decisão explícita de persistir o último filtro.

Consultas são paginadas ou limitadas ao intervalo visível. A janela nunca cria 2.000 frames de linha simultaneamente.

## 19. Notificações

### 19.1 Separação entre decisão e apresentação

`NotificationQueue` decide se um evento deve aparecer e em qual modo. `NotificationFrame` apenas apresenta o item recebido.

O frame:

- usa `EnableMouse(false)`;
- não cobre nem captura ações protegidas;
- usa `AnimationGroup` quando possível;
- é ocultado completamente ao terminar;
- não mantém `OnUpdate` depois da animação.

### 19.2 Fila

Parâmetros iniciais propostos:

| Parâmetro | Valor inicial |
| --- | --- |
| Máximo de itens pendentes | 5 |
| Expiração de item pendente | 6 segundos |
| Coalescência da mesma perícia | 0,75 segundo |
| Duração exagerada | aproximadamente 2,4 segundos |
| Duração discreta | aproximadamente 1,2 segundo |

Se a fila estiver cheia, itens vencidos são removidos primeiro. Depois, ganhos comuns antigos podem ser compactados; um marco de máximo tem prioridade.

### 19.3 Modo exagerado

- frame central independente do painel;
- ícone grande;
- escala, brilho e fade;
- nome e `novo/máximo`;
- indicação `+N` quando houver ganho múltiplo;
- som destacado previamente validado.

### 19.4 Modo discreto

- pulso da linha quando ela estiver visível;
- texto curto próximo ao painel;
- linha transitória quando a perícia estiver oculta no compacto;
- som suave pertencente ao preset, se aprovado nos testes.

### 19.5 Marco de máximo

O marco de máximo usa configuração própria. Se `Ocultar perícias completas` estiver ativo, a remoção da linha é adiada até a apresentação terminar.

### 19.6 Sons

A V1 usa sons internos do jogo por `PlaySound` ou `PlaySoundFile`, com canal explicitamente escolhido e fallback silencioso.

Não haverá controle de volume próprio, pois a API não oferece um ajuste por reprodução que STEP possa representar com fidelidade. O jogador controla o canal nas opções de áudio do jogo.

Sons, canal, duração e intensidade visual só serão fechados após teste no cliente. Seleção livre de sons continua fora da V1.

## 20. Compartilhamento no chat

### 20.1 Geração

As mensagens são geradas a partir de consultas imutáveis do `HistoryStore`. A prévia usa exatamente os mesmos chunks que serão enviados, evitando divergência entre contagem e envio.

### 20.2 Limites

Embora o limite do cliente deva ser confirmado, STEP dividirá inicialmente em aproximadamente 230 bytes úteis por mensagem, deixando margem para prefixo e caracteres multibyte.

A divisão ocorre por unidade semântica — uma perícia ou campo — e não no meio de um nome ou número.

### 20.3 Fila de envio

- intervalo inicial entre mensagens: 0,40 segundo;
- início somente após clique de confirmação;
- cancelamento ao fechar a operação, sair do mundo ou ocorrer erro;
- detalhes permitidos para uma única perícia;
- destino validado imediatamente antes de cada envio.

Não haverá reenvio automático após falha.

## 21. Localização

O namespace global `STEP_L` aponta para a tabela do idioma ativo com fallback metatable para `enUS`.

Regras:

- chaves de localização são estáveis e em inglês técnico;
- nomes de perícia usados na resolução ficam separados de textos de interface;
- formatação de tempo e números usa funções centralizadas;
- mensagens de chat são construídas no idioma do remetente;
- nenhum texto de interface é concatenado de forma que impeça tradução natural.

## 22. Desempenho

### 22.1 Metas

- zero trabalho por quadro quando não houver animação;
- zero varreduras de perícia redundantes dentro da janela de debounce;
- filtro de GUID e subevento antes de processar detalhes do log de combate;
- uma reconstrução de painel por lote de alterações;
- quantidade de frames proporcional às linhas visíveis, não ao histórico total.

### 22.2 Caches

Podem ser mantidos em memória:

- nome localizado para chave canônica;
- equipamento por slot;
- linhas do painel;
- resumo de histórico por perícia;
- `ViewModel` da última renderização.

Caches são invalidados por eventos específicos, não por tempo arbitrário.

### 22.3 Diagnóstico de custo

O modo de diagnóstico poderá contar:

- eventos CLEU recebidos e aceitos;
- varreduras solicitadas e executadas;
- reconstruções de painel;
- checkpoints;
- itens de notificação descartados;
- eventos detalhados podados.

## 23. Segurança e robustez

1. Frames de notificação não recebem mouse.
2. Compartilhamento sempre exige ação explícita.
3. Limpeza completa sempre exige confirmação.
4. Entradas de sussurro são validadas e limitadas.
5. Strings vindas do cliente são tratadas como dados, não como código ou formato.
6. Índices e payloads de eventos são verificados antes do uso.
7. Erros de uma tradução ou ícone usam fallback sem impedir o carregamento.
8. O addon não altera CVars do jogador.
9. O banco é validado antes de criar frames dependentes de configuração.

## 24. Instrumentação de desenvolvimento

Uma compilação de desenvolvimento terá um modo de diagnóstico não divulgado como feature pública:

```text
/step debug on
/step debug off
/step debug events
/step debug snapshot
/step debug activity
```

O modo poderá registrar, com limite e filtros:

- nome do evento;
- subevento do log de combate;
- GUID do jogador como origem/destino;
- mão indicada;
- spellID e castGUID;
- contexto de profissão;
- chave resolvida;
- transições de estado e duração.

Dados não devem ser enviados automaticamente ao chat. A saída padrão é o frame de chat local ou uma pequena janela copiável apenas se isso for viável no cliente.

O código de diagnóstico deve ficar atrás de uma constante de desenvolvimento e não executar trabalho quando desativado.

## 25. Estratégia de testes

### 25.1 Testes puros fora do jogo

Funções sem dependência direta do WoW devem ser testáveis com Lua e APIs simuladas:

- comparação de retratos;
- aplicação de padrões e migrações;
- estados de visibilidade;
- filtros e ordenação do `ViewModel`;
- acumulação por pulso e intervalo exato;
- agregados e retenção;
- divisão de chat por bytes;
- coalescência e prioridade de notificações.

### 25.2 Testes instrumentados no cliente

Obrigatórios antes de considerar cada rastreador concluído:

| Cenário | Evidência exigida |
| --- | --- |
| Mão principal | Evento, mão, item, skillKey e ganho observado. |
| Mão secundária diferente | `isOffHand` ou sinal equivalente e atribuição correta. |
| Erro, esquiva, aparo e bloqueio | Tentativa aceita sem exigir dano. |
| Arco, besta, arma de fogo e arremesso | Slot e subclasse corretos. |
| Varinha | Subevento real e atribuição correta. |
| Sem arma | Separação entre Desarmado e arma de punho. |
| Defesa | Tentativa recebida aceita; combate sem ataque não conta. |
| Produção simples | Início, fim, duração e ganho desacoplado. |
| Fila de produção | Tentativas individuais e interrupção. |
| Mineração, Herborismo e Esfolamento | spellIDs e encerramentos reais. |
| Pesca com loot | Lançamento, espera e fechamento. |
| Pesca cancelada | Fechamento sem sucesso e sem vazamento. |
| Level up | Mudança de máximo sem ganho falso. |
| Abandono e reaprendizado | Segmentos separados e preferência restaurada. |

### 25.3 Matriz visual

Testar ao menos:

- escalas de UI comuns e resoluções 16:9, ultrawide e janela;
- painel compacto e expandido com uma, várias e todas as categorias;
- nomes longos em português, alemão, francês e russo;
- valores de um a três dígitos;
- cores em fundos e condições de iluminação diferentes;
- configurações com muitas perícias;
- log perto do limite;
- notificações exagerada e discreta isoladas e em sequência rápida;
- painel ancorado próximo às quatro bordas da tela.

### 25.4 Critério para alterações visuais

Uma alteração de espaçamento, dimensão, tipografia, animação ou som pode ser feita durante os testes sem reabrir o escopo, desde que preserve o comportamento aprovado.

Se o teste indicar mudança de fluxo, padrão, dado armazenado ou critério de aceite:

1. registrar a proposta;
2. atualizar o PRD;
3. atualizar esta arquitetura;
4. implementar ou ajustar;
5. repetir os critérios afetados.

## 26. Riscos e validações pendentes

| Risco | Tratamento |
| --- | --- |
| Payload de mão secundária variar no cliente | Layouts de `SWING_DAMAGE` e `SWING_MISSED` validados para mão principal; captura com `isOffHand = true` ainda pendente. |
| Varinha usar subevento inesperado | Instrumentar `RANGE_*` e `SPELL_*`; aceitar só o caminho comprovado. |
| Arma de punho ser confundida com Desarmado | Separar subclasse de item e mão vazia no `EquipmentResolver`. |
| Eventos de produção variarem entre janelas | Engenharia validada com `TRADE_SKILL_UPDATE`; janela Craft e outras profissões ainda pendentes. |
| Coleta possuir ranks/spellIDs alternativos | Mineração validada com `2576`; Herborismo, Esfolamento e possíveis IDs alternativos ainda exigem captura. |
| Pesca não emitir um único encerramento confiável | Correlacionar cast, loot, cancelamento e timeout. |
| Desconexão abrupta perder delta recente | Checkpoint somente enquanto ativo. |
| Histórico crescer indefinidamente | Eventos e segmentos limitados; agregados compactos. |
| Notificação exagerada atrapalhar combate | Frame sem mouse, duração curta e teste visual. |
| Configuração ficar extensa | Scroll, agrupamento e refinamento visual sem duplicar estado. |
| Traduções longas quebrarem alinhamento | Largura limitada, truncamento com tooltip e matriz visual. |

## 27. Fases de implementação recomendadas

### Fase 0 — Provas de API

- criar esqueleto mínimo carregável;
- implementar diagnóstico temporário;
- validar retrato de perícias e equipamento;
- capturar combate, produção, coleta e Pesca;
- registrar conclusões neste documento.

### Fase 1 — Núcleo de dados

- banco, migração e configuração;
- registro e scanner;
- equipamento;
- barramento interno;
- testes puros principais.

### Fase 2 — Painel e opções

- `ViewModel`;
- painel compacto/expandido;
- opções nativas e independentes;
- presets, tooltips e comportamento em combate;
- primeira rodada de leitura visual.

### Fase 3 — Rastreamento e histórico

- atividade de combate;
- produção, coleta e Pesca;
- segmentos, agregados e retenção;
- janela de histórico.

### Fase 4 — Notificações e compartilhamento

- fila e modos visuais;
- seleção e validação de sons;
- prévia e fila de chat;
- testes de spam e legibilidade.

### Fase 5 — Qualidade e lançamento

- matriz completa do PRD;
- localizações;
- migração simulada;
- sessões longas, reload e desconexão;
- revisão do PRD e desta arquitetura;
- empacotamento e documentação de release em etapa separada.

## 28. Definição de pronto para iniciar implementação

- PRD 1.0 aprovado.
- Arquitetura Técnica aprovada.
- cliente `20506` disponível para instrumentação.
- decisão de iniciar pela Fase 0 confirmada.

## 29. Definição de concluído para a V1

1. Todos os critérios de aceite da seção 20 do PRD possuem evidência de teste.
2. Todas as validações obrigatórias desta arquitetura foram executadas no cliente.
3. Não restam eventos conhecidos atribuídos à perícia errada.
4. Painel, configurações e notificações passaram pela revisão visual.
5. PRD, arquitetura e comportamento implementado estão alinhados.
6. SavedVariables sobrevivem a reload, logout, migração simulada e histórico no limite.
7. O addon não gera erros Lua nem trabalho contínuo desnecessário em sessão longa.

## 30. Evidências locais consultadas

Esta proposta foi baseada em padrões já presentes no cliente instalado:

- `FUR/FUR.lua`: painel compacto/expandido, posição e reação a combate/equipamento;
- `BAD/BAD.lua` e `AGRO/AGRO.lua`: painel nativo, janela independente, `UISpecialFrames` e configuração compartilhada;
- `ZygorGuidesViewerClassicTBCAnniv/Code-TBC/Profession.lua`: varredura de linhas e associação localizada de profissões;
- `ZygorGuidesViewerClassicTBCAnniv/Code-TBC/Item-DataTables.lua`: metadados de perícias de armas;
- `TradeSkillMaster/LibTSMWoW/Source/Util/ClientInfo.lua`: separação das APIs de profissão por versão do cliente;
- `GatherMate2`: eventos de lançamento e IDs iniciais de coleta;
- `Details`: subeventos e leitura do log de combate.

Essas referências comprovam padrões disponíveis, mas não substituem os testes instrumentados específicos de STEP.

## 31. Aprovação e manutenção

Este documento foi aprovado em 2026-07-11 e é a baseline técnica da V1.

Durante o desenvolvimento:

- descobertas de API devem atualizar as seções correspondentes;
- ajustes visuais devem atualizar parâmetros e a matriz visual quando relevante;
- decisões que alterem comportamento devem atualizar primeiro o PRD;
- alterações de formato persistido devem elevar `schemaVersion` e incluir migração;
- valores ainda marcados como iniciais ou propostos só se tornam definitivos após teste no cliente.
