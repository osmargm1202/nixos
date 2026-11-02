# Jarq: mando con navegación por elementos y controles por servicio

Aplicado con autorización del usuario el 2026-11-01. Generación **55**, sistema
activo y predeterminado:
`/nix/store/wnzpczibgsq56cq2hdn0c6yf3ilkwqx1-nixos-system-jarq-jarq-multimedia`.
Se conserva la generación 54. No hubo reboot ni activación de sistema en Lenovo.

## Cambio

Aplicación publicada y fijada en `df4887317ba8c7297809266e1dc8f69a33b6df4b`:
seis accesos fijos en el mando (YouTube, Netflix, Disney+, HBO Max, Crunchyroll,
Spotify), Buscar, Play/Pausa y selección espacial del DOM para webapps Chrome.
Los selectores se mantienen por servicio. Spotify usa navegación nativa por
Tab/Shift+Tab y MPRIS; YouTube conserva su interfaz VacuumTube.

La política de salida de media bloqueaba los puertos DevTools aleatorios.
Se asigna un puerto fijo `32000 + workspace` a cada perfil Chrome y se permite
únicamente esa lista de puertos, para UID 1100 y destino 127.0.0.1. No se expone
DevTools en LAN/Tailscale. El agente verifica la página enfocada y los dominios
configurados, y no acepta código JavaScript del mando.

## Construcción y alcance

Se reprodujo exactamente la generación 54 desde su fuente archivada en Jarq y se
actualizaron solo el input de aplicación y la regla local de firewall. Lenovo
compiló el sistema completo; Jarq recibió la clausura mediante `nix copy`.
La comparación de clausuras no muestra cambios de versión de paquetes: solo
cambia orgm-multimedia (67,6 KiB menos). Se evitó aplicar el conjunto de cambios
generales posteriores del checkout principal, incluidos los pendientes de
Syncthing.

Fuente exacta instalada y evidencias:
`~/.local/state/orgm-multimedia/20261101-web-navigation/` en ORGM;
fuente archivada también en `/home/jarq/Hobby/nixos-multimedia-web-navigation/`.
La compilación de Lenovo está en `/tmp/orgm-deploy-20261101/installed-source/`.
El pin y la regla quedan también en el repositorio principal para futuras
reconstrucciones; ese checkout incluye otros cambios posteriores a la base usada.

## Validación

- 255 pruebas unitarias aprobadas en la construcción Nix de la aplicación.
- Chromium aislado: transporte CDP real, selección, activación y cuatro perfiles
  de búsqueda/reproducción con fixtures. No certifica los sitios comerciales.
- Mando en navegador: 133 acciones, escritorio y móvil.
- Jarq real: navegador de prueba abierto en example.com; Derecha seleccionó un
  elemento mediante CDP y Abajo informó correctamente el límite de selección.
  Se cerró únicamente esa fuente de prueba y se restauró YouTube.
- API local autenticada y HTML comprobados: seis accesos, Buscar y Play/Pausa.
- HTTPS `https://home.or-gm.com/api/health`: 200 antes y después del cambio.
- Servicios web, cast, Nginx, nftables y cinco servicios de sesión activos;
  ninguna unidad fallida de sistema o usuario al cierre.
- Token y registro de dispositivos autorizados conservan su hash previo.
- YouTube y Spotify permanecen abiertos; la fuente final es YouTube.
- Guardia de rollback de 12 minutos desarmada tras las comprobaciones.

El switch completó correctamente. Una orden auxiliar posterior del wrapper no
localizaba `runuser` en el PATH de su unidad transitoria; se corrigió su PATH y se
verificó que los servicios nuevos ya estaban activos. No requirió otro switch.

## Pendiente de aceptación por servicio

Probar con las cuentas reales el buscador, resultados, filas, detalles y
Play/Pausa en Netflix, Disney+, Max y Crunchyroll; ajustar selectores si el DOM
actual difiere. Los reproductores en iframe externo requieren integración
adicional. Confirmar Buscar durante reproducción en VacuumTube y Ctrl+L en la
versión instalada de Spotify. El despliegue y la navegación genérica sí quedaron
verificados; no se atribuye aceptación DRM o por proveedor a las pruebas sintéticas.
