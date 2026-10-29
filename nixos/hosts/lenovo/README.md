# Lenovo: server, Windows y monitor externo

`lenovo-server` es una configuración independiente de consola, sin Ryoku ni
sus especializaciones de escritorio. Conserva el servidor SSH, Tailscale,
Syncthing, [Nextcloud](../../apps/nextcloud-server.md), Podman y Windows con
VFIO. El usuario y las rutas de datos existentes siguen siendo los mismos.
La configuración `lenovo` conserva el escritorio y sus modos anteriores.
Al instalar `lenovo-server` con `boot`, su entrada se convierte en la
predeterminada; las generaciones anteriores siguen disponibles como respaldo
hasta que las retire la política de generaciones. Los atajos de Lenovo
`os`, `osboot` y `osb` apuntan a `lenovo-server`.

El modo `server` es la entrada predeterminada de cada nueva generación de
Lenovo. Arranca en `multi-user.target`, sin escritorio ni login automático;
mantiene SSH y NetworkManager. Las otras entradas siguen disponibles.
El hook de instalación actualiza `loader.conf` y la selección persistente de
EFI; una selección antigua en EFI no debe prevalecer sobre el modo server.

El orden del menú es `server`, `windows-vfio`, normal, `gaming` y `battery`.
Solo `server` y `windows-vfio` reservan la NVIDIA T500 mediante VFIO y usan
Intel para el host. Normal y gaming conservan PRIME; battery conserva NVIDIA
deshabilitada y el gobernador de ahorro. `lenovo-terminal` conserva su GPU.

El controlador público es **`windows-vm`**, compartido con Envy pero con política
Lenovo propia. [Interfaz, provisión y migración](../../../docs/windows-vm.md).
`windows-rdp` se encarga del acceso web/RDP/Looking Glass y delega el ciclo de vida:
no borra el runtime alternativo, construye imágenes ni fija un grupo VFIO.

`osmarg` conserva `linger` y `lenovo-windows-autostart` con `default.target`, sin
login. La unidad ahora usa el supervisor común de vida completa: en server/windows
selecciona `lenovo-windows`; en los demás modos, `windows` con render Intel.
Adopta los contenedores existentes cuyo disco coincida con el `.env` privado.
Nunca borra ni recrea un runtime existente, y rechaza cualquier otro contenedor
activo que monte el disco compartido. Si un runtime falta, requiere imagen
preparada, credenciales privadas y disco Windows existente antes de crearlo.
Los dispositivos VFIO se derivan de la identidad de la T500 y su grupo actual,
no de `/dev/vfio/16`. Un runtime antiguo con dispositivos obsoletos requiere
revisión manual, no una recreación automática.

`windows-vm prepare-image` es la provisión explícita de SPICE sobre una base
fijada. Un `start` nunca construye ni descarga imágenes contenedor. No se ejecuta
Compose, construye una imagen ni arranca una VM al preparar/instalar boot.
La unidad conserva los wrappers rootless, reintenta fallos cada 15 segundos y
no reinicia Windows después de un apagado limpio manual. Al detenerla solicita
apagado limpio, sin force-kill; el apagado del host puede esperar si el huésped
no responde. Un error del motor nunca se interpreta como contenedor ausente.

```sh
windows-vm status
windows-vm preflight
windows-vm start
windows-vm stop
windows-rdp web
windows-rdp looking-glass # solo en VFIO, con Host compatible dentro de Windows
```

El kernel carga i915 temprano y desactiva el panel roto con `video=eDP-1:d`;
esto también se aplica a la consola del modo server. El escritorio mantiene
la detección de monitores y las configuraciones personales. No se fija un
conector HDMI/DP ni una resolución. En Ryoku los ajustes están en Hub > Displays.

`lenovo-external-monitor --status` muestra conectores y parámetros de arranque.
`lenovo-external-monitor --apply` selecciona una salida externa y desactiva el
panel interno mediante la API de Ryoku, Hyprland, XRandR o wlr-randr, según la
sesión. No reinicia la sesión ni cambia de TTY. Sin escritorio, la política de
consola se aplica al arrancar el kernel; el helper no fuerza cambios DRM.

Para instalar únicamente el próximo arranque, conservando la sesión actual y
Windows activo:

```bash
sudo nixos-rebuild boot --flake path:/home/osmarg/Hobby/nixos#lenovo-ryoku
```

No usar `switch` para desplegar esta transición mientras se trabaja en Windows.
La instalación de boot no activa servicios ni cambia la GPU en uso. El modo
server y la política del kernel deben verificarse después de un reinicio
decidido por el usuario, con la pantalla externa conectada.
