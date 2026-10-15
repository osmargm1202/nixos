# Envy: fase normal

HP ENVY 17m-ce1xxx, i7-10510U, 12 GiB RAM, Intel UHD y NVIDIA MX250 Pascal.

## Configuración activa

`envy`, `envy-normal` y `envy-ryoku` seleccionan el mismo escritorio Ryoku
de `osmarg`, con sus preferencias y aplicaciones compartidas. Esta fase NO
configura VM Windows, VFIO, especializaciones server o gaming. El menú de
arranque está fijado a 1 segundo por preferencia explícita del usuario.

Kernel 6.12 LTS, NVIDIA propietario `legacy_580`, Intel para escritorio y
`nvidia-offload programa` para GPU discreta. No se promete apagado completo de
la MX250: Pascal no admite el ahorro RTD3 fino de generaciones posteriores.

SSD principal serial `PHTE9395032P512B-1`: EFI de 1 GiB y Btrfs `ENVY_ROOT`
con subvolúmenes `@root`, `@home`, `@nix`, `@log`, `@windows`. El último queda
vacío, reservado, sin Windows instalado. Discos VM futuros se crearán sin CoW.
Se usa zram del 50% de RAM, no Optane como swap ni hibernación.

## Pantalla fantasma detectada

Con solo el panel interno conectado, el kernel presenta además `DP-1` como
conectado, sin EDID, a 800×600. Ryoku asignaba allí el workspace2 y el cursor.
El seed exclusivo de envy `.config/orgm-ryoku/monitors_user.lua` desactiva esa
salida; la preparación lo instala como `~/.config/hypr/monitors_user.lua` solo
si no hay override personal. No desactiva eDP ni los otros conectores.
Si un monitor real utiliza DP-1 más adelante, retirar la regla del override
personal y revisar el seed declarado, recargar Hyprland y probar ese puerto.

## Optane: pendiente, NO modificar

El Intel H10 contiene NAND y Optane en una misma tarjeta. Linux detecta el
Optane como `/dev/nvme1n1`, 27,3 GiB, serial `PHTE9395032P512B-2`; conserva
datos BitLocker. El usuario autorizó borrar solamente el SSD principal.

Podría estudiarse su uso independiente como swap de menor prioridad que zram,
previa autorización y prueba; no añade RAM física ni sustituye una ampliación.
Tampoco sería un backup independiente frente al fallo de la tarjeta H10.
La aceleración Intel RST/Optane de Windows no es una función soportada en Linux:
https://www.intel.com/content/www/us/en/support/articles/000056875/memory-and-storage/intel-optane-memory.html
Zram: https://docs.kernel.org/admin-guide/blockdev/zram.html

## Instalación y acceso

`prepare-disk.sh --check` solo inspecciona. `--format --confirm
PHTE9395032P512B-1` destruye SOLO el SSD autorizado, comprueba serial y montajes,
y monta el sistema bajo `/mnt`. No ejecutar en el sistema instalado.

El instalador conserva la conexión Wi-Fi fuera del repositorio y establece una
contraseña inicial privada en shadow; no hay contraseñas en Nix/Store/Git.
SSH: `osmarg@envy` o la IP DHCP, por la clave pública autorizada. Root SSH está
deshabilitado. Cambiar la contraseña inicial con `passwd`.

Repositorio completo en `/home/osmarg/Hobby/nixos`; reconstruir con
`sudo nixos-rebuild switch --flake /home/osmarg/Hobby/nixos#envy`.
Si el usuario mueve el repo o publica cambios, conservar sus modificaciones
preexistentes; no dar por hecho que todo está ya enviado al remoto.

Nextcloud, Tailscale, cuentas y secretos SOPS necesitan sus identidades/login;
no copiar claves privadas indiscriminadamente. Una integración pendiente no
debe confundirse con un fallo de Wi-Fi o de los controladores del hardware.

## Pruebas de hardware tras arrancar

- Arranque: `findmnt / /home /nix /var/log /boot`; `swapon --show`; `systemctl --failed`.
- Wi-Fi/red: `nmcli device`; `ip route`; `resolvectl query nixos.org`; probar Ethernet con cable.
- GPU: `lspci -nnk`; `nvidia-smi`; `vulkaninfo --summary`; `nvidia-offload vulkaninfo --summary`.
- Escritorio: `hyprctl monitors all`; `glxinfo -B`; `nvidia-offload glxinfo -B` dentro de sesión gráfica.
- Pantallas: probar pantalla integrada, brillo, HDMI/DP/USB-C disponibles, hotplug y suspensión/reanudación.
- Sonido: `wpctl status`; probar parlantes, auriculares, micrófono y audio de monitor; HDMI no probado solo por enumerarlo.
- USB/Bluetooth/cámara: `lsusb -t`; `bluetoothctl list`; `v4l2-ctl --list-devices`; probar cada puerto y cámara físicamente.
- SSD/RAM: `sudo smartctl -a /dev/nvme0n1`; `free -h`; `zramctl`. No medir rendimiento con escrituras destructivas.
- Batería/temperaturas: `upower -d`; `powerprofilesctl`; uso normal, ventilador, batería y cierre de tapa.

No declarar puertos, parlantes, micrófono o suspensión probados sin intervención
física. El informe de instalación distingue enumeración, pruebas por software y
pruebas pendientes del usuario.

## Hoja de ruta preservada

Diseño completo: `docs/superpowers/specs/2026-10-15-envy-design.md`.
Plan fase normal: `docs/superpowers/plans/2026-10-15-envy-normal.md`.
Tras validar la base: gaming, Windows render virtual/Pascal, VFIO e IOMMU,
server y Compose por host declarativo. No activarlos hasta esa segunda fase.
