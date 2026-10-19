# Entrega de reparaciones de escritorio — 2026-10-19

## Alcance y autorización

El usuario pidió commit, push y merge a `master`. Al informar de fallos previos
en la suite general, autorizó explícitamente integrar y documentarlos, dejando
su reparación para después. No se presenta la suite completa como verde.

Se integra la rama `feat/widget-editor`, incluyendo el editor de widgets y
Caffeine ya presentes en su commit inicial, más las reparaciones de Hyprland,
Sway y la instalación compartida de ArtCraft de esta sesión.

## Cambios y comprobaciones

- Win+B abre Chromium. Los helpers de foco, resize, DPMS y colocación RDP usan
  dispatchers Lua nativos y validan/escapan los identificadores interpolados.
- Se conserva scrolling nativo con ajuste de visibilidad, sin centrado forzado.
  Win+R pone la columna al 100%; navegadores/PWA abren al 100% sin ocultar barra
  y dock. Se mantiene fullscreen real para RDP y las excepciones flotantes.
- Nautilus y utilidades recuperan reglas nativas; Loupe flota tanto en Sway
  como en Hyprland. Transiciones habilitadas fuera de game mode.
- Alt+Tab usa capturas nativas y enfoca la ventana seleccionada después de
  cerrar el overlay. El selector de fondos tiene posters FFmpeg limitados para
  PNG rechazados por Qt y videos, sin modificar los originales.
- Waybar conserva activo azul, ocupado blanco y vacío gris. Se construyó la
  adaptación de IPC Lua: los tres grupos de tests upstream pasan y los clics
  reales 2/3/1 pasan con configuración compartida y personal. También se probó
  un clic en la barra de la sesión anfitriona y se restauraron foco y cursor.
- Se declara el agente Polkit en el target de Hyprland y FFmpeg como dependencia.
- ArtCraft 0.5.1 se declara a nivel de sistema para todos los escritorios con
  Flatpak, incluso con lista personal vacía; bundle oficial y SHA-256 verificados.
- Pasa la revisión independiente de los cambios de producción, sin hallazgos
  importantes ni patrones de credenciales en el diff.
- Pasan `go test ./...` en `orgm-dot-src` y `orgmai-src` con Go 1.26.8 del store.
- Pasan tests de dispatchers, 121 reglas efectivas, parser Lua real, paridad,
  widgets, Caffeine, herramientas Sway, wallpapers, watcher y cableado Nix.
- La sesión Hyprland privada comprueba Win+R real, geometría scrolling, clic
  exacto de Alt+Tab, Nautilus flotante y ancho inicial de navegador/PWA.

La prueba de teclado usa un keymap evdev completo. El keymap compacto de wtype
puede resolver a otra combinación en Hyprland y dar un falso fallo de Win+R.

## Fallos generales y pendientes documentados

El intento amplio de ejecutar 134 scripts shell y 36 scripts `*.test.py` se
interrumpió tras detectar fallos previos y builds ajenos de dependencias Ryoku;
no se completó ni se declara equivalente a una suite verde.

| Prueba | Resultado observado / pendiente |
| --- | --- |
| `common-system-python.bats.sh` | Exige por grep que Python sea adyacente a `uv`; desfasada respecto al archivo actual. |
| `envy-audio-policy.bats.sh` | Referencia `audio-defaults.json` de Ryoku que ya no existe. |
| `envy-modes.bats.sh` | Espera cinco outputs y no contempla el fallback `orgm-ryoku`. |
| `envy-sway.bats.sh` | Mismo inventario desactualizado de cinco outputs. |
| `envy-monitors.bats.sh` | `lua` no disponible en el PATH de la invocación amplia; repetir con intérprete explícito. |
| `dotfile-source.bats.sh` / `dotfiles-copies.py` | Espera perfil Ryoku en Envy, ahora Sway, y un `desktop.json` no generado por ese perfil. |
| `dotfile-disable-transition.bats.sh` | Límite de 120 s durante materialización/builds Ryoku; requiere ejecución separada. |
| `user-program-isolation.bats.sh` | Exclusiones antiguas de Jarq contradicen su selección actual de Syncthing y herramientas ORGM; se reprodujo también con el módulo Flatpak de HEAD, sin ArtCraft. |
| `vlc-flatpak-video-default.bats.sh` | Busca el ID literal en el módulo compartido, pero las listas están en los módulos de usuario; tampoco está en el módulo de HEAD. |
| `windows-rdp-client.bats.sh` | Fallo previo conocido: escenario `ENVY_FAIL=1` de render-node/connect devuelve 0 en vez de no-cero, reproducido antes sin estas reparaciones. |

No se corrigieron esos contratos o problemas ajenos en esta entrega.

## Estado de despliegue

Se aplicaron los dotfiles mediante `orgm-dot pull` y se recargó Hyprland sin
errores de configuración, incluyendo el ancho de Win+R. Se preservaron la barra
de Sway y la paleta generada al aplicar Waybar. Su binario corregido está activo
mediante drop-in runtime y se conserva con una raíz de GC.

No se ejecutó `nixos-rebuild switch` ni se reinició el equipo. Queda pendiente
la activación NixOS normal para desplegar declarativamente ArtCraft compartido,
el paquete Waybar y las dependencias/unidades declaradas en todos los equipos.
La instalación local preexistente de ArtCraft no se eliminó ni se duplicó.

Las reglas X11 basadas en tipo/role y títulos de Firefox que cambian después
del mapeo siguen sin equivalencia completa en las reglas estáticas nativas.

## Próxima sesión

1. Reparar los contratos antiguos de inventario y perfil y las fixtures faltantes.
2. Revisar el fallo de RDP ya conocido.
3. Repetir la suite completa con dependencias y tiempos adecuados, separando
   evaluación, builds y pruebas de hardware.
4. Aplicar las declaraciones NixOS mediante el procedimiento normal de cada equipo.
