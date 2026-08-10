# Plan: selector Rofi de pestañas Firefox existentes

## Objetivo

En el perfil **i3**, `Win+Esc` abrirá Rofi con las pestañas Firefox ya existentes. Cada fila mostrará título, host e icono. Al elegir una, se enfocará la ventana Firefox que la contiene y se activará esa pestaña. El selector **no abrirá** pestañas ni ventanas, y fallará de forma visible si el puente no está disponible o la pestaña desaparece.

## Alcance y decisión

- Perfil objetivo: i3; no añadir bindings ni helpers a Hyprland, Labwc u otros perfiles.
- Reutilizar el puente nativo de `windows-manager-linux-orgm`; no usar `rofi -show window`, `wmctrl`, ni `firefox-open-tab`.
  - `rofi -show window` solo conoce ventanas del gestor, no pestañas internas de Firefox.
  - `firefox-open-tab` puede terminar en `firefox --new-tab`, contradiciendo el requisito de solo pestañas existentes.
- Transporte de selección: Rofi devolverá el índice de la fila (`-format i`), nunca el título. Los títulos se repiten, pueden contener separadores y no son identificadores.
- Transporte de iconos: Firefox expone `Tab.favIconUrl`, una URL, no un archivo gráfico. Rofi acepta nombre de icono, filename local o markup; no se debe asumir que descarga URLs HTTP(S). El host materializará solo favicons permitidos en una caché local y devolverá paths locales; las entradas sin icono o no materializables usarán el icono de tema `firefox`.

## Hallazgos de documentación — fase 0

| Capacidad | API/protocolo permitido | Evidencia |
| --- | --- | --- |
| Enumerar pestañas | `browser.tabs.query({})` devuelve `Promise<Tab[]>`. | [MDN tabs.query](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/API/tabs/query) |
| Metadatos para Rofi | `Tab.id`, `windowId`, `index`, `active`, `title`, `url` y `favIconUrl`. `url`, `title` y `favIconUrl` requieren `tabs` o host permissions. | [MDN Tab](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/API/tabs/Tab) |
| Enfocar selección | `browser.windows.update(windowId, { focused: true })`, seguido de `browser.tabs.update(tabId, { active: true })`. | [MDN windows.update](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/API/windows/update), [MDN tabs.update](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/API/tabs/update) |
| Host persistente | `browser.runtime.connectNative()` mantiene un puerto bidireccional con el host nativo. | [MDN native messaging](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Native_messaging) |
| Icono por fila Rofi | Fila dmenu: `DISPLAY\0icon\x1fICON\n`; `-show-icons` debe estar activo. | [Rofi dmenu spec](https://github.com/davatorium/rofi/wiki/dmenu_specs) |
| Selección estable Rofi | `rofi -dmenu -format i` devuelve el índice de entrada original. | [Rofi dmenu](https://github.com/davatorium/rofi/blob/next/doc/rofi-dmenu.5.markdown) |
| Favicon local | Rofi admite nombre de tema, filename local o markup. `thumbnail://` usa un path/thumbnailer; no hay API documentada para descargar un URL HTTP(S) arbitrario como icono. | [Rofi theme](https://github.com/davatorium/rofi/blob/next/doc/rofi-theme.5.markdown), [Rofi thumbnails](https://github.com/davatorium/rofi/blob/next/doc/rofi-thumbnails.5.markdown) |

La extensión actual ya declara `nativeMessaging` y `tabs` en `nixos/packages/windows-manager-linux-orgm/manifest.json`; por tanto puede leer los metadatos expuestos por Firefox. `background.js` ya aplica el patrón de foco requerido para `focus-existing`.

## Fase 1 — ampliar el contrato del puente Firefox

### Archivos

- `nixos/packages/windows-manager-linux-orgm/background.js`
- `nixos/packages/windows-manager-linux-orgm/native-host.py`
- `nixos/packages/windows-manager-linux-orgm.nix`
- `nixos/packages/windows-manager-linux-orgm/manifest.json`
- `tests/windows-manager-linux-orgm-background.test.js`
- `tests/windows-manager-linux-orgm.bats.sh`

### Implementación

1. Mantener el mensaje actual `focus-existing` sin cambio funcional para los lanzadores webapp.
2. Añadir dos acciones tipadas al protocolo nativo:
   - `list-tabs`: sin parámetros; responde con una lista ordenada de descriptores de pestaña existentes.
   - `activate-tab`: requiere `tabId` entero; activa únicamente esa pestaña existente.
3. En `background.js`, copiar el patrón existente `browser.tabs.query({})` y devolver, por pestaña elegible:
   ```json
   {
     "id": 123,
     "windowId": 7,
     "index": 2,
     "active": false,
     "title": "Título",
     "url": "https://example.com/path",
     "favIconUrl": "https://example.com/favicon.ico"
   }
   ```
   `title`, `url` y `favIconUrl` son opcionales: normalizarlos a valores ausentes, no inventarlos.
4. Para `activate-tab`, consultar/validar primero el `tabId` solicitado, enfocar `windowId` y activar el mismo `id`. Informar error si ya no existe; no convertir ese error en creación de pestaña.
5. En `native-host.py`, sustituir la validación URL-única de `read_client_message()` por un discriminante `action` estricto. Conservar request IDs y el límite de 64 KiB. Añadir wrappers de cliente explícitos, por ejemplo `windows-manager-linux-orgm-tabs list` y `windows-manager-linux-orgm-tabs activate TAB_ID`; no ampliar el wrapper URL existente con flags ambiguos.
6. Mantener el manifiesto de host con el mismo `allowed_extensions` exacto. Incrementar la versión de la extensión cuando cambie `background.js`.

### Guardas

- No usar `activeTab`: solo autoriza temporalmente la pestaña activa y no resuelve una lista global.
- No usar `tab.id` como identificador persistente: Firefox lo garantiza solo dentro de la sesión actual.
- No listar/activar pestañas privadas salvo que la extensión tenga permiso explícito para ventana privada y el usuario lo solicite. Tratar la ausencia como comportamiento normal.
- No aceptar acciones, campos o tipos adicionales; responder error estructurado.
- No romper `focus-existing`, su normalización de hosts `www` ni las webapps existentes.

### Verificación

- Extender `tests/windows-manager-linux-orgm-background.test.js` con: lista de varias ventanas, `favIconUrl` presente/ausente, título/URL ausentes, selección correcta, `tabId` inexistente y error del API.
- Extender `tests/windows-manager-linux-orgm.bats.sh` para comprobar framing, `list-tabs`, `activate-tab`, error por payload/tipo inválido y preservación de `focus-existing`.
- Confirmar que el paquete sigue instalando host, ambos clientes y manifiesto de native messaging.

## Fase 2 — resolver favicons a iconos locales seguros

### Archivos

- `nixos/packages/windows-manager-linux-orgm/native-host.py`
- `nixos/packages/windows-manager-linux-orgm.nix` si el host necesita una dependencia declarada
- pruebas del host en `tests/windows-manager-linux-orgm.bats.sh`

### Implementación

1. Definir una caché privada, por ejemplo `$XDG_CACHE_HOME/windows-manager-linux-orgm/favicons`, con permisos de usuario y creación atómica.
2. Por cada `favIconUrl`, aceptar únicamente URLs HTTPS bien formadas. Para `http:`, `data:`, `about:`, `resource:`, `moz-extension:`, valores vacíos o no disponibles, no descargar nada y devolver el fallback `firefox`.
3. Usar una clave SHA-256 del URL canónico para el nombre local. Validar tamaño, tipo de imagen y redirecciones antes de publicar un archivo completo en la caché; imponer timeout, tamaño máximo y una política acotada de expiración/evicción.
4. Devolver en cada descriptor un campo de presentación local, por ejemplo `iconPath`, solo si existe un archivo de caché validado. En la primera aparición puede mostrarse el fallback mientras se llena la caché; el menú no debe bloquear esperando la red.
5. Nunca pasar el favicon remoto directamente en el campo `icon` de Rofi. Rofi documenta nombres de icono y filenames, no un descargador HTTP(S) de favicons.

### Guardas

- No añadir `<all_urls>` a la extensión solo para descargar iconos: ampliaría innecesariamente sus permisos.
- No exponer `favIconUrl` ni URL completa como metadata de Rofi; Rofi solo recibe título sanitizado, host y `iconPath` local/fallback.
- No interpolar títulos, hosts o rutas en shell. Sanitizar NUL, separador de campo de Rofi (`\x1f`) y saltos de línea antes de construir filas.
- No sobrescribir archivos cacheados directamente ni seguir redirecciones hacia esquemas no HTTPS.

### Verificación

- Pruebas con favicon HTTPS válido cacheado, URL no permitida, imagen demasiado grande, redirección inválida, caché ya existente y fallo de red.
- Comprobar que cada `iconPath` devuelto es un archivo local bajo el directorio esperado, o que el fallback exacto sea `firefox`.
- Comprobar que la lista sigue respondiendo aunque un favicon falle.

## Fase 3 — helper i3 y menú Rofi

### Archivos

- Crear `dotfiles/config/profiles/i3/.local/bin/i3-firefox-tabs`
- `dotfiles/config/profiles/i3/.local/bin/i3-rofi`
- `dotfiles/config/profiles/i3/.config/i3/config`
- `nixos/common-dotfiles.nix`
- Crear/actualizar `tests/i3-firefox-tabs.bats.sh`
- Actualizar `tests/firefox-open-tab.bats.sh` o crear un contrato específico del binding

### Implementación

1. Crear un helper dedicado, sin reutilizar `firefox-open-tab`. Este solicitará `list-tabs` al nuevo cliente del puente.
2. Construir por cada descriptor una fila Rofi con la sintaxis documentada:
   ```text
   Título saneado — host\0icon\x1f/path/local/favicon.png\n
   ```
   Si no existe `iconPath`, usar `firefox` como icono de tema. Rofi ya se invoca con `-show-icons` en `i3-rofi` y el tema actual declara `element-icon` de 32px.
3. Añadir al wrapper común `i3-rofi` un modo explícito `--tab-picker`. Debe conservar el tema y `-show-icons` existentes, leer filas por stdin y ejecutar Rofi con `-dmenu -format i -no-custom -only-match`; así el helper no duplica la configuración visual ni intenta pasar flags que el wrapper actual no acepta.
4. `i3-firefox-tabs` canalizará las filas al nuevo modo `i3-rofi --tab-picker`. Mantendrá en memoria/archivo privado efímero el array de IDs en el mismo orden de las filas; convertirá el índice elegido al `tabId` antes de llamar `activate-tab`.
5. Mostrar `notify-send` y salir sin efectos si: no hay pestañas, Rofi se cancela, el puente no responde, el índice no es válido o la pestaña ya no existe.
6. Añadir a i3, cerca de los bindings de navegador:
   ```i3
   bindsym $mod+Escape exec --no-startup-id i3-firefox-tabs
   ```
7. Registrar el nuevo helper en la lista i3 explícita de `nixos/common-dotfiles.nix`; no añadirlo a los perfiles Hyprland/Labwc.

### Guardas

- No usar `rofi -show window`: selecciona una ventana, no una pestaña.
- No seleccionar por título, URL o host; usar exclusivamente el índice original y el `tabId` correspondiente.
- No llamar `firefox`, `firefox --new-tab`, `firefox-open-tab` ni `--new-window` desde este helper.
- No permitir que texto web controle los separadores NUL/US de Rofi o argumentos de shell.

### Verificación

- Stub del cliente del puente con pestañas de títulos duplicados, caracteres de control y favicon/fallback; capturar stdin de Rofi y verificar sintaxis, icono y sanitización.
- Stub de Rofi que devuelve un índice y comprobar que se envía el `tabId` correcto a `activate-tab`.
- Stub de `i3-rofi --tab-picker` y contrato del wrapper que compruebe que solo ese modo recibe `-format i -no-custom -only-match`, conserva `-show-icons` y no altera `--drun`, `--window`, `--calc` ni el dmenu genérico.
- Casos de cancelación, lista vacía, error de puente e ID eliminado: comprobar que no se invoca Firefox ni se crea ninguna pestaña.
- Contrato que compruebe `bindsym $mod+Escape` y que `i3-firefox-tabs` está desplegado por `common-dotfiles.nix`.

## Fase 4 — empaquetado, firma y validación final

### Archivos

- `nixos/packages/windows-manager-linux-orgm/manifest.json`
- `nixos/packages/windows-manager-linux-orgm/windows-manager-linux-orgm-unsigned-<versión>.xpi`
- `nixos/packages/windows-manager-linux-orgm/windows-manager-linux-orgm-signed.xpi`
- `nixos/firefox.nix`
- pruebas anteriores

### Implementación

1. Generar el XPI unsigned desde `manifest.json` y `background.js` con la nueva versión.
2. Enviar ese XPI a AMO para firma y sustituir `windows-manager-linux-orgm-signed.xpi` solamente cuando su `manifest.json` interno tenga la misma versión y el código de la extensión actual.
3. Mantener la instalación forzada existente en `nixos/firefox.nix`; no instalar un XPI unsigned como sustituto de la firma.
4. Aplicar el perfil solo después de que la evaluación y las pruebas pasen. Para el equipo objetivo: `nh os switch --flake .#lenovo-windows-i3`.

### Estado conocido que esta fase debe corregir

El árbol fuente declara extensión **1.0.4**, pero el XPI firmado actual contiene **1.0.3**. La nueva funcionalidad no será efectiva hasta que la firma corresponda exactamente al nuevo paquete.

### Verificación

- Inspeccionar `manifest.json` dentro de ambos XPI y comprobar versión idéntica.
- Ejecutar las pruebas específicas del puente, extensión y helper i3.
- Evaluar `nixosConfigurations.lenovo-windows-i3.config.system.build.toplevel.drvPath`.
- Tras activar el perfil, abrir varias pestañas con favicons distintos, pulsar `Win+Esc`, comprobar iconos locales/fallback, elegir una pestaña de otra ventana y comprobar que se enfoca la ventana y la pestaña exactas sin crear ninguna nueva.

## Criterios de aceptación

- `Win+Esc` solo aparece en i3 y abre un selector Rofi de pestañas existentes.
- Cada fila muestra título, host y un favicon cacheado localmente o el fallback `firefox`.
- Una elección enfoca la ventana correcta y activa el `tabId` correcto.
- No hay creación de pestaña/ventana en ningún resultado, incluido un fallo del puente.
- URLs, títulos y favicons malformados no producen inyección de Rofi/shell, descargas inseguras ni un menú bloqueado.
- La extensión firmada instalada tiene la misma versión y contenido funcional que el XPI fuente evaluado.
