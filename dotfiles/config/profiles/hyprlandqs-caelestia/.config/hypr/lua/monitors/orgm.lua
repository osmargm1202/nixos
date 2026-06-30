-- Host-specific monitor layout for orgm.
-- DP-3: primary.
-- HDMI-A-1: right-side vertical panel.
-- Both displays use scale 1 for homogeneous pointer and UI sizing.
-- HDMI-A-1 rotated logical size is 1080x1920; y=-240 aligns it with DP-3 vertical center.
hl.monitor({ output = "DP-3",     mode = "2560x1440@164.96", position = "0x0", scale = 1, transform = 0 })
hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@119.98", position = "2560x-240", scale = 1, transform = 1 })

-- Keep DP-3 as Hyprland's default/main workspace target.
-- Without explicit default workspace rules, Hyprland may pick HDMI-A-1 as the active/default monitor on startup.
hl.workspace_rule({ workspace = "1", monitor = "DP-3", default = true, persistent = true })
hl.workspace_rule({ workspace = "3", monitor = "HDMI-A-1", default = true, persistent = true })

-- nwg-dock: raise dock above waybar bottom_bar (42px tall, margin-bottom=0).
-- Without this, the dock hotspot (y=1434) is hidden behind waybar and never triggers.
hl.env("HYPR_NWG_DOCK_MARGIN_BOTTOM", "42")
