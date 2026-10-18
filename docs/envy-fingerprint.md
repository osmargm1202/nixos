# Envy: lector Synaptics y controlador experimental

## Alcance autorizado

Preparar y compilar **sin activar** el controlador, sin reconstruir NixOS,
registrar huellas, modificar PAM ni acceder al lector con el backend nuevo.
El usuario indicó que no necesita conservar huellas de Windows Hello.
Esto no autoriza formatear el sensor ni modificar su firmware.

El lector de esta PC es **Synaptics USB `06cb:00c9`** (`lsusb`). Con el
`fprintd` estándar instalado, `fprintd-list osmarg` respondió
`No devices available`. Que el servicio se detenga después de estar ocioso
es normal: se activa mediante D-Bus; no demuestra un fallo del daemon.

## Controlador elegido

[synaTudorMiS](https://github.com/vojtapl/synaTudorMiS) implementa el protocolo
nativo del lector Match-in-Sensor (driver `synatlsmoc`). Su README enumera
`06CB:00C9` como **tested**, pero eso no valida este ejemplar ni su firmware.
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
- `nixos/hosts/envy/fingerprint.nix`: módulo importado por Envy,
  **desactivado por defecto**. Al habilitarlo selecciona el daemon parcheado
  y las reglas udev de la biblioteca correspondiente. Rechaza TOD simultáneo.
- `flake.nix`: salidas `libfprint-synatudor` y `fprintd-synatudor` para
  compilar sin activar nada. El resto de hosts y `pkgs.fprintd` no cambian.
- `tests/envy-fingerprint.nix`: evaluación del estado desactivado/activado,
  backend, udev, conflicto TOD y conservación de la política PAM existente.

La opción no se ha establecido a `true` en ninguna configuración:

```nix
# SOLO referencia para una fase futura expresamente autorizada.
orgm.envy.fingerprint.experimental.enable = true;
```

El módulo **no agrega una política PAM nueva**. NixOS ya deriva `fprintAuth`
del servicio fprintd y utiliza `services.fprintd.package` para `pam_fprintd.so`.
Por tanto, al activar el backend en el futuro, las conversaciones PAM existentes
podrían empezar a ofrecer huella: antes de hacerlo hay que revisar explícitamente
`sudo`, SDDM, swaylock y polkit, mantener contraseña y una sesión de recuperación.
No confundir «no cambiar la política» con «ningún efecto sobre autenticación».

## Compilar y evaluar sin activar

Desde la raíz del repositorio:

```sh
nix build .#libfprint-synatudor .#fprintd-synatudor --no-link
nix eval --impure --json --file tests/envy-fingerprint.nix
nix eval --json .#nixosConfigurations.envy.config.orgm.envy.fingerprint.experimental.enable
# Debe mostrar false.
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

## Próxima fase, todavía pendiente

- Revisar los resultados de compilación y la política PAM antes de activar.
- Conservar una sesión administrativa abierta y recuperación por contraseña.
- Autorizar expresamente abrir/emparejar el sensor; activar el backend bajo
  supervisión, evitando modificaciones de autenticación no revisadas.
- Registrar una huella local y verificar coincidencia/no coincidencia y
  cancelación; nunca exportar la plantilla al repositorio.
- Probar Sway lock, login y sudo por separado, incluyendo contraseña, timeout,
  suspensión/reanudación y reinicio. No dar por terminado por una enumeración USB.
