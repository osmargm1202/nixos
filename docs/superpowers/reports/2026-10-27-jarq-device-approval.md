# Jarq: aprobación local de mandos y dominio único

Se sustituyen los códigos de seis dígitos por **Solicitar permiso** en
`https://home.or-gm.com`. La solicitud aparece centrada en una superficie nativa
Quickshell sobre la aplicación abierta, con nombre y navegador y controles
**No, rechazar / Sí, autorizar**. No cambia la fuente ni requiere volver a Home.
La pantalla interna despierta para mostrarla; conserva atenuación 20 s / 60 s.
Las solicitudes vencen en 120 segundos y se limitan a tres pendientes.

Administración del kiosk ofrece dispositivos autorizados, fecha, navegador y
Revocar con confirmación. Solo la sesión local puede listar, aprobar o revocar;
un mando remoto no adquiere esos permisos aunque el proxy conecte por loopback.
La persistencia usa JSON privado y reemplazo atómico, con un único worker API.
Cada cookie corresponde a un dispositivo distinto y su revocación se comprueba
en cada acción. La cookie HttpOnly/Secure/SameSite Strict se renueva al abrir el
mando y dura hasta 400 días en el navegador; borrar cookies o sus propias
políticas de caducidad requieren una nueva solicitud. No es una identidad de
hardware ni persiste a través de distintos navegadores.

La clave interna del launcher/DIAL solo se admite por loopback; ya no inicia
sesión mediante el dominio remoto. Las cookies del formato anterior dejan de
ser válidas. No hay claves ni credenciales en el repositorio o el informe.

Nginx sirve el multimedia exclusivamente con Host `home.or-gm.com`, redirige su
HTTP a HTTPS y rechaza hosts desconocidos/IP con 421 y rechazo del handshake
TLS predeterminado. Se elimina el virtualhost LAN y su Origin autorizado.
La API interna y el descubrimiento DIAL siguen disponibles para sus clientes;
no se cambia la dirección DNS, el certificado ni el acceso privado de Tailscale.
`X-Real-IP` se sobrescribe en Nginx y solo se usa desde el proxy loopback para
separar los límites de peticiones de varios mandos. No otorga permisos locales.

## Versiones y despliegue

- Aplicación pública: `osmargm1202/orgm-multimedia`, revisión
  `19952115f91d5bb1b715c83e42cf0d70eea414d1`.
- Perfil: `jarq-multimedia`; generación instalada **52**.
- Sistema: `/nix/store/h6if8sb1wb63rpdc5yz6k3kp1rnfcb6q-nixos-system-jarq-jarq-multimedia`.
- Generación anterior: 51, conservada para reversión.
- Se importó el cierre compilado y se aplicó con protección temporal de rollback;
  la protección quedó aceptada y su timer detenido tras la comprobación real.
- API, Nginx, DIAL y los cinco servicios de sesión activos; ninguna unidad
  fallida. Registro `/var/lib/orgm-home/devices.json`: propietario media, 0600.
- Se probó con un mando temporal creado y revocado durante la aceptación; no se
  dejó ese acceso autorizado. No se apagó ni reinició físicamente el equipo.

## Validación

- **201 pruebas unitarias** aprobadas; seguridad, aprobación/rechazo/caducidad,
  sesiones tras reinicio, revocación, CSRF, privilegios locales y cola limitada.
- Ruff: análisis de sintaxis/variables de la aplicación y tests; comprobación
  completa de los módulos cambiados de autenticación y control local aprobada.
- Navegador real: solicitud móvil, espera, aprobación por API local, recarga sin
  volver a vincular, Administración, cancelar revocación y revocar. **125 acciones**
  de regresión; capturas `/tmp/orgm-browser-6x_eo7pb`. Bomba simulada aprobada.
- Sway/Chrome/Quickshell reales en sesión aislada: botones nativos de aceptar y
  rechazar mediante puntero Wayland, fuente conservada, revocación y controles
  anteriores aprobados en `/tmp/orgm-sway-smoke-qa2jhcbl`. Un primer pase de la
  revisión final agotó la espera de selección del cursor Home; la repetición
  sin cambios pasó. No se atribuye una causa que no se haya demostrado.
- VM NixOS final aprobada:
  `/nix/store/pwg6fjbrf0kvf3mpc27mvpbvi8fgp9sx-vm-test-run-orgm-multimedia-boot`.
  Comprueba arranque, restricciones por Host, caché/gzip, DIAL y apagado/reinicio
  de la VM; no representa una prueba DRM ni de teléfono físico.
- Aceptación **en Jarq real** aprobada: dominio HTTPS, IP LAN/Tailscale HTTP 421,
  rechazo TLS por IP, clave interna rechazada remotamente, aviso centrado con
  botones reales, despertar de retroiluminación, fuente conservada, persistencia
  tras reiniciar únicamente API, administración remota denegada y revocación
  inmediata. Evidencia privada `/tmp/orgm-device-acceptance.log` y captura
  `/tmp/orgm-device-native-real.png`; la fuente al empezar esa prueba era Home.
- El detector visual no resuelve enlaces Jinja a estilos y advirtió una jerarquía
  tipográfica plana ficticia de 16 px; las capturas reales muestran los tamaños
  existentes. Se corrigió el ancho heredado del botón Revocar en móvil y se
  confirmó sin desbordamiento.

Evidencias seleccionadas, sin cookies ni archivos de claves, se conservan en
`~/.local/state/orgm-multimedia/20261027-device-approval/` en la estación de trabajo.
La aceptación del teléfono del usuario queda para uso real: recargar el dominio,
solicitar permiso y aceptar en la pantalla táctil. Tailscale sigue siendo necesario
cuando se usa la resolución actual del dominio.
