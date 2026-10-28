# Jarq: logo Lenovo durante el arranque de Linux

Se habilita Plymouth con el tema `bgrt` en la base de Jarq. Se elimina la
anulación histórica que lo desactivaba para depurar bloqueos. Se carga `i915`
en el initrd y se restauran `quiet`, `splash` y los niveles de registro en la
lista de parámetros que el perfil multimedia reemplaza con `mkForce`.

El firmware de este Lenovo 80JM/BIOS BDCN71WW publica una imagen BMP BGRT de
548×308, 506406 bytes. Se leyó directamente de
`/sys/firmware/acpi/bgrt/image` y se confirmó visualmente que es el logo Lenovo
original. No se añade una imagen de marca al repositorio. El tema suministrado
por Plymouth conserva `UseFirmwareBackground=true` para arranque/apagado/reinicio.
El valor BGRT `status=0` no impidió leer esa imagen; el código instalado de
Plymouth utiliza los bits de orientación al leer ese campo.

## Instalación

- Perfil: `jarq-multimedia` (también exportado como `jarq`).
- Sistema preparado:
  `/nix/store/pf9c1rpa2qvw8cc0my11jisnljwcvdca-nixos-system-jarq-jarq-multimedia`.
- Instalación mediante `switch-to-configuration boot`: nueva generación **53**,
  entrada predeterminada `nixos-generation-53.conf`.
- La generación **52** sigue ejecutándose; se mantiene su entrada en el menú.
  No se reinició Jarq ni se reactivaron sus servicios.
- No hay overrides EFI de entrada predeterminada o de un solo arranque.
  `loader.conf` conserva timeout 3 y `console-mode keep`.
- Estado previo y nuevo guardados en `/var/lib/orgm-jarq-firmware-logo/`.

## Verificación

- Evaluación Nix de ambos nombres de perfil correcta; Plymouth habilitado,
  tema BGRT, initrd systemd y módulo Intel presentes.
- Compilación completa de la configuración aprobada.
- Se descomprimió el initrd compilado y se comprobaron el tema BGRT,
  `plymouthd.conf`, `plymouth-start.service`, `i915.ko.xz` y el plugin `two-step`.
- Los parámetros previos de IOMMU y módulos bloqueados siguen presentes;
  el binario del kernel coincide con el sistema anterior (Zen 7.0.10).
- La entrada instalada apunta al nuevo sistema y contiene `quiet splash`.
  El SHA-256 del initrd copiado a la partición EFI coincide con el compilado.
- Menú real comprobado: seleccionada 52, predeterminada 53; entrada anterior
  conservada. API, Nginx y DIAL activos, salud de la API correcta.
- El cambio del cierre de dependencias añade Plymouth y sus unidades; no
  sustituye la aplicación multimedia.

La aparición del logo durante el arranque real queda pendiente del siguiente
reinicio físico. La imagen original y su configuración están verificadas;
no se afirma haber observado ya ese arranque.
