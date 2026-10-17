# Envy: entrega de modos internos (sin despliegue)

Fecha de trabajo: 2026-10-17. Diseño y plan aprobados por Osmarg. El checkpoint
`a1b95aa` se publicó en master **antes** de implementar; trabajo aislado en
`feat/envy-modes` para permitir cambios paralelos. Este informe no autoriza ni
ejecuta switch, reboot, VM, descarga de imagen o transición GPU en vivo.

## Implementado

- Una salida `envy`, usuario `osmarg`. Normal predeterminado, menú1segundo;
  gaming/Windows VFIO/server son especializaciones internas, sin variantes flake.
- Kernel6.18.39 y NVIDIA propietario580.173.02, sin modificar flake.lock.
  Intel siempre host; MX2500000:02:00.0/10de:1d13 exclusiva NVIDIA o vfio-pci.
  No ACS override, reset/rebind en vivo ni parámetros de pantalla de Lenovo.
- Normal: Ryoku/Intel/PRIME, render virtual bajo demanda. Gaming: Gamescope/Steam
  TTY1 con NVIDIA, sin Ryoku/SDDM/Windows. Windows: Ryoku/Intel más passthrough.
  Server: consola, SSH/red/Tailscale/Syncthing conservados, sin escritorio/gaming.
- Un contenedor Podman rootless `envy-windows`, Windows11/4GiB/4CPU/disco96GiB,
  VRAMvirtual1GiB; rango de recursos validado en opciones Nix. Puertos únicamente
  loopback8006 y3389TCP/UDP. Password privado, sin nuevos secretos SOPS requeridos.
- Compose/manifest/controlador inmutables por generación, referencia HM en
  `~/Apps/windows/envy/`. CDI NVIDIA del driver host solo en render; grupo VFIO y
  rendernode descubiertos por BDF, nunca índices DRM/grupos hardcodeados.
- Preparación root futura verifica montaje ENVY_ROOT/@windows y NoCoW antes de
  imagen; directorios privados del usuario, sin particionar ni tocar Optane.
- Supervisor usuario con linger, bloqueo de vida completa, adopción conservadora,
  cambios pendientes mientras VM activa y recreación del runtime detenido sin
  borrar discos. Errores del motor no significan ausencia. Stop sin force-kill.
  El límite memlock del manager persistente permite VFIO; login no depende de VM.
- Cliente existente delega rutas Envy a `envy-windows`, conserva ID windows-rdp
  y credenciales específicas; no cambia lifecycle Lenovo/orgm ni sus secretos.

## Evidencia y límites

Las construcciones completas de los cuatro modos y el paquete NVIDIA580/kernel6.18
pasaron con `--no-link`; ver resultados finales más abajo. Las pruebas
usan sysfs/montajes/motor/credenciales **sintéticos**, con procesos reales aislados;
no son prueba física de la MX250. Validadores reales Docker Compose y Podman
Compose procesan ambos overlays con contraseña de fixture, sin descargar/ejecutar
la imagen. Se auditó solo metadatos públicos y fuentes fijadas de la imagen.

Imagen amd64: `docker.io/dockurr/windows@sha256:59f8bed19cfd49cf1701debe34f9df6311e61a4e2ae68aa9f41206e2184e31cc`,
Windowscontainer6.06, revisión013ea27498e0e820a46b3861a0fa047d5b19d846,
QEMUbase7.50/qemu-windows11.2.23. Registro en `image.json`. No se descargó la imagen.

**No demostrado:** arranque kernel candidato en Envy, estabilidad suspend/resume,
HDMI/LG/escala, aislamiento IOMMU real habilitado, reset seguro real, Optimus y
passthrough funcional, renderer NVIDIA/EGL/GBM/Vulkan dentro del contenedor,
controladores guest, Windows/RDP usable o rendimiento. Enumeración/compilación
no certifican esos resultados. El usuario instala drivers Windows.

## Primera aplicación: normal primero, por el usuario

1. Preservar cambios locales y respaldos externos. No formatear nada. Comprobar
   alimentación/red/SSH y una generación anterior en `sudo nix-env -p
   /nix/var/nix/profiles/system --list-generations`; revisar `bootctl list`.
2. Tras integrar la rama y actualizar **tu** checkout, construir/instalar para
   siguiente boot desde ese checkout: `sudo nixos-rebuild boot --flake .#envy`.
   No usar una especialización como base ni cambiar predeterminado a Windows.
   `boot` no conmuta la sesión actual; instalará las entradas del siguiente boot.
3. Revisar `bootctl list` y `/boot/loader/loader.conf`: timeout1, entrada normal
   predeterminada. Reiniciar solo cuando se acuerde; mantener Espacio pulsado
   durante arranque permite abrir el menú para elegir normal/generación anterior.
4. Tras boot normal: `uname -r`, `lspci -nnk`, `nvidia-smi`, `findmnt -M
   /var/lib/windows`, `systemctl --failed`, comprobar SSH y login Ryoku. La VM no
   debe autoarrancar: `systemctl --user is-enabled envy-windows.service` y
   `envy-windows status`. No ejecutar preflight como root.
5. Antes de VM: panel interno, LGUSB-C, HDMI, lock/unlock y sleep/reanudar, por
   separado y con intervención física. Usar seguimiento ENVY-DISPLAY-001 para
   evidencia antes/después. HDMI y recorte de ventanas siguen abiertos.
6. Si falla arranque/gráficos: elegir generación anterior en systemd-boot. Si se
   hizo un switch posteriormente, `sudo nixos-rebuild switch --rollback` recupera
   esa generación; no restaura datos ni Windows. Nunca resetear GPU en caliente.

## Provisión Windows explícita (posterior, no ejecutada)

No es necesaria para usar normal. Recomendado separar primero validación de
hardware. Comprobar espacio con `df -h /var/lib/windows` (96GiB es tamaño dinámico,
no reserva garantizada) y estado `systemctl status envy-windows-storage.service`.
Si falla NoCoW por imagen existente: detenerse y acordar migración manual, no
mover/borrar/convertir el disco automáticamente.

Como osmarg, sin sudo, descargar **solo cuando lo decidas**:

```sh
podman pull --platform linux/amd64 docker.io/dockurr/windows@sha256:59f8bed19cfd49cf1701debe34f9df6311e61a4e2ae68aa9f41206e2184e31cc
```

Crear por canal privado `~/.config/envy-windows/password`, propietario osmarg,
modo0600 (0400 también válido), una línea no vacía. No sobrescribir uno existente,
no usar contraseña en historial, Nix, dotenv público, Git o comandos Compose de
inspección. El nombre de usuario por defecto es osmarg. SOPS es opcional y no hay
apikey Claude. La contraseña de la cuenta Windows y la de login Linux son distintas.
Cambiar el archivo no garantiza cambiar una cuenta ya creada dentro del huésped.

En normal: `envy-windows preflight`, luego `envy-windows start` y
`windows-rdp connect` o `windows-rdp web`. **El primer start ya puede descargar
medios Windows y crear/instalar el guest**; no hacerlo durante pruebas de fuente.
RDP utiliza WINDOWS_RDP_ENVY_WINDOWS_USER (osmarg) y
WINDOWS_RDP_ENVY_WINDOWS_PASSWORD_FILE (archivo anterior), nunca claves de orgm.
No lanzar Compose a mano ni `podman start`: eludirías bloqueo/guardas.

Ventanas/VFIO y server autoarrancan si sus prerrequisitos están presentes;
sin imagen/password/aislamiento muestran fallo de servicio, no bloquean SSH.
Usar `journalctl --user -u envy-windows` para diagnóstico; no publicar inspect
completo, env, configs interpolados o logs guest que puedan incluir datos privados.
No hay SPICE/kvmfr/Looking Glass obligatorio. Para acceso remoto, túnel SSH
explícito a los puertos loopback; no abrirlos al0.0.0.0 por comodidad.

## Validación VFIO posterior y operación

Antes de probar Windows VFIO, mantener la provisión incompleta para inspeccionar
el hardware sin arrancar VM automáticamente. Seleccionar windows-vfio una vez
en el menú (no hacerlo predeterminado); comprobar i915 en00:02.0 y vfio-pci en
02:00.0, grupo por `readlink /sys/bus/pci/devices/0000:02:00.0/iommu_group`,
miembros en su subdirectorio devices y reset_method de la GPU. El controlador
rechaza vecinos adicionales, grupos inaccesibles o bus reset de dispositivos ajenos.
No usar ACS override, `allow_unsafe_interrupts`, unbind/rebind, reset manual ni
ROM extraída para hacer pasar el preflight. Si no es elegible, parar y replantear.
Superar el preflight no sustituye prueba real de Windows/driver/display.

`envy-windows stop` pide apagado limpio y espera salida real; no mata por timeout.
Si Windows no apaga, diagnosticar guest/ACPI/servicio con el usuario; el host puede
esperar indefinidamente al apagar. No `kill -9`, `rm -f` ni borrar volúmenes.
A los dos minutos se avisa sin matar el huésped. Un fallo transitorio al pedir
el apagado se reintenta con backoff acotado (hasta15segundos), sin perder el lock.

Rebuild preserva la VM activa y su supervisor anterior (restartIfChanged=false,
stopIfChanged=false). `envy-windows status` marca pending si cambió generación.
Detener limpiamente y volver a iniciar aplica el runtime nuevo sobre el mismo
disco; para cambiar ownership GPU es obligatorio reiniciar al modo correspondiente.
Optane27GiB, swap, modos alternativos de escritorio y clipboards entre PCs quedan
fuera del alcance; ver `nixos/hosts/envy/PENDING.md`.


## Revisión independiente y correcciones

Una revisión fresca de toda la rama señaló seis problemas importantes; corregidos
con pruebas RED→GREEN: parada de huéspedes huérfanos, esquema de metadata y
conservación del lock, readiness/exit verídicos, mounts de disco solapados,
reintentos de parada transitoria y comprobación NoCoW de las imágenes existentes
(no solo del directorio). La opción VRAM se restringió a256/512/1024/2048/4096MiB:
aceptar valores que el renderer rechaza se revaloró como importante, no cosmético.

La CLI generada se prueba como artefacto Nix, sustituyendo únicamente systemctl
por un doble y el manifest por fixtures aislados. La recuperación de stop usa el
mismo lock, verifica propiedad y salida real; no basta un servicio inactivo.
RuntimeDirectoryPreserve evita perder el inode del lock por limpieza del servicio.
Un fallo al notificar READY no deja un guest vivo sin monitor. No hubo re-revisión:
las correcciones se verifican con regresiones y la suite completa enfocada.

**Minor diferido:** un CDI/archivo de módulo ausente todavía puede producir un
mensaje genérico de prerrequisito en vez de identificar el servicio exacto. Se
rechaza el inicio de forma segura; mejorar diagnóstico no requiere relajar guardas.

**Baseline conocido:** `tests/envy-monitors.bats.sh` todavía espera el antiguo
archivo HM persistente, reemplazado por semillas Ryoku antes de esta rama. El
mismo fallo exacto se reprodujo en a1b95aa desde un archivo limpio; no se cuenta
como PASS ni como regresión de modos. Se conserva ese test histórico sin cambiar
la política de monitores. Las pruebas de semillas/native/provider/DPMS sí pasan.
La primera falta de `lua` en PATH se resolvió ejecutando la suite con lua5_4 del
nixpkgs fijado; no era un defecto de audio ni se cambió su configuración.

## Decisiones de cierre

- No probar físicamente GPU/reset/display/sleep: se conserva el límite autorizado;
  riesgo pendiente de incompatibilidades en el primer boot supervisado.
- No instalar guest/drivers ni probar RDP real: provisión posterior del usuario;
  riesgo pendiente de compatibilidad dentro de Windows.
- Atribuir audio y test histórico de monitores mediante evidencia independiente,
  no ocultar el fallo conocido; cobertura antigua de monitores aún requiere adaptar
  su propietario esperado en una tarea posterior.


## Resultado verificado

- 28 grupos de pruebas PASS, 0 fallos nuevos; 1 fallo histórico de monitores
  reproducido y contabilizado aparte (no PASS).
- 47 pruebas runtime/almacenamiento y5 de CLI Nix generada PASS, incluidas las
  reproducciones RED→GREEN de la revisión y exclusión por lock durante recuperación.
- Base y las3especializaciones construidas completas con `--no-link`, además del
  driver NVIDIA580 con el kernel6.18 seleccionado. Assertions Nix de los modos PASS.
- Flake.lock sin cambios; ningún switch/test/boot/reboot ni guest/image pull/run.
- El checkpoint del plan a1b95aa se publicó primero. La implementación queda en
  `feat/envy-modes`; el checkout principal/master se conserva para el trabajo
  paralelo del usuario. **Merge y primer despliegue quedan pendientes de elección**.

Para integrar después, con cambios locales preservados y la rama revisada:
`git fetch origin`, revisar `git log --oneline master..origin/feat/envy-modes` y
acordar merge. No ejecutar `nh os switch` esperando estos modos si el checkout
todavía contiene solo el checkpoint de planificación.
