-- Lenovo's internal panel is broken. Ryoku configures every external output
-- and remembers dock layouts by monitor identity instead of connector name.
hl.monitor({ output = "eDP-1", disabled = true })
