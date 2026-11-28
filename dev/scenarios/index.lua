-- Every DEV scenario, in run order. MudForge cannot list plugin files, so new
-- scenarios must be added here (tests/acceptance/qa_07_spec.lua checks it).
return {
  "dev/scenarios/status_bar.lua",
  "dev/scenarios/ship_row.lua",
  "dev/scenarios/radar_scan.lua",
  "dev/scenarios/radar_proximity.lua",
  "dev/scenarios/target_cockpit.lua",
  "dev/scenarios/target_disconnect.lua",
  "dev/scenarios/comms_hub.lua",
  "dev/scenarios/passive_input.lua",
  "dev/scenarios/fed_triggers.lua",
  "dev/scenarios/datapad.lua",
  "dev/scenarios/station_console.lua",
  "dev/scenarios/live_readout.lua",
}
