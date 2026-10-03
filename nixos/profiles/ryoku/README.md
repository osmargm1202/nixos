# Ryoku para Osmarg

Perfiles independientes: `orgm-ryoku` y `lenovo-ryoku`. Se usa el módulo oficial
de [Ryoku on NixOS](https://github.com/aethctl/Ryoku-on-NixOS), fijado en
`28c5207586babb136aecf8568ce3ed873fa8f8fd`. Su nixpkgs se conserva separado:
Hyprland, plugins, portales y Quickshell deben usar el mismo conjunto compatible.

Desde la raíz del repo:

```bash
nh os build . -H lenovo-ryoku
nh os switch . -H lenovo-ryoku -s windows-vfio
```

`-s windows-vfio` conserva ese modo de Lenovo. Para elegir normal usa `-S`.
En ORGM usa `-H orgm-ryoku -S`. Tras aplicar, cierra la sesión y entra de nuevo
en Hyprland: cambiar el paquete del compositor necesita una sesión nueva.
Los archivos nuevos utilizados por el flake deben estar registrados en Git;
no hace falta crear un commit para construir o aplicar la configuración.
Usa `-H lenovo-ryoku`: el alias `lenovo` selecciona `lenovo-hyprland`.

Ryoku controla barra, dock, fondos, temas, Kitty, Neovim, monitores, bloqueo,
idle y notificaciones. Las aplicaciones y herramientas de Osmarg conservan su
selección habitual. Se mantienen sus menús de SSH, Pi, archivos, Obsidian,
Firefox, Windows/RDP y AI, sin arrancar Waybar, nwg-dock ni el gestor visual anterior.

Quickshell es el único servidor de notificaciones del perfil Ryoku. La revisión
oficial incluye Mako, cuya activación por D-Bus puede adelantarse a la shell;
la integración excluye Mako y Dunst de los paquetes publicados mientras Ryoku
está habilitado y desactiva ambos servicios de Home Manager. Los helpers siguen
usando `notify-send`; el comando de compatibilidad `dunstify` envía por esa misma
API y no arranca Dunst. i3 y el perfil Hyprland habitual conservan Dunst.

Windows/VFIO sigue usando Podman y su contenedor existente aunque Ryoku habilite
también Docker. La imagen SPICE se construye desde un contexto mínimo en Nix Store
con un `Containerfile.spice` regular, compatible con los enlaces de Home Manager.

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

`Win+L` conserva el bloqueo nativo de Ryoku. `Win+H/J/K` quedan libres;
las funciones nativas que usaban esas teclas se reubican. El enfoque y el
movimiento usan las flechas. `Win+/` abre Ryoku Hub → Keybinds; el informe de
CLI también recoge los accesos personales y las reubicaciones efectivas.

`Print` y `Alt+Print` abren Ryoshot; `Ctrl+Print` captura el monitor con Ryoshot.
`Win+Print` alterna la grabación nativa y `Win+Shift+Print` abre el panel de
captura de Ryoku, con sus opciones de grabación. La configuración se encuentra
en Ryoku Hub → Recording. Los scripts anteriores de Swappy y wl-screenrec no
se instalan en este perfil. `Win+C` abre la calculadora del launcher; el mismo
launcher busca archivos con `/file` y carpetas con `/folder`. `Win+Shift+M`
abre el gestor de archivos: en Nautilus, el menú contextual «Open in Kitty»
permite abrir la terminal en la carpeta seleccionada o actual.

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
restaura nuestro antiguo alias predeterminado a `login`, pero conserva todas
las colecciones y sus secretos. No cambia contraseñas ni migra credenciales.
La política PAM se define en Nix, sin modificar `/etc` desde el escritorio.

Ryoku materializa sus configuraciones editables al activar Home Manager y al
iniciar su sesión. Los overrides de integración se copian como archivos normales,
porque el materializador omite los enlaces del overlay. Al volver a otro perfil,
los archivos editables que ese perfil necesita reemplazar se guardan bajo
`~/.local/state/orgm-ryoku/return-*`. Los ajustes iniciales del teclado se siembran
una vez; las modificaciones posteriores desde Ryoku se conservan.

Kitty usa un fondo con opacidad 85 % (15 % de transparencia), conservando
la paleta y las fuentes nativas. La preferencia se carga desde un include en
`~/.config/kitty/user.conf`, un archivo que Ryoku no sobrescribe. La regla de
Kitty evita que la opacidad de ventanas inactivas multiplique ese valor:
[semántica de las reglas de opacidad](https://wiki.hypr.land/Configuring/Basics/Window-Rules/).
Al volver a otro perfil se retira exclusivamente ese include y se guarda una
copia; los otros ajustes personales se conservan. Para la apariencia general,
Ryoku Hub (`Super+,`) → Window Manager → Look → Opacity sigue siendo el control.

Los ajustes personales iniciales activan el enfoque al pasar el mouse, eliminan
el borde y redondean las esquinas a 12 px. Se guardan en el store de Ryoku
(`desktop.json`), conservando las modificaciones posteriores del Hub.

Las ventanas auxiliares de Osmarg se abren flotantes y centradas en su monitor:
calculadora 420×640, extensión Bitwarden 480×680, Orgmai chat 1360×820,
Orgmai configuración 1120×740, bandeja Nextcloud 560×680 y Syncthing 760×600.
Los tamaños iniciales se limitan al 92 % del ancho y 88 % del alto del monitor;
se pueden redimensionar después. La regla de Bitwarden exige el título de la
extensión de Firefox y no coincide con páginas habituales del navegador.
Firefox asigna ese título después de crear la ventana; un listener de
`window.title` aplica la posición una sola vez y conserva los cambios manuales
al recargar. Se usa la
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

## Verificación

```bash
nix shell nixpkgs#lua -c bash tests/ryoku-shortcuts.bats.sh
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
activar, ejecuta `nh os build . -H lenovo-ryoku` en tu terminal y revisa
su resultado.
