# LOTJ MudForge Plugin architecture

LOTJ uses Onion Architecture: gameplay rules do not know how MudForge receives
an event, draws a widget, or sends a command. Apply this contract to new work
and extract existing features one at a time. The layer names below describe
responsibilities, not an immediate directory move.

## Boundaries

- **Domain** owns gameplay rules, invariants, and state transitions. Functions
  take and return plain Lua values and tables. Given the same inputs, they
  produce the same result. No MudForge globals, GMCP packets, widget IDs,
  I/O, clocks, or hidden mutable state.
- **Application** owns use cases, such as applying a ship observation or
  handling an explicit radar request. It calls the domain, owns use-case state
  for the relevant session, and defines the input and output ports it needs.
  Output ports are narrow function contracts (for example, `publish(snapshot)`
  or `requestRadar()`). Document what each port takes, returns, and does on
  failure; do not pass a general host API into a use case.
- **Adapters** translate between those ports and MudForge. Input adapters turn
  triggers, GMCP packets, mapper callbacks, and UI actions into use-case inputs.
  UI adapters own HTML/JS/CSS, canvas rendering, widget messages, and prompt
  focus. Infrastructure adapters own sends, timers, persistence, and mapper API
  calls. Decode host values at the boundary and pass owned data inward rather
  than sharing host tables. Adapters do not decide gameplay policy.
- **Composition root** ([`src/lotj.lua`](../src/lotj.lua)) owns plugin metadata,
  module loading and wiring. It creates the feature instances, binds adapter
  functions to ports, and keeps host lifecycle hooks as thin delegates. Define
  hooks at script scope; create widgets and wire callbacks in `init`. Keep
  one registration owner per event path, not a second registration on reconnect.
  On unload, release resources the plugin itself owns (guide §2).

Source dependencies point inward: `adapters → application → domain`.
The root can see every layer. A use case may call an injected function whose
implementation is outside it, but it neither loads that adapter nor knows which
one it received. The domain does not load the application. Keep the graph
acyclic; do not use widget globals as a cross-feature API.

## Lua and module loading

MudForge parses Lua 5.1 syntax and transpiles it to JavaScript; it is not a
stock Lua VM (guide §§0, 17). Use plain tables and closures, not metatables,
coroutines, or 5.2+ syntax. For new modules, return a small exports table and
pass dependencies explicitly at construction (for example,
`Cockpit.new({ shipRules = ShipRules, publish = view.render, requestRadar = mud.requestRadar })`).
Bind the host API only in the root and adapters. New modules must not register
callbacks on load or publish their own globals; do not rely on MudForge making
local functions visible across modules.

Load bundled modules once from the root with `loadModule("src/widgets/lotj-ground-map.lua")`
(or the exact registered path for that module). It resolves a case-sensitive,
slash-separated path relative to the plugin's Files tree, not the main script's
folder or the working directory. Calls execute in order, share plugin globals,
return the module's values, and are not cached. `require()` is the separate
flat-name library loader with a restricted sandbox, not a filesystem resolver
for bundled features (guide §§16, 16.4).

The native preview builder (`scripts/build_preview_zip.py`) discovers unique,
literal `loadModule` calls from `src/widgets`, `src/application`, and
`src/domain`, including calls assigned to locals. Update the builder and ZIP
test if a new module path falls outside those directories. Keep the file list explicit
and check that the archive contains `LOTJ Companion.lua` and every registered
module at `LOTJ Companion/<exact plugin-relative path>`. Do not rely on nested
loads or assume that a successful ZIP build proves the client loaded the plugin
(guide §16.4).

## Migration: pilot first

For each feature, record the current observable behavior in fixtures, extract
one use case behind the existing entry point, and switch the wiring once the
old and new paths give the same result. Keep shims only until callers move; do
not run both paths with live side effects. Preserve public widget IDs/names,
event and message shapes, defaults, and saved-state keys unless a separate change
explicitly changes the contract. Leave known defects or unwired features to
separate fixes; an extraction is not a rewrite.

1. **Pilot cockpit.** Start with one ship/target observation-to-display path.
   Move state transitions inward; keep packet decoding, HUD/radar drawing,
   and host sends outside. Feed fixtures for the approved pilot behavior; do
   not turn telemetry into automatic actions. If the slice includes manual
   radar, test that an explicit request calls the send port once and passive
   updates never call it. Leave other widgets and their handlers in place.
2. **Vitals/status.** Consolidate ownership of the root/widget GMCP handlers
   for `Char.Vitals`, `Ship.Info`, `Char.Enemy`, and `Char.Chat`. Preserve the
   HUD's Force visibility rule, wimpy marker, and empty `Ship.Info` hide
   behavior, and characterize partial packets before changing merge policy.
   `onGMCPUpdate` receives the arriving packet; `getGMCPData` reads accumulated
   state. They are not interchangeable, and duplicate listeners both run
   (guide §11).
3. **Comms hub.** Extract channel routing and unread counts as they are wired;
   keep the tab layout, event names, visibility defaults, and prompt focus in
   the UI adapter. Keep the HTML bridge and its readiness handshake at the edge
   when it needs to send initial state (guide §4). Do not wire inactive stats
   or autopilot as part of the extraction.
4. **Ground mapper.** Keep `type = "map"`, `Room.Info`, and the existing text
   trigger and click entry points at the boundary. Keep JavaScript regex and
   `wildcards[1]` (the first capture) in the trigger adapter (guide §7). Keep
   mapper readiness and writes in its adapter; distinguish numeric room IDs
   from display names and do load-time map work behind `onMapReady` (guide
   §11.5). Move room selection and state rules inward without rewriting the
   mapper or silently changing its click behavior.

## Verification rules

- **Domain:** run deterministic unit tests directly against plain Lua tables;
  cover ordinary, missing, zero, and invalid inputs where applicable. No host
  stubs should be needed to load or test the domain.
- **Application and adapters:** inject recording stubs and replay packet,
  trigger, and UI fixtures. Assert values, call arguments and counts, negative
  paths (especially no unintended sends), and lifecycle behavior such as no
  duplicate listeners on reconnect. Retain the existing
  [widget smoke](../tests/ui_scaffold_smoke.lua) and
  [ground-map trigger fixtures](../tests/ground_map_triggers.lua).
- **CI:** make Lua 5.1-compatible syntax, the focused unit/contract tests, and
  existing GMCP/regex regressions repeatable PR checks; add ZIP layout and
  completeness checks when packaging changes. The draft's Lua 5.4 syntax/smoke
  checks are useful but do not certify Lua 5.1 compatibility or MudForge's
  transpiler, regex engine, or widget bridge. Use a targeted, disconnected
  MudForge smoke check for loader or host-facing changes when the client is
  available; record unverified client behavior otherwise. Routine regression
  testing belongs in deterministic CI, not a routine AI QA pass.

## Runtime reference

*MUD Web Client — AI Plugin & Library Authoring Guide* (supplied MudForge
reference): §§0 and 17 (Lua runtime), §2 (lifecycle), §4 (widgets), §7 (triggers),
§11 (GMCP), §11.5 (mapper), and §§16 and 16.4 (libraries and plugin modules).
