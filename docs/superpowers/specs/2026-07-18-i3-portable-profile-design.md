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

- `xorg.xorgserver`;
- `xorg.xinit`;
- `xorg.xauth`;
- `xorg.xrdb`;
- `xorg.xrandr`;
- `xorg.xinput`;
- `xorg.xset`;
- `xorg.xsetroot`;
- `xorg.setxkbmap`.

Stack principal:

- `i3`, `i3lock-color`;
- `rofi`, `kitty`;
- `polybar`, `picom`;
- `dunst`;
- `feh`.

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
