# i3 junto a Hyprland en ORGM

La sesión **i3 (X11)** conserva la configuración y las optimizaciones de arranque
existentes, los atajos, Rofi normal y `steam -silent`. Las últimas instrucciones
del 14 de noviembre de 2026 requieren una sesión sin teclado virtual, fondo ni
efectos, con la barra detallada y cafeína, pero sin monitores de servidores.

## Configuración actual

`nixos/hosts/orgm/i3-session.nix` deriva la configuración de la base compartida
sin cambiar los dotfiles i3 de otros equipos. Conserva los fragmentos de programas
y la capa personal, omitiendo OSK, aplicación del perfil visual, cambio de fondo
y el arranque del helper de monitores que restaura el fondo. Picom no se registra
en la generación nueva. Autorandr no se habilita en esta adaptación.

La barra vuelve a usar el decorador personal de i3status: CPU, memoria, disco,
red, batería cuando corresponda, distribución de teclado, fecha y modo cafeína.
Se conservan el botón de cafeína y Win+Shift+C. Se desactivan mediante variables
específicas de esta sesión los selectores de perfil visual/Picom y los monitores
de servidores. Con `I3_STATUS_SERVERS=0` tampoco se instancia el trabajador que
consulta los servidores; ocultar el bloque no deja consultas en segundo plano.
Los valores predeterminados del decorador compartido se conservan en otros usos.

El lanzador utiliza `i3 -c` con la configuración generada, expuesta también en
`~/.config/i3/orgm-minimal.conf`. Win+Espacio y Alt+Tab llaman a los modos normales
de Rofi. Dunst pertenece al target de i3 y se inicia como servicio D-Bus antes
del escritorio. Hyprland sigue como sesión predeterminada, Server permanece sin
gráficos y Syncthing, Sunshine y Tailscale no reciben reglas de pausa.

Los overrides de usuario persistentes `90-orgm-session.conf` bloquean Picom en
i3 y limitan OSK, notificaciones Hyprland y portal Hyprland a sesiones Wayland.
Esto también protege la generación anterior mientras falta el switch del sistema.
No son máscaras globales: Hyprland conserva su teclado virtual.

## Evidencia de aplicación y verificación

El primer inicio falló porque PAM exportaba XDG_SESSION_TYPE=wayland globalmente:
SDDM seleccionó orgm-i3.desktop pero arrancó wayland-session sin crear Xorg.
El módulo anula esa variable con `lib.mkForce null`. La generación con esa
corrección, `fnjpar12a9wk8a53xwiqw0k27hsfkip1`, arrancó i3/X11 correctamente
el 14 de noviembre a las 20:45:48 AST; i3 PID3441 tiene socket IPC operativo.

Ese reinicio usó todavía las unidades antiguas, por lo que volvieron Picom y
OSK. A las 20:50 se instalaron y recargaron los overrides de usuario, se detuvieron
esos procesos y se restauró la barra detallada. Se instaló el servicio Dunst y
su dependencia del target de i3. La configuración abierta se actualizó por IPC,
sin cerrar la sesión ni sus aplicaciones. El fondo existente se limpió con negro.

A las 20:53 se retiraron además los monitores de servidores y su consulta.
Se verificó una trama real de la barra: battery, caffeine, cpu, disk, ethernet,
keyboard, memory, tztime y wireless, sin orgm-status, picom-effects ni visual-profile.
Se solicitó explícitamente iniciar Picom y OSK: ambos quedaron inactivos con
`ConditionResult=no`. Dunst está activo y no quedan unidades de usuario fallidas.
Las copias anteriores de la configuración están bajo `~/.local/state/i3/`;
la última es `config-before-local-status-20261114-205318`.

Los archivos aplicados apuntan al home-files compilado. La raíz de GC
`~/.local/state/orgm-i3/home-files` conserva sus dependencias para que esta
aplicación persistente de usuario sobreviva a la limpieza de Nix. Home Manager
declara los mismos archivos para la siguiente activación completa.

Pasaron la prueba enfocada `python3 tests/orgm-i3-session.test.py`, el parseo real
con `i3 -C` y el build completo de `.#nixosConfigurations.orgm.config.system.build.toplevel`:
`/nix/store/ijkqvlx9hy92vy0iqr0bn9z2rayyq1bh-nixos-system-orgm-hyprland`.
La prueba verifica cafeína y detalles locales, ausencia de controles visuales y
servidores, guardas de sesión, Steam, entorno X11 y separación de Server.

Dos pruebas generales tienen fallos previos, comprobados con la versión HEAD:
`i3-bar-caffeine.bats.sh` espera resource_blocks en el decorador compartido, donde
esa función no existe; `orgm-status.bats.sh` falla con KeyError: 0 incluso usando
el decorador personal sin estos cambios. No se modificaron esas pruebas ni sus
componentes ajenos para ocultar los errores.

## Estado de la generación de sistema

La generación global activa sigue siendo `fnjpar12a9wk8a53xwiqw0k27hsfkip1`.
Los cambios de usuario descritos arriba ya están aplicados y son persistentes.
Falta `nh os switch . -H orgm` para instalar también las unidades de sistema y
el lanzador nuevos; sudo requiere contraseña en la terminal del usuario.
Tras ese switch queda verificar otro inicio físico con el lanzador nuevo.
No hubo commit/push; los cambios ajenos de navegador y X13 se conservaron.

## 2026-11-14: Brave no abría en i3; corregido en la sesión

El journal de las 21:51–21:52 muestra `Failed to connect to Wayland display`:
browser.nix imponía `--ozone-platform=wayland` al paquete y webapps.nix repetía
esa opción en los lanzadores Origin, aunque la sesión activa era i3/X11.
Ahora se usa el paquete nativo sin esa imposición; Origin selecciona su backend
al arrancar. Las webapps Origin conservan identidades y perfil Default compartido.
Los otros backends Chromium mantienen su selección explícita anterior.

El paquete exacto `ggnkk2lxdig9m3x7ydi3i5x6ydapxhsd-brave-origin-1.99.55`
se obtuvo del caché firmado. Pasaron tests/browser-session.test.py,
browser-profile.test.py y browser-pins.test.py, una apertura real X11 con
Xvfb/HOME/perfil temporal, y el build ORGM completo:
`/nix/store/n5ry2s35bf73lzpy3107ldfi6jrdr82n-nixos-system-orgm-hyprland`.
No se afirma una nueva prueba física de Wayland por esta corrección.

Aplicación de usuario persistente: brave-origin, orgm-browser, el menú principal
y 31 menús webapp apuntan a los archivos compilados, también declarados en Home
Manager. Backups bajo `~/.local/state/orgm-browser-fix/20261114-215704` y
`20261114-215850`; raíz GC `~/.local/state/orgm-browser-fix/home-files`.
Se renovó solo la caché drun de Rofi, conservando el historial y el respaldo.
Brave abrió una ventana real en i3; se dejó abierto. No se editaron directamente
preferencias, cookies, credenciales ni perfiles, ni se ejecutó su migración.
No hubo switch global ni despliegue a X13/Envy; la nueva generación global
puede instalarse posteriormente con el NH habitual.

## 2026-11-15: activación automática de juegos en i3

El usuario confirma que quiere el equivalente a `focus_on_activate` de
Hyprland: volver a un juego cuando solicita atención, por ejemplo al encontrar
partida en Dota. `game-activation.nix` instala el servicio de usuario
`orgm-i3-game-activation`, limitado al target de i3 y a XDG_CURRENT_DESKTOP=i3.
La política global de foco de i3 no cambia.

Un suscriptor IPC bloqueante atiende solo urgencia nueva de `dota2`,
`steam_app_NUM`, `gamescope` y `EtG.x86_64`, las mismas clases de Hyprland.
No concede permisos adicionales al cliente Steam, SteamWebHelper ni otras apps.
No hay sondeo de ventanas, barrido inicial de urgencias ni regreso forzado al
juego por cambios de foco/título. El foco usa un ID numérico de contenedor.
Se redescubre el socket tras reiniciar i3; el servicio termina con su sesión.
No activa fullscreen, efectos, render_unfocused, VRR ni tearing.

Pasó `python3 tests/i3-game-activation.test.py` con Xvfb, i3 real y peticiones
X11 _NET_ACTIVE_WINDOW en una pantalla privada: activaciones repetidas entre
escritorios, conservación de fullscreen, negativos Steam/nombres inválidos/apps
normales, Alt+Tab sin bucle y reconexión tras reiniciar solo el i3 de prueba.
El socket del escritorio original se conservó y no se envió input al Dota real.
También pasaron las regresiones ORGM/laptops y los builds completos locales:
ORGM `q4nm48fg1a25blq05c8h2k45a029ixq9`, Envy
`cx1y1nbyiki04h4a67pvy71i5s0l66a3`, X13 `mqidscpram96s8zphy9p8l21vp1xbgm2`.

Aplicación actual: unidad de usuario habilitada y activa en ORGM a las 00:41
AST, con suscripción IPC confirmada en el journal. Enlaces de unidad/WantedBy
proceden de Home Manager; raíz GC `~/.local/state/orgm-i3-game-activation/unit`.
No se cerró/reinició el escritorio, Steam ni el juego real. La prueba de una
petición real de Dota queda para el próximo evento del usuario. El módulo de
sesión ligera de Envy/X13 reutiliza la misma adaptación en las fuentes; ambas
laptops siguen **sin despliegue**, esperando el aviso del usuario.
