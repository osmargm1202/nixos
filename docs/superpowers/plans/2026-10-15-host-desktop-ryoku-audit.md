# Auditoría: una configuración por host, Ryoku y acceso a aplicaciones

Estado: investigación/propuesta; NO es implementación aprobada ni despliegue.
No se han eliminado perfiles, leído/exportado credenciales, enrolado huellas,
modificado PAM ni activado servicios durante esta auditoría.

## Alcance expresado por el usuario

- Una configuración pública del flake por equipo, sin sufijos de escritorio.
- Selección interpretada: envy, lenovo y orgm → Ryoku; ero y jarq → i3.
  orgm-ryoku pasa a orgm. Confirmar si la enumeración pretendía otro reparto.
- Escoger la configuración existente preferida, NO fusionar alternativas.
  Conservar archivos de los escritorios no seleccionados, pero sin publicarlos
  como sistemas alternativos. Futuros escritorios adicionales conviven dentro
  de la misma configuración de host cuando se pidan expresamente.
- En Ryoku, Hyprland y Niri son sesiones del mismo sistema, no flakes distintos.
- Inicio de aplicaciones y preferencias anidadas por host/usuario, con Ryoku
  como gestor visible donde su interfaz y backend lo admitan.
- Revisar huella, servicios, atajos y provisión cifrada de accesos a aplicaciones.
- Pantallas de envy: recorte en cualquier ventana pospuesto por el usuario.

Aclaración CONFIRMADA por el usuario: conservar los modos internos de cada host
(normal/gaming/Windows/server y los que ya tenga) y eliminar las variantes de
escritorio del flake. No cambiar sus predeterminados ni comportamiento como efecto
lateral. Los modos pueden seguir siendo specialisations dentro de la única salida
del host, no outputs nuevos envy-gaming/envy-server. Los modos de envy pendientes
no se consideran implementados por esta confirmación.

## Decisiones adicionales confirmadas

- Mantener el autoinicio existente de Syncthing y Tailscale durante la migración;
  distinguir servicio de bandeja y no retirar ninguno por confundirlos con apps
  opcionales. Bandejas solo en sesiones gráficas donde correspondan; sin añadir
  procesos gráficos en modos de servidor/consola que antes no los ejecutaban.
- Nextcloud, Discord, Steam y el resto de aplicaciones personales deben derivarse
  de preferencias explícitas del usuario, no forzarse por pertenecer al host o a
  Ryoku. No convertir el bloque global de ocho comandos en nuevos defaults de
  host. Preferencias del usuario pueden variar por host cuando él lo declare.
- Sunshine y otros servicios declarados por modo mantienen su dueño y ciclo de
  vida; no deshabilitarlos ni duplicarlos como aplicaciones de bandeja.
- Claude Code: NO usar API key. Estudiar exclusivamente la vía de suscripción/OAuth
  compatible, con SOPS opt-in y estado mutable protegido; no cambiar facturación.
- Bitwarden CLI ya funciona para el usuario. Su servidor es Vaultwarden propio:
  https://vw.or-gm.com. Configurar ese endpoint, no el cloud de Bitwarden. No
  ejecutar logout/reconfigurar sobre una sesión existente sin una migración
  aprobada; esta auditoría no lee ni modifica su estado ni credenciales.
- Conservar modos internos de cada host; retirar variantes públicas por escritorio
  sin borrar sus archivos. No mezclar configuraciones alternativas existentes.

## Evidencia local y límites

- Inventario actual: configurations.nix y lib/mk-system.nix producen variantes
  por escritorio más aliases; orgm/lenovo aún apuntan a Hyprland personal.
- Evaluadas opciones de envy, lenovo-ryoku, orgm-ryoku, ero-i3 y jarq-i3.
  No equivale a comprobar los cinco sistemas desplegados ni sus periféricos.
- En los cinco: NetworkManager, Bluetooth, PipeWire, polkit, GNOME keyring,
  UPower, power-profiles-daemon, fwupd, impresión, Tailscale y portales activos
  declarativamente; fprintd desactivado. TLP desactivado, no añadirlo junto a PPD.
- Ryoku ya declara Hyprland y Niri. Niri usa gnome/gtk para portales y Hyprland
  hyprland/gtk; no confundir tener varios proveedores instalados con un conflicto.
- lm-sensors y ddcutil ya pertenecen a la clausura de envy. DDC/CI requiere además
  monitor/cable/permisos efectivos; no se probó modificando el monitor en esta ronda.
- geoclue está desactivado: opcional para ubicación automática, no fallo de base;
  preferible ubicación manual o permiso explícito antes de añadir geolocalización.
- Defecto previo comprobado en envy: ryoku-idle llama output.power on y el
  proveedor no encuentra hyprctl en PATH. Sigue pendiente; no atribuirle el recorte.
- SSH a envy estuvo disponible para lsusb: Synaptics 06cb:00c9. En orgm local no
  apareció lector USB evidente; no demuestra ausencia de sensores SPI/otros buses.
  Lectores de Lenovo/ero/jarq aún sin inventario físico en esta ronda.

## Huella: integración por capas, no un solo interruptor

1. Inventariar ID exacto y verificar soporte en la versión fijada de libfprint.
   En esta configuración libfprint1.94.10. La lista oficial publicada es de la
   versión de desarrollo y no garantiza soporte de todas las versiones estables.
2. Declarar fprintd por host compatible; enrolamiento presencial/local por usuario.
   Nunca poner huellas/plantillas biométricas, emparejamiento o PIN de recuperación
   en Git, ni asumir que se transfieren entre lectores/equipos.
3. Definir explícitamente uso en SDDM, bloqueo y opcionalmente sudo/polkit.
   Mantener contraseña y acceso de recuperación; probar cada conversación PAM.
4. El port NixOS fijado sustituye assets/pam/ryoku-lock por pam_unix password-only.
   El shim actual de qylock usa DOS conversaciones PAM: fingerprint y password.
   Activar fprintd NO repara automáticamente esa adaptación; hace falta corregir
   la integración de forma nativa y probar ambos caminos sin bloquear al usuario.
5. Los toggles PAM de la página Lockscreen todavía buscan grosshack en /usr/lib
   y editan /etc/pam.d: no adoptarlos como escritor paralelo a módulos NixOS.
6. Envy06cb:00c9 no aparece en la lista oficial consultada. synaTudorMiS dice
   probado ese ID, pero es experimental, no está en desarrollo activo, modifica
   libfprint/fprintd y advierte pérdida del emparejamiento Windows al formatear
   el sensor. No instalar/alterar firmware/emparejamiento sin proyecto y permiso
   separado. No prometer que la huella de envy funcionará con fprintd estándar.

Fuentes primarias:
- [libfprint: dispositivos](https://fprint.freedesktop.org/supported-devices.html).
- [port NixOS fijado](https://github.com/aethctl/Ryoku-on-NixOS/blob/28c5207586babb136aecf8568ce3ed873fa8f8fd/nix/modules/ryoku.nix).
- [synaTudorMiS: estado y riesgos](https://github.com/vojtapl/synaTudorMiS).

## Qué puede poseer Ryoku y qué debe seguir declarativo

| Área | Estado / propuesta |
| --- | --- |
| Sesiones, shell, Hub, paneles, atajos, apariencia | Ryoku UI y almacenes admitidos; generar defaults de host/usuario y conservar cambios según política explícita |
| Autoinicio de aplicaciones | Syncthing/Tailscale conservados; otras apps desde preferencias del usuario, con variación de host explícita. Una lista efectiva nativa Hyprland/Niri sin duplicar user.lua/XDG/unidades |
| Bloqueo/idle | Ryoku controla política y UI; NixOS dependencias y ciclo de vida, arreglar PATH y probar resume |
| Keyring | Mantener colección cifrada y unlock-on-login; no activar never-ask borrando contraseña ni resetear colecciones para eliminar avisos |
| Audio/red/Bluetooth/energía | Servicios ya declarados; controles de Ryoku sobre APIs soportadas y pruebas de aceptación reales |
| Paquetes/kernel/GPU/PAM/firewall/arranque | NixOS fuente de verdad; adaptar bridges puntuales, no dar permisos amplios de escritura al Hub |
| DNS/backend Wi-Fi/Docker | Ya existen bridges NixOS de Ryoku; verificar política por host y no ejecutar comandos Arch genéricos |
| Snapshots | Política propia declarada, root-only; no debilitar permisos para satisfacer recomendaciones visuales ni confundir Snapper con backup |
| FIDO2, cámara/sensores/ubicación, dictado/Rashin/IA | Opcionales condicionados a hardware, uso, credenciales, privacidad y coste; no habilitarlos solo para eliminar avisos |

### System Check real de envy (solo lectura)

Ejecutado `ryoku doctor --json` con bus/sesión Wayland del usuario, sin reparaciones
ni --explain. Resultado:113 comprobaciones,100ok,7todo,4warn,2note. Salida privada
completa: ~/.local/state/envy/ryoku-system-check-audit.json. No interpretar el
código0 como ausencia de avisos, ni ejecutar remedies Arch a ciegas.

| Aviso real del Hub/Doctor | Interpretación en esta instalación |
| --- | --- |
| Faltan agente de autenticación, audio, portal y NetworkManager | Comprobación basada en paquetes Arch. Servicios NM/PipeWire/WirePlumber/portal realmente active. Ryoku tiene agente polkit nativo en su daemon; no instalar otro solo porque no hay proceso hyprpolkitagent. Falta validar autorización interactiva, no consta falta de paquetes. |
| SDDM no lleva pam_gnome_keyring | El detector mira líneas directas; sddm usa auth substack login/session include login. login sí tiene pam_gnome_keyring por ruta Nix. Corregir detección de include/substack; no duplicar PAM ni resetear keyring. Desbloqueo real de colección aún debe comprobarse. |
| Falta Bibata-Modern-Ice | Tema encontrado en /run/current-system/sw/share/icons/Bibata-Modern-Ice. Detector FHS debe reconocer rutas Nix; no reinstalar por ese aviso. |
| Portal anterior a la sesión | Candidato a revisar timestamps/entorno de la sesión y ensayo de compartir pantalla. No se reinició portal en esta auditoría. |
| Snapshot read access | La política privada root-only impide contar sin privilegios. Adaptar reporte de metadatos con alcance mínimo o mostrar no disponible, no abrir contenido de snapshots para que diga verde. |
| Follow-mouse=1 | Preferencia personal fijada; no sustituir automáticamente por el nuevo default de Ryoku. |
| Host nativo de tema Chromium | Integración opcional del navegador; revisar qué navegador y manifest usa realmente antes de instalar. |
| Guía de user_edits y carpeta de grabaciones ausentes | Mejoras pequeñas de instalación inicial; declararlas/sembrarlas sin pisar datos. No requieren daemon adicional. |
| Dominio regulatorio00; sugiereUS por locale | Confirmar país físico y declarar el correcto; idioma/locale no demuestra país. No aplicarUS automáticamente. |
| NVIDIA sin runtime suspend | Sugerencia genérica fine-grained0x02/mkinitcpio inaplicable a MX250Pascal/NixOS. NVIDIA exige Turing o posterior para RTD3; mantener guarda actual, no copiar el remedio. |
| No fingerprint reader | La ausencia de fprintd/driver hace que el detector no lo vea; lsusb sí muestra06cb:00c9. No equivale a ausencia física de lector. |
| Fallo sops-nix de usuario | Limitación ya aceptada hasta que el usuario aporte identidad; no perseguirla como defecto nuevo. |

Fuentes adicionales: Polkit.qml de la versión fijada describe agente propio;
NixOS pam.d/login y sddm comprobados sin leer secretos.
[Requisitos RTD3 NVIDIA580](https://download.nvidia.com/XFree86/Linux-x86_64/580.65.06/README/dynamicpowermanagement.html).
Ryoku doctor sin argumentos aplica reconciliaciones. --check/--json son de
solo lectura; no se ejecutó doctor normal ni --explain (no se envían informes
a modelos externos). No se cambió la configuración del monitor durante esta ronda.

## Estructura propuesta (todavía no implementada)

Una salida por host con hardware, usuario(s), selección de escritorio/sesiones,
aplicaciones, autoinicio, capacidades y políticas de secretos claramente anidados.
Separar cuatro ámbitos: capacidad hardware del host, preferencias del usuario,
combinación host/usuario y estado privado mutable. Reutilizar módulos comunes sin
mezclar los antiguos escritorios; valores explícitos por host donde varíen.

La migración deberá actualizar consumidores de nombres: nh/rebuild, Ryoku update,
scripts, CI, docs y pruebas. Los fixtures de escritorios alternativos pueden
seguir en tests sin volver a publicarse como sistemas de usuario. No conservar
aliases alternativos activos indefinidamente si contradicen la configuración única.

## Credenciales y estado privado

Auditoría independiente de documentación primaria y código/ayuda instalados,
sin leer las credenciales. SOPS sirve para bootstrap compatible, no para prometer
cualquier sesión permanente entre todos los equipos.

| Aplicación | Viabilidad de bootstrap / límites |
| --- | --- |
| Bitwarden CLI | Usuario confirma funcionamiento con Vaultwarden https://vw.or-gm.com. Declarar ese servidor y preservar sesión existente. BW_CLIENTID/BW_CLIENTSECRET + login --apikey son vía soportada si se decide bootstrap; no copiar credenciales del cloud ni asumir que autenticar desbloquea la bóveda o inicia GUI/extensión. |
| Bitwarden escritorio/extensión | Preferencias/servidor sí; no se encontró contrato oficial para clonar sesiones entre hosts. Biometría es desbloqueo local posterior, no primer login universal. |
| Nextcloud desktop | Docs actuales soportan provisioning no interactivo con app password revocable por host, no contraseña principal. Verificar versión instalada. Exige ruta local nueva/vacía y expone la contraseña por argumento en la interfaz documentada: estudiar protección de procesos/logs antes de automatizar. No repetir cada rebuild. |
| Steam | Instalación/preferencias sí; no se encontró interfaz oficial de bootstrap declarativo de sesión. Mantener login/Steam Guard por equipo; persistencia local no es garantía de portabilidad de archivos. |
| Discord escritorio | Instalación/preferencias y login oficial/QR. No se encontró importación declarativa soportada de sesión; token bot no autentica cliente personal. No automatizar cuenta como self-bot. |
| Tailscale | Auth key de enrolamiento soportada, mínimo alcance e idealmente de un uso/por host. No copiar estado para convertir varios equipos en el mismo nodo. Caducidad de auth key distinta de autorización del nodo; estado seguro TPM exige el mismo TPM. |
| Claude Code | API key DESCARTADA expresamente por el usuario. Estudiar suscripción/OAuth: claude setup-token → CLAUDE_CODE_OAUTH_TOKEN de larga duración con límites de funcionalidad; no sustituye todas las funciones del login interactivo ni vuelve inmutable una sesión ordinaria. No cambiar a facturación API. |
| omp (Oh My Pi) | Confirmado @oh-my-pi/pi-coding-agent, local18.10.3. API keys por proveedor y broker/gateway oficiales. OAuth renueva estado en ~/.omp/agent/agent.db: no tratar SQLite mutable como configuración fija ni compartir una copia entre hosts. Dependiente de política de cada proveedor. |
| Codex | Local0.162.1: ayuda soporta with-api-key/access-token/device-auth. Docs OpenAI admiten copiar auth.json a headless como fallback; no decir imposible. Es un secreto equivalente a contraseña; estado posterior a refresh debe conservarse, no sobrescribir por snapshot antiguo en cada rebuild. API key tiene facturación API, no traslada suscripción. |

Referencias por aplicación:
- [Bitwarden CLI](https://bitwarden.com/help/cli/), [biometría](https://bitwarden.com/help/biometrics/).
- [Nextcloud deployment](https://docs.nextcloud.com/server/stable/admin_manual/desktop/massdeployment.html).
- [Steam Guard](https://help.steampowered.com/en/faqs/view/6639-EB3C-EC79-FF60).
- [Discord login](https://support.discord.com/hc/en-us/articles/360057027354-How-to-Log-In-to-your-Discord-Account), [self-bots](https://support.discord.com/hc/en-us/articles/115002192352-Automated-User-Accounts-Self-Bots).
- [Tailscale auth keys](https://tailscale.com/docs/features/access-control/auth-keys), [secure state](https://tailscale.com/docs/features/secure-node-state-storage).
- [Claude Code authentication](https://code.claude.com/docs/en/authentication).
- [Oh My Pi providers](https://github.com/can1357/oh-my-pi/blob/main/docs/providers.md), [broker](https://github.com/can1357/oh-my-pi/blob/main/docs/auth-broker-gateway.md).
- [OpenAI/Codex authentication](https://learn.chatgpt.com/docs/auth).
- [sops-nix](https://github.com/Mic92/sops-nix).

En el repo ya existe SOPS de usuario para API keys; Tailscale se enrola manualmente.
La identidad age puede provenir de Nextcloud: evitar dependencia circular si esa
misma identidad es lo único que permite autenticar Nextcloud al instalar de cero.

Reglas: solo ciphertext SOPS en Git; clave age fuera; descifrar en runtime con
permisos/propietario correctos y acceso de mínimo privilegio. Nunca Nix .text,
builtins.readFile del secreto descifrado, variables de build ni argumentos con
secretos. El enrolamiento inicial de la clave es externo (no puede descifrarse a
sí misma desde el repo). No leer/copiar ficheros de login durante la investigación.

La huella no proporciona la contraseña con que se cifra GNOME keyring. Login
solo por huella puede pedir desbloquear la colección al primer uso: no solucionarlo
con keyring vacío ni guardando la contraseña PAM en Git.
[GNOME: arranque/desbloqueo](https://wiki.gnome.org/Projects/GnomeKeyring/RunningDaemon).

SOPS puede ayudar al bootstrap soportado por cada app, pero no convierte
cookies/refresh tokens en credenciales inmutables, evita revocaciones ni renueva
sesiones por sí mismo. Preservar estado actualizado del host y no sobrescribirlo
cada rebuild con una copia antigua. Valorar secretos por host, no una credencial
compartida entre todos los equipos por defecto. SOPS opcional para usuarios/apps
no provisionados según preferencia previa; no hacer fallar escritorio básico por
secretos opt-in ausentes.

## Atajos y autoinicio: hallazgos concretos

- Vía nativa compartida: Hub → Session → desktop.autostart, lista de objetos
  command en ~/.config/ryoku/desktop.json. Los proveedores Hyprland y Niri la
  materializan. Nuestra lista personal actual de ocho comandos está en user.lua
  de Hyprland, compartida por todos los hosts osmarg; no es política por host ni
  garantiza arranque de esas aplicaciones en Niri.
- Migrar solamente ese bloque al mecanismo nativo; conservar Syncthing/Tailscale.
  El resto debe venir de la configuración del usuario, no del host ni de una copia
  de los ocho defaults anteriores. NO conservar dos lanzadores para las mismas apps. Sunshine ya tiene autoStart de
  su unidad y un systemctl start en ese bloque; systemd deduplica el proceso,
  pero la responsabilidad está duplicada. Revisar XDG autostart y unidades de
  Nextcloud/KDEConnect/etc: ryoku-session.target quiere xdg-desktop-autostart.target.
- H/J/K no están libres de origen: el Ryoku nativo usa Super+H para scratchpad,
  Super+J para Ryotunes y Super+K para la ayuda. Super+S abre Stash/side menu,
  Super+Escape quicksettings, Super+comma Hub. Scratchpad H no es capacidad
  nativa de Niri; no prometer equivalencia de acciones no soportadas.
- Nuestra capa reserva H/J/K y mueve colisiones nativas a acordes de CUATRO
  modificadores (Super+Ctrl+Alt+Shift+K/J/S/Escape, según registro), lo que hace
  difícil descubrirlos. Es lógico que parezcan faltar accesos al menú lateral.
- Además Hub/cheatsheet interpreta modules/*.lua y keybindRebinds de desktop.json,
  no el código dinámico de nuestro modules.rebind ni osmarg-keybindings.lua;
  puede anunciar combinaciones distintas a las efectivas. No basta añadir otro
  bind oculto ni asumir que la reserva personal es un espacio libre universal.
- Preferir almacenamiento soportado compartido desktop.keybindRebinds,
  desktop.keybinds ({keys,action:"exec",value:...}) y desktop.unbinds. H/K pueden
  reasignarse si elegimos qué función conservar/mover, con detección de conflictos
  y catálogo veraz; no asignados aún en esta auditoría.
- Comandos neutrales disponibles para esas acciones: ryoku-shell quicksettings,
  stash, clipboard, launcher y hub open [keybinds|session]. Validar sintaxis por
  acción y backend; no mezclar un bind de Hyprland con una acción ausente en Niri.

Evidencia: versión fijada Hub SessionPage/backend session, proveedores
ryoku/wm/hyprland y niri; wm/hyprland/legend.go; lista personal user.lua y
orgm-ryoku/shortcuts.lua/osmarg-keybindings.lua. Lectura independiente sin ediciones.

## Siguientes decisiones antes de implementar

- Modos internos vs variantes de escritorio: RESUELTO, se conservan los primeros.
- Autoinicio obligatorio Syncthing/Tailscale y resto usuario: RESUELTO como política;
  elegir listas opcionales concretas por usuario/host sin inferirlas de los defaults.
- Seleccionar política de cambios hechos desde Hub: defaults iniciales conservados
  frente a preferencias explícitamente administradas/reimportadas al repo.
- Aprobar bootstrap de credenciales por aplicación, alcance, revocación y rotación.
- Inventariar lectores y probar PAM/contraseña de recuperación antes de activar.
- Preparar diseño/plan con pruebas; nada de switch/test/boot ni migración destructiva
  como consecuencia de esta auditoría.
