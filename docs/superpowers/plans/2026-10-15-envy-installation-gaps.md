# Envy — debilidades de instalación y base para instalaciones nuevas

## Objetivo solicitado

Al cerrar esta instalación, revisar con Osmarg qué debe venir funcionando desde
cero. Este registro separa defectos del proceso, provisión privada pendiente,
pruebas físicas y mejoras futuras; no autoriza cambios adicionales ni los da por
resueltos. Alcance actual: normal con Ryoku, sin Windows/server/gaming/VFIO.

## Prioridades para la revisión conjunta

| Prioridad | Debilidad / evidencia | Base esperada desde cero | Estado |
| --- | --- | --- | --- |
| Alta | Primer despliegue usó Hyprland personal en vez de Ryoku; timeout inicial 5s | Checklist de preferencias aprobado antes del primer build, alias normal evaluado como Ryoku y timeout1s probado | Configuración corregida; registrar verificación postreinicio en el informe de validación |
| Alta | Identidad age personal no provisionada; sops-nix de usuario falló en el primer arranque | Flujo privado de enrolamiento y diagnóstico explícito; no copiar claves personales automáticamente | Pendiente acordar/provisionar con usuario |
| Alta | Contraseña inicial difícil de introducir; hubo que cambiarla por petición del usuario | Credencial inicial elegida/entregada por canal acordado y prueba de login local antes del cierre | Cambio privado verificado; valor fuera de Git/Store. Revisar fortaleza y retirar archivo de recuperación tras guardarlo |
| Alta | Pruebas SSH no prueban audio/sesión gráfica ni cada puerto | Checklist de aceptación local: login, audio/micrófono, cámara, brillo, suspensión, pantallas y conectividad | Requiere pruebas físicas del usuario; cámara no enumerada en primer arranque |
| Media | Btrfs con subvolúmenes no equivale a snapshots ni backup recuperable | Acordar política de snapshots, retención, copia externa y ensayo de restauración | No implementado; Optane intacto, no es respaldo independiente al compartir tarjeta H10 |
| Media | Snapshot dotfiles incorpora residuos locales ignorados mediante builtins.path | Fuente de configuración reproducible también desde checkout limpio | Diferencia de hash documentada; limpieza/refactor global fuera de este alcance |
| Media | Suite flake-architecture ya tenía una comprobación textual obsoleta | Suite base verde antes de usarla como puerta de nuevas instalaciones | Falla preexistente documentada; no declarar éxito global |
| Media | Tests de disco no cubren todas las negativas de mapping/tipo/capacidad/UID/comandos de inspección fallidos | Probar cada guarda antes de reutilizar automatización destructiva | Guardas reales revisadas; ampliar pruebas pendiente |
| Media | Paquetes Flatpak se instalan después del boot | Mostrar progreso y diferenciar sistema listo de catálogo descargado | Antes de Ryoku: servicio terminó con éxito y 24 apps enumeradas; no prueba cada app |
| Baja | README contiene ejemplo findmnt con varios destinos inválido | Runbook con comandos ejecutables y evidencia por punto de montaje | Informe de validación ya incluye loop válido; README pendiente |

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
