-- Envy reports a phantom DP-1 as connected: 800x600, no EDID, no physical
-- monitor attached. Otherwise workspace2 and the cursor land off-screen.
-- Keep this host-only override after Ryokus generated monitors.lua; do not
-- disable the working eDP panel or other external outputs.
-- If a real monitor later uses DP-1, remove this rule in
-- ~/.config/hypr/monitors_user.lua and test that connector physically.
hl.monitor({ output = "DP-1", disabled = true })
