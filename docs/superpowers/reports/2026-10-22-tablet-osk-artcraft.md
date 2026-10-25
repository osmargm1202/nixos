# Teclado tablet y preferencias ArtCraft — 2026-10-22

## Teclado: corregido y aplicado
La causa era el PanelWindow del botón flotante en el teclado Quickshell, no
Waybar. No tenía condición de visibilidad; el gesto inferior también era
permanente. Ahora ambos siguen el modo tablet manual en Wayland (Hyprland/Sway).

- FileView observa la preferencia manual, con relectura ligera para creación del
  archivo/directorio en el primer uso; no se lanza un helper cada segundo.
- Ausencia, modo off, auto antiguo o JSON inválido ocultan los controles.
- El teclado se puede seguir mostrando mediante atajo, centro de control o IPC
  en modo normal; ocultar el botón no cierra un teclado abierto manualmente.
- X11/i3 conserva sus controles. Quickshell.env puede devolver undefined para
  variables ausentes: se usa coerción booleana, no comparación con cadena vacía.
- Se corrigió otro fallo descubierto en la prueba: `qs ipc call osk show` se
  interpretaba como el subcomando inspector `show`, devolviendo una lista de
  métodos sin abrir nada. `ipc call -- osk show` desambigua los argumentos.
- Pull de on-screen-keyboard aplicado y hot reload comprobado: teclado listo,
  cerrado, modo tablet off y botón/gesto invisibles. No se envió input real.
- Backups del perfil: 20261022T101105.255441901-on-screen-keyboard-pull y
  20261022T102617.924901808-on-screen-keyboard-pull.

## Archivos: preferencia ArtCraft con alternativas nativas
Nuevo módulo compartido y política explícita de100tipos MIME basados en las
asociaciones publicadas por las aplicaciones. Cada formato tiene UNA aplicación
ArtCraft propietaria, seguida de alternativas nativas. Importar un formato no
convierte automáticamente a otro editor de la suite en su propietario.

Ejemplos: CADCraft para DWG/DXF; PdfCraft para PDF; WordCraft para documentos,
TXT/Markdown; GridCraft para hojas/CSV; DeckCraft para presentaciones; PhotoCraft
para imágenes raster; VectorCraft para vectores; LightCraft para RAW;
FilmCraft/SoundCraft para sus formatos de vídeo/audio.
EffectCraft no publica MimeType en su entrada: no se inventaron asociaciones.

- Se usan listas XDG estándar. Si falta la aplicación propietaria, se intenta la
  alternativa instalada sin necesitar un daemon ni escaneo periódico.
- Caso de regresión: si falta PdfCraft, VectorCraft no debe desplazar a Evince
  simplemente porque también importe PDF. Prueba GIO con importador competidor,
  eliminación/reinstalación del propietario y resolución nativa, sin abrir archivos.
- Se preservan HTTP/HTTPS, HTML, directorios y tipos de código configurados.
  TXT/Markdown pasan a WordCraft por la nueva preferencia solicitada.
- Las alternativas específicas conocidas del perfil Cinnamon (Xed/Xreader/
  Xviewer/Celluloid) se mantienen antes de las genéricas.
- xdg.mime transforma listas en cadenas separadas por punto y coma; mkBefore /
  mkAfter no pueden combinarlas. El módulo aplica mkForce solo al conjunto
  explícito de formatos. El sincronizador anterior normaliza estas cadenas para
  no tratar varios desktop IDs como un único nombre de ejecutable.
- La activación nueva corre después de setPreferredFileHandlers y
  mimeAppsDefaults; conserva claves/secciones ajenas, hace backup y sustituye el
  fichero atómicamente. Rechaza symlinks, archivos inválidos y políticas inyectadas.
- Instalar aplicaciones no forma parte de este cambio. Si tampoco existe una
  alternativa válida para un formato (p. ej. DWG sin CAD instalado), no se promete
  un lector inexistente: se recurre al selector normal del escritorio.

### Aplicación real
Se construyó el paquete orgm-artcraft-defaults desde la configuración evaluada,
se ejecutó su política en OrgM y se comprobó idempotencia. GIO confirma:
DWG→CADCraft, PDF→PdfCraft, DOCX→WordCraft, CSV→GridCraft, SVG→VectorCraft,
PNG→Loupe porque PhotoCraft no está instalado. No se abrió ningún documento.

Los cambios declarativos quedan listos para los demás equipos al actualizar su
configuración NixOS; no se hizo switch completo ni despliegue SSH en Envy/Jarq.
Los tres archivos nuevos importados por Nix están añadidos al índice Git para
que `nh os switch .#orgm` no falle por rutas no seguidas. Sin commit/push nuevo.

## CADCraft: reutilizar la ventana todavía NO está implementado
La versión instalada es Flatpak CADCraft0.8.0. Su entrada abre otro proceso con
los archivos recibidos; no hay un mecanismo de instancia única integrado en el
arranque Linux inspeccionado. Existe RPC opcional de control por localhost
(`--control` / CADCRAFT_CONTROL_PORT), pero la instancia actual no lo activó.

No se ha habilitado ese servidor ni enviado órdenes, reiniciado CADCraft o
simulado teclas sobre los planos. El protocolo permite edición amplia y quit
sin confirmación de cambios: no debe confundirse con un canal restringido de
apertura de documentos ni habilitarse silenciosamente para resolver este caso.

El usuario no entendió la elección técnica entre empaquetar otra versión y
mantener el launcher. Se explicó en lenguaje sencillo y se eligió como opción
conservadora mantener el CADCraft del proveedor y sus actualizaciones, no un
fork. La integración compatible y segura de instancia única requiere otro paso.
Mientras tanto, Archivo→Abrir desde la ventana actual evita lanzar otro proceso.

## Verificación
- osk.test.py:7tests OK; manual-tablet:10; control-center:6.
- osk-session.test.py: PASS en Sway headless con Xwayland desactivado, HOME/estado
  privados, política off/on/auto/corrupta/eliminada/atómica y teclado por IPC fuera
  de tablet. Clics reales en botón/teclas hacia Rofi, acentos/AltGr/repetición,
  gesto y reconexión del motor pasan.
- osk-x11-session.test.py: PASS dentro de bwrap con /tmp y red privados, Xvfb+i3
  y render software. Botón/clics/entrada real de los8casos pasan; identidades de
  sockets/locks X11 del escritorio original se verificaron intactas.
- artcraft-defaults.test.py:5tests OK, incluyendo GIO real y un importador
  competidor instalado, preservación/backup/idempotencia/error/dry-run.
- artcraft-defaults-nix.test.py:6hosts públicos OK, usuario correcto de activación,
  código/navegador intactos y exclusión del perfil terminal.
- hypr-nautilus-default.bats.sh:7perfiles históricos OK con la nueva prioridad.
- vlc-flatpak-video-default: PASS (FilmCraft preferido, VLC conservado de fallback;
  OGG no publicado por FilmCraft conserva el predeterminado anterior).
- wayland-session-isolation:15configs PASS; bash -n y git diff --check OK.
- Revisión independiente: sin bloqueantes; revisión adicional de propietario
  único y fallback nativo también sin bloqueantes.
- Se comprobó la evaluación desde `.#orgm` (Git), no solo path:, sin error de
  archivos nuevos no seguidos. No se afirma verde toda la suite histórica ajena.

## Fuentes primarias
- https://specifications.freedesktop.org/mime-apps/latest/default.html
  — orden de aplicaciones, salto de entradas no instaladas.
- Entradas packaging/linux/ai.storyteller.APP.desktop de los repositorios
  https://github.com/storytold — formatos publicados, consultados2026-10-22.
- https://github.com/storytold/cadcraft/blob/v0.8.0/apps/cadcraft/src/main.rs
  — argumentos del arranque y control opcional.
- https://github.com/storytold/cadcraft/blob/v0.8.0/crates/ui-egui/src/control.rs
  — app.open y otras operaciones de control; no activado por esta adaptación.
- https://quickshell.org/docs/v0.3.0/types/Quickshell.Io/FileView/
  — carga, observación y errores de preferencias en QML.
