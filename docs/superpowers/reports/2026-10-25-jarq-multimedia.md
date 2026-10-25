# Jarq multimedia — 25 de octubre de 2026

Registro de entregas sucesivas. El estado vigente está en «Quinta entrega»; las secciones anteriores conservan el historial de cambios y comprobaciones.

Implementación de la Fase 1 solicitada y de las ampliaciones posteriores de pantalla táctil, espejo fijo 1080p, brillo y rotación. Perfil NixOS `jarq-multimedia`; aplicación pública separada: https://github.com/osmargm1202/orgm-multimedia, revisión `d4d386e44ac7e26f6d2538f018315bd74a52f439` fijada en `flake.lock`.

## Entrega

- greetd inicia automáticamente Sway como `media` (UID 1100, sin sudo ni grupo input). El administrador `jarq` (UID 1000) conserva SSH y su cuenta.
- Inicio local, mando responsive en español, catálogo fijo de siete aplicaciones, perfiles independientes de Chrome, videos locales y controles según capacidades.
- FastAPI único en loopback con agente de sesión por socket Unix. Cookie firmada, vinculación, CSRF, validación de origen, límites de entrada y bloqueo de destinos privados.
- Nginx añadido en Jarq. Por decisión del usuario, HTTP privado en `http://home.or-gm.com`, escuchando solo en `100.122.22.48:80`, accesible por Tailscale. No se configuraron HTTPS ni túnel público.
- eDP-1 fuente táctil; HDMI-A-1 copia mediante wl-mirror, ambos 1920×1080. El touch se asigna a eDP. Al retirar HDMI continúa la laptop.
- Teclado español existente reutilizado, barra de Inicio/transporte/volumen/teclado/Voltear, aparición al interactuar y ocultación automática. Mando pequeño abajo a la izquierda, transparente/gris tras seis segundos.
- Brillo interno: slider 5–100%, botones 100%/20%/Atenuar, niveles automáticos 50%/15 s, 20%/35 s, 10%/60 s, 5%/120 s y regreso al 100% con actividad. El reposo ignora inhibidores de video y nunca apaga ninguna salida. Giro interno 180° persistido; HDMI no recibe el comando de giro.
- Fondo nocturno generado con `imagegen`, empaquetado localmente. Prompt y procedencia: `orgm-multimedia/docs/background.md`.

## Preservación y despliegue

Se inspeccionó el sistema real y su fuente Sway anterior. Se conservaron kernel 7.0.10-zen1, Wi-Fi Broadcom `wl`, parámetros DMA/IOMMU operativos, hardware y Tailscale 1.102.3. No se sustituyeron los cambios personales pendientes en este checkout.

Fuente aislada local: `/home/osmarg/.local/state/orgm-multimedia/20261025/source`; manifiesto de archivos superpuestos en el directorio padre. Fuente remota: `/home/jarq/Hobby/nixos-multimedia-20261025/source`. Las copias del store se transfirieron desde el build local por SSH; no se desactivó globalmente la verificación de firmas. Se usó rollback temporal durante cada aplicación y se conservó el sistema anterior.

Sistema original: `/nix/store/7vlas6c7piykcs6nxfjxhm2lfyjxpia4-nixos-system-jarq-sway` (generación original 22). No contiene el código nuevo y sirve como retorno al escritorio anterior desde el bootloader. La contraseña temporal facilitada no se incorporó a los repositorios.

## Evidencia disponible

60 pruebas unitarias, Ruff y verificación responsive en Chromium pasan. La sesión Sway/Chrome real aislada comprueba texto Unicode literal, teclado QML, enfoque, recuperación tras reiniciar agente/API, modo app de Chrome, fullscreen y copia de pantalla. Evidencia de la revisión final de app: `/tmp/orgm-sway-smoke-a8f9dxxy`; capturas web: `/tmp/orgm-browser-eoct95cx`.

En el hardware se detectó HDMI `ABC TV` a 1080p/60 y eDP LG a 1080p/60.020. La copia física de ambas capturas con teclado visible tuvo MAE normalizado 0.0000603. ELAN USB reconocido como pantalla táctil. La API real permitió cambiar el brillo y confirmó los valores del dispositivo.

Audio inspeccionado: salida HDMI `alsa_output.pci-0000_00_03.0.hdmi-stereo`, volumen 40%, sin mute de salida ni de Chrome; IEC958 encendido, ELD válido, estéreo PCM a 48 kHz. El monitor digital HDMI tenía audio real (RMS 1176.79 y pico 7394 sobre muestras int16); se envió además un tono de prueba corto. Esto verifica audio enviado por software; no certifica el volumen o silencio físico del televisor/proyector. Al conectar HDMI se desactiva el mute de esa salida y se trasladan los flujos existentes; los cambios de mute posteriores del usuario se respetan.

La reproducción comercial con cuentas, DRM y aceptación auditiva requiere comprobación del usuario. No se certifica reproducción por el mero hecho de abrir correctamente la página de cada servicio. La extracción física del cable se simuló en pruebas del gestor; se verificó en el hardware la conexión y el espejo.


Las siete aplicaciones pasaron en Jarq apertura, identificación, fullscreen, Home y cierre; el final dejó solo ORGM Home. Se comprobó el control de brillo en 25% y 35%, y el giro a 180°/normal sin girar HDMI. La prueba VM final de arranque/proxy/autologin/recuperación pasó en 26.8 s; log local `/tmp/orgm-multimedia-vm-final-detail.log`. El nuevo inicio con fondo, presets y mando discreto está capturado en `/tmp/orgm-home-final.png`.

Referencias de implementación: [notificaciones y comandos swayidle](https://github.com/swaywm/swayidle/blob/master/main.c), [ajuste hideScrollbars de Chromium](https://chromium.googlesource.com/chromium/src/+/main/third_party/blink/renderer/core/frame/settings.json5), [captura de salida PipeWire](https://docs.pipewire.org/devel/group__pw__keys.html). Los resultados anteriores proceden de las pruebas ejecutadas, no de estas referencias.

La primera prueba de reboot detectó un override EFI persistente: `LoaderEntryDefault=nixos-generation-21.conf` prevalecía sobre `/boot/loader/loader.conf`, que ya seleccionaba generación 30. Se eliminó únicamente ese override con `bootctl set-default ''`, dejando que las siguientes generaciones usen el default declarativo de NixOS. No se eliminaron entradas antiguas. Semántica documentada en [bootctl](https://www.freedesktop.org/software/systemd/man/latest/bootctl.html).

El diagnóstico aislado adicional del swayidle modificado pasó: todos los temporizadores de entrada se ejecutaron con un inhibidor activo y se recibió resume al generar entrada. Script local `/tmp/orgm-idle-only.py`, log `/tmp/orgm-idle-only.log`. En la prueba física hubo interacción manual durante el muestreo, por lo que esos puntos no se usan como certificación de todos los tiempos; el journal sí registró 50% y 20% tras los umbrales y retorno al 100% con actividad. Captura de HDMI mientras eDP estaba girada: `/tmp/orgm-hdmi-while-rotated.png`, imagen exterior derecha.


## Estado final de arranque

Generación 30: `/nix/store/nrrkvw5ngbc1x105i82v2pn5dc9rr1zk-nixos-system-jarq-jarq-multimedia`. Tras limpiar el override EFI, el segundo reinicio arrancó directamente este sistema (boot ID `bc4b1d5e-9458-4e74-91f3-f1113b02cc8f`), con greetd, FastAPI y Nginx activos, respuesta HTTP de salud correcta, kernel 7.0.10-zen1 y cero unidades de sistema fallidas. El bootloader conserva las generaciones previas.

La configuración NixOS queda en el checkout local, sin mezclar ni confirmar en Git los cambios personales ya pendientes. La aplicación sí está confirmada y publicada en su repositorio separado. El fondo final está guardado en `/home/osmarg/Hobby/orgm-multimedia/orgm_home/static/home-night.png`.

La verificación posterior al segundo reboot pasó (`/tmp/orgm-postboot.log` en Jarq): los cinco servicios de sesión activos, Home y wl-mirror en fullscreen, touch listo y conectado, mando discreto, ambas salidas 1080p y HDMI normal. La orientación elegida por el usuario quedó persistida en 180° para eDP; la salida exterior permaneció derecha. Audio predeterminado HDMI sin mute; volumen observado final 65%. Las pruebas de vinculación/CSRF y rechazo de entradas inválidas volvieron a pasar después del reboot.


## Segunda entrega: opciones y correcciones solicitadas

Los outputs canónicos `jarq` y `jarq-multimedia` seleccionan multimedia. Once aplicaciones: se agregaron Poki, StreamEast (`https://streameasto.cx/`), NBA (`https://www.nba.com/watch`) y RetroArch (`org.libretro.RetroArch`). RetroArch instalado con commit `9c51e2bcb6f7f29ecb327ee057b273c5b59efc22d35026e90aef601bc0052752`. No se descargaron ROMs ni se configuraron cuentas.

Se generaron cuatro fondos adicionales mediante imagegen, guardados en `orgm_home/static/home-{bosque,dunas,orbita,aurora}.png`, con prompts en `docs/background.md` del repositorio público. La galería web y el selector Quickshell comparten una preferencia persistente y validada. La barra aparece arriba por actividad, usa SVG y contiene Inicio/Atrás/volumen/mute/teclado/Opciones; se retiraron el tirador, transporte y brillo manual. Administración agrupa Voltear, reiniciar launcher y reiniciar equipo, con confirmación para reboot y autorización logind limitada a `media`.

La nueva secuencia es 20% a los 20 s y cero/apagado de retroiluminación a los 60 s. La prueba física registró `brightness=0`, `actual_brightness=0`, `bl_power=4`; eDP y HDMI siguieron activos y se capturó contenido en HDMI. La regla udev concede a video acceso solo al control de luz de intel_backlight. Actividad restablece `bl_power=0`, 100% y controles. Referencia: https://docs.kernel.org/gpu/backlight.html.

La salida HDMI era correcta, pero un flujo activo de Netflix estaba silenciado. Se restauró y se añadió reconciliación de flujos tardíos según la aplicación enfocada, sin cambiar el mute global. El enfoque cambia de workspace explícitamente. Tras el reboot, Netflix → Inicio → YouTube → Inicio se verificó dos veces con HTTP 200 y foco correcto.

El kernel del boot anterior registró un segfault de VacuumTube en `libxkbcommon` a las 05:14:23. El controlador pasó a conservar un motor de teclado con mapa completo y a usarlo también para pegar texto, evitando el cambio temporal del mapa con wtype. La app ahora usa Alt+Izquierda para historial web y códigos físicos para las teclas nativas.

Durante la comprobación se perdió la red. NetworkManager del boot anterior informó ENFILE («Demasiados ficheros abiertos en el sistema»); no se ha establecido el origen exacto de ese fallo. El usuario confirmó que la interfaz respondía y reinició desde Administración. Volvió la red y arrancó multimedia. Tras el reinicio, los contadores globales oscilaron entre 6005 y 6027 en diez segundos, con los principales procesos entre 131 y 508 descriptores; no se identificó una fuga activa en esa muestra. Memoria disponible observada: 6283 MiB. No se afirma que el fallo ENFILE haya quedado explicado por completo.

Pruebas: 64 pruebas unitarias de agente/seguridad/pantallas, Ruff, web desktop/móvil y Sway/Chrome nativos con historial Atrás, texto literal, teclado y selección táctil de fondo. Evidencia nativa `/tmp/orgm-sway-smoke-lnvnzi38`, web `/tmp/orgm-browser-if3velfa`. VM con permisos CanReboot y retorno de Home pasó en 33.25 s. La comparación de píxeles de Chromium bajo CDP/headless queda como diagnóstico debido a redimensionados de superficie; se conserva comprobación estricta de geometría y la evidencia física de captura HDMI.

Hay cambios paralelos de Bomba/Pump en ambos workspaces. Se conservaron sin confirmar ni sobrescribir; el despliegue de multimedia usa su fuente aislada anterior del módulo de host, sin incorporar esa integración ajena a esta entrega.


## Verificación final de la segunda entrega

Aplicación publicada y fijada: `492b5fa8863d5ec9f1c185e61f7b15b034af8720`. El build propio aplicado fue `/nix/store/p7n1vg87hnc635yird2nq73mibsxivp6-nixos-system-jarq-jarq-multimedia`, generación 33; aplicación systemd v9 con resultado success y aceptación HTTP/CSRF correcta. La VM final pasó en 27.63 s (`/tmp/orgm-vm-persistent-final-detail.log`). La prueba nativa final pasó con el motor de teclado persistente y pegado Unicode: `/tmp/orgm-sway-smoke-wn3c8tbx`, log `/tmp/orgm-native-persistent-final.log`.

La comprobación física posterior confirmó los cinco servicios de sesión activos, Home/YouTube/wl-mirror fullscreen, touch listo/conectado y ambas salidas 1080p. HDMI sin mute, volumen observado 85%; no se cambió el volumen seleccionado por el usuario. Se observó retorno a 100% al interactuar, luego 20% (`brightness=170`), y finalmente `brightness=0`, `actual_brightness=0`, `bl_power=4` por el temporizador. La salida HDMI conserva el modo y el contenido. No hace falta apagar eDP mediante DRM para conseguir oscuridad total; se apaga su retroiluminación y el touch permanece disponible.

Mientras se cerraban las comprobaciones, una integración paralela de Bomba aplicó generación 34: `/nix/store/3dy64hrhimiwhb8qysh0p41zy6fl9cj8-nixos-system-jarq-jarq-multimedia`. No se revirtió ese trabajo. Se comprobó que mantiene el agente exacto de la revisión 492b5fa (SHA256 `254d31853be56f514e932e5a6ee8ff196cbd5c1e71e412e6d7ed489d316a5cfa`), los temporizadores de 20/60 s y cero unidades de sistema fallidas. Las pruebas de Bomba pertenecen a esa integración; no se atribuyen a esta entrega.

La fuente propia reproducible quedó separada del directorio compartido que usa Bomba: `/home/osmarg/.local/state/orgm-multimedia/20261025-final-492b5fa/source`, con manifiesto propio. Su evaluación vuelve a producir exactamente el sistema p7n1 indicado. El manifiesto compartido anterior y los cambios paralelos en ambos repositorios se conservaron. La configuración NixOS sigue sin un commit conjunto para evitar incorporar trabajo ajeno.


## Tercera entrega: flecha de recuperación y cierre de ventanas

Revisión publicada `4f7774cd5d9ab7a76a5c19cdda25763a63806731`, fijada en flake.nix/lock. Sistema aplicado y aceptado: `/nix/store/0896nr2hlbpax9hkwp0ajybaijypashr-nixos-system-jarq-jarq-multimedia`, generación 36. Unidad `orgm-arrow-close-apply-final` con resultado success; cero unidades de sistema fallidas.

Al plegar la barra superior queda una flecha gris hacia abajo de 52×44 px, arriba a la izquierda, con fondo semitransparente. La flecha recupera la barra. La entrada física continúa despertando la retroiluminación, pero respeta el plegado manual y no abre la barra completa sobre el contenido.

La barra incluye X «Cerrar página». El cierre usa el con_id de la ventana enfocada; no busca ni mata la primera ventana de toda la aplicación. Espera el cierre de esa ventana y recupera la ventana original marcada más antigua si sigue abierta. Al cerrar la última ventana vuelve a Inicio. Inicio y ventanas no gestionadas están protegidos. Los popups Chrome también se identifican mediante su perfil/PID aunque tengan un app_id genérico.

Se detectó un caso adicional con Sway: una ventana nueva podía quedar detrás del opener fullscreen. El reconciliador muestra en fullscreen las ventanas nuevas de la webapp actualmente seleccionada. Las ventanas de otras aplicaciones no cambian el foco por ese reconciliador y el reinicio del agente no vuelve a enfocar popups antiguos.

Validación final: 75 pruebas unitarias de agente, seguridad y pantallas; Ruff; paquete Nix y sesión nativa Sway/Chrome con el paquete final que conserva el parche Bomba. La sesión real de prueba hizo clic en ocultar, verificó que la señal de despertar respetaba el plegado y abrió con la flecha; después creó un popup, hizo clic en la X y comprobó que el original seguía abierto/enfocado. Evidencia `/tmp/orgm-sway-smoke-fi10ylwz`, log `/tmp/orgm-popup-native-final.log`.

En Jarq se repitió el flujo con ventanas en blanco creadas únicamente para la prueba: flecha PASS; ventana adicional 31 cerrada, original 29 conservada/enfocada; al cerrar la última regresó a Inicio. Se limpiaron solo esas ventanas y se restauró la fuente anterior. Log remoto `/tmp/orgm-arrow-close-session-check.log`. La aceptación HTTP/CSRF y rechazo de entradas inválidas volvió a pasar y se desarmó el rollback temporal propio.

Fuente reproducible de esta entrega: `/home/osmarg/.local/state/orgm-multimedia/20261025-arrow-close/source`, basada en la configuración compartida que evaluaba exactamente al sistema anterior 9070f7 (generación 35). Conserva la integración Bomba ya instalada. No se sobrescribió el snapshot compartido anterior ni se incluyeron en commits de la aplicación los archivos Pump pendientes de otro trabajo. Fuente y manifiesto se archivaron también en `/home/jarq/Hobby/nixos-multimedia-arrow-close`.

## Cuarta entrega: inicio cinematográfico, fuentes persistentes y conexión

Aplicación publicada `256fe74b3f3ef9a1c5b1c2e6ff603e2accab57b1`. Diseño basado en `/home/osmarg/Downloads/Cinematic Dark Media Center Dashboard.png`: navegación lateral, pestañas por categoría, seis portadas destacadas, catálogo completo de 22 fuentes, aplicaciones abiertas y panel de Spotify con Play/Pausa sin cambiar de pantalla. Se generaron 22 portadas precargadas; sus prompts y procedencia están en `orgm-multimedia/docs/service-covers.md`. Los cinco fondos existentes siguen seleccionables. Se reservan 104 px arriba para la barra nativa; las comprobaciones cubren 1080p, 864p, 720p y móvil. Se instaló la skill oficial Anthropic frontend-design en `/home/osmarg/.codex/skills/frontend-design-anthropic/SKILL.md`.

Cuando una aplicación está abierta, las tarjetas usan una captura reciente de su propia ventana. `grim -T` captura ventanas ocultas sin cambiar el foco; el refresco es cada diez segundos y las imágenes viven fuera del repositorio, con permisos privados y un endpoint autenticado. Se verificó en Jarq manteniendo Inicio enfocado. No se inventan escenas, historial, duración de canciones ni progreso. Las capturas pueden reflejar el último fotograma disponible cuando una aplicación deja de dibujar en segundo plano.

Nuevas fuentes: Kitty, Disney+, Prime Video, Immich (`https://fotos.or-gm.com`), **Claude web (`https://claude.ai`)**, ChatGPT, Uber Eats, Twitch, Kick y AirPlay. No se instala Claude Code. En Jarq se verificó abrir las ocho webapps nuevas en fullscreen y cerrar cada una de vuelta a Inicio. Kitty recibe pegado literal con Ctrl+Shift+V; se comprobó la ejecución de una instrucción de prueba sin shell intermediario del agente, y se eliminó el archivo de prueba. Se desactiva la confirmación interna de cierre de Kitty para que la X del centro multimedia pueda cerrarlo. La apertura de las páginas no certifica la reproducción DRM o suscripciones de cada servicio.

Spotify conserva su ventana y su audio al volver a Inicio o entrar en aplicaciones silenciosas. Otro flujo de audio activo de la fuente seleccionada provoca pausa de Spotify; los flujos de fuentes que quedan en segundo plano se silencian. No se cambia el volumen ni el mute global elegidos por el usuario. Se descubrió que los nodos nativos PipeWire pueden omitir el PID: se completa desde su cliente; para Flatpak se usa el PID de seguridad del host. Esto permite identificar mpv y Chromium aunque el nodo de audio no tenga PID.

Wi-Fi está en el encabezado y en Opciones → Wi-Fi. El panel nativo permite buscar, reconectar y elegir red. La contraseña entra localmente, enmascarada; viaja por stdin/IPC y archivo efímero 0600, sin argv, logs ni HTTP. Los perfiles nuevos pertenecen a media y Polkit permite solo scan, wifi enable/disable, network-control y modify.own; no se concede modify.system. La prueba nativa usa una red ficticia y verifica permisos/borrado del archivo. En Jarq se comprobaron los permisos y un escaneo real que conservó la conexión ARCH.

AirPlay usa UxPlay 1.73.6 desde el proyecto FDH2, iniciado al seleccionar su tarjeta y detenido al cerrarla. Anuncia **ORGM Jarq** en la LAN; se verificaron el servicio, los puertos y el anuncio mDNS sobre `10.0.0.98`. El firewall abre TCP/UDP 7000–7002 únicamente a `10.0.0.0/24`. La salida usa Wayland y PulseAudio/PipeWire. Avahi queda como único respondedor mDNS: systemd-resolved tenía mDNS habilitado por defecto y aparecieron conflictos repetidos de hostname. Se deshabilitó su mDNS, conservando su función DNS normal y la integración Tailscale. Queda pendiente probar una transmisión desde un dispositivo Apple real; no se afirma validación de contenido protegido por DRM.

En los journals del arranque anterior se observaron fallos de cambio de MAC y scan del controlador Broadcom wl, con error 23 traducido como ENFILE. Los contadores globales no indicaban agotamiento de archivos ni OOM. Se deshabilitaron la MAC aleatoria de escaneo y el ahorro de energía; el perfil usa la MAC permanente. Esto es una mitigación de compatibilidad del controlador, no una prueba de estabilidad a largo plazo. Para reiniciar desde Administración se programa un helper fuera del target de sesión: primero termina controles/portales y después solicita el reboot. Así la barra deja Wayland antes del compositor.

Validación: 98 pruebas unitarias, Ruff, navegador desktop/móvil (`/tmp/orgm-browser-a4o9wco1`), regresión Bomba (`/tmp/orgm-pump-browser-fr505uwe`), sesión Sway/Chrome/Quickshell nativa (`/tmp/orgm-sway-smoke-s40_mn23`), evaluación Nix del perfil y VM con anuncio/cierre AirPlay y reinicio. La sesión nativa verificó contraseña Wi-Fi y foco real del teclado, captura autenticada sin cambio de foco, flecha de recuperación y X de popup conservando el original. La integración paralela Bomba/Home Assistant se conserva; sus archivos Pump permanecen pendientes en el worktree y no entraron en los commits de la aplicación. El repositorio NixOS permanece con sus cambios ajenos sin un commit conjunto.

La prueba física de audio reprodujo Spotify, pasó a Kitty y a Videos todavía silencioso sin detener la música, y después cargó un WAV silencioso en mpv. Al activar su audio se pausó Spotify y el foco de audio pasó a Videos; el sink HDMI, su volumen y su mute no cambiaron. Se restauró el estado pausado previo de Spotify y se cerraron únicamente las ventanas y el archivo creados para la prueba. Registro: `/tmp/orgm-cinema-focus-audio-final.log` en Jarq.

Sistema final aplicado `/nix/store/fmaab0nfziq7icwc8v20r3gmwp3m56v5-nixos-system-jarq-jarq-multimedia`, generación 41. VM final de esa revisión: 35.15 s, log `/tmp/orgm-cinema-final-vm.log`. Fuente propia `/home/osmarg/.local/state/orgm-multimedia/20261025-audio-design-airplay/source`, manifiesto separado; parte del sistema mmimj con Home Assistant/Bomba ya integrados. Se actualizó solo el nodo orgm-multimedia del lock principal, preservando los demás inputs y los cambios ajenos.

Reinicio físico desde la misma acción de Administración aceptado; nuevo boot ID `ba91b51a-6c2e-424b-9b4c-c479698c047c`. Regresó generación 41, Inicio fullscreen 1920×1080, los cinco servicios de sesión y nginx/orgm-home/Bomba/Home Assistant activos, sin unidades de sistema fallidas. La barra táctil se detuvo limpiamente: no reapareció «The Wayland connection broke» en el cierre comprobado. Persisten mensajes de systemd al cancelar jobs de dispositivos durante shutdown; no se atribuyen a una caída del launcher. Avahi arrancó como `jarq.local`, sin conflictos de nombre en este arranque; NetworkManager no registró warnings en la comprobación posterior.

Después del reboot el kernel informa `/sys/class/drm/card1-HDMI-A-1/status = disconnected`; Sway solo enumera eDP-1. Por esa detección física la salida de audio actual es la interna, con 40%, sin mute; no se forzó una salida HDMI inexistente. Se preguntó si el proyector sigue conectado/encendido. La prueba física anterior de audio HDMI y cambio Spotify→mpv sí pasó; queda pendiente comprobar la reconexión externa tras este reinicio cuando el proyector esté disponible. La captura real del inicio y los journals finales están en `/home/osmarg/.local/state/orgm-multimedia/20261025-audio-design-airplay/evidence/`.

La fuente y el manifiesto se archivaron en Jarq en `/home/jarq/Hobby/nixos-multimedia-cinema/`. La aplicación está publicada en https://github.com/osmargm1202/orgm-multimedia. Referencias técnicas: https://github.com/FDH2/UxPlay, https://github.com/emersion/grim y https://quickshell.org/docs/v0.1.0/types/Quickshell.Wayland/WlrLayershell/.

## Quinta entrega: categorías laterales, pausa real y recuperación de red

Aplicación publicada `b844e1cf7fa6df473d7aaff6453e10480a009aa2`, fijada en flake.nix/lock. Sistema `/nix/store/hg5k4ligx6m0mx855hclfifyq7cly5yb-nixos-system-jarq-jarq-multimedia`, generación 43. Conserva Bomba/Home Assistant y las modificaciones ajenas pendientes. El snapshot propio es `/home/osmarg/.local/state/orgm-multimedia/20261025-sidebar-playback/source`; no se sobrescribió el snapshot de la entrega anterior.

Inicio muestra las 22 aplicaciones en una banda deslizable. Las categorías Video, Música, Fotos, Juegos, Herramientas y Servicios están en el lateral, junto con Inicio y un único acceso a Opciones. Se retiraron Apps/Mando/Biblioteca del lateral, las pestañas horizontales, el Home duplicado del mando y sus flechas/OK. Quedan audio, silencio, Atrás y teclado. El panel de Spotify tiene anterior, Play/Pausa y siguiente; su imagen abre la aplicación. Wi-Fi es un panel nativo independiente sin fondos ni administración; esas dos funciones tienen páginas propias dentro de Opciones. Se retiró también el engranaje de la barra nativa para mantener un único acceso a configuración.

La reproducción ya no depende solo de silenciar streams. Se enumeran los servicios MPRIS reales de D-Bus y se asocian por PID a la ventana. Para Flatpak se consulta el cgroup del proxy D-Bus: YouTube se anunciaba como `chromium.instance3`, no como `VacuumTube`. Se pausan los videos en segundo plano, conservando Spotify como excepción. La pausa del launcher queda registrada en un archivo privado y solo esa pausa se reanuda al regresar; una pausa manual se conserva. mpv registra igualmente si el launcher lo pausó. La asociación no usa títulos, no enfoca otras ventanas y no envía órdenes globales a todos los reproductores.

En Jarq se reprodujeron tres videos locales reales en tres instancias separadas de Chromium mediante perfiles de prueba del catálogo que estaban cerrados. Al volver a Inicio los tres reportaron Paused y sus posiciones permanecieron congeladas durante la comprobación. Al volver a cada aplicación se verificó Playing; se repitió la vuelta a Inicio. Se cerraron únicamente las ventanas creadas para esa prueba. También se comprobó un clic nativo sobre la imagen de Spotify y la apertura/cierre del panel Wi-Fi independiente. Logs: `/tmp/orgm-sidebar-fixture-check.log` y `/tmp/orgm-sidebar-controls.log`. El primer log conserva al final un fallo del método de coordenadas de la prueba de Spotify; la prueba separada posterior, usando el cursor lógico de Sway, pasó. La pausa/reanudación de los tres videos ya había pasado antes de ese fallo de instrumentación.

Durante la entrega se detectó la causa de las webapps sin contenido: la conexión Wi-Fi respondía a ping, pero las consultas DNS y conexiones TCP/HTTP salían sin recibir respuestas. Una captura de cabeceras en wlp2s0 confirmó las salidas sin respuestas; conntrack estaba en 540/262144, sin saturación. Había advertencias cfg80211 del controlador propietario wl en ese arranque. No se atribuye exclusivamente al driver sin descartar el punto de acceso. La reconexión del mismo perfil guardado restableció DNS, HTTPS y Tailscale; después se abrieron Netflix, Claude e Immich y se comprobaron respuestas HTTPS desde el usuario media para las nueve fuentes nuevas.

El botón «Reconectar» antes utilizaba `nmcli device connect`, que puede no hacer nada si el enlace ya figura conectado. Ahora toma el UUID del perfil activo antes de desconectar y lo reactiva, sin modificar sus ajustes ni contraseñas. El cliente local espera hasta 90 s para esa operación. Si no hay un UUID válido, no desconecta; si ya estaba desconectado, conserva la activación normal de NetworkManager. Se probaron esos casos en unidad.

Pruebas: 106 pruebas unitarias y Ruff; navegador desktop/móvil y navegación/Spotify/opciones (`/tmp/orgm-browser-prnvg18r`); sesión nativa Sway/Chrome/Quickshell (`/tmp/orgm-sway-smoke-rp1iddjm`); regresión Bomba (`/tmp/orgm-pump-browser-8iihalwy`); evaluación Nix y build final. La VM con la revisión de interfaz f019dac pasó en 30.24 s; el cambio posterior de reconexión se valida mediante sus pruebas unitarias y comprobación física. No se atribuye al VM una prueba de Wi-Fi real.

Los HTTP 403 de Claude/ChatGPT/Uber Eats y 503 de Prime Video obtenidos con curl se registran como respuestas de los servicios, no como fallos de DNS; no certifican una sesión autenticada o reproducción DRM. La comprobación Nginx/HTTP/CSRF pasó de nuevo con resolución normal después de recuperar la red. Antes de eso, una prueba con destino IP fijo había verificado el mismo proxy sin depender de DNS. Durante la transferencia se usó IPQoS=ef en los clientes SSH porque algunas sesiones no interactivas se atascaron; no se cambió la política SSH permanente del equipo.

La prueba final del botón de reconexión se ejecutó como media, usando el mismo cliente del panel: desde 12:43:09 hasta 12:43:21 devolvió `ok=true`, conexión activa y redes visibles. El perfil activo en esa prueba fue ORGM5G. No se cambió a otra red desde el código de reconexión. Después volvió a resolver Netflix. Las pruebas originales de HTTP/CSRF también pasaron con DNS normal. Las dos salidas siguen en 1080p, con espejo fullscreen y audio HDMI al volumen seleccionado, sin mute. No se necesitó reiniciar el equipo para esta entrega.

La fuente final, el manifiesto y este informe se archivaron en `/home/jarq/Hobby/nixos-multimedia-sidebar/`. Evidencias locales de esta entrega en `/home/osmarg/.local/state/orgm-multimedia/20261025-sidebar-playback/evidence/`. Rollback temporal propio desarmado después de la aceptación, y cero unidades de sistema fallidas al cierre.


## Sexta entrega: AirPlay con imagen estable

El journal mostró que el receptor sí recibía el video, pero waylandsink fallaba con `Window has no size set` después de `gst_wl_window_ensure_fullscreen: assertion self failed`. UxPlay 1.73.6 traduce `-fs` a la propiedad `fullscreen=true` de GStreamer antes de crear la ventana. Con GStreamer 1.26.11 esa combinación aborta al recibir el primer fotograma. Se quitó únicamente `-fs`; se conserva Wayland, el audio PulseAudio/PipeWire y la gestión fullscreen de Sway y del agente.

Se reprodujo el fallo anterior en una sesión Sway aislada con los mismos plugins de la clausura instalada de UxPlay. La nueva prueba `tests/multimedia-airplay-render.py` comprueba la salida de video crudo y H.264 codificado/decodificado, EOS correcto, ausencia de ERROR y ventana fullscreen 1920×1080. Ambas pasaron; `--check-previous` confirmó exactamente el error original. Evidencia inicial `/tmp/orgm-airplay-render-2kvrbu25`; regresión final `/tmp/orgm-airplay-render-15lk1eod`. No se usó esta prueba sintética para afirmar una transmisión desde Apple: el usuario probó después Duplicar pantalla y confirmó «Sí, imagen estable».

Aplicado sistema `/nix/store/9jrx3l2wdfw4n7p80fz5sq2n75bxpmxl-nixos-system-jarq-jarq-multimedia`, generación 44. La activación reinició únicamente el receptor entre las unidades de la sesión; no requirió reiniciar la laptop. El override efímero usado para probar la corrección fue retirado: ExecStart proviene ahora del perfil permanente, sin `-fs`. El receptor queda activo y no reaparece el error de tamaño en la comprobación posterior. HTTP, autenticación, CSRF y rechazo de entradas inválidas pasaron; cero unidades de sistema fallidas. Rollback temporal propio desarmado tras la aceptación. La inspección final encontró el receptor activo y la pantalla de espera AirPlay, sin transmisión en curso en ese instante; la confirmación de imagen procede de la prueba del usuario.

Fuente reproducible propia `/home/osmarg/.local/state/orgm-multimedia/20261025-airplay-video/source`, manifiesto y evidencias en su directorio padre; archivados en `/home/jarq/Hobby/nixos-multimedia-airplay-video`. Se conserva la revisión de aplicación `b844e1c`, Home Assistant/Bomba y los cambios ajenos. No se publicaron los archivos Pump pendientes ni se creó un commit conjunto del repositorio NixOS.


## Publicación de pendientes

A petición del usuario se publican también los cambios acumulados de escritorio, ArtCraft/CADCraft, acceso remoto privado, teclado/tablet, VA-API, secretos SOPS cifrados y Bomba/Home Assistant, además del perfil multimedia. La aplicación incorpora ahora Bomba en su propio commit `e518a41`; el perfil Nix conserva el pin `b844e1c` y su parche Bomba ya aplicado para mantener reproducible el sistema instalado y evitar aplicar dos veces la misma integración.

Comprobación del conjunto: 121 pruebas de la aplicación y 24 scripts de regresión del repositorio NixOS, todos correctos al cierre. Se adaptaron tres pruebas de escritorio para verificar explícitamente que el perfil multimedia excluye sus paquetes, preferencias MIME y servicio de escritorio remoto; las comprobaciones de los demás escritorios se conservan. Evidencias en `/tmp/orgm-pending-checks/final-results.json` y `/tmp/orgm-all-pending-pytest.log`. No se repitieron las pruebas físicas ya documentadas ni se aplicaron otros cambios al equipo. `http://home.or-gm.com/` y `/api/health` devolvieron HTTP 200; el DNS resuelve a `100.122.22.48`. Se mantiene el acceso HTTP privado por Tailscale; HTTPS todavía no está configurado.
