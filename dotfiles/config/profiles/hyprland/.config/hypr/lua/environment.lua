local env = {
  NIXOS_OZONE_WL = "1",
  MOZ_ENABLE_WAYLAND = "1",
  XDG_SESSION_TYPE = "wayland",
  XDG_SESSION_DESKTOP = "Hyprland",
  XDG_CURRENT_DESKTOP = "Hyprland",
  QT_QPA_PLATFORM = "wayland",
  QT_QPA_PLATFORMTHEME = "qt6ct",
  QT_QPA_PLATFORMTHEME_QT6 = "qt6ct",
  ELECTRON_OZONE_PLATFORM_HINT = "auto",
  GDK_BACKEND = "wayland,x11",
  SDL_VIDEODRIVER = "wayland",
  CLUTTER_BACKEND = "wayland",
  TERMINAL = "kitty",
}

for key, value in pairs(env) do
  hl.env(key, value)
end
