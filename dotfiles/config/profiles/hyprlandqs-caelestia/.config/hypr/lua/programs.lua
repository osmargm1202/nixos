local programs = {
  terminal = "kitty",
  fileManager = "sh -lc 'if command -v nautilus >/dev/null 2>&1; then nautilus --new-window; elif command -v xdg-open >/dev/null 2>&1; then xdg-open .; else kitty; fi'",
  app_launcher = "caelestia-shell ipc call drawers toggle launcher",
  menu = "hypr-qs-menu",
  control_center = "hypr-qs-menu",
  smart_run = "hypr-smart-run",
  lock = "hypr-lock",
  power_menu = "hypr-power-menu",
  display_settings = "nwg-displays",
  distrobox = "kitty -e distrobox-enter arch --",
  piPrompt = "hypr-pi-prompt --launcher rofi",
}

return programs
