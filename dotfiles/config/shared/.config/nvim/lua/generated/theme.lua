local state_theme = vim.fn.expand("~/.local/state/i3-gh0stzk/nvim-theme.lua")
local load_theme = loadfile(state_theme)

if load_theme then
  return load_theme()
end

-- Works before the first i3 theme apply and in non-i3 sessions.
return {
  base00 = "#1a1b26",
  base01 = "#1a1b26",
  base02 = "#222330",
  base03 = "#9ece6a",
  base04 = "#a9b1d6",
  base05 = "#c0caf5",
  base06 = "#e0af68",
  base07 = "#a9b1d6",
  base08 = "#f7768e",
  base09 = "#bb9af7",
  base0A = "#e0af68",
  base0B = "#7aa2f7",
  base0C = "#7dcfff",
  base0D = "#7aa2f7",
  base0E = "#bb9af7",
  base0F = "#f7768e",
}
