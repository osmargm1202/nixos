-- Evaluate the real visual config at the compositor API boundary.
local root = assert(arg[1])
for _, game_mode in ipairs({ false, true }) do
  package.loaded["lua.game-mode"] = { enabled = function() return game_mode end }
  local config, animations = nil, {}
  hl = {
    config = function(value) config = value end,
    curve = function() end,
    animation = function(value) animations[value.leaf] = value end,
  }
  dofile(root .. "/dotfiles/config/profiles/hyprland/.config/hypr/lua/look-and-feel.lua")
  assert(config.general.layout == "scrolling", "Hyprland must retain the scrolling layout")
  assert(config.animations.enabled == not game_mode,
    "global animations must be enabled outside game mode and disabled inside it")
  for _, leaf in ipairs({ "windows", "windowsIn", "windowsOut", "fade", "layers" }) do
    assert(animations[leaf].enabled == not game_mode, leaf .. " must follow game mode")
  end
end
print("PASS: native transitions enabled in normal mode, disabled in game mode")
