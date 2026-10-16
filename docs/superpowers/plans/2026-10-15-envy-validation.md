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
- Transferencia de cierre: PASS, 2795paths al store `/mnt`, no al tmpfs del live;
  `nix-store --store /mnt --check-validity` pasó.
- Repositorio completo y planificación: COPIADOS a `/mnt/home/osmarg/Hobby/nixos`.
- Perfil Wi-Fi privado persistente, autoconnect/MACpermanente y claves HOST SSH
  del propio live: PROVISIONADOS, permisos verificados.
- Contraseña inicial aleatoria: aplicada privadamente a shadow tras activar
  usuario1000:1000; hash comparado sin imprimirlo. `passwd -S osmarg`: P.
  Huella clave autorizada comprobada y claves HOST SSH iguales a las del live.
- `nixos-install --system <cierre> --no-root-passwd --no-channel-copy`: PASS,
  systemd-boot instalado en EFI, entrada Linux Boot Manager creada.
- Menú predeterminado `nixos-generation-1.conf`, solo normal. HP dejó la entrada
  Linux0002 al final, así que se puso primero y se seleccionó BootNext0002 para
  no volver al USB instalador. No se borraron otras entradas de firmware.
- Reinicio: PASS, SSH como `osmarg@10.0.0.50` volvió con la misma clave HOST.
  Hostname `envy`, kernel6.12.96, raíz Btrfs@root en SSD y cierre75mf correctos.
- Arranque medido: 27,939s total (incluye firmware/loader), graphical.target
  tras 4,669s de userspace. En greeter: 1,1GiB RAM; zram5,7GiB activa sin uso.
  No es todavía un benchmark de la sesión personal ni de juegos.
- Wi-FiAX201/conexión/DHCP/ruta/DNS: PASS; SSH, NetworkManager, SDDM y
  HomeManager activos. 0 unidades de sistema fallidas en la comprobación.
- Intel i915 y NVIDIA580.173.02/MX2502GiB: drivers ligados. Vulkan enumera ambos,
  VAAPI Intel iHD inicializa y ofrece perfiles decode/encode. No confundir esa
  enumeración con render de un juego o selección efectiva de GPU de cada app.
- ALSA/SOF detecta audio analógico y HDMI1/2/3. PipeWire/WirePlumber arrancan;
  sin login gráfico personal, sesión SSH no mostró dispositivos de audio.
  Revalidar en la sesión activa y probar parlantes/micrófono físicamente.
- BluetoothAX201 presente. USB/Synaptics/lectorSD y conectores internos/DP
  enumerados. Ethernetr8169 disponible, sin cable durante la comprobación.
- Cámara: NO enumerada, sin `/dev/video*`; revisar físicamente antes de atribuir
  fallo a controlador. Pantallas y todos los puertos siguen pendientes de prueba.
- SMART ambos NVMe PASS y fingerprints de Optane/USB iguales también postboot.
- Aplicaciones Flatpak declaradas: servicio `flatpak-managed-install` continúa
  instalándolas en segundo plano (activating, sin fallo registrado). No se
  declara que todas las aplicaciones estén descargadas ya.
- SOPS de usuario: unidad fallida por identidad age aún no provisionada;
  esperado, no bloqueó HomeManager, SSH ni greeter. NO copiar claves privadas
  personales automáticamente; completar después con el usuario.
- Avisos kernel observados: sensor `lis3lv02d` no reconocido y errores ACPI/WMI
  CreateField de BIOSF.05(2020). No impidieron este arranque; no se cambian BIOS,
  ACPI global ni firmware a ciegas. Revisar sensores/teclas/brillo en pruebas.
- `efibootmgr` no está instalado en el perfil normal; para consulta posterior
  usar `bootctl status` o herramienta efímera, no asumir ese comando disponible.

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

## Decisiones operativas y pendientes de revisión

1. Ejecutar la instalación directamente tras aprobación explícita, sin otra
   ronda de diseño. Cualquier corrección de alcance sigue en fases futuras.
2. Mientras llegaba consentimiento de worktree se trabajó en rama feature sin
   alterar diffs ajenos; al recibirlo se aisló la misma rama y se restauró master.
3. No arreglar el test textual obsoleto ajeno; permanece rojo y no se declara
   suite global verde ni rama integrada en master. Suites relevantes sí pasaron.
4. Mantener snapshot dotfiles ignorados sin limpieza global: un checkout limpio
   puede tener otro hash de fuente, aunque seleccione los mismos ajustes.
5. Windows/VFIO/server/gaming y paquetes específicos gaming siguen diferidos;
   Deskflow normal seleccionado sí se conserva. Si se necesitan otras
   integraciones específicas de Lenovo/orgm, incorporarlas explícitamente.
6. Provisión privada de red/password/hostkeys y cierre fue una puerta de
   despliegue obligatoria, verificada antes del reboot; no escribir secretos
   en código. Contraseña temporal comunicada solo a solicitud del usuario;
   NO incluir su valor en este registro ni memoria.

Menores diferidos: ampliar negativas de guardas de disco para mapping/tipo/
capacidad/UID/comandos fallidos; corregir el comando múltiple findmnt del README
(arriba se proporciona el loop válido). No afectan a las comprobaciones reales
de identidad/montajes ya realizadas, pero conviene resolverlos antes de reutilizar
el instalador en otro contexto. Rama `feat/envy-normal` conservada, sin push/merge.

## Corrección Ryoku y menú1s (despliegue posterior)

- Petición explícita: normal debe usar Ryoku, no el Hyprland personal inicial;
  menú1s y cambio de contraseña por canal privado (valor NO registrado aquí).
- `envy`, `envy-normal` y `envy-ryoku` seleccionan Ryoku. Regresión evaluada
  observada RED con configuración inicial y GREEN tras corregir perfil/timeout.
- Build completo PASS: `/nix/store/s8wxc65v0r9f04c06r4h3v453026lnyz-nixos-system-envy-ryoku`,
  drv `aq572pqb31gfm0f84ir1w4kngjgndria`. Cierre30,5GiB (no confundir con RAM
  o espacio adicional en disco; comparte rutas con la generación anterior).
- Build demorado por timeout de un NAR en cache.nixos.org; recuperó sin cambiar
  fuentes/lockfile. Copia de2001rutas al store instalado completó con exit0.
- Revisión independiente de corrección: sin hallazgos sustantivos. Suites envy
  normal/disk/inventory y Ryoku profile/transition PASS de nuevo antes de reboot;
  shortcuts/folder-icons/rofi PASS con Lua/esquemas GTK explícitos en entorno.
- Fuente completa/metadata Git sincronizada al destino hasta commit `e704d08`;
  cuatro diffs previos y documento previo del usuario conservados sin commit.
- Generación2 preparada con `nix-env --profile .../system --set` y
  `switch-to-configuration boot`, exit0. Default `nixos-generation-2.conf`
  (Ryoku), loader.conf timeout1 y EFI timeout1 establecidos. Generación1
  Hyprland conservada para recuperación. Helper temporal de copia root eliminado.
- Contraseña solicitada verificada por sudo antes de preparar Ryoku; mutableUsers
  conserva cambios privados. Probar de nuevo tras el nuevo arranque.
- Antes de este reboot el instalador Flatpak terminó con Result=success,
  24 aplicaciones enumeradas. Eso no valida el funcionamiento de cada app.
- Usuario autorizó el reinicio y se solicitó; reconexión SSH/verificación de
  sesión Ryoku aún PENDIENTES. No afirmar arranque Ryoku exitoso hasta verificar.

Revisión conjunta solicitada por el usuario:
`docs/superpowers/plans/2026-10-15-envy-installation-gaps.md`. Es una lista de
brechas y aceptación para futuras instalaciones, no cambios extra autorizados.

### Verificación recuperada y corrección de salida fantasma

- El usuario confirmó arranque y volvió SSH. Se comprobó cierreRyoku `s8wxc...`,
  sesión gráfica personal Hyprland/Ryoku, shell y materializador activos,
  HomeManager inicialmente activo, contraseña privada conservada y menú1s.
  No se estableció la causa del intervalo previo sin conexión.
- Problema real reportado: al cambiar de workspace se perdía el escritorio/cursor.
  Hyprland tenía eDP-1 real1920x1080 más DP-1 a800x600, identificación vacía y
  EDID de0bytes. Workspace2 estaba enDP-1; el usuario confirmó ningún monitor,
  adaptador ni dongle conectado. No era necesario cambiar drivers del cursor.
- Un `hl.monitor` live aislado fue revertido por el manejo automático de layout;
  un override manual persistente, cargado tras el generado, sí mantuvo el ajuste.
- Solución exclusiva de envy: seed declarativo
  `dotfiles/config/hosts/envy/profiles/ryoku/.config/orgm-ryoku/monitors_user.lua`
  desactiva soloDP-1, sin desactivar eDP ni otros conectores. El preparador ya
  existente lo instala solo cuando no hay override personal. Al conectar un
  monitor real enDP-1, quitar la regla del override personal y revisar el seed.
- Prueba `tests/envy-monitors.bats.sh`: RED por seed ausente; GREEN ejecutando el
  Lua realmente seleccionado por HomeManager y comprobando salidas desactivadas.
  envy-normal/ryoku-transition también PASS. Revisión independiente sin hallazgos
  sustantivos (revisor no pudo ejecutar Lua; ejecución completa hecha por operador).
- Build nuevo PASS, cierre
  `/nix/store/zqddg1wrvn7ha6nskwjry19x533xcz9j-nixos-system-envy-ryoku`.
  Copia completada, helper temporal borrado. Override aplicado por reload sin
  cerrar sesión. Verificación repetida: soloeDP activa, workspaces en eDP,
  coordenadas de cursor dentro del panel real, sin errores de configuración.
  Confirmación visual del cursor por el usuario sigue siendo prueba física.
- IMPORTANTE: `switch-to-configuration switch` seleccionó generación3 y aplicó
  links/override y Ryoku, pero devolvió exit4 al fallar `home-manager-osmarg` en
  su pasoSOPS, porque sigue sin identidad age. El ajuste de monitores SÍ está
  declarado/materializado y funcionando por comprobación posterior, pero NO
  declarar el rebuild global limpio: queda1unidad de sistema fallida porSOPS.
  No se copian claves privadas ni se deshabilitan secretos para ocultar el fallo.
- Timeout1/defaultgeneración3 y autenticación sudo conservados tras switch.
  Generaciones previas disponibles. No hizo falta otro reinicio para este fix.
- Prueba textual `flake-architecture.bats.sh` continúa fallando con
  `host registry must receive the configuration hostname` (preexistente).
- Verificación amplia adicional: `nix flake check --no-build` evaluó múltiples
  configuraciones, incluido envy, pero terminó exit1 con `interrupted by the
  user` al pasar por Lenovo/GNOME. No se atribuye causa sin evidencia ni se
  declara ese check completo/verde. Suites enfocadas y fullbuild de envy sí PASS.

- Confirmación posterior del usuario: workspaces/cursor ya funcionan. Se cierra
  esa prueba visual concreta; no las demás pruebas físicas ni el fallo SOPS/HM.

## Refuerzo posterior: juegos, fuente estable y recuperación local

- Usuario confirmó expresamente Steam/emuladores/herramientas como Lenovo dentro
  de normal. SOPS deja de ser prioridad: usuario aportará archivo cuando quiera.
  No se modifican secretos ni se afirma que la unidad SOPS/HomeManager esté verde.
- Configuración actual: `/nix/store/fb3mvk9ps0bzg54lb3h7i2wy2fq4bli2-nixos-system-envy-ryoku`,
  generación4, timeout1, Wi-Fi/SSH/contraseña conservados, sin otro reinicio.
- Aplicaciones de juegos en extraModules del escritorio, no hardware base. Helper
  nvidia-game compartido sin cambiar semántica Lenovo. Steam, GameMode, Gamescope,
  MangoHud, ProtonUp-Qt y Sunshine presentes; Sunshine unit active/running.
- OpenGL con glxinfo: Intel UHD CML GT2; mismo probe vía nvidia-game: NVIDIA
  GeForceMX250. Es render real de contexto OpenGL, no benchmark/FPS de juegos.
- Flathub falló primero por timeout de objetos DuckStation; remote-info y descarga
  directa confirmaron app válida. Reintento automático terminó Result=success:
  RetroArch, Dolphin, Cemu, Ryujinx, DuckStation, PPSSPP, PCSX2, RPCS3 y shadPS4
  enumerados instalados. No se descargan ROMs/juegos ni se validan todos los emuladores.
  Avisos EOL de runtimes24.08 observados, sin forzar cambio incompatible.
- Guardas de disco ahora comprueban estado del comando antes de comparar stdout.
  Fallo real valid-output+exit7 reproducido y cerrado; PATH de pruebas hermético,
  identidad/tipo/tamaño/UID/montajes/errores sin escrituras. No se formateó nada.
- Hostname test obsoleto reemplazado por contrato Nix evaluado para tres roles;
  mutaciones temporales de hostname rechazadas.
- Filtro dotfiles previo a builtins.path: raíces consumidas, metadata y directorios
  vacíos filtrados; hash workingtree igual a gitarchive del árbol real. Conserva
  scripts ejecutables, symlinks y contenido. No excluye configuraciones reales sin
  trackear ni promete reproducibilidad de todo el sistema/cleanclone con prefs pendientes.
- Snapper: diarios root/home, retención7diarios, manuales3 con number cleanup;
  otros buckets0, sin snapshots por boot ni configuración de cuotas. Ambos
  .snapshots preparados como subvolúmenes root:root0700; snapshots ro=true.
- Prueba real: archivo efímero en home snapshot1, archivo activo modificado,
  restauración a ruta NUEVA y hash original comprobado; archivo activo se mantuvo
  modificado. Snapshot de prueba y archivos efímeros eliminados. Home timeline2 y
  root timeline1/manual2 creados; cleanup y timers verificados. No prueba de rollback
  de todo el sistema; EFI/Nix y otros subvolúmenes fuera de esas copias. No backup externo.
- Revisión independiente sin Critical/Important; cuatro suites clave corroboradas
  por revisor. Suite enfocada final15PASS/1FAIL: user-program-isolation falla igual
  en master por paquetes Jarq no esperados. Flakecheck global terminó incompleto
  con interrupted by the user. No afirmar suite global verde ni integrar rama.
- Prueba física por cable único (15 de octubre, 17:02): usuario confirmó solo
  USB-C. LGULTRAGEAR109MXYG4W010 detectada enDP-2, EDID256bytes, activa a
  2560×1440@143,933Hz, escala1, a la derecha del panel interno eDP1920×1080,
  escala1,25. Hotplug registrado17:01:46; DP-1 sinEDID permanece desactivada y
  hyprctl configerrors vacío. Usuario confirmó imagen visible por USB-C y después
  precisó contenido cortado en CUALQUIER ventana, no solo ancho de columna0,5.
  Medición posterior de Firefox y terminal de prueba cabe dentro de la LG.
  Prueba temporal de posición positiva no confirmó solución; se restauró posición
  previa sin cambiar escala/layout. Usuario decidió posponer este diagnóstico.
  Retirada y reanudación aún por probar; no se declara ajuste visual validado.
- HDMI solo: usuario confirmó entrada HDMI seleccionada, «sin señal» y cable
  reajustado. A16:47 seguía sin EDID de LG; HDMI-A-1 yDP-2 desconectados.
  Esto no establece aún si la causa es cable, monitor, puerto, firmware o driver.
- Usuario reporta varios apagados/encendidos de pantalla al volver de sleep.
  Suspend/resume s2idle16:13–16:18 y unidades NVIDIA terminaron satisfactoriamente;
  no equivale a reanudación visual correcta. No se ha cambiado driver/kernel.
- Sondeo temporal deDP-1 inconcluso: no llegó a activarse. Al recargar apareció
  una línea final extra `})` en monitors.lua generado; error reproducido con Lua,
  backup conservado y línea retirada restaurando escala1,25. Recarga posterior
  sin errores. Causa de generación aún no establecida; no parche especulativo.
- SKU leído7PS43UA#ABA: ficha de HP identifica17m-ce1013dx y especifica USB-C con
  DisplayPort1.2 y HDMI2.0. Capacidades de ficha no equivalen a prueba física.
  [Ficha del fabricante HP](https://files.bbystatic.com/gUeZ%2Fnd3maD2L7Jr56nDHA%3D%3D/53411AC3-93D9-42BB-B87F-F7DB6D08954F.pdf).
- Privileged Nix copy helper temporal eliminado; sin trusted-users permanente,
  sin push/merge ni cambios a los cuatro diffs previos del usuario.

## Pendientes actualizados por el usuario

- Recorte de contenido en cualquier ventana de la LG: diagnóstico pospuesto por
  petición expresa; no seguir pidiendo fotos/cambios de cable ahora. HDMI no
  detectado, retirada/reconexión y parpadeo al despertar también siguen abiertos.
- Registro de usuario durante resume17:59: `ryoku wm act output.power on` falló
  porque `ryoku-wm-hyprland` no encuentra `hyprctl` en PATH. Reproducido con el
  PATH real; corregido declarativamente en `runtime-path.nix`, con pruebas
  RED/GREEN, build y revisión aprobada. Activación y aceptación física separadas;
  no prueba causa del recorte ni estabilidad física del resume.
- Falta aceptación física de audio/micrófono/cámara (revisar kill switch), brillo,
  USB/lectorSD, conectividad bajo uso, juegos/streaming y consumo/temperatura.
- Backup externo sin destino acordado; automatización privada inicial y auditoría
  de servicios/firewall pendientes. SOPS opcional y Optane intacto. Tests globales
  no cerrados, documentación de esta ronda aún sin commit/integración.

## Comprobación de inicio y Num Lock

Consulta posterior: loader.conf activo contiene timeout1/defaultgeneration4.
Hyprland input:numlock_by_default=true y teclados NumLock=true. SDDM tenía
Numlock=none; añadido al host autoNumlock=true y settings.General.Numlock=on.
Contrato envy-normal RED por falta de política greeter y GREEN tras declaración.
Actualización de migración: política desplegada en generación5, con timeout1
verificado y display-manager sin reiniciar. Falta aceptación visual del NumLock
del greeter en su próximo arranque, no despliegue de la declaración.
Consulta sobre otros perfiles: técnicamente preparables mediante configuraciones
independientes eval/build, sin activación; aún no implementados por esa consulta.

## Cierre de migración de hosts

Ver `2026-10-15-host-desktop-deployment.md`: cinco configuraciones públicas y
builds completos aprobados; solo Envy activado. PATH de hypridle comprobado en
el proceso real, Hyprland sin errores, Bitwarden CLI disponible, startup nativo
migrado. Switch terminó con código4 en la etapa SOPS sin identidad privada,
después de enlazar paquetes y aplicar la migración; no afirmar activación limpia.
LG, aceptación física del resume y perfiles avanzados de Envy siguen separados.
