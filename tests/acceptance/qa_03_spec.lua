-- QA-08 acceptance placeholder for QA-03. Generated from the roadmap card;
-- when work on the card starts, replace the pending() call with real
-- assertions that fail first (TDD). This file is never regenerated.
local pending = dofile("tests/support/pending.lua")
pending("QA-03", "Validar Radar, Proximity e Ship.Info em voo", {
  "capturar uma resposta completa de Radar e Proximity e um pacote `Ship.Info` sem informações privadas. Confirmar posição, altitude, tipos, seleção, mudança de sistema e preservação do terminal. Se o formato divergir, acrescentar uma fixture e corrigir o parser em branch própria.",
})
