-- Osmarg's utility windows. Use Ryoku's monitor-relative sizing convention so
-- a smaller external display never gets an oversized floating window.
local M = {}

local function fit(width, height)
  return {
    "min(" .. width .. ", monitor_w * 0.92)",
    "min(" .. height .. ", monitor_h * 0.88)",
  }
end

local function is_bitwarden_extension(window)
  if not window or not window.mapped then return false end
  local class = window.class:lower()
  if class ~= "firefox" and class ~= "org.mozilla.firefox" then return false end
  -- Firefox supplies this prefix for extension popouts, after mapping them.
  -- A regular tab titled "Bitwarden" must keep its normal browser placement.
  for _, prefix in ipairs({
    "Extension: (Bitwarden Password Manager) - ",
    "Extensión: (Bitwarden Password Manager) - ",
  }) do
    if window.title:sub(1, #prefix) == prefix then return true end
  end
  return false
end

function M.setup()
  local windows = {
    {
      name = "osmarg-calculator",
      match = { class = "^(org\\.gnome\\.Calculator|[Qq]alculate-gtk|[Qq]alculate-qt)$" },
      width = 420, height = 640,
    },
    {
      name = "osmarg-orgmai-chat",
      match = { class = "^orgmai-chat$" },
      width = 1360, height = 820,
    },
    {
      name = "osmarg-orgmai-config",
      match = { class = "^orgmai-config$" },
      width = 1120, height = 740,
    },
    {
      name = "osmarg-nextcloud-tray",
      match = { class = "^com\\.nextcloud\\.desktopclient\\.nextcloud$", title = "^Nextcloud$" },
      width = 560, height = 680,
    },
    {
      -- The native Wayland tray dialog has an empty app_id on this machine.
      name = "osmarg-syncthing-tray",
      match = { title = "^Syncthing Tray$" },
      width = 760, height = 600,
    },
  }

  for _, window in ipairs(windows) do
    hl.window_rule({
      name = window.name,
      match = window.match,
      float = true,
      size = fit(window.width, window.height),
      center = true,
    })
  end

  -- Static rules cannot float/resize a popout whose title arrives late.
  -- Target the event's window, which is not necessarily the focused window.
  local placed = {}
  local function place_bitwarden(window)
    if not is_bitwarden_extension(window) or placed[window.stable_id] then return end
    local monitor = window.monitor
    if not monitor then return end
    -- Monitor handles expose unscaled pixels; rules use logical dimensions.
    local width, height = monitor.width, monitor.height
    if monitor.transform % 2 == 1 then width, height = height, width end
    width = math.floor(width / monitor.scale + 0.5)
    height = math.floor(height / monitor.scale + 0.5)
    placed[window.stable_id] = true
    hl.dispatch(hl.dsp.window.float({ window = window, action = "set" }))
    hl.dispatch(hl.dsp.window.resize({
      window = window,
      x = math.floor(math.min(480, width * 0.92)),
      y = math.floor(math.min(680, height * 0.88)),
      relative = false,
    }))
    hl.dispatch(hl.dsp.window.center({ window = window }))
  end
  hl.on("window.open", place_bitwarden)
  hl.on("window.title", place_bitwarden)
  hl.on("window.destroy", function(window)
    if window and window.stable_id then placed[window.stable_id] = nil end
  end)
  hl.on("config.reloaded", function()
    for _, window in ipairs(hl.get_windows()) do
      if is_bitwarden_extension(window) then
        -- Preserve a user's subsequent manual size/position on config reload.
        if window.floating then placed[window.stable_id] = true
        else place_bitwarden(window) end
      end
    end
  end)
end

return M
