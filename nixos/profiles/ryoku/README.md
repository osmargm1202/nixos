# Ryoku para Osmarg

Hosts Ryoku: `orgm` y `lenovo`; cada host tiene una única salida pública. Se usa el módulo oficial
de [Ryoku on NixOS](https://github.com/aethctl/Ryoku-on-NixOS), fijado en
`28c5207586babb136aecf8568ce3ed873fa8f8fd`. Su nixpkgs se conserva separado:
Hyprland, plugins, portales y Quickshell deben usar el mismo conjunto compatible.
Envy usa únicamente [Sway](../../../docs/envy-sway.md) bajo la salida `envy`;
este perfil Ryoku ya no forma parte de su configuración.

Desde la raíz del repo:

```bash
nh os build . -H lenovo
nh os switch . -H lenovo -s windows-vfio
```

`-s windows-vfio` conserva ese modo de Lenovo. Para elegir normal usa `-S`.
En ORGM usa `-H orgm -S`. Tras aplicar, cierra la sesión y entra de nuevo
en Hyprland: cambiar el paquete del compositor necesita una sesión nueva.
Los archivos nuevos utilizados por el flake deben estar registrados en Git;
no hace falta crear un commit para construir o aplicar la configuración.
Usa `-H lenovo`: selecciona Ryoku directamente; ya no hay alias ni variantes públicas por escritorio.

Ryoku controla barra, dock, fondos, temas, Kitty, Neovim, monitores, bloqueo,
idle y notificaciones. Las aplicaciones y herramientas de Osmarg conservan su
selección habitual. Se mantienen sus menús de SSH, Pi, archivos, Obsidian,
Firefox, Windows/RDP y AI, sin arrancar Waybar, nwg-dock ni el gestor visual anterior.

Los valores básicos se guardan como configuración inicial de Ryoku, sin
reimponerlos en cada activación ni sobrescribir cambios posteriores del Hub.
Del perfil Hyprland habitual solo se conservan los atajos personales adaptados
a Ryoku; no se heredan sus ajustes visuales, animaciones ni comportamiento del
escritorio. Las correcciones de integración deben permitir configurar esas
preferencias desde Ryoku.

La integración resuelve los plugins incluidos desde su paquete en Nix Store,
con el compositor y sus cabeceras de la misma revisión. El Hub conserva sus
interruptores y dispone de herramientas para compilar plugins desde GitHub.
Seleccionar un preset de animación en el Hub reemplaza los ajustes anteriores
solo de animación; la primera selección guarda una copia del escritorio en
`~/.config/ryoku/desktop.json.before-animation-presets`. No se fuerza ningún
preset durante la activación del perfil.

Image borders y Glass liberan sus suscripciones a eventos al descargarse.
Sin esa limpieza, abrir una ventana después de desactivarlos podía ejecutar
callbacks sobre opciones ya retiradas y provocar un cierre con modo seguro.
La prueba de sesión abre ventanas antes y después de descargar y recargar plugins.

Los plugins incluidos aíslan sus símbolos internos: `PHANDLE` y
`g_pGlobalState` no se comparten entre bibliotecas. Cursor motion adapta el
hook de captura al API de Hyprland 0.56.2. Image borders convierte los tamaños
del Hub a tablas Lua y no emite una opción `enabled` que ese plugin no admite.
El archivo de imagen se elige desde el Hub; activar el plugin con esa ruta
vacía no dibuja bordes.

Glass aplica los deslizadores mediante un preset propio que hereda el elegido
en Ryoku, para que el preset no anule blur, opacidad, tinte y brillo.
Focus flash sigue el teclado y ofrece **Also animate mouse focus** para el
ratón. Key sounds obtiene sus perfiles del paquete de Nix Store.
Los presets de animación se aplican inmediatamente; el selector espera el
resultado del backend, conserva la última selección si falla y muestra el
error. Las selecciones rápidas se procesan en orden conservando la más reciente.

El menú de ajustes rápidos incluye **Suspend**. El servicio `fprintd` está
habilitado y el bloqueo conserva conversaciones PAM independientes para huella
y contraseña. El registro de dedos y el interruptor de desbloqueo se manejan
desde Ryoku Hub; no se registra ninguna huella automáticamente. La página distingue
un servicio inaccesible de una respuesta correcta sin lectores compatibles y
conserva los nombres de dedos cuando el lector no está disponible.

Quickshell es el único servidor de notificaciones del perfil Ryoku. La revisión
oficial incluye Mako, cuya activación por D-Bus puede adelantarse a la shell;
la integración excluye Mako y Dunst de los paquetes publicados mientras Ryoku
está habilitado y desactiva ambos servicios de Home Manager. Los helpers siguen
usando `notify-send`; el comando de compatibilidad `dunstify` envía por esa misma
API y no arranca Dunst. i3 y el perfil Hyprland habitual conservan Dunst.

Windows/VFIO sigue usando Podman y su contenedor existente aunque Ryoku habilite
también Docker. La imagen SPICE se construye desde un contexto mínimo en Nix Store
con un `Containerfile.spice` regular, compatible con los enlaces de Home Manager.

**Win+Shift+Espacio** alterna entre ventana flotante y mosaico. El modo seguro
de Hyprland usa sus atajos de emergencia y omite la configuración personal;
no debe confundirse con un cambio guardado por Ryoku.

En modo scrolling, **Win+R** alterna el ancho de la columna activa entre
**33 %, 50 % y 100 %** del área disponible, conservando la altura. Usa la acción
nativa `colresize +conf` y los presets definidos en el override `hypr/user.lua`.
También funciona con una sola columna: se desactiva el ajuste que la forzaba
a ocupar todo el ancho.
El modo de redimensionar con flechas queda en **Win+Ctrl+Alt+Shift+R**.
Los atajos se consultan en **Ryoku Hub → Keybinds** (`Super+,`), y el layout
se selecciona en **Window Manager**.

Los atajos personales tienen su propio archivo en
`dotfiles/config/users/osmarg/profiles/ryoku/.config/orgm-ryoku/osmarg-keybindings.lua`.
El perfil no importa los atajos del Hyprland habitual. Las acciones de escritorio usan los controles de Ryoku. Las colisiones
se trasladan a `Super+Ctrl+Alt+Shift+tecla`; si esa combinación ya está ocupada se
usan F1–F12, números o letras libres con esos modificadores y, cuando hace falta,
con `Super+Ctrl+Alt`. Todas esas teclas están en el teclado de Lenovo.
El informe de la integración se consulta con:

```bash
orgm-ryoku-shortcuts --list
```

`Win+L` conserva el bloqueo nativo. **Win+H abre Stash** (panel lateral) y
**Win+K alterna la ayuda nativa** (cheatsheet). `Win+J` queda reservado.
El enfoque y movimiento siguen usando flechas; **Win+S** conserva el scratchpad
personal y **Win+Shift+S** oculta la ventana. El antiguo H nativo para ocultar
se conserva en `Win+Ctrl+Alt+Shift+H` únicamente en Hyprland.
`Win+/` abre Hub → Keybinds; `Win+,` abre el Hub.

H se expresa mediante `desktop.keybindRebinds`, `desktop.keybinds` y
`desktop.unbinds`, admitidos por ambos proveedores. Si existe una preferencia
explícita H/S del usuario o está ocupado el destino del scratchpad, se conserva
y se omite ese conjunto de valores iniciales (se avisa en el log). Si H/K ya
pertenecen a una acción personalizada del Hub, solo se reubica el default nativo
en un acorde libre del mapa soportado; no se sobrescriben rebindings/unbinds
explícitos. K respeta sus rebindings nativos existentes.
Las nuevas acciones compartidas son visibles en Hub → Keybinds; esto **no**
convierte el registro Lua personal en un catálogo nativo: el Hub/cheatsheet puede
seguir anunciando acordes incorrectos para otras colisiones automáticas.
`orgm-ryoku-shortcuts --list` recoge las reubicaciones dinámicas de Hyprland.
Niri no adquiere las acciones personales de scratchpad, grupos o ventanas que
solo existen en Hyprland; mantiene sus acciones nativas compatibles.
La preparación genera `orgm-ryoku/native-shortcut-ownership.lua` desde las claves
personalizadas del store para que el asignador Lua no robe sus acordes libres.
Esta instantánea se refresca al activar/iniciar, no convierte las ediciones
avanzadas posteriores del Hub en una traducción completa del registro personal.

## Autoinicio nativo

Las aplicaciones se ven y editan en **Hub → Session → Autostart**; el mismo
`~/.config/ryoku/desktop.json` se materializa para Hyprland y Niri. No queda un
segundo bloque de arranque en `hypr/user.lua`.

`orgm.user.autostart` es una lista de comandos opcionales por usuario. Las
bandejas de Tailscale y Syncthing ya no son obligatorias ni se instalan como
arranque XDG en Ryoku. Tailscale conserva su daemon del sistema; Syncthing tiene
una unidad de usuario independiente, con descubrimiento nativo de su estado y
sin imponer carpetas, pares, credenciales o dirección del panel web.

Nextcloud se excluye de Envy: Online Accounts y GVfs proporcionan acceso remoto
desde Nautilus. Los otros hosts conservan su selección de Nextcloud. No se
eliminan cuentas, credenciales, bases de Syncthing ni carpetas sincronizadas.
Las aplicaciones opcionales de Osmarg conservan sus preferencias anteriores;
una lista vacía elegida desde Hub → Session sigue vacía después de reconstruir.

La limpieza de inicio retira una sola vez los comandos de bandejas y el cliente
Nextcloud deseleccionado del store nativo, conservando una copia en
`~/.local/state/orgm-ryoku/desktop.before-retired-startup-v1.json`. Los cambios
posteriores del Hub, incluso reañadir manualmente una aplicación, se conservan.
`native-session-v1.applied.json` mantiene la reconciliación de atajos y nuevas
selecciones sin reemplazar arrays enteros.

Las entradas XDG de Blueman, nm-applet y el applet de impresión quedan ocultas;
Bluetooth, NetworkManager y CUPS siguen habilitados. Udiskie conserva montaje
automático y avisos sin su bandeja. KDEConnect conserva su daemon: no equivale
a un indicador de bandeja ni a los controles Bluetooth de Ryoku.

`cleanup.py` archiva las entradas de arranque que se sustituyen y retira el viejo
script «Set as Hyprland Wallpaper» solamente si coincide con la copia del repo.
Los enlaces manuales al servicio empaquetado de Syncthing se retiran antes de
instalar la unidad declarada. Los archivos modificados y unidades personales se
conservan. Las copias quedan en `~/.local/state/orgm-ryoku/desktop-cleanup-v1/`.

`Print` y `Alt+Print` abren Ryoshot; `Ctrl+Print` captura el monitor con Ryoshot.
`Win+Print` alterna la grabación nativa y `Win+Shift+Print` abre el panel de
captura de Ryoku, con sus opciones de grabación. La configuración se encuentra
en Ryoku Hub → Recording. Los scripts anteriores de Swappy y wl-screenrec no
se instalan en este perfil. `Win+C` abre la calculadora del launcher; el mismo
launcher busca archivos con `/file` y carpetas con `/folder`. `Win+Shift+M`
abre el gestor de archivos: en Nautilus, el menú contextual «Open in Kitty»
permite abrir la terminal en la carpeta seleccionada o actual.

Texto plano y Markdown abren GNOME Text Editor desde la configuración común,
tanto en Ryoku como en Hyprland. Los tipos de programación conservan Neovim;
su entrada `nvim.desktop` lanza Kitty explícitamente para que GIO no elija xterm.
La activación aplica los mismos handlers declarados por el perfil.

Los iconos de carpetas siguen la paleta mediante `ryoku-cmd-folders`. El paquete
de integración usa Papirus desde Nix Store, ya que la ruta upstream
`/usr/share/icons/Papirus` no existe en NixOS. `prepare.sh` instala el hook de
Matugen como seed regular en `ryoku/user_edits/matugen/config.toml`, solo si falta;
las ediciones posteriores se conservan. Los nuevos hooks usan la ruta estable
`/run/current-system/sw/bin/ryoku-cmd-folders`, no la de una generación recolectable;
Ryoku ignora los enlaces simbólicos en ese overlay. La primera activación
selecciona `ryoku-folders` y las posteriores respetan otros temas elegidos.

Ryoku conserva exclusivamente cinco utilidades de la antigua capa común de
Osmarg: sus tres acciones de marcadores, copiar stdin y el temporizador de
reproducción. El historial, la luz nocturna, los menús de red, el cierre de
sesión y los estados de multimedia pertenecen a Ryoku; sus helpers anteriores
no se enlazan. SSH con usuarios guardados, Pi y enfocar/abrir Obsidian siguen
siendo flujos personales que añaden comportamiento a la shell.
Rofi usa paneles redondeados sin borde y los colores de la paleta de Ryoku.
La configuración global cubre los menús de SSH, Pi, archivos, Firefox y símbolos;
un watcher actualiza los colores cuando Ryoku cambia de tema o de fondo.

Ryoku usa SDDM con greeter X11 y sesión Hyprland Wayland, sin autologin.
PAM desbloquea la colección cifrada `login` con la contraseña de acceso; ambas
contraseñas deben coincidir. La política `never-ask` se retiró: la activación
retira una sola vez nuestro antiguo alias predeterminado a `login`, pero conserva
todas las colecciones y sus secretos. Las elecciones posteriores del alias y de
la política del Hub no vuelven a imponerse desde la preparación. No cambia contraseñas ni migra credenciales.
La política PAM se define en Nix, sin modificar `/etc` desde el escritorio.

Ryoku materializa sus recursos al activar Home Manager y al iniciar su sesión.
Nuestras preferencias solo se siembran si falta el archivo; no se reinstalan
sobre un archivo regular o enlace personal existente. Los archivos editables
que un modo de consola necesita reemplazar se guardan en un snapshot privado
`~/.local/state/orgm-ryoku/return-*`; al volver a Ryoku se recuperan solo sobre
slots ausentes o enlaces declarativos comprobados, sin pisar archivos nuevos
del usuario. La selección de modo se comprueba por Ryoku habilitado, no por el
nombre del perfil. El teclado y los stores nativos conservan los cambios del Hub.

Kitty usa un fondo con opacidad 85 % (15 % de transparencia), conservando
la paleta y las fuentes nativas. La preferencia se carga desde un include en
`~/.config/kitty/user.conf`, un archivo que Ryoku no sobrescribe. La regla de
Kitty evita que la opacidad de ventanas inactivas multiplique ese valor:
[semántica de las reglas de opacidad](https://wiki.hypr.land/Configuring/Basics/Window-Rules/).
No se reinserta un include eliminado por el usuario. Al volver a consola se
conservan `kitty/user.conf` y la preferencia editable de opacidad; las otras bases
Kitty no importan ese override de Ryoku. Para la apariencia general,
Ryoku Hub (`Super+,`) → Window Manager → Look → Opacity sigue siendo el control.

Los ajustes personales iniciales activan el enfoque al pasar el mouse, eliminan
el borde y redondean las esquinas a 12 px. Se guardan en el store de Ryoku
(`desktop.json`), conservando las modificaciones posteriores del Hub.

Las ventanas auxiliares de Osmarg se abren flotantes y centradas en su monitor:
calculadora 420×640, extensión Bitwarden 480×680, Orgmai chat 1360×820,
Orgmai configuración 1120×740, bandeja Nextcloud 560×680 y Syncthing 760×600.
Los tamaños iniciales se limitan al 92 % del ancho y 88 % del alto del monitor;
se pueden redimensionar después. Bitwarden se identifica por el título de la
extensión en Firefox o por el app_id de Chromium
(`chrome-nngceckbapebfimnlniiiahkandclblb-<perfil>`); las páginas habituales del
navegador conservan su disposición. Firefox asigna el título después de crear
la ventana, por lo que también se escucha `window.title`.
Las ventanas auxiliares reciben foco y el cursor en su centro una vez por
apertura, incluida la calculadora y los diálogos de bandeja. Esto evita que
el enfoque al pasar el mouse vuelva a la ventana debajo del cursor anterior.
Los cambios de título y las recargas conservan el foco y los ajustes manuales;
al cerrar y reabrir un diálogo se permite un nuevo enfoque inicial. Se usa la
[API nativa de eventos](https://wiki.hypr.land/configuring/core/rules/window-rules/#static-effects)
porque las reglas estáticas solo evalúan el título inicial. Estas reglas
adaptativas están en el override personal
`dotfiles/config/users/osmarg/profiles/ryoku/.config/orgm-ryoku/window-rules.lua`,
cargado desde `hypr/user.lua`; no modifican i3, Hyprland habitual ni Jarq.
Ryoku Hub → Window Rules (modo avanzado) permite agregar otras reglas; su editor
de tamaños de esta revisión admite dimensiones fijas, mientras este override
usa las expresiones adaptativas de Hyprland.

Hypridle 0.1.7 busca su configuración habitual incluso al recibir una ruta con
`-c`. La preparación crea `~/.config/hypr/hypridle.conf` como enlace a la política
generada por Ryoku cuando esa ruta está libre; conserva configuraciones existentes.

Lenovo mantiene normal, batería, gaming, Windows/VFIO y server. Gaming y server
deshabilitan Ryoku completo, incluidos Niri y los servicios de la shell. ORGM
conserva su especialización server. El controlador y los dispositivos VFIO
siguen perteneciendo a los módulos de hardware existentes.

Lenovo ignora los eventos de tapa en todos sus modos, incluida la recuperación
desde TTY. El drop-in de Ryoku que imponía suspensión por tapa está deshabilitado.
Esto no modifica la suspensión manual ni la política de inactividad de Ryoku.
El panel interno averiado se mantiene deshabilitado; el valor inicial de Lenovo
se siembra únicamente cuando no hay `hypr/monitors_user.lua` personal. Ese
archivo, los perfiles de monitores del Hub y `ryoku/shell.json` se conservan en
las activaciones posteriores. Ryoku controla el hotplug y los ajustes de
pantallas desde Hub → Displays. El dock usa QS Bar Settings → Dock, cuyo estado
y aplicaciones fijadas se guardan por la shell, sin un segundo dock.

El hardware de Lenovo también añade `video=eDP-1:d` al arranque para que la
consola de Linux no reactive el panel interno averiado al cambiar de TTY.
Esto mitiga el conflicto observado entre la asignación de salidas de la consola
y la que Hyprland intenta restaurar. No fija el conector ni el modo de las
pantallas externas. Requiere reconstruir NixOS y reiniciar; la recuperación debe
comprobarse con imagen visible al recorrer `tty1 → tty3 → tty1`. Si se repara el
panel interno, hay que retirar ese parámetro del módulo de hardware de Lenovo.

El monitor de Tailscale identifica dispositivos por su primera IP Tailscale,
no por un nombre que puede repetirse. Una IP debe permanecer desconectada en
observaciones continuas durante al menos 90 segundos para avisar; se muestra
el nombre del equipo y su IP. Una pérdida de red local, Tailscale local fuera
de línea, reinicio o pausa larga del muestreo suspende los avisos y comienza
una línea base nueva al recuperar conexión. El notificador también comprueba
la red y descarta la cola anterior a esa recuperación. La política declarativa
está en `orgm.tailscale.peerNotifications`, con `enable` independiente de la VPN
y `disconnectGraceSeconds` configurable. Los eventos nuevos usan un stream v3
para no reutilizar el estado antiguo indexado por nombre.
Para Osmarg está desactivado desde `nixos/users/osmarg.nix`, en todos sus
perfiles; Tailscale y su integración de DNS continúan habilitados.

## Verificación

```bash
nix shell nixpkgs#lua -c bash tests/ryoku-shortcuts.bats.sh
bash tests/ryoku-startup.bats.sh
bash tests/ryoku-transition.bats.sh
bash tests/ryoku-rofi.bats.sh
bash tests/ryoku-profile.bats.sh
```

La prueba de atajos usa los módulos de la revisión fijada de Ryoku y después
ejecuta su Hyprland real con `--verify-config`, incluido el overlay de usuario.
Comprueba los atajos de terminal, launcher, ayuda y controles, sin colisiones
efectivas, incluidos nombres equivalentes como `Next` y `Page_Down`. El cargador
es compatible con Lua 5.5 y reubica también duplicados de los atajos personales.
También comprueba que el título tardío de Bitwarden solo afecte a la extensión,
respete escala y rotación del monitor y conserve los ajustes manuales posteriores.
Las pruebas de transición conservan los archivos editables y llaveros existentes;
la evaluación de perfiles comprueba PAM efectivo, autologin y política de tapa.

Se evaluaron el módulo oficial y todos los modos de arranque de Lenovo y ORGM
con `tests/ryoku-profile.bats.sh`. Esa comprobación valida las opciones e
integración declarativa; no sustituye una construcción completa. Antes de
activar, ejecuta `nh os build . -H lenovo` en tu terminal y revisa
su resultado.

## Inicialización personal y edición posterior

El repo pone el punto de partida; el usuario y Ryoku mandan después. No todas
las partes son editables en el Hub: el código Bash/Lua personal se controla
mediante imports y archivos de usuario, no mediante una segunda GUI inventada.

| Archivo o grupo | Propiedad posterior al primer seed |
|---|---|
| `~/.config/fastfetch/config.jsonc`, `hardware.jsonc`, logos | Archivo regular; Hub/Fastfetch y edición directa |
| `~/.config/starship.toml`, `btop/`, `nvim/` | Seeds conservados por el CLI nativo, sin overlay congelado |
| `~/.bashrc`, `~/.blerc`, `~/.config/bash/user.bash` | Bootstrap/imports editables; no se reponen líneas borradas |
| `~/.config/orgm-ryoku/*.lua`, `rofi.rasi` | Módulos personales editables; sus cambios no se relinkean al Store |
| `hypr/user.lua`, `ryoku/user_edits/hypr/modules/rebind.lua`, hook Matugen, `kitty/user.conf` | Overrides nativos iniciales; las ediciones posteriores ganan |
| `~/.config/orgm-shell/` | Bibliotecas importables de código (OMP, Nix, SSH, tmux, completions y helpers); actualizables desde el repo |
| Stores `desktop.json`, `shell.json` | Hub; preferencias conservadas después de las migraciones puntuales |
| Recursos base Bash de Ryoku y entorno, Quickshell/proveedores | Runtime de la versión fijada, actualizable |
| `native-window-widths.lua`, hints de propiedad de atajos | Derivados del store vigente; editar la fuente del Hub, no estos artefactos |

Los dotfiles personales se leen del checkout por `orgm-dot` y se copian una vez,
antes del materializador. NixOS instala paquetes, servicios y metadatos de
integración; no enlaza las preferencias del repo al Store. Los JSON por
aplicación están en `dotfiles/apps/`. `orgm-dot diff`, `pull` y `push` permiten
actualizar cada aplicación explícitamente, con respaldos restaurables en
`~/.local/state/orgm-dot/backups/`. Las reconstrucciones respetan las ediciones
y los archivos eliminados después de la primera copia.

El helper conserva los límites del runtime de Ryoku: los imports personales de
Bash/Kitty usan sus archivos de usuario y el Hub conserva los stores y recursos
nativos. Los enlaces de directorio ajenos se conservan y bloquean la escritura;
los enlaces antiguos al Store se convierten en copias con respaldo. Véase
[la guía del helper](../../../dotfiles/README.md).

### Fastfetch y Bash

El paquete Nix entrega ahora los recursos Bash/entorno/Rashin que faltaban.
El bootstrap inicial entra en Bash nativo de Ryoku. Los overrides editables de
`ryoku-terminal` desactivan Fastfetch automático tanto en Bash como en Fish;
el comando permanece disponible para ejecutarlo manualmente. Se importa la biblioteca personal
sin volver a iniciar prompt/Starship, zoxide, fzf o un banner paralelo. Quitar un
import de `~/.config/bash/user.bash` se respeta en el próximo switch.

Mise y Starship se inician antes de Zoxide: Mise reemplaza `cd` y Starship puede
encapsular los hooks de prompt. El orden inverso anulaba los saltos de directorio
y podía generar el aviso de inicialización de Zoxide. Ryoku sigue inicializando
Zoxide una sola vez como `cd`/`cdi`; la biblioteca personal también conserva
`z`/`zi`. Los datos de Zoxide y el historial no se borran ni se migran.
La misma biblioteca restaura los cinco atajos FZF de Blesh (Alt+R/F/C/P/A),
las funciones y completions personales y, si ya está instalado, el entorno fnm.
Alt+R conserva el historial FZF personal; Rashin sigue disponible con `rashin`.
Atuin conserva su integración de historial del sistema.

Los scripts de preview conservan sus dependencias `lsd`, `chafa` y `ouch`;
`aichat` respalda el widget Alt+A existente. Las aplicaciones personales
GNOME System Monitor, Network Displays, Sushi, Videos, Pamixer y Pulsemixer
pertenecen a la selección del usuario, independientemente del perfil gráfico.
Miracast mantiene su puerto TCP 7236 y KDE Connect su portal de entrada remota
en Hyprland. Estas herramientas no añaden bandejas ni arranques automáticos.
`memclean-dev` tampoco reinicia Waybar, Conky ni el dock antiguo si está instalada
la unidad de Ryoku, aunque esa unidad esté temporalmente detenida.

Tras aplicar: **Hub → Fastfetch → Save**, abrir una terminal nueva y comparar.
Una vista previa no guarda por sí sola ni cambia un banner ya impreso. No se
reemplaza una configuración Fastfetch regular existente, incluida la actual de
Envy. Los procesos Bash ya abiertos mantienen lo que cargaron: abre otra terminal
para probar el nuevo arranque.

### Lanzador de IA personal

`Super+A` (`orgmai new`, también disponible como `ai-chat new`) pregunta en su
primer lanzamiento qué programa usar: Claude, Codex, OpenCode, OMP o Pi. Guarda
solo la elección con permisos 0600 en `~/.config/orgmai/config.json`. Si ya hay
un programa elegido, lo conserva. La terminal Kitty usa la clase `orgmai-chat`,
que tiene una regla flotante y centrada; el proceso se sustituye directamente
por el programa nativo.

`Super+Ctrl+Shift+A`, `ai-chat config` o `ai-chat program` permiten cambiar el
programa. `Super+Shift+A` abre el historial nativo del elegido; OpenCode continúa
la última conversación y permite navegar desde su propia interfaz.

Pi se ejecuta como **`pi -ne`**, sin extensiones, con su modelo, autenticación,
interfaz y conversaciones habituales. No se usa RPC, un prompt propio ni una
capa de chat de OrgM. Las opciones antiguas de modelo/proveedor/razonamiento del
lanzador se ignoran; los archivos históricos de OrgM se conservan sin importar
ni mezclar conversaciones. Los argumentos adicionales se pasan al programa
nativo como argumentos, sin interpretarlos en un shell.

Los programas no instalados aparecen indicados y el selector muestra cómo
instalarlos, sin elegir otro por su cuenta ni guardar una selección inválida.
El lanzador reconoce Bun, npm, FNM y `~/.opencode/bin` aunque la sesión gráfica
no haya iniciado un shell interactivo. No confunde nuestros wrappers `claude` y
`codex` con una instalación real del cliente.

### DPMS al reanudar

El proveedor Hyprland se corrige para emitir `action = "on"/"off"` en lugar de
`state`, que la API fijada ignoraba y convertía en toggle. Se comprueba con el
binario real y socket/controlador de prueba, sin apagar pantallas reales.
Build y pruebas no sustituyen verificar físicamente lock/unlock y sleep/resume.
Seguimiento: [pendientes Envy](../../hosts/envy/PENDING.md).

### Aplicación manual y comprobación física

Esta revisión se aplica a los hosts que conservan Ryoku, por ejemplo Lenovo.
La investigación de Envy se conserva como antecedente; Envy usa ahora Sway.
Actualiza el checkout del host Ryoku y aplica:

```bash
cd ~/Hobby/nixos
git fetch origin
git switch master
git pull --ff-only
nh os switch . -H lenovo
```

Revisa cualquier error de activación; la ausencia de la identidad privada SOPS
aceptada para este host sigue siendo independiente de estas pruebas. Abre una
terminal nueva después del switch y guarda un cambio de Fastfetch desde el Hub.
Comprueba después lock/unlock y sleep/resume, primero solo con eDP y luego con
la LG por USB-C. HDMI sin señal y contenido recortado continúan pendientes;
esta corrección del proveedor no demuestra que sus causas sean las mismas.

La recuperación automática cubre los modos de consola/servidor de esta revisión.
Un `rollback` a una generación antigua ejecuta su propio script histórico:
no se puede modificar retroactivamente; podría requerir restaurar manualmente
el snapshot privado `orgm-ryoku/return-*` ante un conflicto de Home Manager.
La biblioteca de aliases antigua no se reescribe: alguno que nombre variantes
retiradas todavía requiere actualizarse al host canónico.

Limitación menor conocida: un comentario que mencione `ryoku.bash` puede ocultar
el aviso de import ausente. El archivo se conserva igualmente; para usar el
arranque nativo debe existir un import activo, no solo comentado.
