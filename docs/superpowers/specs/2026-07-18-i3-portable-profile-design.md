# Perfil i3 portable para todos los hosts

## Objetivo

Completar el perfil existente `nixos/profiles/i3.nix` como escritorio X11 portable para `orgm`, `lenovo`, `ero` y `jarq`. El perfil debe iniciar i3 automáticamente desde `tty1`, incluir Xorg Server y ofrecer una sesión diaria funcional alrededor de i3, Rofi, Kitty, Polybar y Picom.

No se creará un segundo perfil. Se conservarán los nombres `orgm-i3`, `lenovo-i3`, `ero-i3`, `jarq-i3` y el output genérico `i3`.

## Decisiones aprobadas

- Mejorar `i3.nix` en lugar de duplicarlo.
- Iniciar mediante autologin de getty en `tty1` y `startx`.
- Mantener un escritorio completo pero portable.
- Reemplazar el fondo animado con una imagen estática administrada por `feh`.
- Declarar explícitamente Xorg Server y herramientas X11 necesarias.
- Usar `userName` para que el autologin funcione tanto para `osmarg` como para `jarq`.

## Arranque de sesión

`i3.nix` habilitará:

- `services.xserver.enable`;
- `services.xserver.windowManager.i3.enable`;
- `services.xserver.displayManager.startx.enable`;
- `services.xserver.displayManager.startx.generateScript`;
- `services.getty.autologinUser = userName`.

El inicio de Fish ejecutará `startx /etc/X11/xinit/xinitrc` solamente cuando:

- la terminal actual sea `/dev/tty1`;
- no exista `DISPLAY`;
- el shell sea una sesión de login.

El script Xinit generado por NixOS importará el entorno a systemd, iniciará la sesión i3 y limpiará los servicios gráficos al salir. Cerrar i3 debe devolver al usuario a TTY sin iniciar otra instancia recursiva.

Autologin implica que una persona con acceso físico obtiene la sesión local sin contraseña. Esta decisión es explícita.

## Xorg y paquetes base

El perfil declarará, directamente o mediante los módulos NixOS correspondientes:

- `xorg-server`;
- `xinit`;
- `xauth`;
- `xrdb`;
- `xrandr`;
- `xinput`;
- `xset`;
- `xsetroot`;
- `setxkbmap`.

Stack principal:

- `i3`, `i3lock-color`;
- `rofi`, `kitty`;
- `polybar`, `picom`;
- `dunst`;
- `feh`;
- `rofi-calc`, `clipmenu`;
- `arandr`, `xkill`.

Integración diaria:

- `networkmanagerapplet`, `blueman`;
- `pavucontrol`, `pamixer`, `playerctl`;
- `brightnessctl`;
- `udiskie`, `usbutils`;
- `flameshot`;
- `polkit_gnome`, `gnome-keyring`;
- `dex`, `xss-lock`;
- `xdg-utils`, portal GTK y herramientas MIME/desktop.

Los módulos comunes del sistema siguen aportando PipeWire, NetworkManager, Bluetooth, Kitty, Chromium y aplicaciones CLI. El perfil declarará las dependencias que sus dotfiles ejecutan para que el contrato del perfil sea visible y verificable.

## Servicios e integración de escritorio

El perfil habilitará:

- D-Bus;
- polkit y agente gráfico;
- GNOME Keyring con PAM para login;
- GVfs;
- UDisks2 y automontaje con Udiskie;
- power-profiles-daemon;
- UPower;
- dconf;
- portal GTK;
- terminal XDG predeterminado `kitty.desktop`.

Se conservará Nautilus como gestor de archivos y Chromium como navegador porque ya forman parte de la configuración común. Los MIME defaults mínimos cubrirán directorios, texto, PDF, imágenes y HTTP/HTTPS con aplicaciones realmente disponibles.

## Dotfiles i3

Se conservarán las rutas de `dotfiles/config/profiles/i3` administradas por `nixos/common-dotfiles.nix`:

- `.config/i3`;
- `.config/polybar`;
- `.config/picom`;
- `.config/rofi`;
- `.config/dunst`;
- `.config/conky`.

Cambios requeridos:

1. Rofi usará Kitty como terminal, no WezTerm.
2. i3 iniciará Polybar mediante un lanzador idempotente, evitando barras duplicadas al recargar.
3. Picom y Dunst seguirán iniciando una sola vez.
4. `xss-lock` bloqueará la sesión al suspender.
5. Los atajos de volumen usarán una herramienta declarada, preferiblemente `pamixer`.
6. El fondo se seleccionará desde imágenes disponibles en `~/.config/wallpapers` y se aplicará con `feh`.
7. Se eliminará el arranque obligatorio de `~/Videos/wallpapers/1.mp4`.

## Helpers de Polybar

Los botones existentes no deben llamar comandos inexistentes. Se agregarán helpers de perfil y se registrarán en `profileSpecificPaths`:

- `i3-hotkeys`: muestra ayuda de atajos mediante Rofi;
- `i3-wallpaper-random`: elige una imagen compatible y la aplica con Feh;
- `i3-powermenu`: ofrece bloquear, suspender, reiniciar, apagar y salir de i3;
- `i3-polybar-launch`: reinicia Polybar de forma idempotente.

Los helpers deben fallar con mensajes claros si no hay imágenes o si falta un comando, sin terminar la sesión i3.

## Paridad diaria con helpers de Hyprland

Hyprland dispone de aproximadamente 45 helpers. i3 no copiará ciegamente los que dependen de `hyprctl`, Wayland, Waybar, Hyprpaper, Hyprlock o plugins de Hyprland. Cada función diaria tendrá un helper `i3-*` o un programa X11 equivalente.

| Función Hyprland | Equivalente i3 aprobado |
| --- | --- |
| Lanzador de aplicaciones | Rofi `drun` / `i3-app-launcher` |
| Selector de ventanas | Rofi `window` / `i3-window-switcher` |
| Buscar y abrir archivos | Helpers `i3-open-file`, `i3-open-file-dir` e `i3-open-file-terminal` |
| Calculadora | `rofi-calc` mediante `i3-calc` |
| Historial del portapapeles | `clipmenud` + `clipmenu` mediante `i3-clipboard` |
| Selector de hosts SSH | `i3-ssh-host` con Rofi y Kitty |
| Menú principal | `i3-main-menu` como agregador de acciones diarias |
| Energía y sesión | `i3-powermenu` |
| Perfiles de energía | `i3-performance-menu` con `powerprofilesctl` cuando esté disponible |
| Wi-Fi | `nm-applet`/`nm-connection-editor`; helper Rofi solo si aporta acciones no cubiertas |
| Bluetooth | `blueman-applet`/`blueman-manager` |
| Dispositivos de audio | `pavucontrol` |
| USB y automontaje | `udiskie`, UDisks2 y Nautilus |
| Pantallas | `arandr` y `xrandr`, sin depender de `hyprctl` |
| Layout de teclado | `i3-keyboard-menu` + `setxkbmap` |
| Fondo actual/aleatorio | `feh` + `i3-wallpaper-random` |
| Ayuda de atajos | `i3-hotkeys` |
| Edición de configuración | `i3-config-editor` |
| Cerrar ventana seleccionada | `xkill` o criterio i3 equivalente |
| Pi prompt | Kitty ejecutando `pi`; helper solo si necesita entrada Rofi |

Los scripts genéricos de Hyprland pueden servir como referencia de comportamiento, pero i3 no llamará ejecutables con prefijo `hypr-`. Si lógica reutilizable merece compartirse, se extraerá a un helper neutral y ambos perfiles usarán wrappers propios.

No requieren paridad i3: transiciones de Hyprland, `hypr-nwg-dock`, plugins/grupos Hyprland, controles Hyprpaper, acciones Waybar, `hyprctl` workspace/focus y herramientas puramente Wayland. i3 ofrecerá sus operaciones nativas para workspace, foco, movimiento, fullscreen, scratchpad y layout.

## Portabilidad de Polybar

La configuración actual contiene tres supuestos no portables:

- batería fija `BAT0`;
- GPU exclusivamente NVIDIA;
- CPU fija en `thermal-zone = 0`.

La barra revisada no mostrará errores en equipos sin batería, sin NVIDIA o con otra topología térmica. Los módulos dependientes de hardware usarán detección segura o helpers que produzcan salida vacía cuando el dispositivo no exista. Como mínimo:

- escritorio sin batería: módulo oculto;
- portátil con batería cuyo nombre no sea `BAT0`: detección automática;
- NVIDIA: temperatura vía `nvidia-smi` si está disponible;
- Intel/AMD o sensor ausente: salida alternativa segura o módulo oculto;
- temperatura CPU: búsqueda de sensor disponible, sin asumir índice fijo.

## Matriz de hosts

`flake.nix` ya expone el perfil i3 para los cuatro hosts. La implementación conservará y verificará:

| Output | Usuario | Hardware adicional |
| --- | --- | --- |
| `orgm-i3` | `osmarg` | NVIDIA, placa orgm, gaming |
| `lenovo-i3` | `osmarg` | portátil Lenovo, audio, gaming |
| `ero-i3` | `osmarg` | Intel |
| `jarq-i3` | `jarq` | Intel, módulo jarq |

No se cambiarán los perfiles predeterminados sin una petición separada.

## Validación

Pruebas estructurales deben comprobar:

- todos los outputs `*-i3` siguen existiendo y apuntan a `i3.nix`;
- `userName` controla autologin;
- startx y su script generado están habilitados;
- Xorg Server, i3, Rofi, Kitty, Polybar, Picom y helpers aparecen en el cierre apropiado;
- cada comando llamado por i3/Polybar tiene paquete o helper correspondiente;
- las funciones diarias de Hyprland tienen helper `i3-*` o programa X11 equivalente documentado;
- ningún atajo/configuración i3 ejecuta un helper con prefijo `hypr-`;
- `rofi-calc`, `clipmenu`, `arandr` y `xkill` están disponibles;
- no quedan referencias a WezTerm ni al MP4 fijo;
- scripts manejan falta de batería, GPU, sensores e imágenes.

Validación Nix:

```bash
nix eval .#nixosConfigurations.orgm-i3.config.services.xserver.enable
nix eval .#nixosConfigurations.orgm-i3.config.services.xserver.displayManager.startx.enable
nix eval .#nixosConfigurations.orgm-i3.config.services.getty.autologinUser --raw
nix eval .#nixosConfigurations.jarq-i3.config.services.getty.autologinUser --raw
nix build .#nixosConfigurations.orgm-i3.config.system.build.toplevel --no-link
nix build .#nixosConfigurations.lenovo-i3.config.system.build.toplevel --no-link
nix build .#nixosConfigurations.ero-i3.config.system.build.toplevel --no-link
nix build .#nixosConfigurations.jarq-i3.config.system.build.toplevel --no-link
```

También se ejecutarán diagnósticos Nix/LSP y las pruebas existentes del repositorio.

## Fuera de alcance

- Cambiar el perfil predeterminado de un host a i3.
- Crear un perfil `i3-full` o `i3-any` separado.
- Mantener fondos animados obligatorios.
- Añadir un display manager gráfico.
- Rediseñar visualmente Polybar, Rofi o Picom más allá de corregir portabilidad y referencias rotas.
