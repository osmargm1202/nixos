# Modo de pantalla táctil siempre encendida

Aplicado en Jarq, generación 65, sin reiniciar el equipo:
`/nix/store/glws6fl0k6vxpbai8jp6sim5p9d0awak-nixos-system-jarq-jarq-multimedia`.
Aplicación: `736778046c7eb278c1d26338271b5d829996c2ac`.

Opciones → Administración incorpora «Pantalla táctil siempre encendida». Se dejó
activado a petición del usuario. Desactivarlo recupera 20% a los 20 s, 0% a los
60 s y despertar al tocar. Cada cambio despierta el panel al 100% y reinicia
los tiempos. Es una preferencia persistente del usuario media, compartida entre
mando y dashboard, independiente del fondo y de la salida externa.

El helper de atenuación consulta el marcador privado touch-always-on antes de
cualquier acceso al brillo o bl_power. El wrapper de orgm-home-idle despierta
el panel antes de iniciar swayidle. El agente reinicia solo esta unidad; si
falla, revierte la preferencia. No reinicia launcher, compositor ni aplicaciones.

334 pruebas unitarias y 186 acciones de navegador: validación estricta, CSRF,
persistencia tras crear un agente nuevo, conservación del fondo, rollback de
preferencia y alternancia Sí/No en la interfaz. Compilado en Lenovo desde la
fuente exacta conservada de la generación 64 más estos cambios de atenuación.
No se activó Lenovo ni se incorporaron cambios ajenos de perfiles.

La activación terminó con ExecMainStatus=0. Se verificaron código JS servido,
endpoint autenticado, selección activada y HTTPS /api/health 200. Se restauró
la aplicación previa; servicios activos y ninguna unidad fallida. Token y
mandos autorizados conservados. La primera consulta coincidió con el reinicio
HTTP durante el switch; se repitió una vez terminada la activación.

Aceptación física: marcador guardado con permisos 0600; a los 86 segundos
tras reiniciar la unidad de inactividad, brillo 852/852 (100%) y bl_power=0.
No se inyectaron entradas durante la comprobación. Rollback desarmado.

Fuente exacta en ~/.local/state/orgm-multimedia/20261104-touch-always-on/source,
/home/jarq/Hobby/nixos-multimedia-touch-always-on y
/tmp/orgm-touch-always-on/source (Lenovo).
