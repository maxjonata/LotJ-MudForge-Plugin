-- QA-08 acceptance placeholder for QA-07. Generated from the roadmap card;
-- when work on the card starts, replace the pending() call with real
-- assertions that fail first (TDD). This file is never regenerated.
local pending = dofile("tests/support/pending.lua")
pending("QA-07", "Rodar testes de feature dentro do MudForge (harness DEV)", {
  "modo DEV que reproduz cenários de feature no cliente real (linhas via feedTriggers, GMCP simulado, send interceptado), relatório PASS/FAIL legível pela máquina",
  "script local copia o build para a pasta de plugins e dispara a execução.",
})
