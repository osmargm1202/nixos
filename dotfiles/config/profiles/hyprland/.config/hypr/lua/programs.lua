local programs = {
  terminal = "kitty",
  fileManager = "sh -lc 'if command -v hyprfm >/dev/null 2>&1; then exec hyprfm --new-window; elif command -v nautilus >/dev/null 2>&1; then exec nautilus --new-window; elif command -v xdg-open >/dev/null 2>&1; then exec xdg-open .; else exec kitty; fi'",
  app_launcher = "hypr-app-launcher",
  menu = "hypr-main-menu",
  control_center = "hypr-main-menu",
  smart_run = "hypr-smart-run",
  lock = "hypr-lock",
  power_menu = "hypr-power-menu",
  piPrompt = "hypr-pi-prompt --launcher rofi",
}

return programs
