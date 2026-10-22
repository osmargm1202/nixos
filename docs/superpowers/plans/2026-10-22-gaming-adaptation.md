# Adaptación gaming de Ryoku — implementación

**Goal:** foco por juego, renderizado de juegos fullscreen en Modo juego y
preferencias VRR/tearing opcionales apagadas por defecto, sobre Hyprland 0.55.4.
**Approval:** usuario aprobó explícitamente los puntos 1, 2 y 3 de la propuesta.
**Scope:** Hyprland; no copiar flags inexistentes a Sway ni permitir activación
universal. Mantener scroll, Win+R y Alt+Tab. No ejecutar Dota ni tocar cuentas.

- [x] TDD: reglas efectivas, matriz modo/opciones y persistencia/rollback del helper.
- [x] Separar ventanas de juegos (dota2, steam_app_NUM, gamescope, EtG) del cliente
  Steam; foco por solicitud solo para juegos. Nada de un watcher de foco continuo.
- [x] Render unfocused: solo juegos fullscreen y solo mientras Modo juego está on.
- [x] Flags game-vrr y game-tearing en el estado Hypr existente, defaults off.
  VRR fullscreen y tearing efectivos únicamente en Modo juego; immediate solo en
  juegos fullscreen. Desactivar modo restaura los valores normales; conserva preferencias.
- [x] CLI `hypr-game-mode {vrr,tearing} {on,off,toggle}`, `options`, `settings`;
  menú Rofi compartido, rollback si falla reload; cambios de preferencias en modo off
  no deben activar modo ni modificar wallpaper.
- [x] Acceso «Opciones de juegos» en centro de control solo para Hyprland.
- [x] Prueba nativa: eventos X11 _NET_ACTIVE_WINDOW, propiedades/reload/on/off y
  controles con clientes ficticios. Montaje /tmp y namespace de red privados para
  no compartir sockets X11 con el padre; comprobar inodos del padre intactos.
- [x] Regresiones existentes, revisión, pull aplicado por asistente y recarga.
  No activar VRR/tearing ni Modo juego en el escritorio del usuario sin su elección.
- [x] Documentar límites: no se prueba una partida, latencia ni VRR real de hardware.

**Files:** game-mode.lua, window-rules.lua, look-and-feel.lua, helper personal
hypr-game-mode, centro compartido desktop.py y tests dedicados/existentes.
**Implementation:** ejecución inline; no nuevos servicios, plugins ni cambio de compositor.

## Extensión solicitada durante la implementación
- [x] CADCraft, las13apps del catálogo ArtCraft y launcher al100% de columna,
  con identidades exactas Flatpak/binario, sin fullscreen ni forzar diálogos.
- [x] Responder posibilidades de Sway sin desplegar foco global ni un helper
  no aprobado: propuesta IPC filtrada por juegos, VRR/tearing por salida y
  estudio por juego del renderizado oculto, sin copiar flags Hyprland.

**Resultado:** ver docs/superpowers/reports/2026-10-22-gaming-adaptation.md.
