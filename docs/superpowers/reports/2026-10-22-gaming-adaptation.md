# Adaptación gaming y ancho ArtCraft — 2026-10-22

## Alcance y resultado
Implementación aprobada de los puntos1,2,3 sobre Hyprland0.55.4; ampliación
solicitada por el usuario para abrir CADCraft y ArtCraft al100% de columna.
Aplicado en OrgM con `orgm-dot pull hyprland`, `orgm-dot pull wayland-tools`
y `hyprctl reload`; sin errores de configuración. El usuario solicitó después
commit y push a master; las verificaciones focalizadas y nativas se repitieron
correctamente antes de integrar los cambios.

- Foco permitido cuando un juego reconocido solicita activación. Incluye dota2,
  steam_app_NUM, gamescope y EtG.x86_64; cliente Steam excluido. No se activa
  `misc.focus_on_activate` global ni se fuerza foco continuamente.
- `render_unfocused` solo en juegos reconocidos fullscreen mientras Modo juego
  está activado; al salir de modo fullscreen o desactivar modo se retira.
- VRR fullscreen y tearing independientes, opt-in persistente. Efectivos solo
  durante Modo juego; immediate limitado además a juegos fullscreen.
  Desactivar modo conserva preferencias pero retira esas opciones efectivas.
- Acceso: Win+Alt+Space → Energía / «Opciones de juegos» (solo Hyprland).
  CLI: `hypr-game-mode settings`, `options`, `vrr on|off|toggle`,
  `tearing on|off|toggle`. Cambiar preferencias con modo apagado no activa el modo.
- Persistencia: game-vrr y game-tearing junto al estado existente Hyprland.
  Escritura atómica, lock y rollback ante fallo de reload; errores de escritura
  y lock se propagan también desde menú. Flags corruptos quedan desactivados.
- ArtCraft:13IDs oficiales, launcher y alias histórico PrintCraft, prefijo
  ai.storyteller opcional y alias binario, regex anclada e insensible a mayúsculas.
  `scrolling_width=1.0`, solo no-modales, sin fullscreen/maximize/float.
  No se fuerza ancho por título genérico ni sufijo craft indiscriminado.
  Es regla de apertura: no se cerró ni reinició el CADCraft real del usuario.
- Scroll, Win+R y movimientos de ventanas preservados.

## Verificación fresca
- tests/hypr-gaming-policy.test.py:9tests OK, matriz8combinaciones,
  persistencia, rollback, fallos mktemp/mv/flock, directorio y flags multilinea,
  menú compartido y disponibilidad exclusiva Hyprland.
- tests/hypr-window-rules.test.py:124reglas efectivas OK, incluyendo45identidades
  ArtCraft/alias y sus casos modales, negativos de identidad/título.
- tests/hypr-gaming-session.test.py: PASS con
  `ORGM_TEST_PARENT_DISPLAY="$WAYLAND_DISPLAY"`. Compositor anidado, /tmp y
  namespace de red privados; solo dispositivos render, sin input físico ni VT.
  Eventos X11 reales _NET_ACTIVE_WINDOW con clientes ficticios: Dota/Steam-app
  recuperan foco a través de workspaces, cliente Steam no. Ciclo fullscreen,
  modo/opciones y restauración efectivos sobre ventanas existentes verificados.
  Clientes Wayland ficticios con las13app_ids ArtCraft y alias de launcher/CADCraft
  abren al100%, sin fullscreen/flotación; negativo con título CADCraft conserva50%.
  Identidades de todos los sockets/locks X11 originales intactas tras el ensayo.
- tests/hypr-game-mode.bats.sh: transiciones, wallpaper, rollback y lock PASS.
- tests/control-center.test.py:6tests OK; menu-style-parity:3tests OK.
- window-move-bindings PASS; wayland-session-isolation:15configs PASS.
- bash -n helper y git diff --check: OK.
- Revisión independiente: sin bloqueantes pendientes después de reparar los
  fallos reproducidos de errexit condicional, parsing multilinea y lectura nil.
- Instalado: control-state contiene gaming-options disponible, reglas coinciden
  byte a byte con fuente; diff de ambos perfiles vacío después de pull.
- Modo real antes/después: deactivated; preferencias VRR/tearing sin archivos,
  options false/false, allow_tearing false, vrr0 y foco global false.
- Backups: 20261022T093957.400617516-hyprland-pull y
  20261022T093957.420148592-wayland-tools-pull.

## Límites
No se inició/reinició Steam ni ningún juego, no se envió input a juegos reales,
no se probó una partida ni se mide latencia o VRR físico del monitor.
No se afirma que la suite general del repositorio esté verde: se ejecutaron las
regresiones anteriores, no los tests con fallos previos ajenos documentados.
No requiere rebuild NixOS para los dos perfiles aplicados; otros equipos reciben
las reglas al actualizar/aplicar su perfil Hyprland.

## Qué se puede hacer en Sway (propuesta, no desplegada)
`focus_on_window_activation` escribe un ajuste global, no una regla por juego.
No usar `for_window ... focus_on_window_activation focus`: ampliaría permiso
para aplicaciones ajenas. Propuesta: política urgent y helper IPC que reaccione
solo a eventos de urgencia de identidades de juegos permitidas, con pruebas de
negativos, cambios de workspace y reconexión. No sería un bucle que fuerce foco.

Sway actual documenta VRR (`output ... adaptive_sync`) y tearing opcional por
salida y ventana fullscreen. Deben verificarse versión exacta de SwayFX y hardware
antes de desplegar, preservar ajustes de cada salida y restaurarlos al apagar modo.
No hay traducción directa de `render_unfocused`; evaluar pausa en segundo plano
por juego y, si corresponde, Gamescope. No se promete corregir todos los motores.
El compositor Sway no está en PATH local OrgM; no se desplegó nada nuevo en Envy.

## Fuentes primarias
- https://github.com/storytold/craft-launcher/blob/main/crates/core/src/catalog.rs
  — catálogo13apps, bundle_id y alias histórico de PdfCraft.
- https://github.com/swaywm/sway/blob/master/sway/commands/focus_on_window_activation.c
  — ajuste global de activación.
- https://github.com/swaywm/sway/blob/master/sway/sway-output.5.scd
  — VRR/tearing por salida y límites fullscreen/hardware.
- https://github.com/hyprwm/Hyprland/blob/v0.55.4/src/config/lua/bindings/LuaBindingsInternal.hpp
  — API nativa de reglas del compositor instalado.
