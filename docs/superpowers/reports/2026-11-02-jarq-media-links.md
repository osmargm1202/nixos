# Win+Alt+Y: enlaces multimedia por servicio

Aplicado el 2026-11-02 en Jarq, generación **58**, sin reboot:
`/nix/store/z4dzhg9c5xq3cczq3ys02qg6d9m80da5-nixos-system-jarq-jarq-multimedia`.
Aplicación publicada y fijada: `60df11217d22abcaa9dbc0004b9c19f5d41b4091`.

## Alcance

El mismo atajo reconoce enlaces directos de contenido de YouTube, Netflix,
Disney+, Max/HBO Max, Crunchyroll, Prime Video y Spotify. Valida servicio y
formato antes de abrir una sesión o enviar HTTP. No hay navegador en el emisor
ni retorno al portapapeles antiguo cuando falta selección. El formulario del
mando y `/media/link/?key=...` aceptan los mismos servicios; el enlace antiguo
`/youtube/link/` también se conserva.

El receptor abre la aplicación detectada y reutiliza la página enfocada de Chrome
con CDP, evitando crear otra ventana. Spotify recibe una URI nativa validada.
El arranque de video es una acción de inicio, no Play/Pausa, y comprueba el ID en
la página. El intento se cancela ante interacción del mando o cambio de fuente.
No elige perfiles, inicia sesión ni pulsa compras; Prime Video solo inicia un
reproductor ya cargado. La respuesta confirma la solicitud, no certifica DRM,
disponibilidad o reproducción comercial. Detalles en docs/media-links.md de la app.

## Instalación

La base exacta de la generación 57 se compiló en Lenovo, cambiando únicamente
el input de aplicación. No se activó sistema en Lenovo. Se transfirió la clausura
a Jarq y se aplicó con guardia de rollback, desarmada tras verificar el resultado.
Se conserva la generación 57.

En ORGM se instaló el paquete construido en Lenovo dentro del perfil de usuario
`~/.local/state/orgm-home/youtube-send/profile` y se actualizó el helper local
para preferir la versión multimedia. El binding sigue ejecutando el mismo nombre
`orgm-send-youtube`; la versión efectiva es 3. No hubo switch en ORGM.
La carpeta/cookie de autorización no se migró; su sesión HTTPS sigue válida.
Envy no respondió por SSH: el pin prepara su siguiente reconstrucción, pero no
se afirma actualización inmediata de su emisor.

## Verificación

- 293 pruebas unitarias en Nix; 144 acciones de navegador.
- Chromium aislado: navegación CDP sobre la página existente, inicio del contenido
  esperado y rechazo de un ID distinto; pruebas de selectores con fixtures.
- Emisor efectivo de ORGM: planes POST correctos para Netflix y Disney+, versión
  3 y autorización guardada válida con el Python empaquetado.
- Jarq: endpoint genérico autenticado; enlace inválido devuelve 422 sin cambiar
  de fuente; GET del enlace rápido no actúa; formulario genérico presente.
- HTTPS 200, servicios activos y ninguna unidad fallida. Token y registro de
  dispositivos autorizados conservan sus hashes.
- No se envió una película comercial de prueba. Se solicitó un enlace al usuario;
  la reproducción con sus cuentas sigue pendiente de esa aceptación real.

El chequeo inicial con el Python descargado por uv carecía de la CA del sistema;
se repitió con el Python Nix que usa el emisor y la sesión HTTPS pasó. No se
relajó la validación TLS. La copia del paquete propio a ORGM requirió importar
sin firma desde el host Lenovo autenticado por SSH; no se alteró la política
permanente de firmas del sistema.

Fuente/evidencia: `~/.local/state/orgm-multimedia/20261102-media-links/` en ORGM,
`/home/jarq/Hobby/nixos-multimedia-media-links/` en Jarq y
`/tmp/orgm-media-links-20261102/source/` en Lenovo. Copia del helper previo en la
carpeta de evidencia. Se preservan los pendientes de Syncthing del checkout.
