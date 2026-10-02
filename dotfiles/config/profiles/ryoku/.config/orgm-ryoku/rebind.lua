local config = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
local name = "orgm-ryoku.shortcuts"
if not package.loaded[name] then
  package.loaded[name] = assert(loadfile(config .. "/orgm-ryoku/shortcuts.lua"))()
end
local shortcuts = package.loaded[name]
local ok, rebinds = pcall(require, "rebinds")
if not ok or type(rebinds) ~= "table" then rebinds = {} end
return function(chord) return shortcuts.rebind(chord, rebinds[chord] or chord) end
