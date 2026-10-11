# Lenovo: server, Windows y monitor externo

El modo `server` es la entrada predeterminada de cada nueva generación de
Lenovo. Arranca en `multi-user.target`, sin escritorio ni login automático;
mantiene SSH y NetworkManager. Las otras entradas siguen disponibles.
El hook de instalación actualiza `loader.conf` y la selección persistente de
EFI; una selección antigua en EFI no debe prevalecer sobre el modo server.

El orden del menú es `server`, `windows-vfio`, normal, `gaming` y `battery`.
Solo `server` y `windows-vfio` reservan la NVIDIA T500 mediante VFIO y usan
Intel para el host. Normal y gaming conservan PRIME; battery conserva NVIDIA
deshabilitada y el gobernador de ahorro. `lenovo-terminal` conserva su GPU.

`osmarg` tiene `linger` y el servicio de usuario `lenovo-windows-autostart`
arranca con `default.target`, sin login. En server/windows arranca el contenedor
Podman existente `lenovo-windows`. En los demás modos arranca `windows`, sin
passthrough. Si ese runtime todavía no existe, lo crea al arrancar ese modo
utilizando la imagen local de Windows y el mismo disco y `.env`, con acceso a
`/dev/dri`. No recrea un contenedor existente ni tiene `ExecStop`. Si ya corre,
no actúa. Si el runtime del otro perfil está activo, rechaza el arranque para
proteger el disco compartido, sin detenerlo. No se ejecuta Compose durante la
preparación o instalación de boot; solamente en el futuro arranque sin VFIO.
Los fallos de arranque se reintentan cada 15 segundos; un runtime VFIO borrado
requiere restaurarse manualmente. El servicio no vigila ni reinicia Windows
después de un apagado manual. El helper `windows-rdp` usa Podman en ambos tipos
de perfil Lenovo, incluso cuando Ryoku también instala Docker.
El autoinicio utiliza el paquete Podman configurado por NixOS, que incluye
los wrappers de `newuidmap` y `newgidmap` necesarios en un servicio rootless.
Un error de Podman al consultar el contenedor aborta el intento; no se confunde
con un contenedor ausente ni provoca la creación de otro runtime.

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
