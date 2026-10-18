# Envy: instalar Windows por web y después usar Looking Glass

Envy usa únicamente Sway como escritorio, bajo la salida `envy`. Los modos
gaming, windows-vfio y server se conservan como especializaciones internas.

El controlador público es ahora **`windows-vm`**, con interfaz común para Envy y
Lenovo y reglas propias por host. `envy-windows`, usado en los ejemplos históricos
de esta guía, sigue funcionando como alias del mismo comando. Ver
[controlador común y compatibilidad](windows-vm.md).

## Configuración y límites

La fuente está en `nixos/hosts/envy/windows.nix`, `windows-runtime.py` y
`nixos/containers/windows/hosts/envy/compose*.yml`. Los enlaces de
`~/Apps/windows/envy/` son salidas de Home Manager: **no editarlos ni lanzar
Compose directamente**. `envy-windows` mantiene el bloqueo del disco y valida
la identidad, el grupo IOMMU y el reset de la MX250.

- Normal: renderer NVIDIA bajo demanda, sujeto a sus prerrequisitos de kernel.
  No es la ruta de Looking Glass.
- `windows-vfio`: Intel mantiene Linux; MX250 se reserva al huésped durante el
  arranque. Looking Glass y la consola web están disponibles en esta modalidad.
- `server`: la misma configuración VFIO, sin escritorio local. La consola web
  puede usarse con un túnel SSH; el cliente Looking Glass es de uso local.
- `gaming`: Windows bloqueado; no se carga kvmfr.

En VFIO se declaran kvmfr de **128 MiB**, permisos `kvm:0660`, IVSHMEM, ratón
relativo y teclado VirtIO, y SPICE para entrada/audio. Se conserva el controlador
USB que necesita el medio `setup.img` del instalador automático; solo se reemplaza
el ratón tablet mediante `MOUSE=virtio-mouse-pci`.

Los puertos publicados son exclusivamente loopback: web `8006`, RDP `3389`
TCP/UDP y SPICE `5901` TCP. SPICE no usa contraseña y debe permanecer local;
no publicarlo en `0.0.0.0` del host ni en la LAN. El enlace loopback no autentica
por sí mismo a otros usuarios locales.

Esto configura el host, **no certifica el passthrough físico de esta MX250**.
Si falla aislamiento/reset o no hay una salida de pantalla capturable en Windows,
no usar ACS override, rebind en caliente, ROM descargada ni resets forzados.

## 1. Instalar la generación NixOS

Construir/aplicar para el siguiente arranque desde este checkout, conservando la
salida única `envy`, cuyo escritorio es Sway:

```sh
cd /home/osmarg/Hobby/nixos
sudo nixos-rebuild boot --flake path:.#envy
```

Revisar las entradas con `bootctl list`. Reiniciar cuando se acuerde y elegir la
especialización **windows-vfio** de esa generación; no cambiar la propiedad de
la GPU en una sesión ya arrancada. Conservar una generación anterior funcional.

Mantener la provisión incompleta hasta revisar el hardware: Windows/server
intentan autoarrancar el servicio, pero fallan de forma conservadora sin imagen,
contraseña o dispositivos válidos. No crear la contraseña antes de esa revisión
si se quiere evitar un primer inicio automático.

Comprobar en VFIO, como el usuario normal:

```sh
lspci -nnk -s 02:00.0
ls -l /dev/kvm /dev/vfio /dev/kvmfr0
systemctl status envy-windows-storage.service --no-pager
envy-windows status
```

La MX250 debe estar en `vfio-pci`, no en NVIDIA. `/dev/kvmfr0` debe ser un
dispositivo de caracteres accesible por el usuario. No ejecutar la VM como root
para eludir permisos. `envy-windows preflight` valida los demás prerrequisitos y
no inicia Windows; sin provisión completa puede detenerse en imagen/contraseña.

## 2. Provisión explícita de la imagen

Como `osmarg`, **sin sudo**, y solo después de decidir descargar las imágenes:

```sh
podman pull --platform linux/amd64 docker.io/dockurr/windows@sha256:59f8bed19cfd49cf1701debe34f9df6311e61a4e2ae68aa9f41206e2184e31cc
envy-windows prepare-image
```

`prepare-image` usa un contexto inmutable en Nix con `FROM` fijado al digest
anterior y añade `qemu-system-modules-spice`. Usa `--pull=never`: primero debe
existir la imagen base. La instalación del paquete SPICE **sí requiere red**
(repositorios APT); no es una construcción totalmente reproducible de esos
paquetes. La etiqueta local incluye el hash de la receta, no el digest del
resultado OCI. No borra ni inicia huéspedes y no accede al disco de Windows.
Puede prepararse también en normal, antes de reiniciar a VFIO.

El inicio ordinario nunca construye/descarga imágenes contenedor por sí mismo.
No usar `Containerfile.spice` directamente: la receta histórica compartida tiene
un `FROM :latest` que el módulo Envy sustituye por la referencia fijada.

Crear por un canal privado `~/.config/envy-windows/password`: archivo real,
propietario `osmarg`, modo `0600` o `0400`, una línea no vacía. No poner la
contraseña en Git, Nix, Compose, argumentos de shell o historial. No sobrescribir
credenciales existentes. El usuario Windows predeterminado es `osmarg`.

## 3. Primera instalación por web

En **windows-vfio**, con los prerrequisitos completos:

```sh
envy-windows preflight
envy-windows start
windows-rdp web
```

También se puede abrir directamente **http://127.0.0.1:8006** una vez iniciado.
El primer inicio puede descargar el medio de Windows y crear/instalar el huésped.
Ese trabajo es independiente de la descarga de la imagen contenedor.

La pantalla virtual/VNC permanece habilitada para la instalación inicial y el
mantenimiento. No necesita Looking Glass Host ni RDP instalado. El disco
persistente sigue en `/var/lib/windows/storage`; no crear otra VM para Looking
Glass ni cambiar su propietario. Si el servicio falló antes por falta de
provisión, `envy-windows start` vuelve a intentar el inicio tras corregirla.

## 4. Preparar Windows y abrir Looking Glass

Desde la consola web:

1. Instalar/verificar el controlador NVIDIA de la MX250.
2. Instalar **Looking Glass Host** compatible con el cliente declarado en
   `nixos/containers/windows/looking-glass-idd-client.nix`: actualmente
   **B7-544-d3fff4eb**, revisión `d3fff4eb571b92e372bff859537bdbeafdbcd7f4`.
   No asumir que cualquier instalador B7/de desarrollo comparte protocolo.
3. Instalar el controlador IVSHMEM según la documentación de Looking Glass y
   verificar el dispositivo de memoria compartida en el Administrador de
   dispositivos. El ISO adicional adjunto contiene controladores **de entrada**
   VirtIO (`vioinput/w11/amd64`), no el controlador IVSHMEM. El instalador
   automatizado puede haber instalado ya los controladores de entrada.
4. Verificar que Looking Glass Host se ejecuta y que Windows tiene una pantalla
   activa capturable asociada a la GPU adecuada. La pantalla que muestra la web
   no es necesariamente la salida de la MX250. En portátiles sin salida física
   utilizable puede ser necesario un controlador de pantalla virtual/IDD
   compatible; no se instala ni se garantiza automáticamente desde NixOS.

Después, en Linux:

```sh
windows-rdp looking-glass
```

También aparece `Local | envy-windows | Looking Glass` en `windows-rdp connect`
cuando kvmfr es accesible. El cliente usa `/dev/kvmfr0` y SPICE en
`127.0.0.1:5901`; **no espera a RDP**. Mantener el acceso web como respaldo. RDP
es opcional y usa las credenciales específicas de Envy si se habilita.

Referencias: [instalación Windows Host](https://looking-glass.io/docs/B7/install_host/),
[kvmfr](https://looking-glass.io/docs/B7/ivshmem_kvmfr/),
[fuente de la revisión cliente/host](https://github.com/gnif/LookingGlass/tree/d3fff4eb571b92e372bff859537bdbeafdbcd7f4).

## Diagnóstico y parada

```sh
envy-windows status
envy-windows preflight
journalctl --user -u envy-windows --no-pager
envy-windows stop
```

No publicar contraseñas, `inspect` completo, configuraciones interpoladas ni logs
del huésped sin revisar. No usar `kill -9`, `podman rm -f` o borrar volúmenes para
resolver un apagado lento. La parada espera al apagado limpio. Un cambio de
configuración queda pendiente mientras Windows está activo y se aplica al
siguiente inicio detenido. Cambiar entre render y VFIO requiere reiniciar el host.

Las pruebas de fixtures y la evaluación Nix no sustituyen una instalación real de
Windows, el test de reset de la MX250 ni una prueba de captura/entrada/audio.
