# windows-vm: un controlador para Windows, con política por host

## Interfaz pública

En Envy y Lenovo se instala el mismo conjunto de comandos:

```sh
windows-vm status
windows-vm preflight
windows-vm start
windows-vm stop
windows-vm prepare-image
```

Sin argumentos muestra `status`. `status` y `preflight` no arrancan la VM.
`start` solicita el arranque al servicio de usuario; `stop` solicita apagado
limpio y espera, sin un timeout que fuerce la muerte del huésped.

La configuración instalada por Nix selecciona el adaptador local. No se detecta
el host por un nombre arbitrario de red ni hay una opción para aplicar las reglas
de Envy en Lenovo. El binario de cada host referencia su propio manifiesto
inmutable, comandos absolutos y servicio de usuario.

`windows-rdp` es el cliente de acceso: conserva el selector web/RDP/Looking Glass.
Sus antiguos comandos `start`, `stop`, `toggle`, etc. delegan en `windows-vm` en
ambos hosts por compatibilidad. **No construye imágenes, borra contenedores ni
elige grupos VFIO por su cuenta.** Otros hosts sin esta integración conservan su
ruta anterior; no se han migrado automáticamente.

## Qué es compartido y qué sigue siendo específico

- `nixos/containers/windows/controller.nix`: genera el CLI y la entrada del
  supervisor para ambos hosts.
- `nixos/containers/windows/windows_runtime.py`: implementación común de consulta
  segura al motor, bloqueo durante toda la vida de la VM, detección de discos
  solapados, confirmación de arranque y apagado limpio. También contiene la
  validación VFIO por identidad/grupo/reset, sin ACS override ni rebind en vivo.
- `nixos/hosts/envy/windows-runtime.py`: políticas de la MX250, montaje
  `ENVY_ROOT/@windows`, NoCoW, contraseña privada y generación de Compose Envy.
- `nixos/hosts/lenovo/windows-runtime.py`: políticas T500/Intel, configuración
  privada existente y adopción conservadora de los runtimes de Lenovo.

Los adaptadores no duplican el supervisor ni el código de parada/bloqueo.
No se comparten discos, contraseñas o identidades PCI entre máquinas.

| | Envy | Lenovo |
|---|---|---|
| Contenedor | `envy-windows` | `windows` (render), `lenovo-windows` (VFIO) |
| Datos | `/var/lib/windows/storage` | `WINDOWS_STORAGE_DIR` del `.env` privado existente |
| Credenciales | `~/.config/envy-windows/password` | `~/Apps/windows/.env` existente |
| GPU dedicada | MX250 `0000:02:00.0`, `10de:1d13` | T500 `0000:01:00.0`, `10de:1fbb` |
| Render | NVIDIA/CDI sujeto a sus requisitos | Intel `0000:00:02.0`, `i915` |
| Unidad de usuario | `envy-windows.service` | `lenovo-windows-autostart.service` |

Las unidades conservan sus nombres para no cambiar la identidad de servicios
existentes. `envy-windows` sigue instalado como **alias de `windows-vm`**, no como
una segunda implementación. El antiguo script fuente `windows-autostart.sh` de
Lenovo solo reenvía a `windows-vm start`; el servicio real usa el supervisor común.

## Provisión de imágenes

El arranque normal no hace `pull` ni `build`. Para preparar la imagen con SPICE:

1. Descargar explícitamente la imagen base fijada en
   `nixos/containers/windows/hosts/envy/image.json` (actualmente también se usa
   como base de Lenovo).
2. Ejecutar `windows-vm prepare-image`, como el usuario normal, sin `sudo`.

`prepare-image` usa un contexto inmutable y `podman build --pull=never`. No necesita
abrir el disco ni las credenciales del huésped. Añadir el paquete SPICE mediante
APT sí utiliza red. La etiqueta local contiene el hash de la receta, no el digest
OCI del resultado; los paquetes APT no están fijados a una instantánea.

Las etiquetas de Envy y Lenovo son específicas de cada host. Una imagen local
antigua de Lenovo no se renombra ni se borra automáticamente. Los contenedores
existentes pueden seguir usando su imagen original; crear un runtime nuevo
requiere la nueva imagen preparada. Si hay cambios pendientes en un runtime de
Lenovo, no se recrea para aplicarlos: se avisa mediante `pending` y se requiere
revisión manual. La huella de los ajustes públicos soportados del `.env`
(recursos, rutas y puertos) detecta sus cambios sin incluir la contraseña.

## Compatibilidad con Lenovo existente

El adaptador utiliza el `.env` ya configurado; **no crea uno ni cambia sus
credenciales o rutas**. Debe ser un archivo real, privado (`0600` o `0400`), del
usuario que ejecuta la VM. El parser no ejecuta shell: admite asignaciones
literales `CLAVE=valor`, comillas simples/dobles y comentarios. Las rutas pueden
usar un prefijo `$HOME` o `${HOME}`; otras expansiones, escapes ambiguos,
asignaciones duplicadas o sintaxis de shell se rechazan sin imprimir secretos.

Se necesitan `WINDOWS_STORAGE_DIR`, `WINDOWS_SHARED_DIR` y `WINDOWS_OEM_DIR`.
Para crear un runtime que falte también se necesita `WINDOWS_PASSWORD` y un único
disco principal no vacío, `data.img` o `data.qcow2`, en la raíz del almacenamiento.
Backups anidados, `setup.img`, firmware u otros nombres no satisfacen esta guarda;
formatos/layouts desconocidos requieren revisión manual, sin conversión automática.
La imagen nueva de Lenovo también aborta antes de la rama `needsInstall` del
instalador fijado: ni una ausencia de marcadores ni una versión incompatible deben
provocar reinstalación, limpieza de datos o descarga de Windows. El parche se
verifica al construir la imagen y falla si no coincide con el código esperado.
No se realiza una instalación nueva del SO de Lenovo de forma automática. La instalación inicial de Envy sigue su procedimiento
propio por [web y Looking Glass](envy-looking-glass.md).

Los contenedores antiguos sin etiquetas del nuevo controlador solo se adoptan si
su montaje `/storage` coincide exactamente con la ruta configurada y no tienen
etiquetas de otro propietario/modo. Un contenedor activo se conserva. Antes de
reiniciar uno detenido se valida el hardware; en VFIO se comprueba además que sus
dispositivos almacenados coincidan con el grupo IOMMU actual y kvmfr. Si el grupo
cambió, se rechaza el inicio: **no se borra/recrea para arreglarlo automáticamente**.

El bloqueo de Lenovo es el mismo en los dos modos GPU. También se revisan otros
contenedores activos que monten el disco, un directorio padre o un archivo dentro
de él; no solo se comprueba el nombre del runtime alternativo. Los enlaces de
disco a otros destinos se rechazan y se conservan sin escribir a través de ellos.

Las comprobaciones son guardas del controlador, no una exclusión frente a procesos
externos que deliberadamente eludan `windows-vm` y ejecuten QEMU/Podman a mano.

## Despliegue y operación

Los cambios de configuración se despliegan como una nueva generación de arranque,
no mediante un `switch` que cambie la GPU o interrumpa la VM en uso. No se cambia
el modo de arranque predeterminado ni se añaden especializaciones desde este
controlador: se respetan las que tenga declaradas cada host.

Después de un reinicio acordado, Lenovo conserva su autoinicio en los modos
existentes. Su unidad reintenta errores de prerrequisitos y salidas fallidas cada
15 segundos; un apagado limpio del huésped no lo reinicia. Ahora permanece como
supervisor mientras Windows está activo. Al apagar el host o detener la unidad
solicita apagado limpio y puede esperar indefinidamente si Windows no responde.
Envy conserva su política de autoinicio según el modo. También se configura
`user@UID.service` sin límite de parada y sin SIGKILL: de otro modo, su timeout
externo de 120 segundos podría terminar la VM aunque la unidad de usuario espere.
Este ajuste afecta al gestor completo del usuario; si un proceso impide terminar
la sesión, el apagado del host también puede quedar esperando.

No ejecutar `podman rm -f`, borrar volúmenes, arrancar dos runtimes manualmente,
reiniciar el gestor de usuario ni cambiar/rebindear la GPU para eludir una guarda.
Para diagnóstico usar `windows-vm status`, `windows-vm preflight` y el journal de
la unidad específica. No publicar `.env`, `inspect` completo ni logs con secretos.

La evaluación Nix y los motores simulados validan las rutas de control, pero no
sustituyen la prueba física de cada GPU, su reset, el host de Looking Glass en
Windows o la captura/entrada/audio.
