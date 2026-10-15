# Envy: instalación declarativa NixOS, Btrfs y Windows

Estado: aprobado con alcance por fases el 2026-10-15; inicialmente SOLO normal.

## Alcance inmediato aprobado (prevalece sobre las fases futuras)

El usuario decidió instalar primero NixOS con perfil normal, sin Windows, sin
server y sin perfil gaming. Normal será el arranque predeterminado. Se conserva
el diseño avanzado de abajo como hoja de ruta, no como funcionalidades a activar
en esta instalación. El repositorio completo y la planificación deben quedar en
`/home/osmarg/Hobby/nixos` del equipo nuevo.

Primero se validarán arranque, rendimiento, Wi-Fi, Ethernet, pantallas/salidas,
USB, sonido y vídeo, documentando cuáles pruebas requieren intervención física.
Se mantiene Btrfs, Intel para escritorio y MX250 mediante PRIME bajo demanda,
sin asignaciones VFIO ni contenedores Windows. Se utiliza zram inicialmente.
El Optane de 27,3 GiB se deja intacto: su posible uso como swap o recuperación
se evaluará después y requerirá autorización antes de borrar sus datos.

## Objetivo y requisitos del usuario

- Host `envy`, usuario `osmarg`, reutilizando sus aplicaciones y preferencias del repositorio.
- Instalación remota desde el live NixOS por `root@10.0.0.50`.
- Btrfs para separar sistema, home y almacenamiento Windows.
- Cuatro modos de arranque: normal, gaming, windows/passthrough y server.
- Windows/passthrough será el modo predeterminado una vez validado.
- Normal: escritorio de bajo consumo, juegos Linux con la GPU potente bajo demanda y Windows con render virtual compartido.
- Gaming: GPU potente para juegos Linux.
- Windows y server: GPU potente asignada exclusivamente a Windows; server sin escritorio, con los servicios equivalentes a Lenovo.
- Compose por host y configuración GPU declarativos, resistentes a redespliegues.
- El usuario instalará los controladores dentro de Windows.

## Hardware observado y autorización destructiva

- HP ENVY Laptop 17m-ce1xxx, placa 86B0, UEFI, Secure Boot desactivado.
- Intel i7-10510U (4 núcleos/8 hilos), 12 GiB RAM.
- Intel UHD `0000:00:02.0`, PCI `8086:9b41`; controla actualmente los conectores de pantalla observados.
- NVIDIA Pascal MX250 `0000:02:00.0`, PCI `10de:1d13`, controlador live nouveau.
- SSD Intel H10 principal: `/dev/nvme0n1`, 476,9 GiB, serial `PHTE9395032P512B-1`.
- **Autorizado explícitamente borrar ese SSD completo**, incluyendo Windows BitLocker, EFI y recuperación.
- Identificarlo por `/dev/disk/by-id/nvme-INTEL_HBRPEKNX0202AH_PHTE9395032P512B-1` y verificar modelo, serial y capacidad inmediatamente antes de borrar.
- **No modificar** `/dev/nvme1n1`, Optane de 27,3 GiB, serial `PHTE9395032P512B-2`, también con BitLocker; ni `/dev/sda`, USB instalador.
- Ambos dispositivos NVMe pasan SMART. No suponer que el Windows antiguo puede recuperarse después del borrado; la VM será nueva.

## Propuesta de almacenamiento (decisión del implementador para revisar)

- GPT: partición EFI FAT32 de 1 GiB y resto Btrfs, sin tocar otros dispositivos.
- Subvolúmenes separados para `/`, `/home`, `/nix`, `/var/log` y `/var/lib/windows`.
- Sistema/home con compresión zstd; almacenamiento de discos VM preparado sin CoW antes de crear las imágenes y excluido de snapshots rutinarios del sistema.
- Un solo almacenamiento Windows persistente utilizado por ambos modos gráficos, nunca dos QEMU simultáneos sobre el mismo disco.
- No hace falta una partición Windows/NTFS física: el guest mantiene su sistema de archivos dentro de una imagen en el subvolumen Windows.
- No cifrado LUKS ni hibernación en esta propuesta; zram para aliviar la RAM limitada, sin swapfile Btrfs inicialmente.
- Documentar montaje y creación reproducibles en el repositorio, con guardas de identidad de disco y confirmación destructiva; no cambiar el instalador genérico ext4 para los demás hosts.

## Propuesta de perfiles (decisiones a revisar)

- Base normal con Hyprland, siguiendo el alias habitual de orgm/lenovo; configuraciones del usuario osmarg sin duplicarlas ni editarlas para envy.
- Menú de arranque con normal, gaming, windows-vfio y server; cambio de propiedad de GPU mediante reinicio, no unbind en caliente.
- Normal: Intel para escritorio; PRIME offload para juegos Linux. Windows usa render virtual de la MX250 si las pruebas reales del stack lo permiten. Mientras Windows use esa GPU no se promete que quede apagada ni consumo mínimo absoluto.
- Gaming: sesión Steam/Gamescope equivalente al patrón Lenovo, seleccionando explícitamente MX250. Windows no arranca automáticamente en este modo, para no competir con los juegos Linux.
- Windows-vfio: Intel conserva escritorio Linux; MX250 reservada temprano a vfio-pci y entregada al guest. Conexión local/RDP y Looking Glass/SPICE si el patrón existente resulta compatible.
- Server: conserva acceso SSH, red, Tailscale, contenedores y arranque Windows VFIO sin login; desactiva escritorio, autologin y aplicaciones de sesión. Como en la especialización Lenovo, los paquetes de escritorio pueden seguir instalados/compartidos, pero no ejecutándose.
- Primer arranque de validación en normal y con SSH comprobado; solo después de validar VFIO se fija windows-vfio como predeterminado. Mantener normal recuperable y generaciones de rollback.
- No heredar los ajustes Lenovo de pantalla interna rota, GPU T500, bus PCI, grupo IOMMU ni opciones de firmware específicas.

## Windows declarativo y persistencia

- Reutilizar la base Compose del repositorio y añadir overlays específicos envy/render y envy/VFIO.
- Mantener Podman rootless como en Lenovo y el entorno osmarg actual; no introducir una segunda VM ni motor Docker paralelo para el mismo disco.
- Publicar Compose y contexto de construcción pequeño/inmutable mediante módulos Nix/Home Manager. Servicio systemd de usuario con linger para arranque sin sesión en windows/server, y reconciliación de la configuración declarada, no solo `podman start` de contenedores obsoletos.
- Secretos y contraseñas fuera de Git y Nix Store; archivo de entorno privado persistente. Obtener credenciales existentes solo de fuentes autorizadas; si no están disponibles, generar credencial inicial privada y comunicar cómo obtenerla sin imprimirla en logs.
- Valores iniciales propuestos: Windows 11, 4 GiB RAM, 4 vCPU e imagen de disco dinámica de 96 GiB, ajustables sin reinstalar.
- No arrancar dos contenedores sobre el mismo almacenamiento. Detener el guest limpiamente antes de recrear o cambiar perfil.
- Puertos de administración solo en loopback por defecto; usar SSH/túnel o acceso VPN autorizado, no exponer RDP/web/SPICE sin restricción a toda la red.
- Helper de acceso integrado con los perfiles envy, preservando comportamiento actual de Lenovo/orgm.
- No habilitar automáticamente todos los servicios de `server/modules`: equivalencia con servicios realmente declarados en el modo Lenovo, sin inventar una nueva plataforma servidor.

## Compatibilidad pendiente: no prometer éxito antes de probar

- Existe tabla ACPI DMAR y remapeo de interrupciones; no hay grupos IOMMU en el live. El kernel live tiene `CONFIG_INTEL_IOMMU_DEFAULT_ON` desactivado y falta `intel_iommu=on` en cmdline.
- Activar IOMMU en configuración instalada y verificar aislamiento real del grupo MX250. No usar ACS override ni `allow_unsafe_interrupts` como atajo.
- MX250 anuncia reset de bus; validar reinicio del guest y aislamiento del puente. No asumir passthrough funcional solo por identificar el dispositivo.
- MX250/Pascal requiere módulo NVIDIA propietario (`open = false`) y una rama que soporte el dispositivo (580 verificada por documentación NVIDIA). No copiar `open = true` del módulo genérico ni finegrained RTD3 incompatible.
- Elegir kernel compatible con ese driver y los requisitos reales del render virtual; el LTS 6.12 de Lenovo no debe heredarse sin verificar los requisitos actuales de virtio/Venus/Helios.
- Render virtual requiere validar Vulkan/EGL/GBM dentro del contenedor y arranque del guest; el usuario instala drivers del guest y valida aceleración/juegos posteriormente.
- Si MX250 compartida no supera preflight o VFIO no es seguro, informar el bloqueo y proponer Intel/software o ajuste de firmware, sin sustituir silenciosamente lo solicitado ni dejar VFIO roto como arranque predeterminado.

## Seguridad operativa y validación

- Preservar cambios locales ajenos: webapps.catalog.nix, ryoku.nix, users/osmarg.nix, tests/chromium-webapps.bats.sh y docs existentes.
- Mantener acceso remoto tras instalación: SSH por clave para osmarg, sudo operativo, red Wi-Fi persistida sin publicar credenciales; root SSH del live no implica root SSH permanente.
- Nunca leer/copiar claves privadas indiscriminadamente. Integraciones que requieran login, VPN o identidad SOPS se documentan como pendientes si falta su provisión segura.
- Evaluar Nix y todos los perfiles; probar scripts/Compose y ausencia de IDs Lenovo antes de instalar.
- Construir y desplegar desde la configuración actual necesaria para osmarg, sin perder sus cambios previos ni atribuirlos a este trabajo.
- Verificar UUID/subvolúmenes/bootloader antes de reiniciar. Reboot coordinado conservando posibilidad de recuperación por USB.
- Comprobar SSH tras reinicio, GPU/driver por modo, servicios y propiedad VFIO, arranque Windows, persistencia del Compose tras rebuild y exclusión de doble acceso a disco.
- Separar en el informe pruebas realizadas de pendientes: drivers/juegos Windows a cargo del usuario, no declarar aceleración Windows confirmada por pasar un test de Vulkan del host.

## Referencias primarias consultadas

- NVIDIA 580, chips soportados (MX250/1D13): https://download.nvidia.com/XFree86/Linux-x86_64/580.95.05/README/supportedchips.html
- NVIDIA, módulos open/propietario y arquitecturas: https://download.nvidia.com/XFree86/Linux-x86_64/580.95.05/README/kernel_open.html
- Dockur, almacenamiento persistente e imagen de disco: https://github.com/dockur/windows

## Fuera de alcance

- Conservar/migrar el Windows BitLocker borrado, tocar Optane/USB, instalar drivers guest por el usuario, garantizar compatibilidad de todos los juegos/anticheat o extender ahora la integración pendiente de orgm a todos los hosts.
