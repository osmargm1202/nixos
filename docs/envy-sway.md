# Envy con SwayFX

`envy` usa SwayFX como único perfil de escritorio. Sway es la sesión
predeterminada de SDDM, con Forest de Qylock. No se publican salidas alternativas
para Ryoku, Hyprland ni una salida separada `envy-sway`.

Se usan los paquetes publicados de NixOS 26.05: SwayFX, Waybar y `nwg-dock`
para Sway, sin parches del compositor ni plugins de Hyprland. SwayFX activa
blur de dos pasadas, sombras suaves y esquinas de 8 px, sin bordes en las
ventanas en mosaico ni flotantes. La barra usa fondo al 82%; el dock no tiene
fondo, borde ni sombra. Kitty y las ventanas OrgM AI tienen opacidad del 94%.
Los navegadores y el vídeo permanecen opacos para conservar legibilidad.
SwayFX 0.5.3 no proporciona las animaciones de ventanas/escritorios de
Hyprland: blur, sombras y transparencia no implican transiciones animadas.
La mejora de rapidez debe comprobarse durante una sesión real.

Intel controla las pantallas y el render de Sway mediante los enlaces PCI de
`/dev/dri/by-path`, resueltos al iniciar para evitar depender de card0/card1.
NVIDIA conserva PRIME offload en normal y gaming, y se reserva mediante VFIO
en windows-vfio y server. Esos modos se conservan dentro de la única salida `envy`. Se mantiene Linux 6.12 LTS y NVIDIA 580. El preflight de
render del Windows existente sigue requiriendo un kernel compatible; esta
configuración no cambia sus requisitos ni da por probada la VM.

## Reconstruir la configuración única

Desde este checkout:

```sh
nix build path:.#nixosConfigurations.envy.config.system.build.toplevel
sudo nixos-rebuild boot --flake path:.#envy
```

Después reiniciar y entrar en la sesión **Sway** de SDDM. `boot` prepara el
próximo arranque sin sustituir el escritorio que está funcionando. Las
especializaciones gaming, windows-vfio y server pertenecen a ese mismo sistema.
Para recuperar una instalación anterior, seleccionar una generación previa
en el menú de arranque.

## Herramientas y atajos

### Keyring al iniciar sesión

SDDM entrega la contraseña al módulo PAM de GNOME Keyring para desbloquear el
llavero `login`. El wrapper de Sway completa inmediatamente la inicialización
con `gnome-keyring-daemon --start --components=secrets`, usando el bus de la
sesión antes de abrir aplicaciones. Se reutiliza el proceso que desbloqueó PAM.

Sin ese paso, el proceso parcial de PAM puede terminar y una activación posterior
por D-Bus arranca otro proceso que vuelve a pedir la contraseña. Se observó en
Envy: PAM informó del desbloqueo al entrar, pero más tarde faltaba su socket y
D-Bus tuvo que iniciar otro daemon. No fue necesario cambiar ni borrar llaveros.

El desbloqueo automático requiere iniciar sesión con la contraseña que cifra el
llavero. Véase [la explicación de GNOME](https://wiki.gnome.org/Projects/GnomeKeyring/RunningDaemon).
`python3 tests/sway-keyring.test.py` verifica PAM y el traspaso al daemon en un
bus privado, con una contraseña y un llavero temporales.

### Atajos

- Super+Space: Rofi; Super+Alt+Space: menú de red, Bluetooth, audio, pantallas e **Inicio y bloqueo**.
- Super+Return: Kitty; Super+E: Nautilus; Super+W: restaurar Firefox o enfocar
  su ventana y abrir una pestaña vacía, como en Hyprland. Super+Shift+W:
  enfocar Firefox sin crear pestaña. Super+B: abrir Chromium.
- Super+Esc: buscar y activar una pestaña existente mediante el puente de Firefox.
- Super+N: centro de notificaciones; Super+Shift+N: alternar no molestar.
- Super+A: OrgM AI flotante; Pi continúa usando `-ne` y su configuración propia.
- Super+Shift+Space: alternar mosaico/flotante una vez por pulsación, sin
  repetición al mantener Espacio; Super+F: pantalla completa.
- Super+1…0: escritorios; Super+Shift+1…0: enviar ventana; Super+S: scratchpad.
- Print: seleccionar y editar captura; Ctrl+Print: captura completa.
- Super+Print: iniciar/detener MP4; Super+Shift+Print: GIF.
- Super+Ctrl+P: bloquear, **suspender**, salir, reiniciar o apagar.
- Super+L: bloquear (también Super+Alt+L); Super+/: consultar atajos.
- Teclas multimedia: volumen, micrófono, reproducción y brillo con OSD.

En este Envy se confirmó que ↑ del teclado integrado estaba físicamente
pulsada e interfería con los atajos. Se deshabilita únicamente su scan code en
el kernel, conservando el teclado inalámbrico y los demás cursores. No es una
regla `nop` de Sway: así la tecla averiada deja de participar en las combinaciones.
El arreglo en vivo y cómo revertirlo están en
[la guía del teclado del host](../nixos/hosts/envy/README.md#flecha-arriba-del-teclado-integrado-averiada).

`mouse_warping container` hace que el cursor acompañe los cambios de foco por
teclado, incluido Super+Tab, hacia la ventana seleccionada. Evita dejarlo sobre
la ventana anterior y reenfocarla al mover el ratón. Se conserva el foco al
pasar el ratón (`focus_follows_mouse yes`); no se restaura una coordenada previa
por ventana, sino que se mueve hacia su centro cuando corresponde.

Waybar conserva la disposición de Hyprland: diez escritorios persistentes,
scratchpad, brillo, batería, audio y micrófono a la izquierda; fecha en español
y reloj de 12 horas en el centro; título de ventana, MPRIS, red, Bluetooth,
notificaciones, energía y bandeja a la derecha. También incluye teclado, fondo y ayuda de atajos.
La barra mide 30 px, usa texto de 13 px, números de escritorio de 12 px e
iconos de bandeja de 16 px. El contador del scratchpad se oculta cuando está
vacío; Super+Shift+S guarda una ventana y Super+S o el contador la recuperan.
Los módulos de ventanas/escritorios/teclado son nativos de Sway; no se carga
el modo de juego de Hyprland. El selector de perfil visual conserva la selección
guardada (SLC, ORGM u OSMAR), sin restaurar tamaños grandes ni un fondo del dock.
El dock usa el backend Sway, está fijo a la derecha con iconos de 32 px, sin
autoocultación ni zona exclusiva. Usa la capa `top`: permanece sobre las
ventanas normales, pero queda detrás de las ventanas fullscreen. La capa
`overlay` lo mantendría también por encima de fullscreen y no debe usarse
para este dock. Se comprobó en una sesión aislada comparando capturas reales:
`overlay` reproduce el problema; `top` queda cubierto tanto por fullscreen
normal como global, y reaparece al salir sin cambiar la geometría de ventanas.
Waybar conserva todo el ancho de la pantalla.
Sway reserva una franja lateral mediante `$dock_gap` (60 px de margen derecho),
independiente de que el dock esté iniciado. Se aplica también a los escritorios
existentes al recargar; las ventanas en pantalla completa no respetan los gaps.
SwayNotificationCenter, el portapapeles, swayidle, la barra y el dock pertenecen al target
de la sesión y se detienen al salir; se detienen al cerrar la sesión.
La red usa `nmtui`, Bluetooth `bluetui` y audio `pavucontrol`; no se
inician applets de NetworkManager, Bluetooth, Tailscale o Syncthing.
OpenRGB no inicia su detector de notificaciones en este perfil.
No se incorpora Sunshine. Spotify conserva la declaración Flatpak común.

Las curvas, shaders, plugins y agrupaciones específicas de Hyprland no se
cargan. Sway usa divisiones, pestañas y scratchpad nativos. Super+G alterna
pestañas/mosaico. El temporizador Super+Shift+Tab usa IPC de Sway.

## Modo gaming de Waybar

El botón de mando junto a Caffeine alterna el modo gaming nativo de SwayFX.
Desactiva blur, sombras, esquinas redondeadas y dimming, deja las ventanas
opacas, pone los gaps a cero y oculta el dock si estaba abierto. La barra
permanece visible para poder desactivarlo con otro clic.
También se libera la reserva derecha del dock. Un único ajuste de gaps al
recargar respeta el modo activo; al salir vuelve el margen configurado.
El cambio conserva el estado de Caffeine: la recarga aplica la apariencia
sin reiniciar Waybar. Las reglas de opacidad sin ventanas coincidentes se
omiten al restaurar, sin cancelar la salida de gaming.

El fondo queda negro y se detienen los reproductores de video de esta sesión.
El archivo de fondo y la selección del perfil se conservan. Cambiar de fondo
o recargar Sway mientras gaming está activo mantiene el fondo negro; al salir
se restaura el fondo seleccionado, incluido video, y los valores configurados
de opacidad/gaps. El dock solo vuelve a iniciarse si estaba activo al entrar.

El estado se guarda en `~/.local/state/orgm-sway/game-mode.json`. La inclusión
final `~/.config/sway/game-mode.conf` aplica las mismas reglas a ventanas
nuevas. `sway-game-mode on|off|toggle|status|sync` permite controlarlo por CLI.
Este botón no cambia la especialización de arranque gaming.

Pruebas: `python3 tests/sway-game-mode.test.py` y
`python3 tests/sway-game-mode-session.test.py`. La segunda usa un compositor
SwayFX, D-Bus, configuración y clientes privados; compara capturas para validar
opacidad, gaps y la restauración del fondo sin alterar la sesión real.

## Menús de aplicaciones, sesión y perfiles

- Super+Space, el icono de aplicaciones y el dock abren Rofi con el diseño de
  `shadowofdominance/swaydots`: buscador, iconos Colloid y ocho resultados.
  La paleta se lee del perfil activo al abrirlo. Los demás menús Rofi conservan
  su tema. `sway-launcher.rasi` y su `NOTICE.md` viven en `~/.config/rofi-sway`.
- El botón de apagado de Waybar, Super+Ctrl+P y Super+Alt+E abren el menú de
  sesión con cinco botones: bloquear, suspender, cerrar sesión, reiniciar y
  apagar. Cerrar sesión, reiniciar y apagar piden una segunda aceptación en
  el propio menú. Suspender bloquea primero mediante Qylock.
- El botón PERFIL de Waybar abre tres tarjetas con el último fondo guardado
  de SLC, ORGM y OSMAR, incluido un fotograma para videos. El perfil actual
  aparece marcado; un perfil sin un archivo válido muestra «Sin vista previa».
  ←/→ o H/L cambian la selección; Enter o clic aplica; Esc o clic fuera cancela.

`menus.qml`, `PowerMenu.qml` y `ProfilePicker.qml` reutilizan `MenuWindow`,
`Surface` y `Style` del carrusel. Se abren en la pantalla activa, terminan al
cerrarse y usan Rofi como fallback si falla Quickshell. El cambio de perfil
conserva Waybar y el estado de Caffeine. No se ejecutan acciones al cancelar.

Pruebas: `python3 tests/sway-menus.test.py` y
`python3 tests/sway-menus-session.test.py`. La segunda usa Sway, Quickshell y
Rofi reales en una sesión privada, con las acciones de sesión sustituidas por
registros para comprobar confirmación, cancelación y orden de bloqueo/suspensión.

## Centro de control, audio, ventanas y portapapeles

El botón de ajustes de Waybar abre `orgm-sway control`. También lo abren el
clic derecho sobre el launcher y Super+Alt+Space. El panel permite ajustar
brillo y volumen, alternar gaming y No molestar, y acceder a audio, portapapeles,
perfiles, bloqueo y sesión. Los accesos de Wi-Fi y Bluetooth abren los mismos
programas existentes; los botones de red/Bluetooth y las capturas no cambian.
Caffeine conserva su botón de Waybar y su funcionamiento independiente.

El clic sobre altavoz o micrófono abre `orgm-sway audio`. Muestra los dispositivos
de salida y entrada de PipeWire, permite elegir los predeterminados, silenciar
y ajustar cada volumen entre 0 y 150%. Los cambios son inmediatos; cerrar no
modifica los valores por sí solo. Rueda y teclas multimedia conservan sus OSD;
el clic derecho sigue abriendo pavucontrol.

Super+V abre el historial de `cliphist` con búsqueda, texto y miniaturas de
imágenes recientes. ↑/↓ seleccionan, Enter o clic copia y Esc cancela. Supr,
con la búsqueda vacía, borra la entrada seleccionada. La copia conserva los
bytes originales y el tipo PNG; no simula pegar en otra aplicación. El servicio
de historial existente sigue siendo el único que registra las copias.

Alt+Tab abre una cuadrícula de escritorios con ventanas, en orden numérico
ascendente. Dos escritorios muestran dos recuadros grandes; cinco se distribuyen
en tres columnas y dos filas, sin un sexto recuadro vacío. Cada escritorio
contiene sus ventanas con la última imagen capturada de su contenido visible.
Pasar el mouse por un escritorio o una miniatura mueve y resalta la selección
del menú; Enter o soltar Alt confirma la ventana resaltada.
Clic en la cabecera o el fondo del recuadro abre ese escritorio; clic en una
miniatura enfoca esa ventana concreta. Alt+Shift+Tab recorre en sentido
contrario; más pulsaciones recorren las ventanas, ↑/↓ cambian de escritorio,
Espacio abre el escritorio seleccionado, soltar Alt o Enter enfoca la ventana
y Esc cancela. Si se suelta Alt antes de que el panel se abra, Enter o clic
permite completar la selección. Super+Tab conserva `focus prev`.

Sway 1.11 expone captura de salidas, pero no el protocolo de captura individual
de ventanas utilizado por Quickshell. Por eso no se anuncian vistas en directo
de ventanas ocultas: el servicio `orgm-sway-previews` actualiza una captura de
la ventana enfocada como máximo cada tres segundos, y al abrir el selector
se capturan las ventanas visibles. Una ventana todavía no capturada indica
«Vista previa pendiente». No se recorren escritorios para generar imágenes.
Las miniaturas viven en `$XDG_RUNTIME_DIR/orgm-sway-previews-<sesión>` con
directorio 0700 y archivos 0600; se eliminan las de ventanas cerradas y el
runtime desaparece al cerrar la sesión. La captura se pausa durante gaming,
el bloqueo Qylock y los paneles que puedan tapar las ventanas.

Los cuatro paneles son componentes de `menus.qml` y usan `orgm-sway-desktop`,
registrado en sway-tools. Solo el recolector de miniaturas permanece activo.
Pruebas: `python3 tests/sway-desktop.test.py` y
`python3 tests/sway-desktop-session.test.py`. La integración usa un compositor,
PipeWire/WirePlumber sin monitores de hardware, dispositivos sintéticos,
clipboard y HOME privados. El menú de atajos y los demás paneles propuestos
quedan anotados en memoria como pendientes de autorización futura.

## Carrusel de wallpapers con Quickshell

El clic derecho sobre el icono de fondo de Waybar y `orgm-sway wallpaper-pick`
abren un carrusel con tarjetas animadas. Clic izquierdo y Super+Alt+W siguen
eligiendo un fondo aleatorio, sin abrir el selector.

Se adaptaron el selector de fondos, el menú de sesión y sus componentes QML de
[shadowofdominance/swaydots](https://github.com/shadowofdominance/swaydots), revisión
`4e61255e006de0f994ae21cfeab9bac5ccd58acc`. Son archivos locales versionados,
**sin submódulo, dependencia del repositorio original ni instalador externo**.
La procedencia y el permiso del README original están en
`~/.config/quickshell/orgm-wallpapers/NOTICE.md`.

- ←/→, H/L o rueda vertical/horizontal: recorrer; Inicio/Fin: extremos.
  La rueda funciona sobre las tarjetas y el resto del menú; los desplazamientos
  pequeños de touchpad/rueda de alta resolución se acumulan sin saltar una imagen
  por cada evento. El receptor visual no intercepta los clics de las tarjetas.
- Clic en una tarjeta lateral: seleccionarla; clic en la central o Enter: aplicar.
- Esc o clic fuera de las tarjetas: cancelar sin cambiar el fondo.
- Se abre en la pantalla activa, selecciona el fondo guardado y usa la paleta
  actual de Waybar. No cambia el perfil visual.
- Incluye imágenes y videos de `~/Pictures/<perfil>` y el último fondo guardado
  de ese perfil, aunque esté fuera de esa carpeta. Recorre subdirectorios y
  elimina duplicados; no mezcla la biblioteca compartida ni los otros perfiles.
- WebP usa el decodificador de `qt6.qtimageformats`, añadido al wrapper privado
  de Quickshell en `nixos/profiles/sway/quickshell.nix` (sin cambiar Qt globalmente).
- Videos admitidos: MP4, MKV, WebM, MOV, M4V y AVI, según los códecs de FFmpeg/mpv.
  Las tarjetas muestran `▶ VIDEO` y un fotograma PNG generado bajo demanda por
  FFmpeg; no reproducen videos dentro del carrusel. La caché está en
  `$XDG_CACHE_HOME/orgm-sway-wallpapers` y se invalida por ruta, tamaño y mtime.
- Solo se cierra tras aplicar correctamente. Si falla el IPC, muestra el error
  sin reemplazar el estado guardado y permite reintentar o cancelar.

`orgm-sway` entrega un catálogo JSON en un directorio temporal privado; QML
llama al backend local con un vector de argumentos, sin interpolación de shell.
Sway expande por sí mismo los nombres de `output bg`: los nombres con espacios,
comillas, `$()` u otros caracteres especiales pasan mediante aliases simbólicos
privados de nombre seguro. Se guardan las rutas originales, y los aliases
permanecen en el runtime para el arranque asíncrono de swaybg y nuevas pantallas.
No se copian las imágenes originales ni se matan procesos globalmente.

Las imágenes se aplican con swaybg. Los videos usan `mpvpaper ALL`, en bucle, sin
sonido ni configuración personal de mpv, como unidad transitoria de usuario
`orgm-sway-video-<uuid>.service`, ligada a `sway-session.target`. El reproductor
anterior se detiene **antes** de arrancar el nuevo, esperando a que termine su
cgroup. Después se limpian `swaybg` y `mpvpaper` residuales de la misma sesión
(mismo UID, ejecutable y endpoint Wayland), incluidos duplicados sin unidad
registrada. Se envía SIGTERM y se espera la salida; si no termina en 2 s, se usa
SIGKILL y se vuelve a esperar. Los pidfds evitan matar un PID reutilizado.
No se toca ningún reproductor de otra sesión ni se usa `pkill` global.
El mismo orden se aplica al volver a una imagen: primero parar, luego aplicar.
Si existen `nvidia-offload` y `nvidia-smi -L` detecta una GPU operativa (espera
máxima de 2 s), mpvpaper arranca mediante `nvidia-offload`. Si NVIDIA está ausente,
el driver no responde o está asignada a VFIO, usa el backend normal. Si falla el
arranque offload, detiene completamente ese intento antes de reintentar sin
offload. No cambia la GPU de Sway ni fuerza un decodificador de video concreto.
Esto puede aumentar el consumo de batería al mantener la GPU dedicada activa.
Para desactivarlo en una selección:

```sh
ORGM_SWAY_WALLPAPER_OFFLOAD=0 orgm-sway wallpaper-pick
```

`orgm-sway wallpaper` restaura también los videos al iniciar o recargar Sway.
La selección y el perfil conservan la ruta original; `sway/wallpaper-preview`
apunta al fotograma que utiliza el bloqueo. Si falta ese PNG, el bloqueo usa
color sólido y nunca intenta cargar el video como imagen.

Los cambios de fondo se serializan con `sway/wallpaper.lock`, también ante dos
peticiones simultáneas, para no solapar reproductores. La extracción y la
comprobación de dependencias ocurren antes de parar el fondo. Si falla el nuevo
arranque se intenta restaurar el fondo anterior, sin grabar el perfil ni
solapar procesos; la selección guardada se conserva aunque también falle esa
restauración.
Los errores del reproductor se consultan con
`journalctl --user -u 'orgm-sway-video-*'`.

El perfil instala Quickshell 0.3.0 con formatos de imagen, FFmpeg y mpvpaper.
La interfaz solo vive mientras está abierta, con `--no-duplicate`, y sale al
terminar la animación de cierre. Solo hay un reproductor residente cuando se
elige un video; no se importan los menús de energía/red/Bluetooth ni el servicio
de fondos animados de upstream. Rofi queda como fallback si falta Quickshell o falla la
carga de QML. Mientras no se reconstruya NixOS, el helper admite el paquete fijado
en `~/.local/state/orgm-sway-wallpaper-quickshell`, y FFmpeg/mpvpaper en
`~/.local/state/orgm-sway-wallpaper-tools`.

Pruebas sin compositor: `python3 tests/sway-wallpapers.test.py`.
La prueba real optativa usa HOME, D-Bus, compositor y entrada **aislados**:

```sh
ORGM_TEST_QS=/ruta/al/paquete/bin/qs python3 tests/sway-wallpapers-session.test.py
```

Para probar además eventos reales de rueda y clic, construir el dispositivo
virtual exclusivo del compositor de prueba (sin uinput ni eventos al escritorio):

```sh
nix build --impure --expr 'let p=(builtins.getFlake ("path:" + toString ./.)).inputs.nixpkgs.legacyPackages.x86_64-linux; in p.callPackage ./tests/helpers/sway-pointer-keeper.nix {}' --out-link /tmp/sway-test-pointer
ORGM_TEST_QS=/ruta/al/paquete/bin/qs \
  ORGM_TEST_POINTER_KEEPER=/tmp/sway-test-pointer/bin/sway-test-pointer-keeper \
  python3 tests/sway-wallpapers-session.test.py
```

Comprueba dos pantallas (1920×1080 y 1280×720), teclado, rueda vertical/horizontal,
scroll de alta resolución, clic en tarjetas, cancelación, duplicados,
aplicación real, recuperación de errores, nombres especiales y salida del proceso.
Guarda capturas sintéticas y logs en el directorio privado indicado al terminar.

Con `ORGM_TEST_VIDEO_TOOLS=/ruta/al/paquete/bin` habilita además fixtures WebP y
MP4 sintéticos: decodificación real de miniaturas, reproducción en dos pantallas,
bucle, cambios repetidos, limpieza de un reproductor duplicado, peticiones
concurrentes, restauración del video y retorno a imagen. Antes de cada arranque
comprueba que no queda ningún swaybg/mpvpaper anterior vivo. Si utiliza offload,
verifica además que el PID aparezca en la lista real de procesos de NVIDIA.
Se puede probar la ruta normal con `ORGM_SWAY_WALLPAPER_OFFLOAD=0`.
Esta variante crea unidades
transitorias UUID en el gestor de usuario real, conectadas **solo** al compositor
privado, y las detiene en `finally`; no aplica fondos ni envía entrada al
escritorio del usuario.

## Reglas de ventanas migradas

Las reglas nativas están en `~/.config/sway/window-rules.conf`, versionadas en
`dotfiles/config/profiles/sway/.config/sway/window-rules.conf`. Se compararon:

- `hyprland/.config/hypr/lua/windows-workspaces.lua` del perfil común.
- Las reglas base del input Ryoku fijado por el flake
  (`ryoku/hyprland/modules/window_rules.lua`).
- `users/osmarg/profiles/ryoku/.config/orgm-ryoku/window-rules.lua` y
  `window-defaults.json`, más las reglas guardadas actualmente en Ryoku.

Se incluyen criterios `app_id` para Wayland y `class` para XWayland:

| Aplicación / tipo | Comportamiento en Sway |
| --- | --- |
| Nautilus | Flotante, centrado, 78% del área de trabajo por dimensión |
| GNOME Calculator y Qalculate GTK/Qt | Flotante, centrado, tamaño de utilidad |
| Nextcloud | Flotante; solo el panel `Nextcloud` recibe tamaño compacto |
| Syncthing Tray | Flotante por identidad del cliente y título exacto, no por título solo |
| Audio, Bluetooth, red y File Roller | Flotantes, centrados y proporcionales |
| OrgM AI | Chat grande; configuración/historial algo menores |
| Bitwarden | Popouts de extensión flotantes y enfocados; pestañas normales no |
| Swappy/Satty, pantallas, apariencia y cuentas en línea | Flotantes y centrados, sin instalar programas adicionales |
| Spotify, Ghosttype y Ryotunes | Flotantes como en las reglas base de Ryoku |
| SSH de Ryoport, SPICE, QEMU y Looking Glass | Flotantes; RDP de Windows en pantalla completa |
| Diálogos X11, selectores y autenticación | Flotantes y opacos; los transitorios Wayland los gestiona Sway |
| Steam, steam_app, gamescope y Enter the Gungeon | Opacos, sin blur/sombra e inhibición de reposo en fullscreen visible |

Los tamaños porcentuales se adaptan a pantallas menores; no reproducen el
`min(píxeles, porcentaje)` de Hyprland ni anulan los mínimos del propio cliente.
Las reglas no añaden un daemon ni inician aplicaciones. En Envy, Nextcloud por
GOA sigue siendo accesible desde Nautilus: estas reglas no instalan ni arrancan
el cliente de sincronización de Nextcloud, excluido expresamente en ese host.

Sway evalúa las reglas también cuando llega un título tardío. El popout de
Bitwarden se coloca y enfoca una vez; títulos posteriores no deshacen su tamaño
o posición manual. Se comprobó ese caso con otra ventana enfocada. Las pestañas
normales llamadas Bitwarden, Nextcloud o Web Notifications no se convierten en
utilidades. Swaync gestiona las notificaciones Wayland; para las ventanas de
notificación X11 se usa su tipo real, no una palabra en el título del navegador.

No se portan shaders/HyprGlass, animaciones, anchos de columnas del compositor
scrolling, ni páginas del propio shell Ryoku. Las webapps siguen en mosaico por
defecto, sin forzar sus diálogos a mosaico. `hardware-fastfetch` se aproxima como
flotante grande: Sway no tiene el mismo estado maximizado. No se habilita tearing
global ni se oculta el indicador de compartición de Chromium en el scratchpad.

## Inicio y bloqueo: catálogo Qylock

**Qylock/Quickshell sustituye a swaylock-effects.** El paquete `orgm-qylock`
usa la fuente completa de [Darkkal44/qylock](https://github.com/Darkkal44/qylock),
fijada en `nixos/sddm/sddm-qylock.nix`, con **41 variantes**. Los vídeos,
fuentes y demás assets permanecen en el store de Nix, no en los dotfiles. Las
miniaturas del carrusel se generan durante la compilación a partir de los
assets upstream; las variantes Clockwork comparten la preview de esa familia.
No se ejecutan instaladores ni el lanzador upstream con `killall`.

**Super+Alt+Space → Inicio y bloqueo** abre un carrusel independiente:

- ←/→, H/L, rueda, Home/End para recorrerlo; Enter o tarjeta central aplica.
- Escape/clic exterior cancela sin cambiar nada.
- Aplicar solicita autorización Polkit para modificar el **próximo greeter
  SDDM**, no para autenticar el lock. Mientras se autoriza, el carrusel se oculta
  y libera el teclado para no tapar el diálogo de contraseña del agente.
- Si se cancela o falla la operación privilegiada, el tema anterior permanece
  y vuelve el carrusel con el error. Si funciona, el mismo enlace atómico
  root-owned selecciona tanto el siguiente SDDM como los próximos bloqueos.
- **No reinicia SDDM ni cierra la sesión actual.** No descarga nada al abrirse.
  La primera incorporación necesita que SDDM arranque una vez con el nuevo
  drop-in (normalmente, en el próximo arranque del equipo tras reconstruir): el
  daemon que ya estaba iniciado puede conservar `Current=GreenShift` en memoria.
  Después usa siempre el alias `current`, y cambiar el enlace sirve para el
  siguiente greeter sin volver a reiniciar el servicio.

SDDM y el lock **no son el mismo proceso**: SDDM muestra el tema QML al iniciar
sesión; el adaptador Quickshell usa el mismo tema dentro de
**`WlSessionLock` / `ext-session-lock-v1`** para proteger la sesión existente.
No es una ventana fullscreen y Escape no desbloquea. Tampoco captura las
ventanas privadas: el fondo, imágenes y animaciones pertenecen al tema Qylock,
independientemente del wallpaper estático/vídeo del escritorio.

**Super+L**, **Super+Alt+L**, el menú de energía, los 10 minutos de inactividad
y `before-sleep` usan `orgm-qylock lock`. Super+→ conserva enfocar a la derecha
y Super+Ctrl+L mueve la ventana. Las pantallas siguen apagándose a los 15 min.
`orgm-sway-lock` queda únicamente como alias de compatibilidad para el
swayidle que ya estaba en ejecución; no llama a swaylock. No hace falta
reiniciar swayidle, Waybar ni reproducir de nuevo el wallpaper para migrarlo.
El helper devuelve éxito **solo después de confirmar `secure` al compositor**,
no al crear el proceso. Si otro bloqueo está terminando una autenticación,
espera y vuelve a bloquear antes de dar por preparado `before-sleep`.

La contraseña se verifica por PAM (`pam_unix` y su helper del sistema), con
políticas privadas inmutables `orgm-qylock-pw`/`orgm-qylock-fp` dentro del paquete;
no se modifica el PAM global ni se concede una vía IPC de desbloqueo. La huella
requiere el opt-in **`orgm.sway.fingerprint.enable`** (false por defecto). Envy
puede activarlo con su backend validado, usando `services.fprintd.package` y sin
habilitar huella en sudo/SDDM. `~/.config/orgm-qylock/fingerprint` con `off` gana
al valor de Nix. No se ejecuta `fprintd-list` ni se sondea el sensor al preparar
el bloqueo: el PAM de huella empieza en paralelo solo dentro del lock seguro.
Todos los tests privados fuerzan huella off; la validación física y activación
del backend se documentan por separado en [envy-fingerprint.md](envy-fingerprint.md).

**F2 abre una interfaz de contraseña de respaldo**, con el mismo PAM, si un
skin no carga o presenta problemas. No hay periodo de gracia. Los QML del
bloqueo real se cargan del paquete inmutable, con autorecarga desactivada:
actualizar dotfiles no debe destruir un session-lock que ya esté activo.
Se incluye un parche acotado de Quickshell para destruir a tiempo las ventanas
de salidas retiradas antes de que Qt 6.11 las mueva a una salida de otro tamaño;
sin él, esa transición viola el protocolo y deja el compositor bloqueado sin UI.

Archivos principales:

- `~/.local/bin/orgm-qylock`: catálogo, selección privilegiada y supervisor.
- `~/.config/quickshell/orgm-locks/`: carrusel editable y paleta del perfil.
- `~/.config/quickshell/orgm-lock/`: copia de las fuentes del adaptador; para
  cambiar el bloqueo real hay que recompilar `qylock-runtime.nix`.
- `/var/lib/orgm-qylock/sddm/current`: selección compartida root-owned.
- `/etc/sddm.conf.d/90-orgm-qylock.conf`: drop-in declarativo de NixOS; antes
  del primer rebuild puede crearlo el helper tras autorizar. Solo sustituye
  archivos con su propia marca, nunca configuraciones administrativas ajenas.
- `~/.config/qylock/theme`: preferencia legacy, leída solo si todavía no existe
  selección compartida. No se sobrescribe la configuración de Ryoku.

Durante la migración el runtime está protegido por el GC root
`~/.local/state/orgm-qylock-package`; tras reconstruir se prefiere el paquete
del sistema. La configuración anterior de swaylock permanece respaldada en
`~/.local/state/qylock-migration-backup.*`; sus paquetes de generaciones
anteriores no desaparecen hasta reconstruir y eventualmente hacer GC.

```sh
orgm-qylock themes             # carrusel, sin bloquear
orgm-qylock catalog            # JSON, sin interfaz ni autenticación
orgm-qylock lock               # bloqueo real: ejecutar solo cuando quieras
```

Validación aislada: cargaron las 41 variantes; Winter, Forest y Clockwork también
cargaron en el greeter real de SDDM **en test-mode**, sin autenticación. Se
verificaron carrusel, cancelación, liberación/restauración del teclado durante
un agente simulado y bloqueo Wayland en dos monitores 1920×1080/1280×720:
desconexión, todas las salidas desactivadas/restauradas, cambio de resolución y
escala fraccional. Se rechazaron Escape y token incorrecto; el token correcto
funcionó con **PAM simulado**, tanto en F2 como en el formulario normal Winter.
El supervisor confirmó `secure`, incluidos duplicados. HOME/runtime/D-Bus/Wayland
privados y bus de sistema inaccesible en la prueba. **Estas pruebas no usaron
la contraseña real, no accedieron al lector ni bloquearon el escritorio activo.**
La prueba física del lector es independiente, documentada en la guía de huella.
La autenticación real del nuevo locker y suspensión física quedan para
la comprobación interactiva del usuario; cargar todos los skins no equivale a
haber probado todos sus controles (hay warnings visuales upstream en algunos).

Prueba nativa optativa, con el módulo PAM exclusivo de pruebas:

```sh
ORGM_TEST_QYLOCK_PACKAGE=/nix/store/…-orgm-qylock-1.0 \\
ORGM_TEST_QYLOCK_PAM=/nix/store/…-qylock-private-test-pam/lib/qylock-test-pam.so \\
python3 tests/qylock-session.test.py
```

## Centro de notificaciones: SwayNotificationCenter

**Swaync 0.12.6 sustituye a Dunst únicamente en el perfil Sway.** El servicio
sigue siendo `orgm-sway-notifications.service`, ligado a `sway-session.target`.
Su tipo D-Bus y el alias `swaync.service` hacen que tanto el inicio de sesión
como la activación D-Bus usen un único daemon. Dunst ya no se instala desde
este perfil; Hyprland/i3 conservan su integración anterior.

- Super+N o clic izquierdo en la campana de Waybar abre/cierra el panel.
- Super+Shift+N o clic derecho en la campana alterna **No molestar**.
- El panel muestra historial agrupado, botones para limpiar y el interruptor DND.
- Las notificaciones normales permanecen en el historial tras caducar el popup,
  también con DND. No se promete conservarlas después de reiniciar el daemon.
- Volumen, micrófono y brillo mantienen sus helpers `notify-send`, sustitución
  síncrona y barras de progreso; las reglas `osd-*` los hacen transitorios para
  no llenar el historial. DND también puede silenciar estos avisos.
- El panel y los popups dejan libre la franja derecha del dock. La campana usa
  suscripción nativa a eventos, sin sondeo periódico.

Archivos editables: `~/.config/swaync/{config.json,style.css,orgm-current.css}`;
manifiesto `dotfiles/apps/swaync.json`. El perfil visual genera la paleta Swaync
junto con la de Waybar y recarga **solo CSS**, sin reiniciar el servidor ni
borrar el historial o alterar DND. Nunca invoca `dunstctl` desde el backend Sway.

La sustitución en vivo usa el paquete construido y un override temporal del
servicio bajo `/run/user/1000/systemd/user`, con Dunst enmascarado solo durante
esta sesión para evitar su reactivación. Se respalda su historial anterior,
pero no se reenvía como notificaciones nuevas. Para persistir el ejecutable,
el alias de activación y el paquete hay que reconstruir NixOS con
`sudo nixos-rebuild boot --flake path:.#envy` y arrancar esa generación;
la configuración editable y los atajos ya están aplicados sin cerrar sesión.
El puente temporal `~/.local/bin/swaync-client` prefiere siempre el binario de
`/run/current-system/sw/bin`; mientras falta, usa el paquete protegido por el
GC root `~/.local/state/orgm-swaync-package`. Ambos pueden retirarse después
de arrancar la generación reconstruida.

Se probó Swaync real en SwayFX headless con D-Bus privado: historial, OSD
transitorios, DND, datos JSON para Waybar, recarga CSS sin perder estado y
apertura/cierre del panel. Esta prueba no reemplaza la revisión interactiva
del aspecto y las acciones de notificaciones de aplicaciones concretas.

## Capturas y el editor de Ryoku

El flujo actual sigue siendo `slurp → grim → Swappy`. Print y Alt+Print
seleccionan una región; Ctrl+Print captura todas las salidas. No son todavía
atajos distintos para ventana y monitor activo. La configuración de Swappy
oculta inicialmente su panel y no guarda automáticamente; el editor sí está
instalado y se abre después de capturar. Se añadieron pruebas del envío correcto
del PNG y la geometría al editor, además de la cancelación existente.

El editor de Ryoku es **Ryoshot**. La revisión de su código confirma que usa
Quickshell/layer-shell, `ScreencopyView` y un fallback `grim -o`, compatibles en
principio con Sway. No se ha ejecutado ni empaquetado como aplicación independiente
en este perfil. Copiar solo `quickshell/ryoshot` no basta:

- Hay que empaquetar Quickshell/Qt coherentes y `Ryoku.Ui.Singletons`.
- El portapapeles llama a `ryoku-shell clip-copy`: necesita adaptación a `wl-copy`.
- La geometría de ventanas depende del proveedor Hyprland/Niri de Ryoku;
  para ajuste a ventanas hace falta un backend IPC Sway.
- Fijar imágenes, sonidos, OCR y editar atajos tienen integraciones adicionales.
- La subida opcional de imágenes usa servicios externos; no se debe automatizar.

Un port acotado puede empezar con región/monitor y edición, sin cargar todo el
shell Ryoku. Alternativas rápidas: mantener Swappy, probar Satty para anotaciones,
o integrar **Gradia**, que ya está instalado como Flatpak
`be.alexandervanhee.gradia`. Ninguna alternativa se ha impuesto como reemplazo.

## Paridad pendiente y complementos de comodidad

La revisión también distingue funciones que aún no son equivalentes:

- Alt+Tab usa tarjetas Quickshell con miniaturas del último contenido visible;
  Sway no permite aquí una vista en directo de cada ventana oculta.
- Super+Tab usa `focus prev` del layout; no es el historial global de última
  ventana de Ryoku. El cursor ya acompaña los cambios efectivos de foco.
- Super+Shift+F usa fullscreen global de Sway, no el maximizado de Hyprland.
- El autoinicio personal guardado en Ryoku incluye KDE Connect, Firefox,
  Discord minimizado y Steam silencioso. El perfil Sway aún no consume
  `orgm.user.autostart`; no se lanzan procesos duplicados para simular esa paridad.
- Los shaders, la panorámica animada y el scrolling de Ryoku requieren otro
  enfoque; no son opciones desactivadas de este SwayFX.

El historial y DND ya están integrados con Swaync (sección anterior).
El resto son propuestas, **no instalaciones ni cambios de atajos efectuados**:

| Prioridad | Complemento | Enfoque compatible |
| --- | --- | --- |
| Alta | Capturas de ventana/monitor, retardo y editor visible | Ampliar grim/slurp y elegir Swappy, Satty, Gradia o port Ryoshot |
| Alta | OCR regional al portapapeles | grim/slurp + Tesseract + wl-copy |
| Alta | Grabación con indicador y parada segura | Módulo Waybar y seguimiento del PID propio, no pkill global |
| Alta | Volver a la última ventana real | Historial de foco por IPC, separado del overview futuro |
| Media | Selector de color HEX/RGB | Captura puntual Wayland, copia y notificación |
| Media | Luz nocturna | wlsunset o gammastep con interruptor |
| Media | Perfiles al conectar pantallas/dock | kanshi, complementando nwg-displays |
| Media | Batería y energía | Alertas reales y menú powerprofilesctl, además del porcentaje de Waybar |
| Media | Imágenes fijadas y códigos QR | Visor flotante; zbar/qrencode para leer/generar QR |

Para conservar un escritorio rápido conviene elegir primero las funciones
faltantes y reutilizar los servicios presentes. EasyEffects y la integración
con el teléfono mediante KDE Connect son opciones adicionales, no requisitos
para trasladar las reglas de ventanas.

## Perfil visual y GTK

`~/.config/sway/appearance.ini` define el fallback oscuro mediante dconf.
Después se aplica el perfil guardado por `orgm-visual-profile`, que ahora tiene
backend Sway y restaura su paleta de Waybar/Swaync/Kitty, preferencia GTK y fondo
estático o video. El selector de la barra muestra tarjetas de SLC, ORGM y OSMAR
con una vista previa del último fondo guardado de cada uno; clic derecho
alterna GTK claro/oscuro por perfil. No se ejecutan los backends Hyprland o i3.
El fondo sin imagen de un perfil nuevo conserva el fondo estático actual.
El icono de fondo de Waybar y Super+Alt+W eligen un fondo aleatorio del perfil,
sin menú; clic derecho sobre el icono abre el carrusel Quickshell descrito arriba.
El carrusel solo lista los fondos asociados al perfil activo. Para la selección
aleatoria, si la carpeta del perfil está vacía, se usan las carpetas compartidas `~/Pictures/Wallpapers`,
`~/Pictures/wallpapers`, `~/Wallpapers` o `~/.local/share/wallpapers`.
Se evita repetir la imagen actual cuando hay alternativas.
Los cambios de perfil no alteran el tamaño compacto de la barra ni la
transparencia total del dock. No se añade ningún daemon.

Se instala **Colloid-Dark** para los iconos GTK, incluidos los MIME de PDF,
Word y otros documentos. `appearance.ini`, settings.ini de GTK 3/4 y dconf
mantienen la selección también en Nautilus/GTK4; aplicar un perfil visual no
la restablece a Adwaita. El paquete `colloid-icon-theme` queda declarado en Nix.

### Miniaturas de Nautilus y Nextcloud

`~/.config/sway/appearance.ini` incluye `[Files]` con
`show-image-thumbnails=always`. `orgm-sway appearance` aplica esa preferencia
mediante dconf al iniciar/recargar. Nautilus usa `local-only` por defecto, lo que
impide las miniaturas en las carpetas Nextcloud/WebDAV abiertas por GOA, aunque
los generadores estén disponibles. Las opciones editables son `always`,
`local-only` y `never`; los archivos antiguos sin esa sección reciben `always`.

Mostrar miniaturas remotas puede descargar archivos para generarlas. No se
modifican el límite existente de imágenes (50 MB en la sesión revisada), los
formatos deshabilitados ni la caché. Se verificó la generación real de una
miniatura PNG con Nautilus en una sesión aislada; su wrapper ya aporta el
generador de imágenes GdkPixbuf, por lo que no se añadió otro paquete para eso.
Si una vista abierta no se actualiza, recargarla con Ctrl+R.

## PATH de sesión y recarga

SDDM no ejecuta el shell interactivo. El wrapper de Sway añade
`~/.local/bin` a `PATH` antes de iniciar el compositor. Además, los atajos
usan `$exec`, que prepara ese mismo PATH para cada proceso: funciona también
al recargar una sesión que ya había arrancado sin la ruta de los helpers.
Esto cubre Rofi (Super+Space), Firefox (Super+W), los menús y los OSD.
Super+E sigue abriendo Nautilus; no se intercambian navegador y archivos.

Para aplicar los archivos editables sin cerrar la sesión:

```sh
orgm-dot pull sway
orgm-dot pull waybar
orgm-dot pull nwg-dock
orgm-dot pull swaync
swaync-client --reload-config --skip-wait
swaync-client --reload-css --skip-wait
swaymsg reload
systemctl --user restart orgm-sway-waybar orgm-sway-dock
```

`pull` reemplaza las rutas de cada aplicación con respaldo previo: revisar
`orgm-dot diff APP --patch` si hay modificaciones locales. El cambio del
wrapper Nix y el ejecutable/posición del dock requieren reconstruir el sistema
para futuros inicios, pero los atajos corregidos y los efectos se aplican con
la recarga anterior. Un override temporal de systemd bajo `/run/user` solo
cubre la sesión de prueba; desaparece al reiniciar. Si los archivos nuevos
no están añadidos a Git, usar `path:.#envy` en los comandos de rebuild
para incluirlos sin modificar el índice de Git.

### Selector de pestañas Firefox: Super+Esc

El atajo ejecuta `sway-firefox-tabs`, que consulta el puente
`windows-manager-linux-orgm-tabs`, abre Rofi y enfoca la pestaña elegida sin
crear una pestaña nueva. Al enfocar usa el título de la pestaña seleccionada,
no la primera ventana Firefox del árbol. Con títulos duplicados utiliza foco o
urgencia cuando permiten identificar una ventana; si sigue siendo ambiguo no
salta a una coincidencia arbitraria. La extensión firmada es persistente: el
atajo no debe instalarla ni volver a iniciarla. Cancelar Rofi con Esc no es un error.

Si el puente devuelve `Connection refused`, puede haber un socket abandonado
en `$XDG_RUNTIME_DIR/windows_manager_linux_orgm.sock`, aunque la extensión esté
activa. En la sesión revisada se retiró únicamente ese socket, tras comprobar
que pertenecía al usuario, era realmente un socket y rechazaba conexiones.
La extensión reconectó automáticamente sin cerrar Firefox.

El host corregido en el repositorio recupera sockets abandonados bajo un bloqueo
exclusivo. No reemplaza hosts activos, archivos normales ni enlaces simbólicos;
conserva el archivo de bloqueo entre reinicios y solo retira su propio socket
al terminar. Las pruebas cubren recuperación después de SIGKILL y coexistencia
con un host de una generación anterior, incluso entre `bind()` y `listen()`:
se comprueba también que ningún socket del kernel conserve esa ruta.
Este cambio del paquete nativo
se incorpora al reconstruir NixOS; la recuperación puntual y el cambio del helper
Sway ya están aplicados en la sesión actual.

## Configuraciones editables

Home Manager instala programas y servicios; `orgm-dot` copia los archivos del
checkout como archivos editables. El contexto es `osmarg/envy/sway` y sus
snapshots están separados de Ryoku e Hyprland. El primer bootstrap conserva
los archivos locales existentes; no restablece toda `~/.config`.

```sh
orgm-dot list
orgm-dot show sway
orgm-dot diff sway --patch
orgm-dot pull sway
orgm-dot push sway
```

Aplicaciones independientes: `sway`, `waybar`, `rofi`, `nwg-dock`, `qylock`,
`swayidle`, `sway-tools`, `sway-wallpapers`, `swaync` y `desktop-tools`. Los archivos antiguos de
Dunst se conservan como configuración inactiva; no se inicia su servidor. Rofi usa
`~/.config/rofi-sway` y los helpers nuevos usan el prefijo `sway-`, para
coexistir con los archivos de Ryoku sin depender de sobrescribirlos. El manifiesto de `nwg-dock` incluye
sus imágenes de interfaz; se usa el cargador SVG del paquete oficial librsvg.
`nwg-dock` 0.4.3 solo admite abajo/arriba/izquierda en upstream: el override
`nwg-dock-right.nix` añade un parche pequeño para el anclaje derecho y sus
menús; no se modifica SwayFX. Este cambio sí recompila únicamente el dock.
Por ejemplo, `orgm-dot pull waybar`
reemplaza la configuración de esa aplicación con respaldo previo. `push`
guarda el snapshot en el checkout; Git commit/push se ejecuta aparte.

Sway guarda sus salidas en `~/.config/sway/outputs.conf`; el menú Pantallas
abre nwg-displays con esa ruta. Se desactiva el conector fantasma DP-1 de
Envy y se dejan automáticas las demás pantallas. Los tiempos editables de
swayidle son bloqueo a 10 minutos, pantallas apagadas a 15 minutos y bloqueo
antes de suspender. Super+Alt+W aplica un fondo estático aleatorio.

## Verificación

```sh
bash tests/envy-sway.bats.sh
bash tests/firefox-open-tab.bats.sh
bash tests/windows-manager-linux-orgm.bats.sh
bash tests/configuration-inventory.bats.sh
bash tests/visual-profiles.bats.sh
python3 tests/sway-lock.test.py
```

Además de compilar el sistema completo y sus tres especializaciones, se
validó el archivo con `sway --validate` y se inició SwayFX con una salida
headless aislada, renderizada en Intel. La prueba comprobó reglas flotantes,
alternancia a mosaico, Waybar, nwg-dock, la carga de swayidle, capturas con
grim y grabación MP4 con el codificador VAAPI de Intel. Las pantallas
físicas, suspensión/reanudación y juegos deben comprobarse en el arranque real.
