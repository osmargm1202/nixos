# Jarq multimedia

`nixosConfigurations.jarq-multimedia` selecciona un sistema de sala con greetd → usuario `media` → Sway → Chrome kiosk. Los outputs `jarq` y `jarq-multimedia` seleccionan el mismo perfil multimedia por solicitud del usuario. No se añaden estos servicios al resto de los hosts.

La aplicación vive en [orgm-multimedia](https://github.com/osmargm1202/orgm-multimedia), en `/home/osmarg/Hobby/orgm-multimedia` en la máquina de desarrollo. `flake.lock` fija su revisión; aquí permanecen exclusivamente integración NixOS, catálogo, parche de entrada y pruebas del sistema.

```bash
nix build .#nixosConfigurations.jarq-multimedia.config.system.build.toplevel
nix build .#checks.x86_64-linux.multimedia-boot
bash tests/jarq-multimedia.bats.sh
```

El build no aplica cambios a ningún equipo. Antes de desplegar, inspeccionar el sistema activo y su fuente real, conservar UUID/kernel/Wi-Fi/SSH y comprobar que uid 1100 esté disponible. En Jarq existe antecedente de una fuente Sway distinta del checkout canónico. Se inspeccionó la fuente activa de Jarq y se trasladaron sus ajustes de kernel 7.0.10, Wi-Fi `wl` y DMA `iommu=soft` a un módulo exclusivo de multimedia; el kernel compilado coincide con el activo. Tailscale conserva la versión 1.102.3.

El usuario administrador `jarq` permanece separado de `media`, que no tiene sudo ni acceso al grupo input. La API escucha únicamente en 127.0.0.1:8765 y el agente se comunica por un socket Unix de ese usuario. Para vincular un teléfono, abrir Opciones → Desde el teléfono → Generar código en la pantalla de Jarq: son seis dígitos, válidos durante dos minutos y un solo uso. La clave permanente aleatoria se genera fuera del store; `orgm-home-pair` la muestra mediante sudo para administración.

`home.or-gm.com` resuelve a `100.122.22.48`, la IP Tailscale de Jarq. El dominio padre impone HSTS para sus subdominios, por lo que el perfil sirve `https://home.or-gm.com` con un certificado ACME validado mediante DNS de Cloudflare y renovación automática. `orgm.multimedia.tlsCredentialFile` apunta a un token root-owned fuera del Nix store; systemd lo entrega al cliente ACME por LoadCredential. No se cambian el registro A ni la exposición privada por Tailscale. La entrada alternativa `http://10.0.0.98` funciona en el Wi-Fi doméstico sin VPN. El firewall limita los puertos al tailnet y a la LAN declarada, y la API permanece en loopback. Ambos mandos requieren vinculación, cookie firmada, CSRF y origen exacto.

Para una publicación futura mediante Cloudflare, cambiar al modo `cloudflare`, habilitar Access con familiares autorizados y configurar `/var/lib/orgm-home/access.env` según el README de la app. Ese modo exige JWT válido y falla cerrado si falta la configuración. No se instala cloudflared en el perfil ni se publica el servidor en interfaces externas.

El parche `wtype-chromium.patch` deriva del commit `4b4c4cbd22e57fa2dc03bc8a69f1f9e2fc7f220d` de [atx/wtype PR 74](https://github.com/atx/wtype/pull/74) y se limita a este perfil. La app usa un atajo con posiciones físicas estables y selección temporal para evitar que Chrome interprete texto Unicode como teclas de control.

Flatpak instala VacuumTube y Spotify con reintentos. Sus commits no se fijan todavía. La política de salida de `media` bloquea conexiones nuevas a redes privadas para limitar redirecciones/rebinding desde el navegador; verificar su efecto en Spotify Connect antes de permitir excepciones.

YouTube tiene un puente DIAL fijo en TCP 8766 y descubrimiento UDP 1900, limitado a las subredes de `airplayNetworks`. Corre como usuario dinámico independiente y usa la API autenticada para abrir VacuumTube al recibir un inicio de transmisión. UxPlay 1.73.7 arranca con la sesión y anuncia HLS usando el reproductor alternativo `-hls 2`; su reproductor accede solo al puerto propio 7001 en loopback IPv4/IPv6, sin abrir la salida privada general de `media`. Una ventana de video o flujo de audio AirPlay nuevo selecciona automáticamente esa fuente. Duplicar pantalla fue confirmado por el usuario; el envío directo de YouTube mediante AirPlay sigue pendiente de aceptación con esta versión. Max admite enviar enlaces a su webapp desde Opciones → Desde el teléfono; esto no emula un Chromecast certificado para DRM.

La disposición final solicitada duplica a 1080p: `eDP-1` es fuente táctil y `HDMI-A-1` recibe la copia de wl-mirror; al desconectar HDMI continúa la laptop. El workspace 99 se reserva al espejo. La barra superior conserva Inicio, Atrás, cerrar página, volumen/silencio y teclado. Las tarjetas Abiertas tienen una X independiente para terminar todas las ventanas de esa fuente sin enfocarla. Las categorías y el único acceso a Opciones están a la izquierda; Wi-Fi es un panel independiente. Quickshell se limita a esta superficie táctil; no se instala un escritorio tradicional. El touch ELAN USB está reconocido en el hardware.

Los navegadores vinculados abren un mando con flechas/OK, Inicio, Atrás, teclado y audio; las pestañas inferiores permiten abrir Aplicaciones y Opciones sin cambiar por sí solas la pantalla de Jarq. El selector Cambiar app muestra las fuentes abiertas y cambia directamente a una de ellas, conservando sus ventanas. El segundo botón de la barra nativa ofrece el mismo cambio sobre la aplicación en uso. En Inicio, el mando sigue habilitado: las flechas recorren el dashboard, un borde claro indica la selección y OK la activa; al volver se recupera la aplicación seleccionada. En páginas web, Siguiente elemento y Anterior envían Tab y Shift+Tab para seleccionar controles que no respondan a flechas.

La prueba VM no certifica la GPU/HDMI/audio/DRM físicos de Jarq. Netflix, Max y Crunchyroll requieren login manual y pruebas de reproducción. Consultar el informe de esta entrega para distinguir implementación, pruebas locales y aceptación física.

El brillo actúa exclusivamente sobre `intel_backlight`: baja al 20% a los veinte segundos y a cero al minuto, incluyendo el apagado real del backlight mediante `bl_power`. La actividad física restaura el 100%. No hay sliders ni presets de brillo en el menú. El swayidle de este perfil usa notificaciones de entrada del protocolo v2 e ignora inhibidores de video; ese cambio no afecta otros escritorios. La regla udev permite escribir al grupo video de `media`, sin sudo.

«Voltear», en Administración, alterna eDP-1 entre normal y 180°, vuelve a mapear el touch y conserva la elección. Al plegar la barra superior queda una flecha discreta arriba a la izquierda para recuperarla. Las aplicaciones se fuerzan a pantalla completa; Chrome oculta barras de desplazamiento conservando el desplazamiento táctil.

Al reemplazar una sesión gráfica en vivo se reinicia `orgm-home-session.target` después de importar el entorno real de Sway. Así los agentes reciben el socket de la sesión nueva. Tras un `switch` con la sesión conservada, recargar el gestor de usuario y reiniciar los servicios de ORGM permite recoger nuevas rutas del store. La fuente aplicada y sus evidencias se registran en el informe de entrega; se conserva la integración Bomba/Home Assistant.

En la validación de arranque apareció una selección EFI persistente a la generación 21. Se limpió con `bootctl set-default ''` para que prevalezca el default que genera NixOS en `/boot/loader/loader.conf`. Para diagnosticar un arranque que vuelve a otro perfil, comparar `bootctl status`, las variables EFI y `/proc/cmdline`; no basta con revisar `/nix/var/nix/profiles/system`.


Actualización: los workspaces 1–12 alojan once aplicaciones; se añaden Poki, StreamEast, NBA web oficial y RetroArch por Flatpak. La barra táctil solo muestra símbolos y aparece arriba por actividad, sin tirador persistente ni controles de transporte. Opciones tiene cinco fondos y Administración (giro/reinicios). El perfil solo autoriza a `media` a solicitar reboot mediante logind; no le otorga sudo.

La política actual sustituye la secuencia anterior: 20% tras 20 segundos y 0% tras 60 segundos. Se permite el cero real de brightnessctl y se escribe `4` en `intel_backlight/bl_power` para apagar la retroiluminación; al activar se restaura `bl_power=0` y 100%. La regla udev concede acceso únicamente al control de luz interno. Se mantiene activo eDP para conservar la imagen HDMI. La prueba física registró brightness=actual_brightness=0, bl_power=4, ambas salidas activas y captura HDMI con contenido.

El agente reconcilia los flujos tardíos y el mute heredado entre perfiles Chrome, sin modificar el mute global del usuario. La selección de aplicación cambia explícitamente de workspace antes de enfocar. Atrás usa el motor nativo de teclado y Alt+Izquierda en webs. Los fondos se guardan de forma validada y atómica en el estado de `media`.
