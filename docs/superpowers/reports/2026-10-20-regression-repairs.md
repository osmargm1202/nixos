# Reparación de regresiones documentadas y VLC flotante — 2026-10-20

Resuelve los diez fallos de pruebas descritos en el
[informe previo](2026-10-19-desktop-premerge.md). No equivale a declarar verde
toda la suite histórica del repositorio ni a haber activado un nuevo sistema.

## Resultados conjuntos

Los diez scripts siguientes pasan juntos, cada uno con el límite original
de 120 segundos. La ejecución termina con `FAILED_TOTAL=0`:

| Prueba | Reparación / contrato comprobado |
| --- | --- |
| `common-system-python.bats.sh` | Evalúa Python y las herramientas de desarrollo en el perfil efectivo del usuario; no exige orden textual ni convierte `uv` personal en paquete global. |
| `envy-audio-policy.bats.sh` | Conserva la prueba del consumidor WirePlumber fijado y ejercita los controles actuales de Sway: salida/micrófono, 150%, pasos, mute, Waybar y daemon; sin depender del seed eliminado de Ryoku. |
| `envy-modes.bats.sh` | Exige cinco hosts canónicos y el fallback explícito `orgm-ryoku`, conservando comprobaciones de modos y aislamiento. |
| `envy-sway.bats.sh` | Mismo inventario exacto de seis outputs y regresiones Sway delegadas. |
| `envy-monitors.bats.sh` | Usa Lua declarado por el lock u override explícito y comprueba la existencia real del seed; mantiene panel interno y excluye únicamente DP-1 fantasma. |
| `dotfile-source.bats.sh` | Envy debe copiar Sway; Lenovo y ORGM fallback deben copiar Ryoku. Evalúa inventario JSON sin realizar referencias store de escritorios enteros. |
| `dotfile-disable-transition.bats.sh` | Ejecuta una transición real remove/bootstrap/restore y comprueba tombstones y aislamiento de contextos; ya no duplica la suite de copias y builds. |
| `user-program-isolation.bats.sh` | Respeta Syncthing/ORGM elegidos por Jarq y su default de avisos Tailscale; prueba explícitamente deshabilitar Syncthing, ORGM, avisos, Nextcloud y tmux, sin tocar exclusiones ni secretos. |
| `vlc-flatpak-video-default.bats.sh` | Evalúa VLC instalado y sus MIME de i3, normalizando el valor escalar/lista del módulo NixOS; evita fuga de defaults a otros perfiles. |
| `windows-rdp-client.bats.sh` | Selecciona el destino antes de simular fallo de backend y exige invocación del controlador, error no-cero y ausencia de RDP/fallback de motor. Comprueba cancelación por separado. |

### Aclaración del supuesto fallo funcional de RDP

El helper de producción ya propagaba correctamente el fallo del controlador.
La prueba anterior, sin display ni entrada, cancelaba en EOF antes de invocarlo;
esa cancelación devuelve éxito intencionalmente. No hizo falta cambiar el
helper. La regresión corregida se verificó además contra una copia temporal
mutada para tragarse el error: la prueba la rechaza específicamente.

## VLC flotante

Se agregan reglas por identidad `vlc` / `org.videolan.VLC`, sin distinguir
mayúsculas, en Sway y Hyprland. También cubren class de XWayland; no se usa el
título de ventana para decidir. Se centra la ventana, pero no se fuerza tamaño
ni fullscreen, conservando los controles manuales del reproductor.

- Sway: 35 tests de herramientas pasan, incluyendo identidades y negativos.
- Hyprland: 122 reglas efectivas comprobadas, incluyendo VLC y navegador
  titulado «VLC» que debe seguir tiled.
- `vlc-floating-session.test.py`: clientes Wayland con identidades VLC flotan
  realmente en SwayFX privado; un navegador con ese título no flota.
- `hypr-window-switcher-session.test.py`: clientes VLC flotan realmente en
  Hyprland privado; siguen pasando Win+R 100%, scrolling sin centrado forzado,
  clic exacto de Alt+Tab, Nautilus y anchos iniciales navegador/PWA.

## Cobertura nativa y controles negativos conservados

La integración pesada no se eliminó: está separada en
`rtk proxy bash tests/integration/dotfiles-native-materialization.sh`.
Pasaron la materialización real dos veces para Lenovo y ORGM Ryoku, la
persistencia de redondeado 19 y snapshot en el contexto `osmarg/orgm/ryoku`, y el
parser nativo de Hyprland. La suite completa de copias/disable/native pasó
7 pruebas; wrappers rápidos sin caché terminaron en 20 y 21 segundos.

También pasaron RDP headless/gráfico, CLI de VMs (11 pruebas), runtimes
Lenovo/Envy (110), dispatchers Lua y regresiones vecinas de Sway/Ryoku. Los
controles negativos rechazan un límite de audio reducido a 100%, panel interno
deshabilitado e intérprete explícito inexistente. La revisión independiente
no encontró problemas importantes.

## Aplicación y límites

Se aplicaron `orgm-dot --profile sway pull sway` y `orgm-dot pull hyprland`.
Hyprland se recargó sin errores; se comprobaron las copias efectivas de ambas
reglas. No había un VLC abierto que requiriera migrar su estado actual.

No se arrancaron VMs ni se ejecutó `nixos-rebuild switch`. El commit y push
posteriormente solicitados incluyen únicamente estas reparaciones. Se
preservaron fuera de ese commit los archivos Roboto ya preparados y el cambio
de importación en `lib/mk-system.nix`, ajenos a esta tarea.

Continúan fuera del alcance las limitaciones de tipos/roles X11 y títulos de
Firefox posteriores al mapeo indicadas en el informe anterior, y la activación
de las declaraciones NixOS pendientes mediante el procedimiento normal.
