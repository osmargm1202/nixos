# Instalación de ORGMOS en NixOS

El instalador es `install.sh` en la raíz del repositorio. El archivo descargado
puede llamarse `/tmp/orgm-install.sh`; ese nombre local no cambia la URL de origen.
Para Ubuntu/Debian o Arch y solo dotfiles, usar `server/install.sh`.

## Publicación

Publicar el instalador y los módulos actuales del repositorio en `master` antes
de probarlo desde otro equipo. Configurar una redirección HTTPS exacta:

```text
Host: nixos.or-gm.com
Path: /install
Status: 302 o 307
Location: https://raw.githubusercontent.com/osmargm1202/nixos/master/install.sh
```

Verificar que la descarga final devuelve HTTP 200 y contiene Bash:

```bash
curl -fL https://nixos.or-gm.com/install -o /tmp/orgm-install.sh
bash -n /tmp/orgm-install.sh
bash /tmp/orgm-install.sh --help
```

## Instalar desde una ISO

Arrancar una ISO NixOS x86_64 con conexión a Internet. Para UEFI, arrancar la ISO
en modo UEFI. Ejecutar el archivo descargado:

```bash
bash /tmp/orgm-install.sh --install
```

El instalador permite borrar un disco completo o utilizar particiones ya montadas.
El particionado automático crea 1 GiB de arranque y el resto como raíz ext4,
sin swap ni cifrado. Rechaza discos con particiones montadas o swap activo y exige
escribir la ruta exacta del disco antes de borrarlo. En UEFI utiliza FAT32 y
systemd-boot; en BIOS utiliza una tabla MBR, `/boot` ext4 y GRUB.

Para conservar particiones existentes o preparar cifrado LUKS, montarlas primero
en `/mnt` y `/mnt/boot`, y elegir usar los montajes existentes. El instalador genera
`hardware-configuration.nix` si falta y conserva uno existente, incluidas sus
declaraciones LUKS. La raíz de destino debe ser distinta del sistema en ejecución.
Se puede cambiar el destino con `--root /ruta/de/montaje`.

Después se elige perfil, configuración de usuario (`osmarg` o `jarq`) y hostname.
Los perfiles de escritorio también eligen GPU y kernel. Los perfiles disponibles
son Hyprland, labwc, i3, Cinnamon, GNOME, Ryoku, server y terminal. Ryoku por ahora
solo admite la configuración personal de `osmarg`. Las aplicaciones y
dotfiles dependen de la configuración de usuario elegida; añadir otra requiere
un módulo en `nixos/users` y actualizar el menú.

El instalador muestra el flake y pide confirmar su escritura, con respaldo del
flake y lockfile anteriores. Actualiza el input `orgmos` para evitar reutilizar
una revisión obsoleta del repositorio y evalúa la configuración antes de ejecutar `nixos-install`.
La instalación pide la contraseña de root y después establece la del usuario
elegido mediante `nixos-enter`. No reinicia automáticamente.

Si se decide ejecutar manualmente el comando de instalación mostrado, establecer
también la contraseña del usuario antes de reiniciar, por ejemplo:

```bash
sudo nixos-enter --root /mnt --command 'passwd osmarg'
```

La partición EFI debe tener espacio para las generaciones de arranque. El flujo
no configura Secure Boot ni enrola claves TPM.

## Reconfigurar un NixOS instalado

```bash
bash /tmp/orgm-install.sh --rebuild --dry-run
bash /tmp/orgm-install.sh --rebuild
```

`--rebuild` nunca ofrece particionar. Utiliza la configuración de hardware local,
respalda el flake anterior y aplica el perfil con `nixos-rebuild switch` si se
confirma. No cambia el bootloader con opciones del instalador. El flake generado
apunta `nh` a la configuración local `#default` y utiliza `path:` para incluir
archivos aunque el directorio esté dentro de un checkout Git.

`--dry-run` requiere una configuración de hardware existente, muestra el flake
y el siguiente comando; no escribe archivos en el destino, no descarga módulos,
no particiona, no instala ni solicita privilegios. En una instalación nueva se
puede usar después de preparar los montajes y generar la configuración de hardware.

## Qué significa el cifrado de disco

LUKS cifra los datos de una partición. Sin una clave válida, retirar el disco y
conectarlo a otro equipo no permite leer su contenido cifrado. La contraseña LUKS
se solicita antes de iniciar el sistema y es independiente de la contraseña del
usuario. Con esa contraseña o una clave de recuperación se puede desbloquear el
disco en otro equipo compatible.

TPM2 permite vincular un método de desbloqueo al hardware y, mediante políticas,
al estado del arranque. Se debe conservar una contraseña o clave de recuperación
fuera del equipo para poder recuperar los datos si cambia o falla la placa.
El desbloqueo automático con TPM por sí solo no garantiza protección si roban
el equipo entero. Cuando el volumen ya está desbloqueado, el sistema puede leer
los datos; el cifrado no sustituye los permisos ni protege frente a malware con
acceso suficiente. Habitualmente `/boot` queda sin cifrar.

Referencias: [cifrado en NixOS](https://wiki.nixos.org/wiki/Full_Disk_Encryption)
y [documentación de systemd-cryptenroll](https://github.com/systemd/systemd/blob/main/man/systemd-cryptenroll.xml).

## Verificación local

```bash
bash tests/install-installer.bats.sh
```

Las pruebas usan directorios temporales y simulan instalación, arranque y cambios
de contraseña. No particionan discos ni cambian el sistema anfitrión. Una instalación
real y su primer arranque todavía deben verificarse en una máquina virtual o equipo
de destino.
