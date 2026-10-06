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
  -- Chromium popouts have the extension's own app_id; normal tabs retain the
  -- browser app_id, even when their page title happens to be "Bitwarden".
  if class:match("^chrome%-nngceckbapebfimnlniiiahkandclblb%-.+$") then return true end
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

local function exact(value)
  return "^" .. value:gsub("([^%w_%- ])", "\\%1") .. "$"
end

function M.setup()
  local windows = {
    {
      name = "osmarg-calculator",
      classes = { "org.gnome.Calculator", "Qalculate-gtk", "qalculate-gtk", "Qalculate-qt", "qalculate-qt" },
      width = 420, height = 640,
    },
    {
      name = "osmarg-orgmai-chat",
      classes = { "orgmai-chat" },
      width = 1360, height = 820,
    },
    {
      name = "osmarg-orgmai-config",
      classes = { "orgmai-config" },
      width = 1120, height = 740,
    },
    {
      name = "osmarg-nextcloud-tray",
      classes = { "com.nextcloud.desktopclient.nextcloud" }, title = "Nextcloud",
      width = 560, height = 680,
    },
    {
      -- The native Wayland tray dialog has an empty app_id on this machine.
      name = "osmarg-syncthing-tray",
      classes = { "" }, title = "Syncthing Tray",
      width = 760, height = 600,
    },
  }

  for _, window in ipairs(windows) do
    local match = {}
    if window.classes then
      local alternatives = {}
      for _, class in ipairs(window.classes) do
        alternatives[#alternatives + 1] = class:gsub("%.", "\\.")
      end
      match.class = "^(" .. table.concat(alternatives, "|") .. ")$"
    end
    if window.title then match.title = exact(window.title) end
    hl.window_rule({
      name = window.name,
      match = match,
      float = true,
      size = fit(window.width, window.height),
      center = true,
      no_initial_focus = false,
      focus_on_activate = true,
      no_follow_mouse = false,
    })
  end

  local function is_utility_window(window)
    if not window or not window.mapped then return false end
    for _, utility in ipairs(windows) do
      if not utility.title or utility.title == window.title then
        if not utility.classes then return true end
        for _, class in ipairs(utility.classes) do
          if class == window.class then return true end
        end
      end
    end
    return false
  end

  local focused = {}
  local function focus_once(window)
    if focused[window.stable_id] then return end
    focused[window.stable_id] = true
    hl.dispatch(hl.dsp.focus({ window = window }))
    -- follow_mouse=1 would otherwise return focus to the window beneath the
    -- old pointer. Use the final geometry after floating/resizing/centering.
    local at, size = window.at, window.size
    hl.dispatch(hl.dsp.cursor.move({
      x = math.floor(at.x + size.x / 2),
      y = math.floor(at.y + size.y / 2),
    }))
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
  local function on_window(window)
    if is_bitwarden_extension(window) then
      place_bitwarden(window)
      if placed[window.stable_id] then focus_once(window) end
    elseif is_utility_window(window) then
      focus_once(window)
    end
  end
  hl.on("window.open", on_window)
  hl.on("window.title", on_window)
  local function forget(window)
    if window and window.stable_id then
      placed[window.stable_id], focused[window.stable_id] = nil, nil
    end
  end
  hl.on("window.close", forget)
  hl.on("window.destroy", forget)
  hl.on("config.reloaded", function()
    for _, window in ipairs(hl.get_windows()) do
      if is_bitwarden_extension(window) then
        -- Preserve a user's subsequent manual size/position on config reload.
        if window.floating then placed[window.stable_id] = true
        else place_bitwarden(window) end
      end
      -- Reload applies missing placement but must not move the cursor or
      -- steal focus from the user's current window on later title updates.
      if is_bitwarden_extension(window) or is_utility_window(window) then
        focused[window.stable_id] = true
      end
    end
  end)
end

return M
