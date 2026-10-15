# Envy: registro de instalación normal y validación

## Alcance aprobado

Solo NixOS normal/Hyprland/osmarg; Windows, server, gaming y VFIO aplazados.
Borrar únicamente SSD principal serial `PHTE9395032P512B-1`, 512110190592 bytes.
Conservar Optane serial `PHTE9395032P512B-2` y USB instalador.

## Inventario previo

- HP ENVY Laptop 17m-ce1xxx/86B0; UEFI, Secure Boot desactivado.
- i7-10510U, 4c/8t; 12 GiB RAM; Intel UHD00:02.0/MX250 Pascal02:00.0.
- Wi-Fi Intel AX201 con iwlwifi, Ethernet Realtek r8169, audio sof-hda-dsp.
- i915 controla pantalla integrada y conectores DP/HDMI observados.
- SSD principal SMART PASSED, 11% usado, 0 errores de integridad.
- Optane27,3GiB SMART PASSED, 2% usado, 0 errores de integridad. No se monta ni usa como swap.
- Live sin grupos IOMMU; kernel sin IOMMU por defecto. No se activa VFIO en esta fase.

## Comprobaciones de código antes de instalar

- PASS: nuevo test evaluado `tests/envy-normal.bats.sh` (RED antes de crear host).
- PASS: `tests/envy-disk.bats.sh` (RED antes del script; negativas sin escrituras).
- PASS: `tests/configuration-inventory.bats.sh`, `tests/host-role-wiring.bats.sh`.
- PASS: `tests/install-installer.bats.sh`, sin cambiar instalador genérico.
- PASS: `bash -n`, `git diff --check` en cambios del host.
- Baseline conocido rojo ANTES de implementar: `tests/flake-architecture.bats.sh`
  exige literal `inherit inputs userName hostName;`, pero builder ya incluye `role`.
  No se arregla ni se oculta como una regresión de envy.
- Revisión independiente de configuración y script: sin bloqueadores críticos/importantes;
  cobertura negativa de algunas guardas y comando findmnt README quedan como menores.
- `prepare-disk.sh --check` REAL por SSH pasó: by-id, dispositivo, serial,
  capacidad y ausencia de particiones montadas. No produjo escrituras.
- Backup GPT/metadatos, perfil Wi-Fi privado y fingerprints de Optane/USB
  guardados fuera del repo bajo `/root/envy-install-private` del live.

## Estado operacional

- Build completo: PASS, kernel6.12.96/NVIDIA580.173.02/Hyprland0.56.2.
  Cierre `/nix/store/75mf3nxb4iw6m3jbnh56mx4xq44h0kv5-nixos-system-envy-hyprland`,
  18,1 GiB; `nix build` exit0 y comparación con evaluación de la configuración final.
- Formateo autorizado: PASS, solo SSDprincipal; UUID Btrfs
  `c5b103f7-60c1-47e5-b1d6-f752c460cf7b`. Montajes verificados destino por destino;
  `@windows` vacío y atributo NOCOW confirmado.
- Fingerprints de primeros4MiB Optane y USB: iguales antes/después. No se usan
  como almacenamiento ni swap, y los comandos destructivos no los referencian.
- Transferencia de cierre: EN CURSO al store `/mnt`, no al tmpfs del live.
- Repositorio completo y planificación: COPIADOS a `/mnt/home/osmarg/Hobby/nixos`.
- Perfil Wi-Fi privado persistente, autoconnect/MACpermanente y claves HOST SSH
  del propio live: PROVISIONADOS, permisos verificados.
- Contraseña inicial aleatoria: archivo privado del usuario creado, pero
  aplicación a shadow y prueba de acceso: PENDIENTES tras activar el usuario.
- Instalación bootloader, reinicio y prueba del sistema arrancado: PENDIENTES.
- Verificaciones de hardware después de arrancar: PENDIENTES.

Esta sección se actualiza con resultados reales, no con los resultados esperados.

## Aislamiento del trabajo

Por confirmación del usuario, la rama `feat/envy-normal` se continúa en
`/home/osmarg/Hobby/nixos/.worktrees/envy-normal`. El checkout principal volvió a
master manteniendo sus cuatro modificaciones previas intactas. El worktree y
el destino conservan esas preferencias sin atribuirlas a estos commits.
La copia de dotfiles incluye el snapshot local original; residuos ignorados
pueden cambiar el hash de `builtins.path` aunque no se seleccionen como archivos
Home Manager. No se limpian archivos del usuario durante esta instalación.

## Acceso previsto y seguridad

- Repositorio y toda planificación en `/home/osmarg/Hobby/nixos`.
- SSH por clave como `osmarg`, no root ni contraseña SSH.
- Contraseña inicial privada solo fuera de Git/Store/logs; recuperable mediante
  SSH por clave en `~/.local/state/envy/initial-password`, permiso0600 del usuario.
  Cambiarla con `passwd` y borrar ese archivo tras guardarla en el gestor de claves.
- Perfil NetworkManager con credenciales persistentes solo en `/etc/NetworkManager/system-connections`, root0600.
- Cuentas SOPS/Nextcloud/Tailscale esperan provisión/login del usuario; no trasladar
  indiscriminadamente claves privadas del equipo actual.

## Lista física pendiente del usuario

Pantalla interna/brillo, HDMI/DP/USB-C, cada USB/lectorSD, cámara, micrófono,
parlantes/auriculares, Bluetooth, Ethernet con cable, suspensión/tapa/reanudación,
temperaturas y autonomía. Enumerar dispositivos no demuestra que esas funciones
funcionen físicamente; los tests GPU por software tampoco garantizan juegos.

Comprobar montajes con un comando válido por destino:

```bash
for m in / /home /nix /var/log /var/lib/windows /boot; do
  findmnt -M "$m" || break
done
```

## Planificación futura conservada

`docs/superpowers/specs/2026-10-15-envy-design.md` documenta el objetivo avanzado.
Después de validar normal: evaluar uso Optane con autorización nueva; medir GPU y
rendimiento; verificar IOMMU/aislamiento/reset, Windows virtual y VFIO, gaming y
server. No se ha instalado Windows ni reservado una GPU para un guest.
