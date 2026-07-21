-- Hyprland 0.55 Lua config.
-- Canonical config for this setup; legacy split .conf fallbacks were removed.

require("lua.monitors")
local programs = require("lua.programs")
require("lua.autostart")
require("lua.environment")
require("lua.permissions")
require("lua.look-and-feel")
require("lua.layout")
require("lua.input")
require("lua.keybindings").setup(programs)
require("lua.windows-workspaces")
