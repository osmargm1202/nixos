# Envy: lector Synaptics y controlador experimental

## Alcance autorizado

La primera fase fue preparar y compilar **sin activar** el controlador, sin reconstruir NixOS,
registrar huellas, modificar PAM ni acceder al lector con el backend nuevo.
El usuario indicó que no necesita conservar huellas de Windows Hello.
Esto no autoriza formatear el sensor ni modificar su firmware.

Posteriormente el usuario confirmó estar presente y **autorizó una prueba
física temporal**, incluida apertura/emparejamiento, registro y verificación;
continúan prohibidos el formato, borrados existentes y cambios de firmware.
Se ejecutó el runner en bus privado con resultado funcional positivo (véase
la validación física más abajo), sin activar el módulo ni cambiar PAM.
Después el usuario autorizó **backend permanente + desbloqueo de Sway**, con
contraseña disponible y **sin huella en sudo ni SDDM**. La preparación de esa
integración se distingue abajo de su aplicación real.

El lector de esta PC es **Synaptics USB `06cb:00c9`** (`lsusb`). Con el
`fprintd` estándar instalado, `fprintd-list osmarg` respondió
`No devices available`. Que el servicio se detenga después de estar ocioso
es normal: se activa mediante D-Bus; no demuestra un fallo del daemon.

## Controlador elegido

[synaTudorMiS](https://github.com/vojtapl/synaTudorMiS) implementa el protocolo
nativo del lector Match-in-Sensor (driver `synatlsmoc`). Su README enumera
`06CB:00C9` como **tested**. Esa declaración por sí sola no valida este
ejemplar; la prueba física local documentada más abajo sí confirmó las
operaciones básicas, no la seguridad ni la fiabilidad a largo plazo.
Requiere las dos piezas siguientes, fijadas con revisión completa y hash:

| Pieza | Revisión |
| --- | --- |
| [libfprint de vojtapl](https://github.com/vojtapl/libfprint) | `92c9c2b1c2f5ff41fdf6ed705143900a191e8a59` |
| [Parche de fprintd y documentación](https://github.com/vojtapl/synaTudorMiS) | `b700a346e735e429f757828bffe7fbbdaf9f9415` |

La biblioteca se deriva de libfprint 1.94.9 y agrega una API de persistencia.
El parche de fprintd 1.94.5 permite guardar/cargar el emparejamiento y
persistirlo al cambiar, no solamente al cerrar el daemon.

No se usa `synaTudor` de Popax21 que relinka un driver Windows, ni basta añadir
el ID USB a un driver distinto. Tampoco es un controlador TOD.

### Los enlaces originales

- [Artículo Ubuntu/HP Envy](https://johanneskinzig.com/fingerprint-authentication-with-ubuntu-2404-on-my-hp-envy-notebook.html):
  trata un **ELAN `0c4c`** y la rama `elanmoc2`; no corresponde a nuestro
  Synaptics. No trasladar sus pasos `apt`, `meson install`, `ldconfig` ni
  `pam-auth-update` a NixOS.
- [Consulta del foro HP](https://h30434.www3.hp.com/t5/Notebook-Software-and-How-To-Questions/Fingerprint-drivers-on-linux/td-p/8129841):
  es una consulta de soporte de 2021, no un paquete para NixOS. La página
  devolvió HTTP 403 durante la investigación; el índice de búsqueda permitió
  confirmar el asunto, no validar todas las respuestas.

## Archivos e integración

- `nixos/hardware/fingerprint/synatudor.nix`: paquetes sin overlay global;
  conserva los install-checks de libfprint y activa explícitamente las pruebas
  virtuales de fprintd (nixpkgs no las ejecuta por defecto).
- `nixos/hardware/fingerprint/fprintd-tests-decode-errors.patch`: corrección
  solo del helper de pruebas Python, que pasaba bytes a `GLib.GError` en lugar
  de texto. Mantiene las aserciones de errores D-Bus y no modifica el daemon.
- `nixos/hosts/envy/fingerprint.nix`: módulo importado por Envy, con opción
  **desactivada por defecto**, pero ahora habilitada explícitamente en la
  configuración fuente de Envy tras autorización. Selecciona daemon y reglas
  udev, reutiliza el estado validado, bloquea el arranque si falta el pairing y
  fuerza contraseña en todos los servicios PAM gestionados. Rechaza TOD.
- `flake.nix`: salidas `libfprint-synatudor` y `fprintd-synatudor` para
  compilar sin activar nada. El resto de hosts y `pkgs.fprintd` no cambian.
- `tests/envy-fingerprint.nix`: evaluación del estado desactivado/activado,
  backend, udev, conflicto TOD, contraseña y ausencia de huella en PAM.
- `tests/envy-fingerprint-state.test.py`: ejecuta el guard generado con datos
  ficticios; prueba estado ausente, vacío, directorio inesperado y válido.

La configuración fuente de Envy selecciona:

```nix
orgm.envy.fingerprint.experimental.enable = true;
```

**Declarar la opción no significa que ya se haya aplicado al sistema activo.**
El módulo ahora extiende el submódulo `security.pam.services` para forzar
`fprintAuth=false` en todos los servicios gestionados, incluidos servicios
personalizados: evita que `services.fprintd.enable` propague huella a sudo,
login, SDDM o polkit. SDDM conserva su substack login con contraseña.
El bloqueo Qylock usa una conversación independiente desde su propio
`configDirectory`; su opt-in de huella es independiente de este PAM gestionado.
No se concede una vía IPC de desbloqueo ni se elimina la contraseña.

## Compilar y evaluar sin activar

Desde la raíz del repositorio:

```sh
nix build .#libfprint-synatudor .#fprintd-synatudor --no-link
nix eval --impure --json --file tests/envy-fingerprint.nix
nix eval --json .#nixosConfigurations.envy.config.orgm.envy.fingerprint.experimental.enable
# En la fuente actual de Envy muestra true; no indica qué generación está activa.
```

Si hay archivos nuevos aún no añadidos a Git (incluidos otros trabajos del
repositorio), las flakes Git los excluyen. Para comprobar el árbol completo sin
alterar el índice:

```sh
nix build "path:$PWD#libfprint-synatudor" "path:$PWD#fprintd-synatudor" --no-link
nix eval --json "path:$PWD#nixosConfigurations.envy.config.orgm.envy.fingerprint.experimental.enable"
```

`nix build --no-link` solo produce salidas en el store. No ejecutar sus
binarios ni `nixos-rebuild switch/test/boot` durante esta fase. No se requieren
privilegios administrativos para la compilación.

## Riesgos antes de una prueba física

1. **Experimental**: el autor declara que no está en desarrollo activo y
   documenta fugas de memoria OpenSSL, FIXMEs y falta de pruebas del driver.
   Compilar y pasar pruebas virtuales no demuestra seguridad biométrica,
   estabilidad ni funcionamiento real de `06cb:00c9`.
2. **Emparejamiento automático al abrir**: en la revisión fijada,
   `fetch_pairing_data()` puede avanzar a `OPEN_SEND_PAIR` si no hay datos
   persistentes. Abrir/reclamar el lector no debe presentarse como una prueba
   garantizadamente de solo lectura. No ejecutar ni siquiera un cliente de
   detección con el daemon experimental sin autorizar antes este riesgo.
3. **Estado no reversible con NixOS**: el autor advierte de pérdida del
   emparejamiento Windows al formatear la partición del sensor. Windows y Linux
   no comparten actualmente huellas/emparejamiento. Volver a una generación
   NixOS anterior revierte paquetes, no los datos internos del lector.
4. **Secretos en logs**: el código contiene mensajes de depuración que incluyen
   la clave privada de emparejamiento (`store_pairing_data`/`load_pairing_data`).
   No activar `G_MESSAGES_DEBUG=all`/`LIBFPRINT_DEBUG` para uso normal ni publicar
   un journal completo sin inspeccionarlo y sanearlo. No guardar datos
   biométricos, certificados o claves en Git, archivos Nix o el Nix store.
5. **Persistencia local**: el parche usa `/var/lib/fprint/0-persistent/` para
   emparejamiento y `/var/lib/fprint/` para huellas. Son datos sensibles; si
   existen, su respaldo debe ser privado y preservar permisos. No borrarlos
   como primer paso de diagnóstico. Un respaldo de archivos del host no es un
   respaldo completo del sensor ni de Windows Hello.
6. **No formatear ni actualizar firmware**: no ejecutar utilidades Python de
   ingeniería inversa, `clear_storage`, borrados globales o recetas de reseteo.
   Cualquier operación destructiva necesita autorización separada.

## Validación realizada (2026-10-18)

- Compilación de ambas salidas: **correcta** con el nixpkgs fijado en el repo.
- libfprint install-checks: **97 OK, 0 fallos, 26 omitidas**.
- fprintd, lectores virtuales en sandbox Nix (`sandbox = true`):
  **537 OK, 0 fallos, 2 omitidas**. Se conserva la exclusión de la suite
  `TestPamFprintd` de nixpkgs por sus timeouts conocidos: esto **no valida PAM**.
- Antes del parche Python de pruebas hubo 24 fallos por formatear bytes como
  texto; una compilación de control con fprintd estándar y sus pruebas
  habilitadas reprodujo exactamente los mismos 24. Se corrigieron las cuatro
  construcciones de `GLib.GError` con salida de subprocesos, sin saltar pruebas.
- Verificados los símbolos `fp_device_get_persistent_data` y
  `fp_device_set_persistent_data`, el enlace/RUNPATH de fprintd hacia la
  biblioteca modificada y la entrada udev `usb:v06CBp00C9*` en la salida.
- `tests/envy-fingerprint.nix`: todas las aserciones pasan, incluida
  conservación de contraseña y de política PAM (salvo la ruta del backend
  cuando se habilita explícitamente).
- Configuración Envy evaluada desde `path:$PWD`: opción experimental **false**,
  paquete activo declarado **fprintd estándar**. `/run/current-system` no cambió
  durante este trabajo. En la fase de compilación no se ejecutó `nixos-rebuild`,
  enrolamiento, verificación, borrado, actualización de firmware ni el daemon
  experimental sobre USB real. La prueba física posterior se describe abajo.

**Resultado de esta fase:** empaquetado y compilación validados. La suite
virtual no contiene pruebas específicas del protocolo `synatlsmoc`, ni
demuestra seguridad o fiabilidad biométrica.

## Prueba física aislada autorizada

Salida `envy-fingerprint-test`, implementada en
`nixos/hardware/fingerprint/synatudor-probe.py`. Compilación correcta y
15 pruebas del orquestador pasan sin lector ni privilegios, incluida una
comprobación real de que su bus privado rechaza al usuario normal.
**La infraestructura y las operaciones básicas del lector se probaron con
éxito en la ejecución local posterior.**
El primer intento local falló antes de abrir el lector: `pkgs.polkit` seleccionaba
la salida `bin`, que no contiene `polkitd`. Se corrigió a `pkgs.polkit.out` y
la compilación ahora valida todos los ejecutables de las rutas sustituidas,
sin ejecutarlos. El intento fallido cerró su bus privado; no quedaron procesos
de prueba activos ni se inició el daemon del lector.

```sh
nix build "path:$PWD#envy-fingerprint-test" --out-link result-fingerprint-test
sudo ./result-fingerprint-test/bin/envy-fingerprint-test osmarg
```

El ejecutable y sus dependencias quedan en el Nix store; no se reconstruye el
sistema. Requiere contraseña sudo y terminal interactiva. Crea un bus D-Bus
privado con autenticación EXTERNAL que acepta solo root y polkituser, inicia
una instancia real y separada de polkit y el daemon experimental, y no utiliza
los servicios del bus del sistema. No modifica ni detiene servicios existentes,
PAM, SDDM, qylock ni la selección de backend del sistema. El backend estándar
no soporta este lector; el runner rechaza una unidad del sistema ya experimental.

Antes de abrir el sensor espera Enter. Después guía el registro del **índice
derecho**, una coincidencia positiva, rechazo de otro dedo y verificación de
persistencia tras reiniciar únicamente su daemon privado. Si ya existe ese
dedo en el estado de prueba, omite el registro: no lo reemplaza. Comprueba los
códigos semánticos del CLI (incluido el exit 1 esperado para `verify-no-match`),
limita tiempos y termina sus procesos al finalizar/cancelar. No llama borrados,
formato ni utilidades de firmware. Ctrl+C cancela sin borrar datos.

El estado de emparejamiento/huella y el log permanecen en
`/var/lib/fprint-synatudor-test/`, propietario root, modo 0700. No se mezclan
con `/var/lib/fprint`. **No eliminar ese estado**: podría ser necesario para
reabrir el sensor sin volver a emparejarlo. No enviar `probe.log` completo;
compartir solo la salida normal del cliente y revisar errores de forma acotada.
Esto no elimina los riesgos internos del sensor: el aislamiento protege la
integración de autenticación del host, no revierte cambios de emparejamiento.

### Resultado físico confirmado por el usuario (2026-10-18)

Runner corregido:
`/nix/store/0z293b2k3k9ah68x5n79nc4yvzcf7dnk-envy-fingerprint-test/bin/envy-fingerprint-test`.
El usuario ejecutó con sudo para `osmarg` y compartió únicamente la salida
normal del cliente:

- Detectado un lector `Synaptics Tudor Match-In-Sensor`.
- Registro del índice derecho: `enroll-completed`. Los `enroll-retry-scan`
  intermedios no impidieron completar el registro.
- Dedo registrado: `verify-match (done)`.
- Otro dedo: `verify-no-match (done)`.
- Tras reiniciar el daemon privado: `verify-match (done)` sin registrar de nuevo.
- Runner finalizó con su mensaje OK y conservó el estado privado; posteriormente
  no se observaron procesos de prueba activos y `/run/current-system` no cambió.

**Conclusión acotada:** el backend funciona para registro, coincidencia,
rechazo y persistencia entre procesos en este lector concreto. Una sola
prueba negativa no mide la tasa de falsa aceptación ni demuestra seguridad
biométrica. No se han probado reinicio del equipo, suspensión/reanudación,
PAM, SDDM, desbloqueo Sway ni sudo. No hubo formato, borrado ni firmware.

## Preparación del backend permanente

Alcance autorizado: backend + bloqueo Sway; **no sudo ni SDDM por huella**.
No se copia, mueve ni vuelve a registrar la huella. La unidad usa directamente
`/var/lib/fprint-synatudor-test/`, pese al sufijo histórico `test`, para
conservar el pairing que ya funciona. El reset de lista systemd es necesario:

```ini
StateDirectory=
StateDirectory=fprint-synatudor-test
StateDirectoryMode=0700
```

Sin la línea vacía, la unidad upstream conservaría además `fprint` y exportaría
ambos nombres en `STATE_DIRECTORY`; el daemon seleccionaría el primero y podría
emparejar desde cero. `ExecStartPre` exige la ruta única correcta y un archivo
no vacío en `0-persistent/synatlsmoc/`; si falta, aborta antes de abrir el lector.
El guard detecta ausencia, no prueba integridad criptográfica de un archivo.
No borrar ese estado. En una instalación nueva se requiere recuperar sus datos
por una vía privada autorizada, no generar secretos desde Nix/Git.

Verificación de la preparación:

- Evaluación del Envy real: backend experimental seleccionado en fuente,
  **31 servicios PAM sin `pam_fprintd.so`**, contraseña conservada en
  sudo/login/polkit y SDDM con substack login.
- Unidad de servicio y script pre-start compilados correctamente, comprobando
  que el texto generado resetea la lista de StateDirectory.
- 5 tests del guard pasan con directorios ficticios; 15 del runner pasan.
- En la preparación no se cambió la generación activa. La aplicación posterior
  autorizada y sus comprobaciones se describen a continuación.

## Generación permanente aplicada (2026-10-18)

El fallo de hotplug de Qylock se corrigió y la sesión de integración validó
nativamente dos monitores, retirada/restauración, modo/escala, fallback y PAM
simulado. Se restauró el opt-in Envy `orgm.sway.fingerprint.enable=true`.

Se detectó y corrigió otro fallo de integración: sin
`environment.pathsToLink = [ "/share/orgm-qylock" ]`, el perfil del sistema
no publicaba runtime.json y el helper HOME seguía usando el bridge FP=false.
`tests/envy-fingerprint-system.test.py` verifica los archivos reales de la
generación, no solo opciones: 6 comprobaciones pasan (metadata, políticas PAM,
backend, StateDirectory y SDDM sin reinicio por cambios). La evaluación real
`tests/envy-fingerprint-host.nix` también pasa con los modos de Envy.

El usuario autorizó la generación conjunta (incluye cambios de escritorio y
componentes Windows preparados en otras sesiones). Revisó dry-activate: no
paraba SDDM ni user@1000; reiniciaba fprintd, Home Manager, polkit y udev y
recargaba D-Bus. Después creó un respaldo privado en
`/var/lib/fprint-synatudor-backup.6PW30C/state`, seleccionó el perfil system y
ejecutó `switch-to-configuration switch` sin errores.

**Primera generación permanente y perfil de arranque comprobados:**
`/nix/store/ydlf08g3bb31yvniw6jpkcn81lx0gdz6-nixos-system-envy-sway`.
Posteriormente se aplicó `whbrfn6...` con la excepción de energía, indicada abajo.

Comprobaciones pasivas tras aplicar:

- Metadata de sistema exportada, `fingerprintEnabled=true`, runtime
  `/nix/store/csvliwghj3zkc9v50y47idg9gw86d0jx-orgm-qylock-1.0`.
- Helper HOME selecciona ese runtime sobre su bridge, sin opt-out del usuario.
- PAM privado FP apunta a fprintd-synatudor; PAM privado password sigue separado.
- Ningún archivo en `/etc/pam.d` contiene `pam_fprintd`.
- Unidad fprintd usa backend experimental, guard pre-start y exactamente
  `StateDirectory=fprint-synatudor-test`, modo0700. Estaba inactive/dead sin
  fallos, normal antes de activación D-Bus; esto no valida aún su arranque real.
- SDDM sigue activo y no hay unidades de usuario fallidas; no se ejecutó un
  bloqueo, reinicio o suspensión automáticamente.

### Verificación del servicio real y excepción de energía

El primer `fprintd-verify` sin sudo encontró el lector, pero falló al abrirlo
con `endpoint stalled or request not supported`. El journal filtrado indicó
`Sensor is in TLS session but host is not`. El sensor estaba en runtime suspend,
`power/control=auto`, con autosuspensión de 2000ms.

El usuario puso **solo el lector** `/sys/bus/usb/devices/1-5` en
`power/control=on`, reinició fprintd y repitió la verificación sin sudo:
**`verify-match (done)`**, sin volver a registrar ni modificar el pairing.
La combinación resolvió ese intento; no aísla causalmente autosuspend del
reinicio del daemon ni garantiza que todos los errores TLS tengan esa causa.

Se preparó un workaround conservador y específico en udev99: dispositivo USB
`06cb:00c9`, acciones add/change, `power/control=on`. No desactiva runtime PM
para otros dispositivos ni la suspensión global del sistema. Puede aumentar
ligeramente el consumo del lector. La sintaxis pasa `udevadm verify`.

**Generación actual aplicada por el usuario y comprobada en sistema/perfil:**
`/nix/store/whbrfn6c45z9p2hqgn979zlg7ccwhr6n-nixos-system-envy-sway`.
La aplicación terminó sin errores; solo reinició udev y activación de usuario.
7 tests contra la generación activa pasan, incluido el match USB preciso.
La metadata Qylock, políticas sudo/SDDM y unidad fprintd son idénticas a la
generación anterior `ydlf08g3...`; no hay cambios de paquetes en el diff de
closures. Comprobados `power/control=on`, runtime_status=active, SDDM activo
y ninguna unidad del sistema fallida. Persistencia efectiva tras reboot y
suspensión siguen pendientes de prueba física.

### Desbloqueo físico de Qylock confirmado

El usuario confirmó que **Win+L y la huella desbloquearon correctamente**.
Tras cambiar el tema/fondo de Qylock a `material-you-dark`, informó un fallo
intermitente de reconocimiento y después confirmó que volvió a funcionar sin
intervención. La comprobación pasiva mantuvo FP=true tanto en metadata como en
preferencia efectiva, `power/control=on` y ninguna unidad de usuario fallida.
Persistían advertencias de sesión TLS remota sin sesión local al reabrir.
No hay evidencia suficiente para atribuir el fallo al tema ni declarar resuelta
la intermitencia. No se reconfiguró el lector, no hubo reset ni nuevo enrolamiento.

## Próxima fase, todavía pendiente

- Repetir desbloqueos para caracterizar la intermitencia; verificar contraseña
  real y F2, cancelación/timeout y suspensión/reanudación/reinicio con trabajo
  guardado.
- Conservar sesión administrativa y recuperación por contraseña. No reiniciar
  ni suspender automáticamente mientras el usuario tenga trabajo abierto.
- Mantener el carácter experimental y no exportar datos biométricos a Git.
