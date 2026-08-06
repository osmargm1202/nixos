local programs = {
  terminal = "kitty",
  fileManager = "sh -lc 'if command -v nautilus >/dev/null 2>&1; then nautilus --new-window; elif command -v xdg-open >/dev/null 2>&1; then xdg-open .; else kitty; fi'",
  app_launcher = "hypr-app-launcher",
  menu = "hypr-main-menu",
  control_center = "hypr-main-menu",
  smart_run = "hypr-smart-run",
  lock = "hypr-lock",
  power_menu = "hypr-power-menu",
  piPrompt = "hypr-pi-prompt --launcher rofi",
}

return programs
