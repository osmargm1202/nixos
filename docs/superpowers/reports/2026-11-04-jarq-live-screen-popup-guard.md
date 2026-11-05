# Jarq: pantalla en directo y cierre de ventanas adicionales

Aplicado sin reiniciar el equipo: generación 69, `/nix/store/dgyv5dcnrj3rrsqn5nb0sxdm12ajrjmm-nixos-system-jarq-jarq-multimedia`. Aplicación fijada en `45ee9bcbbe09aac5fcd9ef72bdc7008eb5c7504f`.

Se compiló en Lenovo, sin activar su configuración. La fuente utilizada parte de la generación 68 que estaba instalada en Jarq y añade únicamente el pin multimedia y los servicios/proxy de esta función. Copia exacta en `~/.local/state/orgm-multimedia/20261104-live-guard/source` y en Jarq `~/Hobby/nixos-multimedia-live-guard`.

## Comportamiento

- Las webapps Chrome conservan la ventana marcada como principal (o la más antigua). El agente cierra ventanas adicionales sin llevar al frente las apps en segundo plano.
- Un guardián CDP conserva la página principal y cierra pestañas adicionales, independientemente del foco, con estado persistente entre reinicios del agente. No modifica Home, aplicaciones nativas ni AirPlay. Las sesiones antiguas ambiguas con varias pestañas raíz se conservan hasta reabrir la app, evitando cerrar una película por una inferencia incorrecta.
- Pantalla del mando abre noVNC/WayVNC a un máximo de 20 fps. Captura ligera queda como alternativa explícita. Clic y desplazamiento usan el controlador existente; la barra conserva el teclado contextual. No se implementa arrastre de objetos.
- El backend usa un socket Unix privado, sin puerto VNC expuesto ni teclado/portapapeles adicionales. La autorización se comprueba antes del upgrade y cada ocho segundos. Un máximo de dos visores; el último cierre detiene el backend. Concesiones abandonadas vencen a los 25 segundos. Salir de la vista u ocultar el navegador desconecta el visor.

## Validación

- 349 pruebas unitarias aprobadas durante la construcción final del paquete.
- Navegador del mando: 184 acciones aprobadas, incluyendo el modo de captura alternativo.
- Chromium aislado: cierre de popup/pestaña, persistencia de la página central, redirección dentro de la misma página y conservación de sesiones antiguas ambiguas.
- Sway/Chrome/WayVNC/noVNC reales en Lenovo: actualización del framebuffer, toque del teléfono recibido por Chrome, ausencia de capturas JPEG periódicas, liberación al salir y supervivencia de la aplicación. También pasan escritura nativa, detección de campos y Enter. Evidencia: `/tmp/orgm-screen-native-_qo7u79n/live-phone.png`. Esta prueba usa el mismo código funcional que el paquete final; las revisiones posteriores ajustan el propio fixture.
- Jarq: servicios web, proxy, audio/control de sesión y shell activos; ninguna unidad fallida. Disney+ permanece abierto y vuelve al frente. Clave de control y registro de dispositivos conservados (sumas verificadas, sin publicarlas).
- Conexiones autenticadas RFB aprobadas por loopback y por `wss://home.or-gm.com/api/remote/live` a través de Nginx/HTTPS. Solo se pidió el saludo del protocolo; no se capturó la película. WayVNC queda inactivo tras desconectarse.
- Temporizador de reversión cancelado después de verificar el despliegue. Falta la valoración del usuario sobre fluidez en su teléfono y red reales.
