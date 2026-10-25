# Jarq multimedia

`nixosConfigurations.jarq-multimedia` selecciona un sistema de sala con greetd → usuario `media` → Sway → Chrome kiosk. Los outputs `jarq` y `jarq-multimedia` seleccionan el mismo perfil multimedia por solicitud del usuario. No se añaden estos servicios al resto de los hosts.

La aplicación vive en [orgm-multimedia](https://github.com/osmargm1202/orgm-multimedia), en `/home/osmarg/Hobby/orgm-multimedia` en la máquina de desarrollo. `flake.lock` fija su revisión; aquí permanecen exclusivamente integración NixOS, catálogo, parche de entrada y pruebas del sistema.

```bash
nix build .#nixosConfigurations.jarq-multimedia.config.system.build.toplevel
nix build .#checks.x86_64-linux.multimedia-boot
bash tests/jarq-multimedia.bats.sh
```

El build no aplica cambios a ningún equipo. Antes de desplegar, inspeccionar el sistema activo y su fuente real, conservar UUID/kernel/Wi-Fi/SSH y comprobar que uid 1100 esté disponible. En Jarq existe antecedente de una fuente Sway distinta del checkout canónico. Se inspeccionó la fuente activa de Jarq y se trasladaron sus ajustes de kernel 7.0.10, Wi-Fi `wl` y DMA `iommu=soft` a un módulo exclusivo de multimedia; el kernel compilado coincide con el activo. Tailscale conserva la versión 1.102.3.

El usuario administrador `jarq` permanece separado de `media`, que no tiene sudo ni acceso al grupo input. La API escucha únicamente en 127.0.0.1:8765 y el agente se comunica por un socket Unix de ese usuario. La clave aleatoria se genera fuera del store. `orgm-home-pair` la muestra mediante sudo.

El usuario confirmó que `home.or-gm.com` resuelve a `100.122.22.48`, la IP Tailscale de Jarq, y eligió HTTP privado por ahora. `orgm.multimedia.exposure = "tailscale"` instala Nginx, lo limita a esa IP:80 y abre el puerto únicamente en `tailscale0`. La API permanece en loopback. El mando requiere clave de vinculación, cookie firmada, CSRF y origen exacto. Los clientes deben tener acceso al tailnet.

Para una publicación futura mediante Cloudflare, cambiar al modo `cloudflare`, habilitar Access con familiares autorizados y configurar `/var/lib/orgm-home/access.env` según el README de la app. Ese modo exige JWT válido y falla cerrado si falta la configuración. No se instala cloudflared en el perfil ni se publica el servidor en interfaces externas.

El parche `wtype-chromium.patch` deriva del commit `4b4c4cbd22e57fa2dc03bc8a69f1f9e2fc7f220d` de [atx/wtype PR 74](https://github.com/atx/wtype/pull/74) y se limita a este perfil. La app usa un atajo con posiciones físicas estables y selección temporal para evitar que Chrome interprete texto Unicode como teclas de control.

Flatpak instala VacuumTube y Spotify con reintentos. Sus commits no se fijan todavía. La política de salida de `media` bloquea conexiones nuevas a redes privadas para limitar redirecciones/rebinding desde el navegador; verificar su efecto en Spotify Connect antes de permitir excepciones.

La disposición final solicitada duplica a 1080p: `eDP-1` es fuente táctil y `HDMI-A-1` recibe la copia de wl-mirror; al desconectar HDMI continúa la laptop. Los workspaces 1–8 se fijan en eDP y el 99 se reserva al espejo. La barra «Mando táctil» ofrece Inicio, Atrás, Play/Pausa, transporte compatible, volumen y el teclado español existente. Quickshell se limita a esta superficie táctil solicitada posteriormente; no se instala un escritorio tradicional. El touch ELAN USB está reconocido en el hardware.

La prueba VM no certifica la GPU/HDMI/audio/DRM físicos de Jarq. Netflix, Max y Crunchyroll requieren login manual y pruebas de reproducción. Consultar el informe de esta entrega para distinguir implementación, pruebas locales y aceptación física.

El brillo actúa exclusivamente sobre `intel_backlight`: control manual 5–100%, presets 100%/20%/Atenuar y reposo progresivo a 50% (15 s), 20% (35 s), 10% (60 s) y 5% (120 s). Una interacción vuelve al 100% y muestra los controles durante ocho segundos. La pantalla nunca se apaga. El swayidle de este perfil usa notificaciones de entrada del protocolo v2 e ignora inhibidores de video; ese cambio no afecta otros escritorios. La regla udev de brightnessctl permite escribir al grupo video de `media`, sin sudo.

«Voltear» alterna eDP-1 entre normal y 180°, vuelve a mapear el touch y conserva la elección en el estado de la aplicación. El botón de mando queda abajo a la izquierda y tras seis segundos pierde el fondo y pasa a gris. Las aplicaciones se fuerzan a pantalla completa; Chrome oculta barras de desplazamiento conservando el desplazamiento táctil.

Al reemplazar una sesión gráfica en vivo se reinicia `orgm-home-session.target` después de importar el entorno real de Sway. Así los agentes reciben el socket de la sesión nueva. Tras un `switch` con la sesión conservada, recargar el gestor de usuario y reiniciar los servicios de ORGM permite recoger nuevas rutas del store. El despliegue de esta entrega usa una copia limpia de HEAD con los archivos de multimedia superpuestos: no incorpora los cambios personales pendientes de este checkout.

En la validación de arranque apareció una selección EFI persistente a la generación 21. Se limpió con `bootctl set-default ''` para que prevalezca el default que genera NixOS en `/boot/loader/loader.conf`. Para diagnosticar un arranque que vuelve a otro perfil, comparar `bootctl status`, las variables EFI y `/proc/cmdline`; no basta con revisar `/nix/var/nix/profiles/system`.


Actualización: los workspaces 1–12 alojan once aplicaciones; se añaden Poki, StreamEast, NBA web oficial y RetroArch por Flatpak. La barra táctil solo muestra símbolos y aparece arriba por actividad, sin tirador persistente ni controles de transporte. Opciones tiene cinco fondos y Administración (giro/reinicios). El perfil solo autoriza a `media` a solicitar reboot mediante logind; no le otorga sudo.

La política actual sustituye la secuencia anterior: 20% tras 20 segundos y 0% tras 60 segundos. Se permite el cero real de brightnessctl y se escribe `4` en `intel_backlight/bl_power` para apagar la retroiluminación; al activar se restaura `bl_power=0` y 100%. La regla udev concede acceso únicamente al control de luz interno. Se mantiene activo eDP para conservar la imagen HDMI. La prueba física registró brightness=actual_brightness=0, bl_power=4, ambas salidas activas y captura HDMI con contenido.

El agente reconcilia los flujos tardíos y el mute heredado entre perfiles Chrome, sin modificar el mute global del usuario. La selección de aplicación cambia explícitamente de workspace antes de enfocar. Atrás usa el motor nativo de teclado y Alt+Izquierda en webs. Los fondos se guardan de forma validada y atómica en el estado de `media`.
