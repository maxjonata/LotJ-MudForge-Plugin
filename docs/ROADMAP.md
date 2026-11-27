# Roadmap do LotJ-MudForge-Plugin

Este arquivo é a fonte de verdade do projeto para planejamento, prioridades,
dependências e andamento. O Git registra a implementação. Os PRs, testes e
testes manuais registram o que foi verificado. Atualize este arquivo antes de
iniciar um novo trabalho e depois de integrar uma entrega ou descobrir um
bloqueio.

**Objetivo** — levar ao MudForge o fluxo de trabalho da UI comunitária do LotJ
para Mudlet, com identidade visual própria, controles explícitos de navegação
e uma visão local de radar em 3D isométrico. Organizar o uso em Map, System e
Galaxy, com terminal, vitais e comunicações acessíveis. O projeto está em
prévia para desenvolvimento.

**Base desta revisão** — `main` em `beafae8`, com o PR de navegação #10
publicado em `ac5f0cd`. Revisado em 27 de novembro de 2026.

## Como colaborar

1. Leia este arquivo, [CONTRIBUTING](../CONTRIBUTING.md) e as
   [fronteiras da arquitetura](architecture.md). Confira o estado atual de
   `origin/main` e dos PRs vinculados.
2. Antes de editar código, registre na linha do item o responsável, branch ou
   PR, recorte, arquivos que pretende tocar e critério de aceitação. Publique
   a atualização para quem vai trabalhar em paralelo. Use o ID do item no PR.
3. Mantenha um worktree e um PR por mudança em paralelo. Coordene antes de
   tocar os mesmos arquivos. Quem assumir um item deve conseguir reproduzir
   os testes a partir do PR e desta página.
4. Ao entregar, registre commit ou PR, resultado da CI e teste manual quando
   aplicável. Marque **Feito** quando integrado e verificado para o recorte.
   Use **Em curso**, **A fazer** ou **Bloqueado** para as outras situações.
   Se precisar, crie um item separado para a validação que ficou pendente.

## Entregue em `main`

| ID | Entrega | Evidência |
| --- | --- | --- |
| BASE-01 | Histórico local recuperado, estrutura Lua, barra de status, Comms Hub, Ground Map e módulos da prévia. Ship HUD e Datapad entraram como esboços. | [PR #1](https://github.com/maxjonata/LotJ-MudForge-Plugin/pull/1), `67bc2ab` |
| BASE-02 | Fluxo de branches e PRs, guia de importação, arquitetura Onion e migração por fatias. | [PR #2](https://github.com/maxjonata/LotJ-MudForge-Plugin/pull/2), [#3](https://github.com/maxjonata/LotJ-MudForge-Plugin/pull/3), [#5](https://github.com/maxjonata/LotJ-MudForge-Plugin/pull/5) |
| QA-01 | ZIP nativo com testes de conteúdo, sintaxe Lua, módulos de UI, regex de combate e validador GMCP. Corrigido o formato de caminho nos testes no Windows. | [PR #4](https://github.com/maxjonata/LotJ-MudForge-Plugin/pull/4), [#7](https://github.com/maxjonata/LotJ-MudForge-Plugin/pull/7) |
| MAP-01 | Rastreamento pelo mapa nativo, IDs numéricos para seleção explícita e preservação do cursor em atualizações de texto/GMCP. | [PR #6](https://github.com/maxjonata/LotJ-MudForge-Plugin/pull/6), `b7f2fa0` |
| MAP-02 | Argumentos numéricos no redimensionamento e descarte de callbacks atrasados de widgets substituídos. | [PR #9](https://github.com/maxjonata/LotJ-MudForge-Plugin/pull/9), `beafae8` |
| NAV-01 | Cockpit piloto, coordenadas quando chega `Ship.Info`, abertura explícita, comandos Radar e Proximity por clique e tratamento de desconexão. | [PR #8](https://github.com/maxjonata/LotJ-MudForge-Plugin/pull/8), `d9987cc` |
| QA-02 | Prévia importada e ativada no MudForge 2.0.6762. HP e movimento receberam dados do LotJ. Os dois botões do piloto chegaram ao servidor, que exigiu cockpit ou torreta para responder com dados. | Teste na versão `beafae8`, sessão descartável **LotJ Plugin Test** |
| DOC-01 | Índice local e offline da documentação com 1.112 documentos, incluindo 1.000 tópicos do LotJ e o manual do MudForge. | `.cache/referencia/index.html` na cópia principal deste host. Outras estações usam os links de referência abaixo. |

## Em execução

| ID | Estado e responsável | Plano e aceite |
| --- | --- | --- |
| NAV-02 | **Em curso** · agente desta conversa · `feat/lotj-navigation` · [PR #10](https://github.com/maxjonata/LotJ-MudForge-Plugin/pull/10) | Prévia 0.2.0 com Map/System/Galaxy, gráfico isométrico X/Y/Z, altitude por hastes, alcance, seleção de contato, Radar, Proximity, Comms, Fit e 15 sistemas públicos. Importação, alcance, Fit, abertura do mapa nativo e exibição do catálogo confirmados no cliente. Fechar a revisão, repetir CI no commit final e integrar. |
| QA-03 | **Bloqueado** · depende de uma sessão de voo | Obter uma saída de Radar e Proximity capturada de um cockpit ou torreta e um `Ship.Info` autorizado e sem dados privados. Reproduzir a saída pela entrada do plugin e confirmar posição, tipos, alturas, seleção e mudança de sistema. Capturar apenas o necessário para o teste. |

### Próximo trabalho registrado — NAV-02

1. Resolver os apontamentos do PR #10 no aplicativo do cockpit, no parser, na
   composição e no widget. Cobrir coordenadas fracionárias, posição antes e
   depois dos contatos, descarte de respostas atrasadas, indicação de leitura
   truncada, aviso de Proximity, mudança de sala, linhas ANSI e desenho dos
   eixos/hastes. Conferir os limites de correlação de comandos e pacotes contra
   a API publicada e o pacote Mudlet antes de presumir campos do servidor.
2. Executar sintaxe, regressões Lua/JS, validação GMCP, regex e integridade do ZIP.
   Repetir no navegador se o contrato da interface mudar. Conferir a
   revisão e a CI do commit final, então integrar e atualizar este roadmap.
3. Assim que houver uma sessão de voo, executar **QA-03**. O teste com dados
   simulados cobre projeção e integração offline. O teste no solo cobre
   instalação, visibilidade e controles do cliente.

Arquivos reservados para NAV-02 até conclusão: `src/lotj.lua`,
`src/application/scrapper-cockpit.lua`, `src/domain/radar-scan.lua`,
`src/widgets/lotj-scrapper-cockpit.lua`, `src/widgets/lotj-ground-map.lua`,
`tests/scrapper_cockpit*` e `README.md`.

## Fila de trabalho

| Prioridade | ID | Estado | Entrega e aceite |
| --- | --- | --- | --- |
| Próximo | COMMS-01 | **A fazer** | Ligar entradas do jogo a Local, CommNet, Clan, Broadcast, OOC e Tell. Caracterizar Imm e Debug. Usar amostras e fixtures por canal, manter terminal intacto, filtrar e rotear sem duplicar, controlar histórico e não lidos e restaurar foco ao escolher a aba. Preparar parser e fixtures em paralelo, coordenar o gancho `onLine` com NAV-02. |
| Próximo | HUD-01 | **A fazer** | Consolidar os handlers de vitais, oponente, nave e comlink. Corrigir indicador de oponente vazio, barra Force quando o valor máximo zera e divisões inválidas. Cobrir pacotes parciais, saída de combate, troca de nave, limite wimpy, vida/movimento/energia/casco/escudo e reconexão. |
| Próximo | MAP-03 | **A fazer** | Validar mapa em movimento, recenter e mudança de área no cliente. Melhorar posição relativa dos painéis e tamanhos em desktop e mobile com controle do jogador. Usar um mapa de teste com mais de uma sala, sem depender de configurações pessoais. |
| Depois | NAV-03 | **A fazer** | Completar paridade do radar com dados reais: atributos de contatos, mudança de sistema, enquadramento, erros e Proximity estruturado se o formato for confirmado. Separar comandos de leitura de ações de voo. |
| Depois | GAL-01 | **A fazer** | Validar `Ship.System` em voo, posição galáctica e mudança de sistema. Planejar atualização do catálogo público, busca e marcadores locais editáveis com armazenamento por mundo. Confirmar seleção e remoção sem enviar comandos ao jogo. |
| Depois | UI-01 | **A fazer** | Consolidar navegação à direita, terminal, vitais e Comms em um layout MudForge. Definir como usar as superfícies nativas, suportar redimensionamento e teclado, testar legibilidade e foco e preservar ajustes salvos. |
| Depois | SHIP-01 | **A fazer** | Completar HUD de nave com velocidade, energia, casco, escudos e estado de pilotagem. Avaliar indicadores comunitários como chaff e tick após confirmar origem, unidade e cadência dos dados. |
| Depois | DATA-01 | **A fazer** | Definir o recorte de Datapad/Holocron. Usar dados realmente disponíveis, separar catálogo e dados do personagem e testar a navegação do painel. |
| Depois | GAME-01 | **A fazer** | Definir e validar os módulos opcionais de estatísticas de combate, força, crafting, facção e ficha. Os controles de autopilot e ações de voo exigem requisitos, limites e aceite próprios antes da implementação. |
| Depois | QA-04 | **A fazer** | Verificar sintaxe Lua 5.1 em CI, world/iframe lifecycle, reconexão, carga de radar/Comms e importação com dados existentes em versões alvo do MudForge. Registrar casos de teclado, desktop e mobile. |
| Publicação | REL-01 | **A fazer** | Definir versão, changelog, compatibilidade, recuperação em caso de falha e pacote oficial. Decidir entre ZIP de release e formatos `plugins.json`/`.mfp` depois de validar a distribuição. |
| Manutenção | DOC-02 | **A fazer** | Vincular este roadmap nos ambientes de trabalho compartilhados. Referenciar a documentação oficial por URL e manter as evidências das validações acessíveis sem duplicar o backlog. |

## Referências

- [Manual de autoria e API do MudForge](https://mudforge.org/docs/ai-plugin-guide.md)
  e [documentação do cliente](https://mudforge.org/#/docs).
- [Pacote comunitário LotJ para Mudlet](https://github.com/LotJ/lotj-mudlet-ui)
  e [mapa público do LotJ](https://www.legendsofthejedi.com/galaxy-map).
- [PRs do plugin](https://github.com/maxjonata/LotJ-MudForge-Plugin/pulls) e
  [CI do repositório](https://github.com/maxjonata/LotJ-MudForge-Plugin/actions).
