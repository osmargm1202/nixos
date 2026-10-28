# Atajo YouTube: envío HTTPS directo con autorización propia

Win+Alt+Y usa ahora un cliente HTTP, sin abrir el navegador ni cambiar el foco
local. Envía un POST JSON a `https://home.or-gm.com/api/apps/youtube/open-url`
con cookie y CSRF propios. El enlace rápido web y el campo del mando conservan
su función; este cambio corresponde al cliente del atajo.

## Autorización y persistencia

El cliente aprovecha los endpoints de aprobación ya existentes. Sin permiso,
solicita autorización en Jarq y espera hasta dos minutos. Al aprobar, guarda su
cookie en `~/.local/state/orgm-home/youtube-send/device.cookies`, modo 0600,
con el directorio en 0700. Una nueva ejecución carga esa misma identidad y
renueva la sesión. Se autorizaron las dos instalaciones solicitadas como:

- `ORGM · atajo YouTube`.
- `ENVY · atajo YouTube`.

Son identidades independientes, revocables desde Administración de Jarq. Se
aprobaron mediante la API administrativa local, usando el acceso ya autorizado
a Jarq y la aceptación del usuario de crear estos nuevos permisos. No se
copiaron cookies de navegadores ni el secreto de la sala a los equipos clientes.
La cookie sigue la caducidad renovable de la API; si se borra, revoca o se invalida
la firma del servidor, se solicita permiso de nuevo.

`orgm-send-youtube --pair` autoriza sin enviar un video. `--dry-run` imprime el
plan POST sin conectar ni crear credenciales. `--version` identifica esta
versión como `orgm-send-youtube 2 (HTTPS directo)`.

Un bloqueo de archivo impide solicitudes simultáneas del mismo equipo. Las
cookies se reemplazan atómicamente. No se siguen redirecciones HTTP ni se
repite un envío tras timeout, cuyo resultado podría haberse aplicado. Un 401
rechazado antes del despacho puede solicitar aprobación y reintentar una vez.
La selección inválida se rechaza antes de conectar o pedir autorización.

## Instalación

- Aplicación: `3352e52ce539ccc488a6c1b87a8477c8dfeee379`.
- Paquete reproducible instalado en ambos equipos:
  `/nix/store/4jkrh7bzrjnjx0s1fmgxgldv57js6dzi-orgm-send-youtube`.
- Perfil privado: `~/.local/state/orgm-home/youtube-send/profile`.
- Lanzador: `~/.local/bin/orgm-send-youtube`; detecta si un binario global es
  realmente el cliente HTTPS antes de preferirlo. Nunca deriva al antiguo
  lanzador que abría el navegador. Copia previa `sender-browser.before`.
- Nix deja de incluir xdg-utils en las dependencias del atajo. Las combinaciones
  de teclas ya instaladas no cambian ni requieren recargar los escritorios.
- No se reconstruyó ni reinició Jarq: conserva la generación 54. El receptor y
  sus endpoints no cambian; solo los clientes adquieren credenciales propias.

## Validación

- **248 pruebas unitarias** aprobadas. Las nuevas pruebas usan HTTP real,
  cookie jar real y un agente de sala simulado: aprobación, persistencia entre
  procesos, rechazo, caducidad, revocación, CSRF, redirects bloqueados,
  concurrencia y ausencia de reintentos ambiguos. Selecciones inválidas no
  envían ni inician la vinculación.
- Ruff de los módulos/tests afectados y compilación Nix del paquete aprobados.
- Aceptación real en ORGM y Envy: segundo proceso reutiliza la cookie guardada,
  sin nuevas ventanas ni cambios de foco. Comprobación de autorización de
  0.37/0.26 s respectivamente; no son tiempos de arranque de un video.
- POST HTTPS real desde cada cliente con su cookie/CSRF y un destino inválido
  devuelve **422**: la autorización llegó hasta la validación sin reproducir
  nada. El envío válido se verifica en la integración HTTP con el agente
  simulado y utiliza el mismo endpoint ya probado con el Short en Jarq.
- Dos identidades distintas verificadas en el registro de Jarq. La aplicación
  de sala se conservó durante la aprobación; servicio web activo.
- Evidencias seleccionadas sin cookies ni secretos en
  `~/.local/state/orgm-multimedia/20261028-youtube-direct-http/`.
