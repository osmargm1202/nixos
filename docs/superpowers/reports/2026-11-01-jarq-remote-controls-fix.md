# Jarq: logos, búsqueda y controles del mando

Aplicado el 2026-11-01, generación **56**, sin reboot:
`/nix/store/n3achzrj6cx99xxc33vi5b4wmbzkrkw2-nixos-system-jarq-jarq-multimedia`.
Aplicación publicada y fijada en `e1f8f13a6a27d207125ebfe1e48f05dc40698892`.

## Correcciones

- Los seis accesos usan logos SVG con nombre accesible y selección visible.
  Fuentes/atribución en `static/icons/brands.txt` de la aplicación.
- La app activa no recibe órdenes de foco ni reproducción al tocar su acceso;
  una app abierta usa el endpoint de cambio de ventana. El agente también evita
  efectos si la ventana de esa app ya está enfocada.
- Play/Pausa de YouTube resuelve el reproductor MPRIS por proceso/cgroup, en vez
  de asumir el nombre VacuumTube. En Jarq se anuncia como chromium.instance3.
- Buscar abre su propia vista con un campo y su envío, sin archivos locales ni
  formulario de enlaces. La consulta reemplaza el texto y pulsa Enter en una
  acción del agente, vinculada a la app elegida; rechaza cambios de aplicación.
- Enter del teclado envía la tecla nativa, separada de OK/activación de elementos.

## Validación y despliegue

La base exacta de la generación 55 se compiló en una copia temporal de Lenovo;
solo se actualizó el input de aplicación. No se activó ningún sistema en Lenovo.
Clausura transferida a Jarq con nix copy, switch correcto y guardia temporal de
rollback desarmada tras comprobar el resultado.

261 pruebas unitarias en Nix y 139 acciones de navegador aprobadas. La prueba de
navegador verifica logos, acceso activo sin mutaciones, búsqueda independiente,
envío mediante Enter del teléfono y tecla Enter separada de OK.

En Jarq real se comprobó que el acceso a YouTube activo devuelve unchanged sin
cambiar PlaybackStatus, y que Play/Pausa produce Playing → Paused → Playing.
Se restauró su estado inicial. El HTML autenticado contiene los seis logos, la
vista de búsqueda independiente y el control Enter. Servicios y HTTPS correctos;
ninguna unidad fallida. Token y registro de autorizaciones conservan sus hashes.
Al cierre siguen abiertos Inicio, YouTube y Spotify, con YouTube en pantalla.

No se hizo una búsqueda nueva sobre el video del usuario durante la aceptación
física. El envío y Enter están verificados en pruebas del agente y navegador;
las integraciones DOM de los proveedores comerciales conservan los pendientes
por servicio documentados en la entrega anterior.

Fuente reproducible y evidencias en
`~/.local/state/orgm-multimedia/20261101-controls-fix/` (ORGM),
`/home/jarq/Hobby/nixos-multimedia-controls-fix/` (Jarq), y
`/tmp/orgm-controls-fix-20261101/source/` (Lenovo).
La generación 55 queda disponible para volver atrás.
