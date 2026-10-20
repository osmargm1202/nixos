# Dock y ciclo de anchos de Hyprland — 2026-10-20

## Diagnóstico y cambios

- El dock instalado era `nwg-dock-hyprland 0.4.8`. Al hacer clic emitía
  `dispatch focuswindow address:…` y `dispatch bringactivetotop`; el parser
  nativo Lua de Hyprland 0.55.4 rechazaba ambos. La regresión con clic real
  reprodujo exactamente esos errores y no cambió la ventana enfocada.
- Se fija el backport oficial de [PR #116](https://github.com/nwg-piotr/nwg-dock-hyprland/pull/116),
  commit `afcbb25b3702c4ccf1aa3b3583c0f61b71b3c587`, con hash verificado.
  Añade fallback Lua para foco exacto, elevar ventana y workspace especial;
  cubre también el menú de varias ventanas de una aplicación.
  Se conserva la versión/dependencias estables, sin actualizar todo nixpkgs.
- NixOS instala ese mismo paquete y fija `NWG_DOCK_BIN` en el servicio del
  compositor. Sway queda sin cambios.
- `Win+R` estaba fijado a `colresize 1.0`; ahora usa `colresize +conf` en los
  perfiles base y personal. Recorre 33/50/66/100% y vuelve a empezar.
- `fullscreen_on_one_column=true` ocultaba el ancho elegido cuando solo había
  una columna. La prueba nativa reprodujo ese segundo problema; se desactiva
  la expansión automática para respetar el ciclo incluso con una sola ventana.
  Se mantienen scrolling, ajuste sin centrado forzado y reglas explícitas
  de apertura al 100% para navegador/PWA.
- La ayuda de atajos de ambos perfiles refleja el ciclo actual.

## Verificación específica

- Prueba roja: dock original, clic real entre workspaces, parser Lua rechaza
  las llamadas y la dirección activa no cambia.
- `hypr-native-dispatch.test.py`: registros base/personal y helpers pasan.
- `hypr-window-switcher-session.test.py`: teclado real recorre
  100 → 33 → 50 → 66 → 100 → 33% tanto con varias columnas como con una sola.
  También pasan clic exacto de Alt+Tab, Nautilus/VLC flotantes y aperturas
  navegador/PWA al 100%, sin fullscreen.
- `hypr-dock-package.test.py`: paquete instalado = binario del servicio;
  sin filtrar el servicio al perfil Sway.
- `hypr-nwg-dock.bats.sh`: arranque, exclusión mutua, selección de binario,
  conservación de pins y reload seguro pasan.
- En la repetición precommit, el test del launcher volvió a pasar pero emitió
  una advertencia no fatal al desaparecer `/proc/PID/cmdline` durante el
  recorrido de procesos. No se modificó ese helper en esta entrega.
- `hypr-window-rules.test.py`: 122 reglas efectivas pasan.
- `hypr-sway-parity.test.py`: 8 pruebas pasan.
- `hypr-dock-layout.test.py`: pasa reserva efectiva Lua sin doble margen;
  el caso GTK se omite por faltar un intérprete GTK explícito. No se presenta
  como ejecución gráfica satisfactoria.
- Compilación del dock y `checkPhase` de Go pasan. El backport no modifica
  vendorHash. Hay advertencias previas CGO de declaración de `free` en gotk4;
  no son fallos de compilación/prueba.
- Revisión independiente: sin hallazgos accionables, incluyendo la política
  de una sola columna y sus reglas de apertura separadas.

### Límite gráfico detectado durante la validación del dock

La sesión principal quedó bloqueada con qylock desde las 02:14. Se verificó
visualmente el bloqueo; `loginctl LockedHint=no` no reflejaba ese estado.
No se intentó desbloquearla, introducir credenciales ni matar el bloqueo.

Con el binario parcheado el primer clic nativo (y en una ejecución los dos
primeros) enfoca la dirección exacta y recibe `ok` para las llamadas Lua.
La repetición completa 1 → 2 → 1 y el menú multi-ventana quedan pendientes:
el padre bloqueado deja de entregar callbacks `wl_surface.frame`, por lo que
GTK recibe los botones pero no puede asignar/pintar sus widgets reconstruidos.
La traza Wayland confirmó los eventos de botón y el callback de frame sin
respuesta; la pila Go estaba en el loop normal GTK, sin bloqueo del dispatcher.

No se convierte ese resultado parcial en una prueba verde del flujo completo.
`hypr-dock-click-session.test.py` requiere explícitamente un padre desbloqueado
y visible. La tentativa headless auxiliar no se conserva: no obtuvo un modo
válido; SwayFX 0.5.3 como padre tampoco sirve para esta versión de Aquamarine
por incompatibilidad xdg_wm_base 5/6.

Para terminar tras desbloquear, sin builds nuevos:

```sh
rtk proxy env ORGM_TEST_PARENT_DISPLAY=/run/user/1000/wayland-1 \
ORGM_TEST_DOCK=/nix/store/j9kmc5mq8pk9c600chfizbbhvidc90xp-nwg-dock-hyprland-0.4.8/bin/nwg-dock-hyprland \
python3 tests/hypr-dock-click-session.test.py
```

Los diagnósticos opcionales `ORGM_TEST_DOCK_DEBUG=1` y
`ORGM_TEST_ARTIFACTS=/tmp/dock-art` conservan el protocolo/log de la fixture.


## Suite general

Se ejecutaron los 175 scripts superiores `*.bats.sh`, `*.test.py` y `*.test.js`
con dos workers y límite de 120 s por script, sin activar las integraciones
opt-in de Hyprland. Resultado inicial: **155 con exit 0, 20 con exit distinto
de 0**. Exit 0 puede incluir SKIP; esto no declara toda la suite verde.
Logs locales: `/tmp/orgm-dock-suite/`; inventario: `results.txt`.

Fallos observados en esa invocación general, no reparados por este cambio:

| Script | Resultado observado |
| --- | --- |
| `control-caffeine-session.test.py` | No hay `sway` en PATH; llega `None` a Popen. |
| `desktop-widgets-session.test.py` | Falta compositor Sway, emite SKIP con exit 1. |
| `hypr-device-support.bats.sh` | Contrato textual/evaluación de soporte de dispositivos no satisfecho. |
| `i3-bar-caffeine.bats.sh` | El fixture espera `resource_blocks`, inexistente en el wrapper actual. |
| `i3-cursor-size.bats.sh` | Busca settings.ini GTK en la capa i3, ruta ausente. |
| `i3-firefox-tabs.bats.sh` | Exige despliegue de la capa personal. |
| `install-installer.bats.sh` | Inventario del menú no incluye el perfil Sway esperado. |
| `nvim-x11-clipboard.bats.sh` | Contrato de xclip global de orgm-cinnamon no satisfecho. |
| `orgm-status.bats.sh` | Fixture accede a índice 0 en una estructura incompatible. |
| `qylock-session.test.py` | Integración opt-in sin ORGM_TEST_QYLOCK_PACKAGE/PAM. |
| `runtime-generated-desktop-config.bats.sh` | Espera activación `initGeneratedConfigs`, inexistente. |
| `ryoku-folder-icons.bats.sh` | No encuentra esquemas GSettings en el entorno. |
| `ryoku-profile.bats.sh` | Espera `programs.ryoku` en outputs donde no existe. |
| `ryoku-provider-compat.bats.sh` | Espera defaults Ryoku en Envy, actualmente Sway. |
| `ryoku-shortcuts.bats.sh` | `lua` no disponible en PATH (validación niri previa pasó). |
| `ryoku-startup.bats.sh` | Espera máscaras autostart retiradas. |
| `sway-desktop-session.test.py` | Falta compositor Sway en PATH. |
| `sway-game-mode-session.test.py` | Falta compositor Sway en PATH. |
| `sway-menus-session.test.py` | Falta compositor Sway en PATH. |
| `sway-wallpapers-session.test.py` | Falta compositor Sway en PATH. |

### Repetición con dependencias explícitas

Con SwayFX/Lua de la caché y el esquema GSettings explícitos pasan
`desktop-widgets-session.test.py`, `sway-desktop-session.test.py`,
`sway-game-mode-session.test.py`, `sway-menus-session.test.py`,
`sway-wallpapers-session.test.py`, `ryoku-shortcuts.bats.sh` y
`ryoku-folder-icons.bats.sh`. Sus fallos iniciales eran del entorno de prueba,
no fallos demostrados de producción. Logs:
`/tmp/orgm-dock-suite-prerequisites/`.

`control-caffeine-session.test.py` pasa al agregar también `swayidle`
explícito: clic real de Waybar y centro QS comparten el estado persistido y la
inhibición sigue siendo efectiva. Así se resuelven por entorno ocho de los
veinte resultados iniciales; quedan doce sin resolver en esta entrega,
incluida la integración opt-in de qylock no configurada.

`vlc-floating-session.test.py` también pasa con SwayFX explícito.

## Aplicación y alcance

Se aplicaron los dotfiles con `orgm-dot --repo "$PWD" pull hyprland` y se
recargó la sesión sin errores. Se comprobó el valor efectivo
`scrolling:fullscreen_on_one_column=false`.

El dock compilado está activo desde la raíz de GC
`~/.local/state/orgm-hyprland-tools/nwg-dock`, apuntando a
`/nix/store/j9kmc5mq8pk9c600chfizbbhvidc90xp-nwg-dock-hyprland-0.4.8`.
El override runtime es
`/run/user/1000/systemd/user/orgm-hyprland-dock.service.d/90-orgm-dock-lua.conf`.
Se reinició únicamente ese servicio y se comprobaron el ejecutable efectivo,
el estado activo y los hashes de pins/estilo sin cambios. El wrapper temporal
con `-debug` se retiró y el servicio vuelve a usar directamente el paquete
parcheado mediante el launcher normal.

No se ejecuta `nixos-rebuild switch` ni se reinicia el equipo.
Las declaraciones NixOS se desplegarán de forma permanente mediante el
procedimiento normal del equipo.

Roboto se integró aparte en `61389ef`, publicado en `origin/master`, con sus
pruebas de todos los hosts/roles/modos y seis caras tipográficas pasando.

## Pendiente inmediato

1. Usuario desbloquea la sesión (solicitado de forma asíncrona); no necesita
   probar nada todavía. Repetir el flujo gráfico completo del dock.
2. Si pasa, actualizar este informe y comunicar que está listo para probar.
3. Por solicitud posterior del usuario, esta entrega integra dock/ciclo con
   commit y push; Roboto se publicó previamente en `61389ef`. Esto no cambia
   el estado pendiente de la validación gráfica ni declara verde la suite.
4. Activación NixOS permanente mediante el procedimiento normal, no ejecutado.
