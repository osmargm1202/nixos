# Envy: configuración única y modos internos

HP ENVY 17m-ce1xxx, i7-10510U, 12 GiB RAM, Intel UHD y NVIDIA MX250 Pascal.

## Configuración activa

`envy` es la única salida pública de este host y conserva Ryoku de `osmarg`
mientras se prueba `orgm-dot`, con sus preferencias y aplicaciones compartidas. Las fuentes preparan
normal (base), gaming, windows-vfio y server; **todavía no desplegados**.
Normal conserva Steam y emuladores. Sunshine se reserva para ORGM. El menú de
arranque está fijado a 1 segundo por preferencia explícita del usuario.

Kernel seleccionado por el usuario: 6.12 LTS actualizado, NVIDIA propietario
`legacy_580`, Intel para escritorio y
`nvidia-offload programa` para GPU discreta. No se promete apagado completo de
la MX250: Pascal no admite el ahorro RTD3 fino de generaciones posteriores.
La rama de modos evaluó 6.18 como candidato, pero se conserva la elección de
6.12 LTS. El render NVIDIA de Windows requiere kernel >=6.16; su preflight
rechaza iniciarlo en 6.12. No se cambia el kernel ni se omite ese control.

SSD principal serial `PHTE9395032P512B-1`: EFI de 1 GiB y Btrfs `ENVY_ROOT`
con subvolúmenes `@root`, `@home`, `@nix`, `@log`, `@windows`. El último queda
vacío, reservado, sin Windows instalado. Discos VM futuros se crearán sin CoW.
Se usa zram del 50% de RAM, no Optane como swap ni hibernación.

## Pantalla fantasma detectada

Con solo el panel interno conectado, el kernel presenta además `DP-1` como
conectado, sin EDID, a 800×600. Ryoku asignaba allí el workspace2 y el cursor.
El seed exclusivo de Envy `.config/orgm-ryoku/monitors_user.lua` desactiva esa
salida. Se copia desde el checkout y la preparación de Ryoku lo instala solo
si no hay override personal en `~/.config/hypr/monitors_user.lua`. Mantiene eDP
y los otros conectores; el Hub conserva el control del layout.

## Dotfiles y escritorio

`orgm-dot` migra los enlaces antiguos a copias editables con respaldo en
`~/.local/state/orgm-dot/backups/`. Las reconstrucciones posteriores respetan
las ediciones locales; `diff`, `pull` y `push` trabajan por aplicación. `ryoku-hub`
permite guardar los ajustes `desktop.json` y `shell.json` del Hub sin copiar su
runtime completo. Véase [la guía](../../../dotfiles/README.md).

Envy mantiene Ryoku; esta migración no cambia el escritorio ni sustituye sus
configuraciones por las de Hyprland. El perfil Hyprland alternativo queda
preparado con Hyprland, portal, Waybar, nwg-dock y mpvpaper oficiales de NixOS.
El cambio de escritorio queda pendiente de la decisión del usuario. Véase
[el perfil Hyprland](../../profiles/hyprland/README.md).

## Plugins y huella

El cierre observado el 17 de octubre dejó un callback de Image borders activo
tras descargar el plugin; el watchdog arrancó Hyprland con `--safe-mode`.
Se corrigió la retirada de callbacks en Image borders y Glass en el perfil
Ryoku compartido de Envy, Lenovo y ORGM.

`fprintd` sigue habilitado. El lector USB de este equipo es Synaptics
`06cb:00c9`: `fprintd-list osmarg` responde `No devices available` con el
controlador instalado. No figura en la
[lista de dispositivos de libfprint](https://fprint.freedesktop.org/supported-devices.html).
Existe un [controlador experimental](https://github.com/vojtapl/synaTudorMiS)
que incluye ese ID, pero no está integrado aquí: requiere cambios adicionales
en libfprint/fprintd y su autor advierte de incompatibilidad con el emparejamiento
de Windows. El desbloqueo por huella de este lector queda pendiente de un
controlador validado; instalar o activar el servicio no basta.

## Estado de salidas externas (2026-10-15)

Con solo USB-C conectado, LG ULTRAGEAR detectada en `DP-2`, activa a
2560×1440 ~144Hz y escala1, junto a eDP escala1,25; sin errores de Ryoku.
Imagen confirmada por el usuario, con contenido cortado en cualquier ventana;
el usuario decidió posponer ese diagnóstico. Retirada y reanudación estable pendientes. HDMI solo no
identifica la LG, incluso tras reajustar el cable y seleccionar entrada HDMI.
El usuario también reporta parpadeo al despertar: servicios de resume correctos
no prueban una reanudación visual correcta. Causa aún sin determinar;
no modificar drivers basándose únicamente en estos síntomas.

## Memoria de incidencias abiertas

Ver [PENDING.md](PENDING.md): **ENVY-DISPLAY-001** conserva el parpadeo y apagado
tras lock/sleep, el recorte de contenido en la LG y la validación de HDMI, junto
con la evidencia y criterios pendientes. Incluye los controles existentes para
extender/duplicar monitores. No están resueltos ni se cambian políticas de
pantalla, suspensión o bloqueo mediante esta documentación.

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

Envy usa Online Accounts/GVfs en lugar del cliente de sincronización Nextcloud.
Ryoku controla la UI de red, Bluetooth y audio; Tailscale y Syncthing siguen
conectados mediante sus servicios, sin lanzar sus bandejas.
Tailscale, Syncthing, cuentas y secretos SOPS necesitan sus identidades/login;
no copiar claves privadas indiscriminadamente. Una integración pendiente no
debe confundirse con un fallo de Wi-Fi o de los controladores del hardware.

## Pruebas de hardware tras arrancar

- Arranque: comprobar cada montaje con el loop de abajo; `swapon --show`; `systemctl --failed`.
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
Tras validar la base: perfil gaming dedicado, Windows render virtual/Pascal,
VFIO e IOMMU, server y Compose por host declarativo. Las aplicaciones de juegos
ya pertenecen a normal. Los modos avanzados están preparados sin activación;
ver el informe de entrega enlazado más abajo.

## Juegos en normal

Steam, GameMode, MangoHud, Gamescope y ProtonUp-Qt; emuladores declarados vía
Flathub. Sunshine solo se habilita en ORGM. Intel sigue renderizando el escritorio;
Steam configura PRIME para sus juegos y `nvidia-game programa` invoca
`nvidia-offload`, rechazando fallback silencioso si falta el helper. No hay
autologin GamescopeTTY1 en normal; solo gaming lo habilita. Instalar las
aplicaciones no instala juegos/ROMs ni inicia sesión en Steam por el usuario.
Los emuladores pueden seguir descargándose por `flatpak-managed-install`.

## Puertas de instalación y recuperación

1. Antes de formatear: verificar inventario, serial exacto, backups privados de
   metadatos y autorización del SSD. Si ya está instalado, NO repetir el formato.
2. Provisión privada separada del repo: conexión NetworkManager persistente,
   clave pública autorizada y contraseña de usuario por canal acordado. No
   sobrescribir credenciales existentes al reanudar; no poner secretos en Nix.
3. Antes de reiniciar: sistema construido/copiadovalidado, contraseña probada,
   repositorio presente, EFI/default/timeout revisados y acceso remoto preparado.
4. Después: comparar sistema real con el cierre construido, comprobar red/SSH,
   login gráfico, monitores/workspaces y servicios; mantener una generación
   anterior como recuperación. Generación anterior no es copia de tus datos.
5. SOPS es opcional hasta que Osmarg aporte su identidad: no trasladar claves ni
   bloquear esta fase esperando el archivo. Su fallo puede dejar HomeManager
   parcialmente activado; revisar y completar cuando el usuario lo suministre.
6. Verificar las aplicaciones Flatpak aparte del arranque del sistema.

```bash
for m in / /home /nix /var/log /var/lib/windows /boot; do
  findmnt -M "$m" || break
done
```

## Recuperación local Btrfs

Snapper programa snapshots diarios de `/` y `/home`, retiene hasta 7 diarios por
configuración y hasta 3 manuales si se crean con `--cleanup-algorithm number`.
No hay buckets horarios/semanales/mensuales ni snapshots automáticos por boot.
Los snapshots son no recursivos: `/nix`, `/var/log`, `/var/lib/windows` y `/boot`
no forman parte de esas copias. No se crea swap ni se utiliza Optane.

El servicio `envy-prepare-snapshots` verifica ambos puntos de montaje Btrfs,
rechaza rutas existentes inseguras y prepara `/.snapshots` y `/home/.snapshots`
con propietario root y modo 0700. Snapper espera su preparación satisfactoria.

```bash
sudo snapper -c root list
sudo snapper -c home list
systemctl status snapper-timeline.timer snapper-cleanup.timer
```

Para recuperar un archivo de home: inspeccionar con sudo
`/home/.snapshots/ID/snapshot/osmarg/`, copiar a un destino NUEVO y comprobar
contenido/propietario antes de reemplazar el original. No usar `snapper rollback`
como si restaurara automáticamente el arranque: NixOS usa generaciones y el
fstab fija `@root`; EFI/Nix están fuera de estos snapshots.

Retención se aplica por cleanup, no es una cuota instantánea ni garantiza espacio
libre. Vigilar espacio, sobre todo tras descargar/borrar juegos grandes. No son
backup independiente ante fallo/robo del SSD; el respaldo externo necesita un
destino acordado. Los snapshots pueden conservar archivos privados hasta que
expire su retención, aunque se borren en el sistema activo.

## Inicio: menú y Num Lock

Menú systemd-boot declarado a1segundo y comprobado en loader.conf del sistema
activo. Hyprland ya tiene numlock_by_default=true tanto en teclado como ajustes;
estado de teclados comprobado encendido. SDDM se encontró con Numlock=none;
ahora el host declara autoNumlock=true y General.Numlock=on, con contrato Nix
RED/GREEN. Esta modificación aún NO se ha desplegado ni se ha reiniciado SDDM;
el greeter activo no se declara corregido hasta aplicar y comprobar un login.

Los modos avanzados futuros pertenecen a specialisations dentro de `envy`, no
a salidas flake independientes; pueden validarse con eval/build --no-link sin
switch/test/boot. Ya están preparados y autorizados como fuentes: no se ha
aplicado ningún cambio vivo. Normal continúa predeterminado; instalar entradas
en el menú requiere la acción posterior del usuario. Windows/server arrancan
la VM solo si existen imagen, contraseña y hardware elegible.


## Volumen inicial de audio y micrófono

`audio.nix` declara **150%** para las rutas nuevas de entrada/salida de la tarjeta
integrada PCI00:1f.3. Se usa la propiedad nativa por dispositivo de WirePlumber:
la ganancia lineal3.375 corresponde a1.5³, es decir150% en wpctl/PulseAudio.
No usar1.5 como ganancia lineal ni una configuración global limitada a1.0.

Los volúmenes, balance y mute que guarde el usuario tienen prioridad. No hay
servicio que vuelva a imponer150% en cada login/reconexión, ni se borra el estado.
La primera aplicación también ajusta las dos rutas predeterminadas actuales;
USB/Bluetooth u otras preferencias existentes no se amplifican automáticamente.

150% puede saturar/distorsionar, especialmente el micrófono. Es un valor inicial
solicitado, no una mejora de calidad ni garantía de nivel acústico. Se puede
reducir desde Ryoku/Pavucontrol. Prueba `tests/envy-audio-policy.bats.sh` verifica
la configuración y ejecuta el consumidor de rutas real de WirePlumber fijado.

Referencia: [WirePlumber: defaults de rutas y propiedades por dispositivo](https://pipewire.pages.freedesktop.org/wireplumber/daemon/configuration/settings.html).

El límite del control de Ryoku es independiente del nivel de PipeWire:
`orgm-ryoku/audio-defaults.json` habilita inicialmente `qsbar.audioBoost` en
`shell.json` mediante migración única bloqueada y respaldada. Así el deslizador
qsbar y `ryoku-volume` admiten150%; sin ese indicador las teclas vuelven a100%.
Las elecciones posteriores del Hub se respetan, sin forzar el toggle cada rebuild.


## Windows y modos avanzados: entrega sin despliegue

Informe y procedimiento completo: [2026-10-17-envy-modes](../../../docs/superpowers/reports/2026-10-17-envy-modes.md).

| Entrada | Sesión | MX250 | Windows |
|---|---|---|---|
| normal (base) | Ryoku/Intel | PRIME | Render virtual manual |
| gaming | Gamescope/Steam TTY1 | NVIDIA para juegos | Bloqueado |
| windows-vfio | Ryoku/Intel | VFIO | Automático condicionado |
| server | Consola/SSH, sin DM/WM | VFIO | Automático condicionado |

Un solo `envy-windows`, disco en `/var/lib/windows/storage`; Compose declarado en
`nixos/containers/windows/hosts/envy/`, publicado como referencia inmutable en
`~/Apps/windows/envy/`. **No lanzar compose directamente**: el controlador aplica
las guardas y el bloqueo de vida completa. No se ha creado ni descargado una VM.

```sh
envy-windows status
envy-windows preflight
envy-windows start   # manual en normal, prohibido en gaming
envy-windows stop    # espera apagado limpio; nunca fuerza kill
journalctl --user -u envy-windows --no-pager
windows-rdp connect # conserva selector RDP/web y credenciales específicas de Envy
```

Asignaciones declarativas en `orgm.envy.windows`: memoryMiB=4096, cpus=4,
diskGiB=96, vramMiB=1024, con rangos validados por Nix (VRAM potencia de dos). Redimensionar una imagen
existente no se promete por editar diskGiB. No modificar credenciales existentes
para ajustar recursos. Los cambios públicos quedan pendientes mientras la VM
esté activa; se reconcilian en su próximo inicio detenido, sin borrar el disco.
