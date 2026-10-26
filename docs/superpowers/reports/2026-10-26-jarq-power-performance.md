# Jarq: apagado y rendimiento de ORGM Home

Aplicación publicada `aa9d24fef9672d9966c243e7b7f739a682abb916` (funciones en `93d2458`, ajuste de caché de rechazos en `aa9d24f`). Sistema aplicado `/nix/store/vj5pik5ww9igvzf1sbyicr5c4slwpss4-nixos-system-jarq-jarq-multimedia`, generación 51. Se conserva el perfil predeterminado jarq-multimedia, las ventanas, la exposición HTTPS privada, AirPlay y Bomba/Home Assistant. No se reinició ni apagó la laptop física durante la entrega.

## Encendido

El dashboard y el mando web muestran Apagar en el encabezado; la barra nativa incorpora el icono de encendido antes de la flecha de plegado. Ambas superficies ofrecen Apagar/Reiniciar y requieren una segunda confirmación. Cancelar queda como primera acción de la confirmación web. En la superficie nativa abrir/cancelar conserva la aplicación enfocada. El helper corre fuera del target de sesión, detiene controles y portales antes de solicitar la operación a logind, y Polkit permite power-off/reboot únicamente a media, sin sudo. La suspensión continúa deshabilitada.

Se verificó el botón nativo instalado en Jarq con eventos Wayland reales: abrió Encendido, mostró la segunda confirmación y Cancelar cerró el panel conservando Inicio. Capturas `/tmp/orgm-power-native-real.png` y `/tmp/orgm-power-home-real.png`; log `/tmp/orgm-power-ui-acceptance.log`. El apagado real y reinicio se probaron en VM, incluyendo arranque posterior y ausencia del error de conexión Wayland al salir. La operación física no se ejecutó.

## Presión de CPU

Se muestrea /proc/stat cada cinco segundos, usando diferencias de contadores. Si la CPU total permanece al menos en 80% durante 60 segundos se termina la última fuente elegible dejada en segundo plano. Debe llevar treinta segundos fuera de foco y hay un máximo de un cierre por minuto. Inicio, la fuente enfocada, Spotify, terminales y AirPlay se protegen. Se vuelve a consultar el foco bajo el lock del controlador antes de actuar. Solo se señalan procesos del mismo UID y se comprueba la fecha de inicio del PID; se termina su descendencia con SIGTERM y, si hace falta, SIGKILL. Flatpak recibe el ID fijo de su fuente. El cierre aparece como aviso en el mando y en el journal. Los perfiles web se conservan; los borradores no guardados de una fuente cerrada pueden perderse.

Pruebas de umbral, duración, picos breves, protección y enfriamiento; además, un caso con procesos Linux reales ejercita la elección por presión sostenida y termina únicamente el proceso de segundo plano, manteniendo vivo el que representa la fuente activa. No se provocó saturación de un minuto en Jarq mientras el usuario utilizaba la plataforma. Al comprobar el sistema instalado, el monitor reportó aproximadamente 11,7% de CPU y no cerró fuentes. Esto valida el mecanismo de alivio; no certifica la causa exacta de todas las congelaciones de video.

Las capturas dejan de redibujar todas las aplicaciones al ver una película: se refrescan cada veinte segundos cuando Inicio o el catálogo remoto las solicitan y se omiten con CPU alta. El catálogo conserva la última captura disponible.

## Assets, Nginx y FastAPI

Las 22 portadas PNG de 1586×992 se redujeron a un máximo de 640×400 y WebP calidad 83; cinco fondos también usan WebP. Los 27 archivos pasan de 54.081.898 a 1.065.566 bytes: reducción de 98,0%. No se generó contenido visual nuevo; la procedencia y prompts permanecen documentados y los PNG originales están en el historial/directorio de generación. El conjunto estático completo ocupa aproximadamente 1,5 MB.

Un manifiesto de hashes versiona cada URL y sus dependencias CSS. HTML y JavaScript usan el mismo hash por archivo, evitando descargas duplicadas y permitiendo reutilizar imágenes sin cambios después de otra entrega. Nginx sirve /static/ directamente desde el paquete, con sendfile, open_file_cache, gzip y caché pública immutable de un año para URLs versionadas. El acceso local por FastAPI aplica ETag/revalidación y gzip nivel 4. Las URLs sin versión tienen una hora y revalidación. HTML, sesiones, controles y capturas privadas conservan no-store, incluyendo respuestas rechazadas. El test de Nginx detectó que antes el middleware devolvía rechazos sin no-store; se corrigió y se volvió a ejecutar la VM.

Comprobación HTTPS real en Jarq (`/tmp/orgm-power-perf-acceptance.log`): portada Spotify de 38.242 bytes, aproximadamente 6,9 ms de transferencia total local; repetición condicional HTTP 304 con cero bytes de cuerpo; JavaScript comprimido de 6.983 bytes; estado autenticado en aproximadamente 29,5 ms. La API privada mantuvo no-store y media recibió CanPowerOff=yes. Son tiempos desde Jarq hacia su propio Nginx; no se presentan como latencia de un teléfono por Internet ni una prueba de FPS.

## Red y vinculación

Al diagnosticar la lentitud, Jarq respondía por LAN y su IP Tailscale pero fallaban DNS y conexiones HTTPS externas. La consulta por nombre tardaba unos quince segundos en fallar; el mismo /api/health con IP fija devolvía 200 en unos treinta milisegundos. ICMP al gateway respondía. Se reconectó el mismo perfil ORGM5G, sin cambiar red ni credenciales. Después DNS respondió en unos 65 ms y HTTPS por nombre en unos 46 ms. No se atribuye exclusivamente al driver ni se afirma estabilidad permanente sin seguimiento.

Durante una inspección de procesos se imprimió accidentalmente la clave interna de vinculación del kiosk. Se informó al usuario y se renovó mediante escritura atómica, preservando dueño y permisos privados; la clave anterior y sus cookies dejan de ser válidas. API, kiosk y DIAL se iniciaron con la nueva clave. No se registra ningún valor de clave en este informe, repositorio, manifiesto o evidencias archivadas. El teléfono se vuelve a vincular mediante un código local de seis dígitos, válido dos minutos y un solo uso. El token DNS de Cloudflare no se modificó.

## Validación y publicación

198 pruebas unitarias; Ruff de errores de sintaxis/variables y comprobación completa de los nuevos módulos; navegador con 123 acciones (`/tmp/orgm-power-perf-browser-final.log`, capturas `/tmp/orgm-browser-om0yi1n9`); regresión de Bomba con acciones simuladas (`/tmp/orgm-power-perf-pump.log`). Sesión Sway/Chrome/Quickshell final: `/tmp/orgm-power-perf-native-final.log`, evidencia `/tmp/orgm-sway-smoke-1u4kihdr`, incluyendo mando en Inicio, selector de apps, confirmación/cancelación de encendido, cierre de popup y teclado. Evaluación Nix del perfil y build final correctos. VM final `/nix/store/ck8z4ng6h9pmmsk6zb1v438qd40hvxn9-vm-test-run-orgm-multimedia-boot`: Nginx cache/gzip/no-store, reinicio, apagado y vuelta a Inicio. Los estados simulados de pruebas no se confunden con reproducción comercial o un pico real de CPU del hardware.

Aceptación: API, Nginx, DIAL y cinco servicios de sesión activos, cero unidades fallidas de sistema o usuario. Rollback temporal propio aceptado y timer detenido. Fuente, manifiesto y evidencias propios en `/home/osmarg/.local/state/orgm-multimedia/20261026-power-performance/`, archivados en `/home/jarq/Hobby/nixos-multimedia-power-performance/`. Las capturas físicas se conservan como evidencia privada, sin publicarlas en GitHub.

Referencias: https://nginx.org/en/docs/http/ngx_http_core_module.html, https://nginx.org/en/docs/http/ngx_http_gzip_module.html y https://www.starlette.io/middleware/.
