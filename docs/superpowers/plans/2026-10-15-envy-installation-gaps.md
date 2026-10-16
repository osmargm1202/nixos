# Envy — debilidades de instalación y base para instalaciones nuevas

## Objetivo solicitado

Al cerrar esta instalación, revisar con Osmarg qué debe venir funcionando desde
cero. Este registro separa defectos del proceso, provisión privada pendiente,
pruebas físicas y mejoras futuras; no autoriza cambios adicionales ni los da por
resueltos. Alcance actual: normal con Ryoku y aplicaciones de juegos; sin perfiles Windows/server/gaming/VFIO.

## Prioridades para la revisión conjunta

| Prioridad | Debilidad / evidencia | Base esperada desde cero | Estado |
| --- | --- | --- | --- |
| Alta | Primer despliegue usó Hyprland personal en vez de Ryoku; timeout inicial 5s | Checklist de preferencias aprobado antes del primer build, alias normal evaluado como Ryoku y timeout1s probado | Corregido y verificado tras arranque: Ryoku/timeout1; faltó contrato explícito antes del primer despliegue |
| Aceptado por usuario | Identidad age personal no provisionada; sops-nix de usuario falló en el primer arranque y en el rebuild posterior hizo fallar home-manager-osmarg (switch exit4) | Flujo privado de enrolamiento y diagnóstico explícito; no copiar claves personales automáticamente | Usuario no quiere priorizarlo; aportará el archivo cuando le interese. No transferir claves ni afirmar unidad verde |
| Alta | Contraseña inicial difícil de introducir; hubo que cambiarla por petición del usuario | Credencial inicial elegida/entregada por canal acordado y prueba de login local antes del cierre | Cambio privado verificado; valor fuera de Git/Store. Revisar fortaleza y retirar archivo de recuperación tras guardarlo |
| Alta | Salida fantasma DP-1 conectada sin EDID ni monitor: workspace2/cursor fuera del panel | Comparar salidas reales con inventario y probar cambios de workspace en sesión local | Corrección host-only aplicada y declarada; usuario confirmó que ya funciona. DP-1 queda desactivada hasta revisar un monitor real en ese conector |
| Alta | Pruebas SSH no prueban audio/sesión gráfica ni cada puerto | Checklist de aceptación local: login, audio/micrófono, cámara, brillo, suspensión, pantallas y conectividad | Requiere pruebas físicas del usuario; cámara no enumerada en primer arranque |
| Media | Btrfs con subvolúmenes no equivale a snapshots ni backup recuperable | Acordar política de snapshots, retención, copia externa y ensayo de restauración | Implementados snapshots diarios root/home, 7 diarios y manuales con cleanup hasta3; recuperación real de archivo probada. Falta respaldo externo; Optane intacto |
| Alta | Particionado automatizado, pero parte de la provisión privada de red/credenciales necesitó pasos operativos fuera del flujo versionado | Instalación reproducible de extremo a extremo: pedir entradas privadas, validar acceso/red y repetir sin exponer secretos ni sobrescribir credenciales existentes | Runbook con puertas de reanudación/red/acceso documentado; automatización privada integral aún no consolidada. No implica guardar secretos en Nix |
| Media | Snapshot dotfiles incorpora residuos locales ignorados mediante builtins.path | Fuente de configuración reproducible también desde checkout limpio | Corregido filtro previo a builtins.path: metadata, raíces no consumidas y directorios vacíos excluidos; fuente real igual a git archive. No promete excluir configuraciones reales sin trackear |
| Media | Suite flake-architecture ya tenía una comprobación textual obsoleta | Suite base verde antes de usarla como puerta de nuevas instalaciones | Comprobación obsoleta sustituida por contrato Nix evaluado, GREEN y mutaciones rechazadas. Otro test global de aislamiento Jarq sigue fallando igual en master |
| Media | Tests de disco no cubren todas las negativas de mapping/tipo/capacidad/UID/comandos de inspección fallidos | Probar cada guarda antes de reutilizar automatización destructiva | Ampliado con PATH hermético. Encontrado/corregido fallo real: stdout correcto + exit no cero podía superar comprobación. Negativas y no escrituras verificadas |
| Media | Paquetes Flatpak se instalan después del boot | Mostrar progreso y diferenciar sistema listo de catálogo descargado | Antes de Ryoku: servicio terminó con éxito y 24 apps enumeradas; no prueba cada app |
| Baja | README contiene ejemplo findmnt con varios destinos inválido | Runbook con comandos ejecutables y evidencia por punto de montaje | README e informe ahora contienen loop válido por destino |

## Aspectos que no deben convertirse en cambios a ciegas

- Secure Boot desactivado y raíz sin cifrado: revisar modelo de amenazas y
  recuperación antes de decidir cifrado/arranque verificado; no prometidos en
  esta fase ni activables sin planificación de claves y acceso remoto.
- Red/SSH: verificar política del firewall, claves autorizadas, actualizaciones
  y exposición de servicios del perfil normal antes de convertirlo en servidor.
  En el primer escritorio se observaron listeners en todas las interfaces
  (SSH22, OpenRGB6742, descubrimiento5353/5355, KDE Connect1716). Un listener
  no demuestra accesibilidad a través del firewall; auditar necesidad y reglas
  por separado. Ryoku también incluye Docker: normal no equivale a base mínima.
- MX250 Pascal: driver propietario580 fijado por compatibilidad; medir offload,
  consumo, temperatura/autonomía y suspensión con pruebas reales. Enumerar Vulkan
  no demuestra qué GPU renderiza una aplicación.
- Avisos ACPI/WMI y sensor desconocido: correlacionar con fallos observables;
  no modificar BIOS/ACPI solo para ocultar mensajes.
- Windows, passthrough, gaming, servidor y posible uso de Optane quedan en fases
  posteriores con nuevas pruebas y autorizaciones; no son fallos de normal.

## Siguiente conversación

1. Revisar con el usuario las debilidades que él haya observado.
2. Priorizar qué entra en la plantilla común de instalaciones nuevas frente a
   ajustes exclusivos de envy.
3. Definir aceptación, recuperación y manejo privado de credenciales/secretos.
4. Aprobar un plan separado antes de implementar refuerzos.

## Confirmación del usuario

El usuario confirmó que el cambio de workspaces/cursor ya funciona. El arreglo
DP-1 es una excepción específica de este hardware, no una solución universal de
autodetección. SOPS queda aceptado hasta aportar archivo; reproducibilidad de dotfiles, recuperación
local y guardas se han reforzado. Respaldo externo y pruebas físicas siguen pendientes; esa confirmación no convierte el rebuild en verde.

Actualización del usuario: SOPS no es prioridad; solo le interesa cuando él
aporte su archivo. Se conserva esa limitación conocida sin provisión automática
ni cambio de secretos. El esfuerzo pasa a juegos, pantallas, pruebas y fuente
reproducible; no seguir tratándolo como bloqueo de aceptación del usuario.

## Resultado del refuerzo posterior

- Steam/emuladores/Sunshine en normal confirmados expresamente por usuario.
- Nueve emuladores declarados ya instalados; Flathub terminó con éxito tras un
  reintento por timeout. Avisos de runtimes EOL24.08 observados: requieren
  seguimiento del empaquetado upstream, no forzar un runtime incompatible.
- OpenGL predeterminado Intel UHD; el mismo probe con nvidia-game usa MX250.
- Snapper root/home y timers activos, root:root0700 y snapshots read-only; archivo
  recuperado a destino nuevo y comprobado sin sustituir el archivo activo.
- Suite enfocada:15/16 PASS; única falla Jarq preexistente, reproducida en master.
  Flakecheck amplio incompleto con mensaje interrupted by the user; no globalgreen.
- USB-C único confirmado: LG enDP-2 a2560×1440~144Hz y usuario confirma imagen.
  HDMI único sigue sin detectar LG tras ajustar cable/entrada. Contenido cortado
  en cualquier ventana de la LG; usuario pospone diagnóstico. Retirada y resume
  estable pendientes; no declarar HDMI funcional ni defecto de hardware probado.
- Resume: además del parpadeo reportado, journal confirma que el proveedor WM de
  Ryoku no encuentra hyprctl en PATH al ejecutar output.power on. Reproducido y
  corregido declarativamente, con pruebas y build aprobados. Activación y prueba
  física de resume se registran aparte; relación con recorte desconocida.
