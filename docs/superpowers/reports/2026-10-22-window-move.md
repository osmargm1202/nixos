# Win+Shift+flechas — Hyprland y Sway

## Goal
Restaurar el movimiento de ventanas con Win+Shift+las cuatro flechas y
verificar ambos compositores, manteniendo scrolling.

## Instructions
Aplicar los pulls y recargas sin esperar a que el usuario los ejecute.
Conservar Ctrl, las flechas de foco, Win+R, Alt+Tab, layout y archivos locales.
Sin switch, commit/push, autenticación ni pruebas sobre ventanas reales del usuario.

## Discoveries
- Los perfiles base/personal de Hyprland, el perfil Sway y las configuraciones
  activas de OrgM/Envy solo tenían movimiento con Win+Ctrl+flechas. Win+Shift
  no estaba asignado; i3 sí tenía esos atajos.
- La API fijada Hyprland 0.55.4 acepta direcciones abreviadas l/r/u/d.
  En scrolling, izquierda/derecha mueven entre columnas; arriba/abajo
  reordenan dentro de una columna. Una columna con una sola ventana no tiene
  otra posición vertical a la cual moverla. No se cambia esta semántica.
- Validar Sway por SSH sin seleccionar backend intenta abrir un VT. El
  primer intento se rechazó y la configuración se restauró antes de recargar.
  La validación correcta usa un runtime privado y backend headless/pixman.

## Accomplished
- Añadidos cuatro atajos Shift en Sway y ambos perfiles Hyprland; en Hyprland
  repiten al mantener la tecla. Ctrl/HJKL y foco sin Shift se conservan.
- RED: la nueva prueba detectó `missing SUPER + SHIFT + up`. GREEN posterior:
  contratos Lua ejecutados de ambas capas y cuatro comandos reales de Sway.
- Pruebas de teclado virtual real contra sockets privados: cuatro direcciones
  con ventanas en mosaico/apiladas y flotantes, tanto Hyprland scrolling como
  Sway. También pasan las cuatro direcciones flotantes con el Ctrl existente.
  No se enviaron teclas sintéticas a la sesión real ni se movieron sus ventanas.
- Pasan `hypr-native-dispatch.test.py`, los ocho casos de
  `hypr-sway-parity.test.py`, `hypr-scroll-overview.test.py` y whitespace check.
- OrgM: `orgm-dot pull hyprland` aplicado con backup
  `20261022T044535.452343127-hyprland-pull`; reload correcto, configerrors vacío,
  cada Win+Shift+flecha activo exactamente una vez y con repeat.
- Envy/Sway: fuente activa conservada en
  `/home/osmarg/Hobby/nixos-osk-switch-20261021-Gvlor6/source`, solo cuatro
  aliases añadidos. `orgm-dot pull sway`, validación headless correcta y reload
  mediante el SWAYSOCK del gestor. `get_config` confirma los cuatro atajos.
  Backup final del helper: `20261022T044643.636877906-sway-pull`.
  Preservados siete paths locales D-only de pantallas/fondos/efectos/workspaces.
  Respaldo adicional: `~/.local/state/orgm-window-move/20261022T004643-headless-validation`.

## Verification commands
```sh
rtk proxy python3 tests/window-move-bindings.test.py
rtk proxy python3 tests/window-move-session.test.py
rtk proxy env ORGM_TEST_COMPOSITOR=hyprland ORGM_TEST_PARENT_DISPLAY=/run/user/1000/wayland-1 python3 tests/window-move-session.test.py
```
La integración de Sway usa un compositor privado headless. Hyprland requiere
explícitamente el socket padre y crea un compositor anidado con IPC privado.
No se declara verde toda la suite del repositorio ni prueba física del teclado.

## Next Steps
Prueba física del usuario. Commit/push solo si se solicita. Los pendientes
anteriores de despliegue completo Envy/Jarq no se alteran con este arreglo.

## Relevant Files
- `dotfiles/config/profiles/hyprland/.config/hypr/lua/keybindings.lua` — base.
- `dotfiles/config/users/osmarg/profiles/hyprland/.config/hypr/lua/keybindings.lua` — capa efectiva personal.
- `dotfiles/config/profiles/sway/.config/sway/config` — aliases Sway.
- `tests/window-move-bindings.test.py` — contratos base/personal/Sway.
- `tests/window-move-session.test.py` — movimiento real por teclado privado.

## Key Learnings:
1. Una captura del binding registrado no basta: comprobar desplazamiento real
   con teclas y ventanas privadas en ambos compositores.
2. En scrolling, arriba/abajo requiere ventanas apiladas en la misma columna;
   no se debe reemplazar el layout para simular un movimiento inexistente.

## Corrección de aislamiento posterior
El fallo de Steam reveló que los sockets X11 globales no quedaban aislados por
el HOME/runtime privados. Se deshabilitó el Xwayland innecesario del fixture
Sway y de las otras pruebas Wayland-only. Se recuperó la conexión del padre sin
reiniciarlo; ver [reparación de Steam](2026-10-22-steam-xwayland.md).
