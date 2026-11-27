-- QA-08 acceptance placeholder for FND-03. Generated from the roadmap card;
-- when work on the card starts, replace the pending() call with real
-- assertions that fail first (TDD). This file is never regenerated.
local pending = dofile("tests/support/pending.lua")
pending("FND-03", "Trocar globals entre módulos por event bus de aplicação", {
  "Porta `publish(event)`/`subscribe`",
  "nenhum módulo chama global de outro",
  "specs do bus.",
})
