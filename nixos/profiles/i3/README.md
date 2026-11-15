# i3 y su variante ligera

## Sesión opcional en Envy y X13

`light-session.nix` agrega **i3 ligero (X11)** al selector existente: Sway sigue
como escritorio principal de Envy y GNOME el de X13. No crea otra salida de
flake ni especialización. Envy conserva i3 también en windows-vfio; gaming y
Server, y el Server de X13, no incorporan esta sesión.

`light-config` se carga desde el almacén Nix sin importar los autostarts o
personalizaciones del escritorio principal. No arranca Picom, teclado virtual,
fondo, dock, widgets ni aplicaciones como Steam o el navegador. Las aplicaciones
existentes siguen disponibles en Rofi. La barra conserva detalles locales y
cafeína, sin controles visuales ni servidores ni su consulta periódica.
Los paquetes son del nixpkgs bloqueado; solo se generan wrappers/configuración
pequeños, sin parches del gestor de ventanas ni versiones nuevas por este cambio.

Atajos: Win+Enter terminal, Win+Espacio aplicaciones, Alt+Tab ventanas,
Win+C calculadora, Win+E archivos, Win+W navegador, Win+N red, Win+B Bluetooth,
Win+F10 audio, Win+Shift+C cafeína, Win+L bloqueo con contraseña,
Win+Shift+E cerrar sesión. Hay espacios 1–10, teclas multimedia y brillo.
La cafeína también se alterna desde su indicador en la barra.

El lanzador separa el entorno X11 del de Sway/GNOME; su target inicia Dunst y
el agente polkit. `xss-lock` usa i3lock antes de suspender. No cambia la política
biométrica ni el bloqueo nativo de los otros escritorios. Archivos y navegador
usan los manejadores predeterminados del host.

**Preparado localmente, no desplegado.** Esperar a que el usuario avise que las
laptops están encendidas antes de conectarse o aplicar. Tras desplegar, elegir
la sesión en SDDM (Envy) o en GDM (X13); con autologin, cerrar sesión primero.
El primer inicio físico, bloqueo, brillo y monitores requieren pruebas por host.
No asumir que los conectores XRandR de Envy coinciden con Sway ni copiar su
regla de DP-1 sin verificarla.

`python3 tests/i3-light-session.test.py` compara escritorio, GPU, catálogo y
autostart antes/después, comprueba los modos sin gráficos, construye las sesiones
y valida la configuración con i3 real. Prueba el lanzador con sustitutos de
systemd/D-Bus/i3 sin tocar ninguna sesión real.

## Perfil i3 principal

`i3.nix` mantiene el escritorio existente. `lightweight.nix` importa esa misma
base, conserva autotiling, swallowing, atajos, portapapeles y monitor externo,
y selecciona aplicaciones pequeñas, Xterm, LightDM GTK, i3status y bloqueo
con i3lock-color. No instala Picom, fondos de vídeo ni el teclado
Quickshell. Steam se ejecuta dentro de i3, sin sesión Gamescope.
Chromium puede habilitarse por usuario para webapps y Widevine; hm lo selecciona.
Las preferencias `orgm.i3.terminal`, `orgm.i3.alternateTerminal`,
`orgm.i3.statusCommand` y `orgm.i3.barFont` se leen mediante Xresources: i3
expande las variables del archivo principal antes de procesar los includes.
La barra conserva el decorador compartido `i3status-localized`: iconos, colores,
IP, batería, teclado, cafeína, CPU, memoria disponible, espacio libre y fecha
completa en español. La variante ligera usa letra de 9.5 puntos y actualiza cada
cinco segundos. Omite únicamente el control de Picom, que no está instalado.
El perfil conserva Plymouth y el logo de arranque del escritorio compartido;
cada host puede aportar una imagen de respaldo cuando no exista BGRT.
El usuario puede elegir `neovim` y `orgm.neovim.prebuilt = true` para LazyVim:
el adaptador carga complementos y parsers del almacén Nix, conservando las
opciones y atajos editables. No descarga ni compila complementos al abrirse.

Los menús Rofi se adaptan al monitor activo, con un máximo de 480 px de ancho,
tipografía de 10.5 puntos y una cantidad limitada de filas con desplazamiento.
En 1366×768 muestran hasta ocho filas. Se conservan los modos de aplicaciones,
ventanas, calculadora, pestañas de Firefox y menús propios. El perfil ligero
envuelve también las llamadas Rofi de Clipcat, símbolos, SSH e IA, limitando
tanto las filas del tema como las solicitadas en la línea de comandos.
También reemplaza el fragmento de i3 que iniciaba el teclado en pantalla.

## Separación de preferencias y hardware

- `nixos/users/<usuario>.nix`: programas, selección de emuladores, bundles de
  ArtCraft y aplicaciones personales.
- `dotfiles/config/users/<usuario>/profiles/i3/`: variaciones editables del usuario.
- `lightweight.nix` y `dotfiles/config/profiles/i3-lightweight/`: configuración
  ligera reutilizable por cualquier usuario y host.
- `nixos/hosts/<equipo>/`: hardware, dispositivos, cargador y claves públicas.

El perfil agrega `i3-lightweight` a `orgm.user.programs`. orgm-dot aplica sus
archivos después del i3 compartido y antes de las preferencias del usuario y
el host. No utiliza archivos personales de Osmarg o Jarq. El contexto sigue
siendo `i3`, por lo que las integraciones compartidas conservan su funcionamiento.

Para otro equipo, agregar una entrada a `configurations.nix` con `role =
"desktop"`, `profileName = "i3"`, `profile = ./nixos/profiles/i3/lightweight.nix`,
el usuario elegido y su hardware recién generado. No copiar UUID, `/dev/sda`,
claves autorizadas ni opciones Intel de la ThinkPad a otro hardware.

Las credenciales y sesiones de los proveedores de IA permanecen en el HOME del
usuario. OrgM AI conserva los menús y accesos a clientes nativos. El usuario hm
selecciona Codex, Claude Code y Pi como paquetes Nix; los instaladores compartidos
siguen disponibles para instalaciones personales. Bun utiliza el binario Linux
baseline SSE4.2, sin exigir AVX/AVX2.

## Actualizaciones sin compilación en el equipo pequeño

El destino tiene `nix.settings.max-jobs = 0`. Construir en un equipo potente,
comprobar el resultado y transferirlo mediante `nix copy`/`nixos-rebuild` con
`--target-host`. La configuración reutiliza cache.nixos.org y orgm.cachix.org;
las derivaciones propias se realizan en el equipo de construcción. Cambiar el
perfil no crea automáticamente un constructor remoto permanente.

En una instalación desde el USB se puede usar `nix copy --to
'ssh://root@IP?remote-store=/mnt' RUTA_DEL_SISTEMA` y luego `nixos-install
--root /mnt --system RUTA_DEL_SISTEMA --no-root-passwd` en el destino. Provisionar
el checkout y la conexión Wi-Fi antes del primer arranque.

Validación: `python3 tests/thinkpad11e.test.py`, pruebas Go de orgm-dot, pruebas
de Firefox y pruebas de CADCraft. CADCraft en i3 identifica el PID real del
cliente X11 mediante XRes; no utiliza el PID dentro del sandbox para enfocar.

Ejemplo de actualización de un equipo ya instalado, desde el constructor:

```sh
nix build path:.#nixosConfigurations.thinkpad11e.config.system.build.toplevel --out-link /tmp/thinkpad11e-update
system=$(readlink -f /tmp/thinkpad11e-update)
nix copy --to ssh-ng://hm@10.0.0.63 "$system"
ssh -t hm@10.0.0.63 "sudo nix-env --profile /nix/var/nix/profiles/system --set '$system' && sudo '$system/bin/switch-to-configuration' switch"
```

Sincronizar antes el checkout editable de dotfiles al destino. Después de la
primera activación, las preferencias ya inicializadas solo se actualizan con
`orgm-dot pull APP`; las activaciones siguientes conservan las ediciones locales.
