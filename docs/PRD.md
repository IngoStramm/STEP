# STEP — Skill Training & Evolution Panel

## Product Requirements Document (PRD)

| Campo | Valor |
| --- | --- |
| Produto | STEP — Skill Training & Evolution Panel |
| Cliente-alvo | World of Warcraft Anniversary / Burning Crusade Classic 2.5.6 |
| Interface-alvo | 20506 |
| Versão do documento | 1.0 |
| Status | Aprovado como baseline funcional |
| Data da aprovação | 2026-07-11 |
| Idioma canônico | Português do Brasil |

## 1. Resumo do produto

STEP é um addon compacto e configurável para acompanhar a evolução das perícias aprendidas por um personagem. Ele reúne em um único painel as perícias de combate, profissões primárias e profissões secundárias que o jogador decidir visualizar.

Além de mostrar o valor atual e máximo de cada perícia, STEP registra o tempo dedicado à progressão, mantém um histórico de ganhos, oferece notificações visuais e sonoras e permite compartilhar resumos no chat do jogo.

O produto deve servir igualmente a jogadores que desejem acompanhar apenas armas, apenas profissões ou uma combinação personalizada das duas categorias.

## 2. Problema

Durante o leveling e o treinamento de profissões, o jogo não oferece uma visão compacta e persistente das perícias que o jogador escolheu desenvolver. Para consultar o progresso, o jogador precisa abrir janelas maiores, alternar entre categorias e interpretar valores sem um histórico de quanto tempo cada avanço exigiu.

STEP deve resolver esse problema com uma visualização discreta, disponível durante o jogo e adaptável ao objetivo de cada personagem.

## 3. Objetivos

1. Exibir o progresso das perícias aprendidas escolhidas pelo jogador.
2. Permitir uma visualização compacta para acompanhamento contínuo e uma visualização expandida para consulta completa.
3. Medir e registrar o tempo ativo dedicado ao treinamento de cada perícia.
4. Celebrar ganhos de perícia com níveis configuráveis de notificação.
5. Manter um histórico por personagem, com visão resumida e detalhada.
6. Permitir o compartilhamento controlado de resumos no chat.
7. Funcionar no idioma do cliente sem depender de nomes em inglês para identificar perícias.
8. Preservar uma interface pequena, legível e coerente com o estilo visual do FUR.

## 4. Não objetivos da primeira versão

1. Mostrar perícias que o personagem ainda não aprendeu.
2. Informar onde ficam treinadores ou quanto custa aprender uma perícia.
3. Recomendar receitas, rotas de coleta ou locais de treinamento.
4. Automatizar ataques, produção, coleta ou qualquer ação protegida do jogador.
5. Sincronizar dados entre jogadores ou usar serviços externos.
6. Criar perfis compartilhados entre personagens.
7. Exibir um botão no minimapa.
8. Calcular uma estimativa de tempo até o máximo.
9. Criar metas de sessão.
10. Exportar o histórico completo para ferramentas externas.

## 5. Público-alvo

- Jogadores criando e evoluindo personagens novos.
- Jogadores treinando perícias de armas atrasadas.
- Jogadores desenvolvendo profissões primárias ou secundárias.
- Jogadores que desejam medir o tempo gasto em uma progressão.
- Jogadores que preferem interfaces compactas e configuráveis.

## 6. Terminologia

| Termo | Definição |
| --- | --- |
| Perícia | Linha numérica aprendida pelo personagem, com valor atual e valor máximo. |
| Perícia de combate | Perícia de arma, Defesa ou Desarmado. |
| Profissão primária | Profissão principal aprendida pelo personagem, como Alquimia, Mineração ou Engenharia. |
| Profissão secundária | Culinária, Primeiros Socorros ou Pesca. |
| Painel compacto | Estado reduzido que mostra apenas as perícias selecionadas para acompanhamento prioritário. |
| Painel expandido | Estado completo que mostra todas as perícias habilitadas para essa visualização. |
| Tempo ativo | Tempo no qual o personagem está efetivamente praticando uma perícia segundo as regras deste documento. |
| Tempo decorrido | Tempo online transcorrido entre dois ganhos, independentemente de o personagem ter praticado continuamente. |
| Sessão | Período iniciado no login ou reload e encerrado no logout, desconexão ou reload seguinte. |
| Evento de ganho | Alteração positiva do valor atual de uma perícia. |

## 7. Categorias contempladas

### 7.1 Perícias de combate

STEP deve reconhecer e poder exibir todas as perícias de armas aprendidas pelo personagem, incluindo as variações de uma e duas mãos, armas de longo alcance e varinhas quando aplicáveis.

Regras especiais:

- Defesa deve existir como opção, mas vir oculta por padrão.
- Desarmado deve existir como opção, mas vir oculto por padrão.
- Perícias de armadura, idiomas e linhas sem progressão numérica não devem ser tratadas como perícias monitoráveis.
- O addon deve considerar apenas perícias que o personagem aprendeu.

### 7.2 Profissões primárias

STEP deve reconhecer as profissões primárias numéricas aprendidas pelo personagem, incluindo:

- Alquimia.
- Alfaiataria.
- Couraria.
- Encantamento.
- Engenharia.
- Ferraria.
- Herborismo.
- Joalheria.
- Mineração.
- Esfolamento.

Especializações de profissão sem uma progressão numérica própria não devem criar linhas independentes.

### 7.3 Profissões secundárias

STEP deve reconhecer:

- Culinária.
- Primeiros Socorros.
- Pesca.

Montaria não faz parte do escopo porque não progride pelo uso da mesma maneira que as demais perícias monitoradas.

### 7.4 Aprendizado, abandono e reaprendizado

- Uma perícia aprendida após o login deve aparecer automaticamente nas configurações.
- Uma profissão abandonada deve ser removida das visualizações ativas.
- O abandono deve encerrar qualquer medição ativa e criar um marco no histórico.
- Caso a profissão seja reaprendida, o novo progresso deve começar em um segmento separado.
- Médias anteriores ao abandono não devem ser combinadas com o novo segmento.
- Preferências de exibição anteriores podem ser restauradas quando a mesma perícia for reaprendida.

## 8. Painel principal

### 8.1 Aparência

O painel deve ser discreto, compacto e baseado na linguagem visual do FUR:

- Fundo escuro sem bordas pesadas.
- Cabeçalho curto com o título `STEP`.
- Resumo opcional no cabeçalho, como `4/9 no máximo` ou `3 precisam treino`.
- Linhas densas, mas legíveis.
- Ícones de 16 a 18 pixels.
- Janela arrastável quando destravada.
- Posição salva por personagem.
- Altura ajustada dinamicamente ao conteúdo.

Cada linha deve mostrar:

```text
{ícone} {nome localizado da perícia} {valor atual}/{valor máximo}
```

O nome deve ser exibido porque ícones semelhantes podem tornar ambíguas perícias de uma e duas mãos.

### 8.2 Cores

- Verde: valor atual igual ao máximo.
- Amarelo: valor atual igual ou superior a 90% do máximo, mas ainda incompleto.
- Vermelho: valor atual abaixo de 90% do máximo.
- Branco: separador `/` e valor máximo.

A cor deve considerar o valor-base aprendido. Bônus temporários ou provenientes de equipamento podem aparecer no tooltip, mas não devem alterar a classificação de progresso.

### 8.3 Agrupamento

No painel expandido, a ordem padrão das seções deve ser:

1. Perícias de combate.
2. Profissões primárias.
3. Profissões secundárias.

Se houver conteúdo visível em mais de uma seção, deve existir entre elas uma linha horizontal e um pequeno título localizado. Se uma seção não tiver linhas visíveis, seu título e seus separadores não devem aparecer.

No painel compacto, as mesmas regras de agrupamento devem ser aplicadas apenas às perícias selecionadas para esse estado.

### 8.4 Ordenação

O jogador deve poder escolher entre:

- Menor percentual de conclusão primeiro, com perícias completas ao final.
- Ordem alfabética localizada.

A ordenação deve ocorrer dentro de cada categoria e não deve misturar combate com profissões.

### 8.5 Destaque da arma equipada

Quando uma perícia corresponder a uma arma equipada, sua linha deve receber um destaque visual discreto. O destaque não deve substituir a cor de progresso nem alterar a ordem configurada.

Uma opção adicional, desabilitada por padrão, pode fazer a perícia da arma equipada aparecer temporariamente no painel compacto mesmo quando não estiver fixada nele.

## 9. Estados compacto e expandido

### 9.1 Alternância

- O cabeçalho deve possuir um controle `+`/`−`.
- Clicar no cabeçalho ou no controle deve alternar os estados.
- O estado atual deve ser salvo por personagem.
- Deve existir a opção `Iniciar expandido`.

### 9.2 Visibilidade por perícia

Nenhuma perícia é obrigatória. Cada perícia aprendida deve possuir um seletor com três estados:

1. Oculta.
2. Somente expandido.
3. Compacto e expandido.

Uma perícia configurada para o compacto também deve aparecer no expandido. O painel expandido é sempre um superconjunto do painel compacto.

### 9.3 Padrões iniciais

No primeiro uso de um personagem:

- Perícias de armas aprendidas devem iniciar como `Somente expandido`.
- A perícia correspondente à arma equipada deve iniciar como `Compacto e expandido`, quando identificável.
- Defesa e Desarmado devem iniciar ocultos.
- Profissões primárias e secundárias devem iniciar ocultas.
- Log e notificação devem inicialmente acompanhar as perícias visíveis.

Esses padrões não impõem regras permanentes e podem ser alterados livremente.

### 9.4 Presets

As configurações devem oferecer presets aplicados manualmente:

- Armas: oculta profissões, mostra armas aprendidas no expandido e fixa a arma equipada no compacto; Defesa e Desarmado permanecem ocultos.
- Profissões: oculta perícias de combate e mostra todas as profissões aprendidas no compacto e no expandido.
- Completo: mostra todas as perícias aprendidas no expandido, fixa a arma equipada no compacto e mantém Defesa e Desarmado ocultos até escolha explícita.
- Começar vazio: oculta todas as perícias.

Aplicar um preset deve solicitar confirmação quando substituir uma configuração personalizada existente.
Depois da aplicação, log e notificação devem acompanhar as perícias tornadas visíveis, sem impedir ajustes individuais posteriores.

### 9.5 Nenhuma perícia visível

Se todas as perícias estiverem ocultas:

- O painel principal deve ficar oculto em vez de permanecer vazio.
- O addon deve continuar acessível pelos comandos e pelas opções do jogo.
- Uma mensagem discreta deve informar que nenhuma perícia está selecionada.
- Logs e notificações explicitamente habilitados para perícias ocultas devem continuar funcionando.

### 9.6 Comportamento em combate

O jogador deve poder escolher uma das opções:

- Manter o estado atual.
- Compactar automaticamente em combate e restaurar o estado anterior ao sair.
- Ocultar automaticamente em combate e restaurar o estado anterior ao sair.

Ocultar e compactar são comportamentos mutuamente exclusivos.

## 10. Configurações

### 10.1 Acesso

As configurações devem estar disponíveis em dois locais sincronizados:

- `Opções do jogo > AddOns > STEP`.
- Janela individual arrastável aberta por `/step config`.

A janela individual deve:

- Fechar com `Esc`.
- Salvar sua posição.
- Atualizar imediatamente o painel principal.
- Mostrar os mesmos valores do painel nativo.

### 10.2 Configurações gerais

- Mostrar ou ocultar painel.
- Travar ou destravar painel.
- Escala do painel.
- Resetar posição.
- Iniciar expandido.
- Mostrar ou ocultar o resumo de progresso no cabeçalho.
- Ordenação.
- Ocultar perícias completas.
- Comportamento em combate.
- Sempre mostrar temporariamente a perícia da arma equipada no compacto.
- Modo global para ganhos comuns.
- Modo global para o momento em que uma perícia atinge o máximo.

### 10.3 Configurações por perícia

Cada perícia aprendida deve permitir:

- Escolher a visibilidade.
- Ativar ou desativar o registro no log.
- Ativar ou desativar a participação nas notificações.

Devem existir controles em massa por categoria:

- Mostrar todas no expandido.
- Fixar todas no compacto.
- Ocultar todas.
- Ativar ou desativar logs.
- Ativar ou desativar notificações.
- Restaurar padrões da categoria.

## 11. Tooltips

Ao passar o mouse sobre uma linha, o tooltip deve poder mostrar:

- Nome completo da perícia.
- Valor-base atual e máximo.
- Percentual concluído.
- Quantos pontos faltam.
- Bônus temporários ou de equipamento, quando existirem.
- Pontos ganhos na sessão.
- Tempo ativo desde o último ganho.
- Tempo ativo total da sessão para essa perícia.

## 12. Notificações

### 12.1 Modos globais

O jogador deve configurar separadamente ganhos comuns e o momento em que uma perícia atinge o máximo. Cada um desses dois tipos de evento deve permitir três modos:

#### Exagerada

- Ícone grande da perícia em destaque.
- Animação de escala, brilho e desaparecimento.
- Texto central informando o novo valor.
- Som destacado.

#### Discreta

- Brilho ou pulso breve na linha.
- Texto pequeno próximo ao painel.
- Som suave, se fizer parte do preset discreto.

#### Nenhuma

- Apenas os valores e o histórico são atualizados.

### 12.2 Regras

- A participação pode ser desabilitada individualmente por perícia.
- Atingir o máximo deve poder usar um modo diferente do ganho comum.
- Ganhos rápidos devem entrar em uma fila e não se sobrepor.
- A fila não deve manter notificações antigas por tempo excessivo.
- Se uma perícia oculta no compacto subir no modo discreto, sua linha deve aparecer temporariamente, receber o efeito e desaparecer novamente.
- Se `Ocultar perícias completas` estiver ativo, uma perícia que acabou de atingir o máximo deve permanecer visível pelo tempo necessário para a celebração antes de ser ocultada.

## 13. Medição de tempo

### 13.1 Princípios

- O log deve priorizar tempo ativo.
- O tempo decorrido deve ser registrado como contexto complementar.
- Tempo offline nunca deve ser contabilizado.
- Reload, logout ou desconexão devem pausar os contadores com segurança.
- O tempo acumulado desde o último ganho pode continuar na sessão seguinte.
- Um ganho associa ao evento o tempo ativo e o tempo decorrido acumulados desde o ganho anterior observado.
- Aplicar consumíveis, melhorias temporárias ou encantamentos e trocar equipamento que modifica uma profissão não inicia o cronômetro dessa profissão.
- Bônus temporários e de equipamento podem ser exibidos como contexto, mas não são ganhos permanentes e não criam entradas de progressão no log.

### 13.2 Perícias de ataque

Estar em combate é obrigatório, mas não suficiente.

O tempo ativo de uma perícia de ataque deve ser contabilizado somente quando:

1. O personagem estiver em combate.
2. Uma arma correspondente estiver equipada ou o ataque corresponder à perícia monitorada.
3. O addon observar uma tentativa de ataque relevante.

Após uma tentativa, a perícia pode permanecer ativa durante um pequeno intervalo entre ataques. A medição deve parar quando:

- O personagem sair de combate.
- A arma deixar de corresponder à perícia.
- Não houver nova atividade pelo intervalo definido tecnicamente.

O comportamento deve contemplar:

- Mão principal e mão secundária com perícias diferentes.
- Duas armas da mesma categoria.
- Ataques à distância.
- Varinhas.
- Troca de armas durante o combate.
- Ataques que erram, são esquivados, aparados ou bloqueados.

### 13.3 Defesa

Defesa deve acumular tempo ativo quando:

- Estiver habilitada para log.
- O personagem estiver em combate.
- O addon observar tentativas de ataque recebidas pelo personagem.

Apenas permanecer em combate sem receber ataques não deve treinar o cronômetro de Defesa.

### 13.4 Desarmado

Desarmado deve seguir as regras de perícia de ataque e só acumular tempo quando o ataque observado corresponder efetivamente a Desarmado.

Casos especiais do cliente envolvendo armas de punho e Desarmado devem ser validados na Arquitetura Técnica e nos testes em jogo.

### 13.5 Profissões de produção

Culinária, Primeiros Socorros e profissões primárias de produção devem acumular tempo somente durante tentativas reais de fabricação.

- Abrir a janela da profissão não inicia o contador.
- Produção em fila deve acumular o tempo das operações executadas.
- Interrupções encerram a tentativa atual.
- Uma tentativa pode consumir tempo ativo mesmo quando não resultar em ganho.

### 13.6 Profissões de coleta

Mineração, Herborismo e Esfolamento devem acumular tempo durante tentativas reais de coleta.

- Aproximar-se de um recurso ou abrir o mapa não inicia o contador.
- A tentativa começa quando a ação de coleta começa.
- Sucesso, falha ou interrupção encerram a tentativa.
- A tentativa pode consumir tempo ativo mesmo quando não resultar em ganho.

### 13.7 Pesca

Pesca deve acumular tempo desde o lançamento da linha até um dos seguintes resultados:

- Coleta do peixe ou item.
- Cancelamento.
- Interrupção.
- Término da tentativa sem coleta.

O período de espera pelo peixe faz parte do tempo ativo de Pesca.

## 14. Log e histórico

### 14.1 Armazenamento funcional

- O histórico deve ser separado por personagem.
- Deve sobreviver a logout e reload.
- Deve possuir retenção limitada para não crescer indefinidamente.
- A política e o limite exatos de retenção serão definidos na Arquitetura Técnica.

### 14.2 Acesso

O log deve abrir em uma janela separada, arrastável e fechável com `Esc`, acessível por:

- `/step log`.
- Botão com ícone de histórico ou relógio no painel principal.
- Botão nas configurações.

### 14.3 Visualização resumida

A visualização resumida deve apresentar:

| Campo | Descrição |
| --- | --- |
| Perícia | Nome localizado. |
| Progressão | Valor inicial e final do período. |
| Pontos | Quantidade obtida. |
| Tempo ativo | Soma do tempo efetivamente monitorado. |
| Tempo decorrido | Tempo online transcorrido. |
| Média | Tempo ativo médio por ponto. |
| Melhor ponto | Menor tempo ativo registrado para um ganho no período. |
| Ponto mais lento | Maior tempo ativo registrado para um ganho no período. |
| Média recente | Média dos últimos ganhos disponíveis, com a quantidade considerada indicada na interface. |

### 14.4 Visualização detalhada

Ao selecionar uma perícia, o jogador deve poder consultar eventos individuais contendo:

- Data e horário.
- Valor anterior e novo valor.
- Tempo ativo desde o ganho anterior.
- Tempo decorrido desde o ganho anterior.
- Sessão à qual o ganho pertence.
- Marcos de máximo, abandono ou reaprendizado.

### 14.5 Filtros

- Sessão atual.
- Histórico completo.
- Perícias de combate.
- Profissões primárias.
- Profissões secundárias.
- Perícia específica.

### 14.6 Ações

- Limpar dados da sessão atual.
- Limpar histórico completo com confirmação.
- Selecionar uma ou mais perícias para compartilhamento.
- Compartilhar resumo.
- Compartilhar detalhes quando apenas uma perícia estiver selecionada.

## 15. Compartilhamento no chat

### 15.1 Destinos

O jogador deve poder escolher, quando disponíveis:

- Grupo.
- Raid.
- Guilda.
- Dizer.
- Sussurro, com destinatário informado pelo jogador.

### 15.2 Resumo de uma perícia

Formato conceitual:

```text
[STEP] Espadas: 100 -> 125 (+25) em 42m10s ativos. Média: 1m41s por ponto.
```

### 15.3 Resumo de várias perícias

Formato conceitual:

```text
[STEP] Sessão: Espadas +25 em 42m; Mineração +7 em 18m; Pesca +8 em 31m.
```

### 15.4 Proteção contra spam

- `Compartilhar todas` deve usar sempre o formato resumido.
- Detalhes devem ser permitidos apenas para uma perícia por operação.
- Mensagens maiores que o limite do chat devem ser divididas com segurança.
- O envio deve respeitar intervalos e não disparar muitas linhas simultaneamente.
- Antes de um compartilhamento extenso, o jogador deve visualizar quantas mensagens serão enviadas.

## 16. Comandos

| Comando | Comportamento |
| --- | --- |
| `/step` | Mostrar ou ocultar o painel principal. |
| `/step config` | Abrir a janela individual de configurações. |
| `/step options` | Abrir STEP em `Opções > AddOns`. |
| `/step log` | Abrir a janela de histórico. |
| `/step expand` | Expandir o painel. |
| `/step compact` | Compactar o painel. |
| `/step toggle` | Alternar compacto/expandido. |
| `/step show` | Mostrar o painel quando houver perícias visíveis. |
| `/step hide` | Ocultar o painel. |
| `/step lock` | Alternar o bloqueio da janela. |
| `/step reset` | Resetar a posição do painel principal. |
| `/step help` | Listar comandos disponíveis no idioma do cliente. |

Clique direito no cabeçalho do painel principal também deve abrir a janela individual de configurações.

## 17. Localização

- Todos os textos apresentados ao usuário devem usar o idioma do cliente.
- Inglês deve ser o fallback para qualquer tradução ausente.
- Português do Brasil e inglês devem ser tratados como idiomas canônicos durante o desenvolvimento.
- A primeira versão pública deve seguir o padrão dos addons existentes deste workspace e contemplar os idiomas suportados pelo cliente quando as traduções estiverem disponíveis.
- Identificadores persistidos não devem depender do nome traduzido da perícia.
- Textos compartilhados no chat devem usar o idioma do jogador que envia.

## 18. Persistência

As preferências e o histórico devem ser específicos por personagem.

Devem persistir:

- Posição, escala, bloqueio e visibilidade do painel.
- Estado compacto ou expandido.
- Ordenação e comportamento em combate.
- Visibilidade, log e notificação de cada perícia.
- Posição das janelas de configuração e histórico.
- Histórico de ganhos e segmentos de treinamento.
- Estado necessário para pausar e retomar medições com segurança.

Atualizações futuras do addon devem preservar dados válidos e possuir migração quando a estrutura persistida mudar.

## 19. Fluxos principais

### 19.1 Primeiro uso com foco em armas

1. Jogador entra com o addon habilitado.
2. STEP identifica as perícias aprendidas.
3. Armas aparecem no expandido e a arma equipada aparece no compacto.
4. Defesa, Desarmado e profissões permanecem ocultos.
5. Jogador move e trava o painel.

### 19.2 Configuração exclusiva para profissões

1. Jogador abre `/step config`.
2. Aplica o preset `Profissões` ou configura manualmente.
3. Oculta todas as perícias de combate.
4. Seleciona profissões para compacto e expandido.
5. Ativa log e notificações somente para as profissões desejadas.

### 19.3 Ganho de perícia em combate

1. Jogador entra em combate e executa ataques relevantes.
2. STEP acumula tempo ativo da perícia correspondente.
3. A perícia aumenta.
4. STEP registra o evento, atualiza a linha e exibe a notificação configurada.
5. O novo tempo médio aparece no log.

### 19.4 Ganho de profissão

1. Jogador inicia produção, coleta ou pesca.
2. STEP acumula somente o período ativo da ação.
3. A profissão aumenta.
4. STEP atualiza painel, log e notificação.

### 19.5 Compartilhamento

1. Jogador abre `/step log`.
2. Seleciona sessão ou histórico e uma ou mais perícias.
3. Escolhe destino e nível de detalhe.
4. STEP mostra uma prévia da quantidade de mensagens.
5. Jogador confirma o envio.

## 20. Critérios de aceite da primeira versão

### Descoberta e atualização

- [ ] Apenas perícias aprendidas e elegíveis aparecem nas configurações.
- [ ] Novas perícias aprendidas surgem sem reload obrigatório.
- [ ] Ganhos e alterações de máximo atualizam o painel automaticamente.
- [ ] Abandono e reaprendizado de profissão não corrompem o histórico.

### Painel

- [ ] Painel compacto e expandido funcionam e persistem.
- [ ] Cada perícia aceita os três estados de visibilidade.
- [ ] Não existe perícia marcada como obrigatória ou `Sempre`.
- [ ] Categorias vazias não exibem cabeçalho ou separador.
- [ ] Ícone, nome, valor atual e máximo permanecem legíveis.
- [ ] Cores respeitam os limiares definidos.
- [ ] Arma equipada recebe destaque sem esconder a cor de progresso.
- [ ] Ocultar todas as perícias não deixa uma janela vazia.

### Configurações

- [ ] Painel nativo e janela individual mostram os mesmos valores.
- [ ] Alterações feitas em qualquer um atualizam imediatamente o outro e o painel principal.
- [ ] Janela individual fecha com `Esc` e salva posição.
- [ ] Presets e ações em massa não sobrescrevem configurações sem confirmação apropriada.

### Medição

- [ ] Perícia de ataque não acumula tempo apenas por estar em combate.
- [ ] Ataques relevantes iniciam ou mantêm o tempo da perícia correta.
- [ ] Fim do combate interrompe os contadores de combate.
- [ ] Defesa exige tentativas de ataque recebidas.
- [ ] Produção, coleta e pesca só acumulam durante ações reais.
- [ ] Tempo offline nunca é contabilizado.
- [ ] Reload e logout não perdem tempo já acumulado.

### Notificações

- [ ] Os três modos globais funcionam.
- [ ] A participação pode ser desativada por perícia.
- [ ] Atingir o máximo possui tratamento distinto.
- [ ] Ganhos rápidos não produzem efeitos sobrepostos ilegíveis.
- [ ] Ganho de uma linha oculta no compacto permanece perceptível nos modos visuais.

### Histórico e compartilhamento

- [ ] Eventos persistem por personagem.
- [ ] Visões de sessão, histórico e detalhe apresentam dados coerentes.
- [ ] Limpeza completa exige confirmação.
- [ ] Resumo de uma ou várias perícias é legível no chat.
- [ ] Detalhes são limitados a uma perícia por operação.
- [ ] Mensagens respeitam os limites do chat e proteção contra spam.

### Compatibilidade e qualidade

- [ ] STEP aparece em `Opções > AddOns` no cliente-alvo.
- [ ] Todos os comandos documentados funcionam.
- [ ] Textos usam o idioma do cliente com fallback em inglês.
- [ ] Configurações e histórico sobrevivem a reload e novo login.
- [ ] O addon não realiza atualizações contínuas desnecessárias quando nenhuma atividade está ocorrendo.

## 21. Casos de borda obrigatórios para validação

- Duas armas de categorias diferentes equipadas simultaneamente.
- Troca de arma durante o combate.
- Varinha e ataque à distância.
- Armas de punho e possível interação com Desarmado.
- Ganho múltiplo ou atualizações muito próximas.
- Level up aumentando o máximo das armas.
- Treinamento de novo rank de profissão aumentando o máximo.
- Produção em fila interrompida.
- Coleta falha ou interrompida.
- Pesca cancelada ou encerrada sem loot.
- Profissão abandonada e reaprendida.
- Skill oculta com log e notificação ativos.
- Todas as skills ocultas.
- Entrada em combate com auto-compactar ou auto-ocultar.
- Reload durante uma medição ativa.
- Log próximo do limite de retenção.
- Compartilhamento que exige várias mensagens.

## 22. Requisitos de experiência e segurança

- STEP não deve executar ações de jogo pelo jogador.
- Nenhuma notificação deve bloquear cliques ou interferir com frames protegidos.
- A notificação exagerada deve ser visível sem permanecer tempo excessivo na tela.
- A notificação discreta não deve causar poluição visual.
- Compartilhamento só ocorre após ação e confirmação do jogador.
- Limpeza de histórico completo exige confirmação explícita.
- O painel deve permanecer dentro dos limites da tela.
- Posições inválidas após mudança de resolução devem ser recuperáveis com `/step reset`.

## 23. Indicadores de sucesso

STEP será considerado funcionalmente bem-sucedido quando:

1. Um jogador puder configurar um painel apenas de armas, apenas de profissões ou misto.
2. O painel puder permanecer aberto durante o jogo sem ocupar espaço excessivo.
3. O histórico diferenciar claramente tempo ativo de tempo decorrido.
4. Ganhos de perícia forem percebidos no modo escolhido sem spam.
5. Os resumos compartilhados forem úteis e curtos.
6. O addon permanecer estável durante sessões longas e após reloads.

STEP não deve coletar telemetria externa. A avaliação será feita por testes locais, feedback dos usuários e relatos de erro.

## 24. Dependências e referências de produto

- FUR é a referência visual do painel compacto e expandido.
- BAD e AGRO são referências para a janela individual de configurações, integração com as opções nativas e fechamento com `Esc`.
- STEP deve ser independente e não exigir bibliotecas ou outros addons para funcionar.

## 25. Decisões reservadas para a Arquitetura Técnica

Os itens abaixo não alteram o comportamento esperado, mas precisam de investigação e validação antes do desenvolvimento:

1. APIs e eventos exatos disponíveis no cliente `20506` para cada categoria.
2. Identificadores estáveis usados para persistência e localização.
3. Regra e duração do intervalo de atividade entre ataques.
4. Distinção confiável entre mão principal, mão secundária, ataques à distância e varinhas.
5. Tratamento específico de armas de punho e Desarmado.
6. Eventos confiáveis para produção em fila, coleta e Pesca.
7. Estrutura e versionamento das SavedVariables.
8. Limite e política de retenção do histórico.
9. Recursos visuais e sonoros dos modos de notificação.
10. Fila, duração e descarte de notificações rápidas.
11. Divisão e temporização segura das mensagens de chat.
12. Estratégia de testes automatizados e testes dentro do jogo.

## 26. Evoluções futuras candidatas

As seguintes ideias ficam registradas, mas não fazem parte dos critérios de aceite da primeira versão:

- Estimativa até o máximo baseada no histórico recente.
- Meta de sessão por perícia.
- Exportação de texto completa e copiável.
- Histórico comparativo entre personagens.
- Perfis de configuração.
- Pausa e retomada manual do rastreamento.
- Reordenação manual das perícias.
- Seleção de sons individuais.
- Localização de treinadores e perícias ainda não aprendidas.
- Integração opcional com painéis como Titan Panel ou Data Broker.

## 27. Aprovação e controle de mudanças

Este PRD foi aprovado como baseline funcional em 2026-07-11. A aprovação confirma o comportamento esperado, mas não pressupõe que todas as decisões técnicas reservadas já estejam validadas no cliente.

Durante o desenvolvimento e os testes em jogo:

- O layout do painel principal e das configurações pode ser ajustado para melhorar leitura, densidade, contraste, espaçamento e navegação.
- Os modos de notificação devem ser prototipados e testados visualmente antes de seus efeitos, dimensões, duração e sons serem considerados definitivos.
- Ajustes puramente visuais que preservem o comportamento podem ser registrados diretamente na revisão seguinte deste documento.
- Alterações que modifiquem escopo, padrões, fluxos, dados persistidos ou critérios de aceite exigem atualização explícita do PRD.
- A Arquitetura Técnica e a implementação devem sempre seguir a revisão aprovada mais recente.
- Uma mudança só deve ser considerada concluída quando documentação, implementação e critérios de aceite estiverem novamente alinhados.
