# Roadmap do LotJ-MudForge-Plugin

O [GitHub Project LOTJ Plugin Mudforge](https://github.com/users/maxjonata/projects/1/views/1) é a fonte de verdade para
planejamento, prioridades, dependências, responsáveis e andamento. Use o
**Monthly roadmap** para a linha do tempo e o **Backlog** para ver os status.
A fila, o trabalho ativo e os bloqueios são mantidos nos cartões.

Antes de começar código, atualize o cartão com responsável, branch ou PR,
escopo, arquivos e critérios de aceitação. Depois da verificação, registre
o commit ou PR, os testes executados e os bloqueios que permanecerem.
Coordene alterações concorrentes pelos cartões e siga
[CONTRIBUTING](../CONTRIBUTING.md) e a [arquitetura](architecture.md).

**Objetivo** — levar ao MudForge o fluxo da UI comunitária do LotJ para
Mudlet, com identidade visual própria, controles explícitos de navegação
e radar 3D isométrico, integrando Map, System e Galaxy ao terminal, aos vitais
e às comunicações.

**Base histórica** — o registro abaixo documenta o estado de `main` em
`beafae8`, em 27 de novembro de 2026. O estado atual está no quadro.

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

## Épicos de paridade com o Mudlet

Em 27 de novembro de 2026 o quadro recebeu os épicos abaixo. Cada cartão tem
paridade, camada, fonte e critério de aceite, e o quadro é a fonte de verdade.
Legenda: **T** temos, **P** parcial, **N** não temos, **U** UX nova.
Cartão sem fonte vira Pesquisa ou Bloqueado. Nunca inventar comando ou API.

| Épico | Cartões | Foco |
| --- | --- | --- |
| FND — Fundação | FND-01..06 | Lua 5.1 no CI e runner de specs, camadas Onion com root único, event bus, `Core.Supports.Set`, classificador de linhas, settings por mundo. Bloqueia os demais. |
| NAV — Pilotagem | NAV-03..11 | Radar real, auto-radar, hyper pronto, troca de aba, chaff, **cockpit de alvo (NAV-08)**, mira inimiga (pesquisa), painel de voo, autoflight. |
| GAL — Galáxia | GAL-01..03 | Mapa a partir de `Galaxy.Systems`, menu `calculate`/`showplanet`, marcadores. |
| ROOM — Sala | ROOM-01..05 | Painel fixo de sala, entidades com clique direito, ground mapper, estados de movimento, numpad. |
| COMMS | COMMS-02..03 | Comlinks por personagem, badges e atalhos de abas. |
| HUD | HUD-01..04 | Vitais consolidados, feed de eventos sem spam, combatstats, oponente. |
| ONB — Novatos | ONB-01..04 | Tutorial, paleta de comandos, Holocron com metadados, links clicáveis. |
| UTIL | UTIL-01..09 | Automações da comunidade, todas **bloqueadas** até a regra anti-bot do LotJ ser verificada. UTIL-07..09 não são automação. |

Os metadados de comandos do LotJ (nome, sintaxe, categoria, contexto e link do
help) vão para `docs/reference/lotj-commands.json`. O texto integral do help
fica só na referência local. GAME-01 foi substituído por estes épicos.

## Referências

- [Manual de autoria e API do MudForge](https://mudforge.org/docs/ai-plugin-guide.md)
  e [documentação do cliente](https://mudforge.org/#/docs).
- [Pacote comunitário LotJ para Mudlet](https://github.com/LotJ/lotj-mudlet-ui)
  e [mapa público do LotJ](https://www.legendsofthejedi.com/galaxy-map).
- [PRs do plugin](https://github.com/maxjonata/LotJ-MudForge-Plugin/pulls) e
  [CI do repositório](https://github.com/maxjonata/LotJ-MudForge-Plugin/actions).
