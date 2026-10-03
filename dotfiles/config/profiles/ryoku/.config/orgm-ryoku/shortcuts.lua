-- Preserve Osmarg's current bindings, adapting desktop actions to Ryoku.
local M = { personal = {}, relocated = {}, reserved = {}, used = {} }
local real = hl
-- XKB gives these spelling pairs the same keysym. Compare the physical
-- binding too, so Next cannot bypass a personal Page_Down reservation.
local aliases = {
  PRIOR = "PAGE_UP", NEXT = "PAGE_DOWN", QUOTELEFT = "GRAVE",
  KP_PRIOR = "KP_PAGE_UP", KP_NEXT = "KP_PAGE_DOWN",
}

function M.normalize(chord)
  local modifiers, key = {}, nil
  for raw_token in chord:gmatch("[^+]+") do
    local token = raw_token:match("^%s*(.-)%s*$"):upper()
    if token == "SUPER" or token == "CTRL" or token == "ALT" or token == "SHIFT" then
      modifiers[token] = true
    else
      key = aliases[token] or token
    end
  end
  local parts = {}
  for _, modifier in ipairs({ "SUPER", "CTRL", "ALT", "SHIFT" }) do
    if modifiers[modifier] then parts[#parts + 1] = modifier end
  end
  parts[#parts + 1] = key or ""
  return table.concat(parts, " + ")
end

-- Capture only the personal binding declarations. Actions already use native
-- Ryoku commands; they do not borrow or translate another profile's config.
local proxy = setmetatable({
  bind = function(chord, action, options)
    M.personal[#M.personal + 1] = { chord, action, options, original = chord }
  end,
}, { __index = real })

local config = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
local env = setmetatable({ hl = proxy }, { __index = _G })
local personal = assert(loadfile(config .. "/orgm-ryoku/osmarg-keybindings.lua", "t", env))()
personal.setup()
-- Keep these chords available for the user. Relocate Ryoku's scratchpad,
-- music and cheatsheet actions too, rather than assigning them back here.
for _, key in ipairs({ "H", "J", "K" }) do
  M.reserved[M.normalize("SUPER + " .. key)] = true
end
-- Reserve effective personal chords before upstream loads. Preserve the first
-- assignment when a personal chord is duplicated and relocate later ones.
local function free_chord(chord)
  local key = chord:match("([^+]+)$"):match("^%s*(.-)%s*$")
  local candidate = "SUPER + CTRL + ALT + SHIFT + " .. key
  local fallback = {}
  for _, prefix in ipairs({ "SUPER + CTRL + ALT + SHIFT + ", "SUPER + CTRL + ALT + " }) do
    for i = 1, 12 do fallback[#fallback + 1] = prefix .. "F" .. i end
    for i = 0, 9 do fallback[#fallback + 1] = prefix .. tostring(i) end
    for byte = string.byte("A"), string.byte("Z") do
      fallback[#fallback + 1] = prefix .. string.char(byte)
    end
  end
  local index = 0
  while M.reserved[M.normalize(candidate)] or M.used[M.normalize(candidate)] do
    index = index + 1
    assert(index <= #fallback, "Ryoku shortcut namespace exhausted")
    candidate = fallback[index]
  end
  return candidate
end

for _, binding in ipairs(M.personal) do
  local normalized = M.normalize(binding[1])
  if M.reserved[normalized] then
    local relocated = free_chord(binding[1])
    binding[1] = relocated
    normalized = M.normalize(relocated)
  end
  M.reserved[normalized] = true
end


-- Prefer all four modifiers, with a physical-key fallback using three.
-- Retain free Ryoku chords; relocate only collisions, including GUI rebinds.
function M.rebind(original, requested)
  local normalized = M.normalize(requested)
  if not M.reserved[normalized] and not M.used[normalized] then
    M.used[normalized] = true
    return requested
  end
  local candidate = free_chord(requested)
  M.used[M.normalize(candidate)] = true
  M.relocated[#M.relocated + 1] = { original, candidate }
  return candidate
end

function M.install()
  for _, binding in ipairs(M.personal) do
    real.bind(binding[1], binding[2], binding[3])
  end
  local state = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
  local report = io.open(state .. "/orgm-ryoku/shortcuts.tsv", "w")
  if report then
    for _, binding in ipairs(M.personal) do
      report:write("Osmarg\t", binding.original)
      if binding.original ~= binding[1] then report:write(" → ", binding[1]) end
      report:write("\n")
    end
    for _, binding in ipairs(M.relocated) do
      report:write("Ryoku\t", binding[1], " → ", binding[2], "\n")
    end
    report:close()
  end
end

return M
