# Envy: modos internos Windows, gaming y server

Estado: alcance aprobado por el usuario («sí» a preparar sin desplegar, normal
predeterminado); detalle técnico nuevo pendiente de revisión del plan.
Complementa, no borra, `2026-10-15-envy-design.md`.

## Intención y límites

Implementar fuentes para los modos faltantes en una única salida `envy` y su
usuario `osmarg`. No activar, instalar Windows, descargar imágenes de VM,
reiniciar, cambiar drivers vivos ni probar DPMS/sleep. Mantener Optane, particiones,
credenciales y configuraciones personales intactos. El usuario instala drivers
Windows y autoriza por separado el primer despliegue/arranque real.

Se conservará el método de ejecución inline con revisión final independiente.
Este documento y el plan requieren aprobación antes de código de implementación.

## Evidencia previa (SSH solo lectura, 2026-10-17)

- Intel UHD 8086:9b41 en 0000:00:02.0 con i915; MX250 Pascal 10de:1d13 en
  0000:02:00.0 con nvidia, sin función de audio PCI hermana observada.
- Kernel activo 6.12.96, sin intel_iommu=on ni grupos IOMMU utilizables.
  El contador de directorios incluye únicamente la raíz vacía: cero grupos.
- MX250 anuncia reset de bus; no demuestra que un reset real sea seguro.
- renderD128 corresponde a Intel; renderD129 a MX250, pero los índices no son
  identidad estable y no se declararán como identificación de GPU.
- /var/lib/windows ya monta Btrfs @windows en ENVY_ROOT con compresión heredada;
  todavía hay que preparar NoCoW antes de crear imágenes, nunca retroactivamente.
- Podman y /dev/kvm existen. No se han inspeccionado discos guest ni secretos.

## Decisiones técnicas propuestas por el implementador

1. **Kernel candidato 6.18 LTS**, mismo driver NVIDIA propietario legacy_580.
   El lock actual evalúa kernel6.18.39 y NVIDIA580.173.02; no cambiar flake.lock.
   El renderer actual requiere host blobs desde6.13 y guest PAT desde6.16 para
   Intel+NVIDIA. Conservar6.12 y prometer el render Windows no sería honesto.
   Construir candidato completo antes de ofrecer despliegue; no afirmar mejoría
   de suspensión por actualizarlo. Este cambio técnico se destacará al usuario.
2. Normal mantiene Ryoku/Intel/PRIME y **Windows render bajo demanda**, no un
   huésped de4GiB siempre consumiendo los12GiB de la laptop. Windows/server
   autoarrancan el huésped tras pasar sus guardas; gaming no arranca Windows.
3. Gaming usa Gamescope/Steam TTY1 existente con selección NVIDIA explícita,
   no NVIDIA global en normal ni PRIME sync que presuponga cableado de pantallas.
   Autologin tty1 solo en gaming; SDDM/PAM normal y Windows conservan login.
4. Reutilizar Podman rootless y un solo contenedor **envy-windows**, único disco,
   con GPU render o VFIO según modo; no copiar el autostart conservador de Lenovo
   que presupone una VM ya creada. Lenovo/orgm quedan sin cambios de runtime.
5. Acceso Windows por cliente RDP existente y consola web, ambos loopback.
   No introducir kvmfr, SPICE sin contraseña, Looking Glass ni una ROM extraída
   como requisito inicial. GPU passthrough y visualización por RDP son distintos;
   no se promete salida física desde la MX250 ni ausencia de problemas Optimus.
6. Imagen Windows fijada por digest OCI compatible con el renderer auditado;
   resolución de metadatos remota durante implementación, sin pull/run/build de
   la imagen. Si no se puede verificar digest/plataforma, no inventarlo.

## Matriz de modos

| Modo | Escritorio | GPU host | Windows | Inicio huésped |
|---|---|---|---|---|
| normal (base/predeterminado) | Ryoku: Hyprland/Niri existentes | Intel, MX250 offload | render virtual MX250 | manual |
| gaming | Gamescope/Steam TTY1 | MX250 para juegos, Intel disponible | bloqueado | nunca |
| windows-vfio | Ryoku: sesiones existentes | Intel; MX250 vfio-pci | passthrough MX250 | automático condicionado |
| server | consola multi-user, sin DM/WM | Intel consola; MX250 vfio-pci | passthrough MX250 | automático condicionado |

Son `specialisation.gaming`, `windows-vfio` y `server` dentro de `envy`.
Normal es la configuración base, sin variante `envy-normal`. Menú1segundo,
orden normal/windows/gaming/server y sin selector EFI que fuerce Windows/server.
No copiar video=eDP-1:d, política de tapa ni IDs/grupos T500 de Lenovo.

## Módulos y propiedad GPU

- Extraer configuración gráfica de Envy a `gpu.nix`, con opción interna
  `orgm.envy.windowsVfio.enable` y mismo comportamiento normal cuando está false.
- En normal/gaming: legacy_580 propietario, PRIME offload, nvidia-game. Runtime
  CDI NVIDIA habilitado solo con driver propietario del host, para llevar al
  contenedor bibliotecas correspondientes a ese driver y no las de otra rama.
- En Windows/server: intel_iommu=on, iommu=pt; vfio/vfio_pci/vfio_iommu_type1
  temprano y únicamente ID10de:1d13. Excluir carga NVIDIA/Nouveau, offload y CDI.
  Intel/i915 nunca se reserva a VFIO. Sin ACS override ni unsafe interrupts.
- Guardas runtime resuelven grupo por BDF, no `/dev/vfio/16`: rechazar grupo
  inexistente, dispositivos extra ajenos a la GPU y reset de bus que afecte
  vecinos no autorizados. No unbind/reset/rebind en caliente desde scripts.
- Server reproduce la política Lenovo de consola/SSH/red/Tailscale/Syncthing,
  Podman/servicios existentes. No importar el rol genérico server que fuerza
  Docker, otras claves, kernel y permisos sudo. Apagar todas las rutas de
  escritorio y gaming, no solo cambiar default.target.

## Windows declarativo y persistente

Archivos propiedad del repo bajo `nixos/containers/windows/hosts/envy/`, publicados
como generación Nix en `~/Apps/windows/` y consumidos por rutas Store absolutas.
Config base Envy independiente de la base genérica insegura para estos puertos:
no heredar binds0.0.0.0, disco/puertos modificables desde un dotenv ni ID Lenovo.

Valores iniciales: Windows11, 4GiB RAM, 4vCPU, disco dinámico96GiB, VRAM virtual1GiB,
usuarioosmarg; contraseña exclusivamente en archivo privado0600. No generar ni
commitear secretos ni habilitar nuevos secretos SOPS obligatorios. Opciones de
asignación Nix explícitas y validadas; ausencia de contraseña bloquea VM, no login.

Almacenamiento único `/var/lib/windows/{storage,shared,oem}`, propiedad de osmarg,
creado en futura activación mediante preparación idempotente: confirmar montaje
Btrfs @windows/ENVY_ROOT y aplicar NoCoW a storage vacío antes de la imagen.
Si hay imágenes existentes sin la propiedad requerida, fallar informativamente,
no reformatear, mover ni convertir datos en automático. No tocar Optane/swap.

Puertos host fijos127.0.0.1:8006 y127.0.0.1:3389 tcp/udp; no abrir firewall de VM.
Transferencia externa por túnel SSH o VPN explícita, no exposición LAN automática.
NAT de Podman rootless, KVM/tun mínimos y keep-groups; no privileged ni devices
indiscriminados. Dos modos diferentes nunca reciben el disco simultáneamente.

Un runner `envy-windows {start|stop|status|preflight}`:
- Solo usa Podman, nunca Docker por precedencia de PATH; modo desde marcador Nix.
- Preflight sin cambios ni descarga: comprueba modo, identidad GPU/driver/grupo,
  acceso KVM, preparación de disco/credenciales privadas y render adecuado.
- Selecciona render por BDF y CDI; overlay derivado con nodos/grupo resueltos en
  XDG_RUNTIME_DIR privado, no índices PCI/DRM mutables ni credenciales en Git.
- Render no sustituye MX250 por Intel/software ni promete Vulkan por ver /dev/dri.
  Validación de EGL/GBM/Vulkan dentro del contenedor y drivers guest queda para
  prueba autorizada posterior; documentar si algún requisito no se puede probar.
- Sin imagen local, no arranca ni descarga implícitamente: instrucción explícita
  de provisión posterior. Preparar código no instala un Windows nuevo al rebuild.
- Lock mantenido durante la vida completa del contenedor y guardas de montajes
  impiden doble uso mediante este controlador; un proceso guardián/servicio
  mantiene el lock hasta la parada real del contenedor, no solo durante `up -d`.
- VM activa: no parar/recrear por rebuild ni modificación de Compose; indicar
  cambio pendiente. Al siguiente inicio con VM parada, comparar hash público de
  configuración, migrar runtime sin borrar volúmenes/disco y conservar privados.
  No usar `--no-recreate` para dejar configuración obsoleta indefinidamente.
- Fallos Podman distintos de «contenedor ausente» abortan; no adivinar que puede
  aprovisionar/recrear. Stop limpio con gracia2min; no kill automático por timeout.
- Bloquear cambios a otra GPU en caliente: pedir reboot al modo correspondiente.
- Logs/status nunca muestran entorno/contraseña ni config renderizado con secreto.

`systemd --user` con linger ejecuta el supervisor común. Normal sin wantedBy;
windows/server con wantedBy default.target y guardas previas. Gaming no tiene
runtime iniciable. El cliente `windows-rdp` delega start/stop/status de perfiles
Envy a ese controlador; no hace `podman start` directo ni usa defaults osmar.
Mantener rutas y pruebas existentes Lenovo/orgm; no añadir Envy a claves secretas
compartidas sin identidad provista por el usuario.

## Criterios de aceptación y lo no demostrado

- Nix eval y construcciones completas de base/3especializaciones sin switch.
- Tests de matriz de ownership GPU/servicios, puertos, almacenamiento, source
  persistente, reconciliación segura y concurrencia con dobles de Podman.
- Validadores reales Compose y scripts; rutas de binarios y dependencias de
  systemd explícitas. Cambiar Compose y reconstruir conserva el archivo declarado.
- Regresiones normal/ryoku/seed y modos Lenovo; no variantes públicas añadidas.
- Entrega con plan de primer reboot normal6.18, validación de pantallas/suspend,
  render real y luego VFIO/IOMMU/reset/Windows. Sin certificar rendimiento guest.
- Nunca cambiar predeterminado a Windows hasta petición posterior y validación.

## Fuentes consultadas (primarias)

- https://github.com/qemus/qemu/blob/master/src/display.sh — selección render por
  identidad, kernel host blobs/PAT y requisitos del runtime NVIDIA; validar contra
  el digest seleccionado, no asumir que una etiqueta mutable conserva contrato.
- https://github.com/dockur/windows — KVM/Podman, disco persistente y provisión guest.
- https://docs.kernel.org/driver-api/vfio.html — aislamiento por grupo IOMMU.

## Fuera de alcance

Despliegue/VM real, driver guest, cambiar firmware/Optane, validar HDMI/recorte,
resolver clipboard SSH, nuevos perfiles de escritorio, extraer vBIOS, Docker
Windows paralelo, migrar contratos Lenovo o habilitar todos los servicios server.
