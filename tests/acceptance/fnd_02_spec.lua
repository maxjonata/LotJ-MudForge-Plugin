-- QA-08 acceptance placeholder for FND-02. Generated from the roadmap card;
-- when work on the card starts, replace the pending() call with real
-- assertions that fail first (TDD). This file is never regenerated.
local pending = dofile("tests/support/pending.lua")
pending("FND-02", "Separar domain, application, adapters e um root único", {
  "Dirs `src/{domain,application,adapters/{gmcp,text,ui,host}}`",
  "wiring só em `src/lotj.lua`",
  "builder ZIP e teste atualizados",
  "comportamento igual.",
})
