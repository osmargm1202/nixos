-- Recovery layout; NWG Displays owns ~/.config/hypr/monitors.lua after edits.
-- DP-1 is the phantom 800x600 output without EDID on this Envy.
hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x0", scale = 1.25 })
hl.monitor({ output = "DP-1", disabled = true })
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
