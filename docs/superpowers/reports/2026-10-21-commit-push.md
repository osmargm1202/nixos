# Cierre y publicación — 2026-10-21

## Goal
Guardar y publicar en master el trabajo aceptado: ScrollOverview de Hyprland,
OSK Quickshell compartido, teclado local de autenticación, tablet manual,
centro de control/menús, integración de terminal y Roboto Condensed.

## Instructions
El usuario confirmó que el switch de OrgM funciona y pidió commit/push.
Se mantiene la instrucción anterior de integrar documentando los fallos previos,
sin presentar la suite general como completamente verde. No se activan sistemas
remotos ni se prueban credenciales o un desbloqueo real.

## Verification
- `NIXPKGS_ALLOW_UNFREE=1 nix flake check --impure --no-build .`: todos los checks pasan.
- Build completo desde la fuente Git `.#orgm`: correcto, salida
  `/nix/store/d8696fsbs33jxyh1g6s80hhzwcaxiw0f-nixos-system-orgm-hyprland`.
- Sistema actual y predeterminado de OrgM: ambos apuntan a esa generación.
- Suite general: 192 scripts ejecutados, inicialmente 175 con exit 0 y 17
  no satisfactorios. Exit 0 puede incluir pruebas opt-in omitidas.
- Corregidas cinco fixtures desactualizadas; sus ejecuciones posteriores pasan:
  `control-caffeine-session.test.py`, `envy-sway.bats.sh`,
  `hypr-glass-shaders.bats.sh`, `sway-firefox-tabs.bats.sh`, `windows-rdp.bats.sh`.
  Se conserva la entrada real de usuario y el helper real: no se omiten los casos.
- Los doce resultados no satisfactorios restantes coinciden exactamente con
  el inventario previo de ScrollOverview. No se declara verde toda la suite:
- `hypr-device-support.bats.sh`
- `i3-bar-caffeine.bats.sh`
- `i3-cursor-size.bats.sh`
- `i3-firefox-tabs.bats.sh`
- `install-installer.bats.sh`
- `nvim-x11-clipboard.bats.sh`
- `orgm-status.bats.sh`
- `qylock-session.test.py`
- `runtime-generated-desktop-config.bats.sh`
- `ryoku-profile.bats.sh`
- `ryoku-provider-compat.bats.sh`
- `ryoku-startup.bats.sh`

## Discoveries
Las fixtures de menús necesitan instalar el nuevo orgm-rofi y su biblioteca,
no solo el llamador. El fixture RDP debe exponer Python en su PATH cerrado.
El centro completo necesita scroll y una posición real del control para la
prueba de Caffeine; esperar a que termine la animación de rueda evita apuntar
a una posición transitoria. Los servicios deshabilitados siguen presentes en
el árbol de opciones Nix, pero no deben contarse como servicios activos.

## Accomplished
Fuente, pruebas y documentación reunidas selectivamente en el índice del
repositorio canónico. No se añaden secretos, bytecode ni estado local. No se
eliminan worktrees. Las cinco reparaciones de fixture cambian solo pruebas.

## Next Steps
Envy/Jarq mantienen los pendientes de despliegue/conectividad indicados en
sus informes. Quedan los doce contratos previos y la mejora menor de detectar
perfiles energéticos soportados; no forman parte de esta publicación.

## Relevant Files
- `nixos/osk/`, `nixos/tablet.nix` — servicios compartidos y tablet manual.
- `dotfiles/config/profiles/wayland/` — dock, menús y centro de control.
- `dotfiles/config/programs/shell/.config/quickshell/orgm-osk/` — teclado.
- `nixos/profiles/sway/qylock-*` — empaquetado seguro.
- `nixos/profiles/hyprland/hyprland-scroll-overview.nix` — plugin fijado.
- `tests/` — regresiones, integración nativa y cinco fixtures reparadas.
- `docs/superpowers/reports/` — alcance y límites de cada despliegue.

## Key Learnings:
1. Las pruebas deben incluir todas las dependencias reales desplegadas y usar
   geometría actual, no las coordenadas de una versión anterior de la interfaz.
2. Un build correcto desde una fuente path no verifica la visibilidad de archivos
   de la fuente Git utilizada por nh; probar también el formato real .#host.
