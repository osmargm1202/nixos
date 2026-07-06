-- Tab-group plugin: https://github.com/chpock/hyprdeck
-- Every workspace becomes one tab group (monocle + tab strip). Auto-merges
-- ALL new tiled windows unconditionally -- there is no partial/opt-in mode.
--
-- Set ENABLED to false to fully disable: reverts to stock Hyprland focus/move
-- dispatchers and drops the group config in layout.lua. No rebuild needed --
-- just flip this and reload Hyprland config (hyprctl reload or relogin).
local ENABLED = true

local M = { enabled = ENABLED }

if ENABLED then
  package.path = "/etc/hyprdeck/lua/?.lua;" .. package.path
  M.hyd = require("hyprdeck").setup({ log_level = "info" })
else
  M.hyd = {
    dsp = {
      focus = hl.dsp.focus,
      window = { move = hl.dsp.window.move },
    },
  }
end

return M
