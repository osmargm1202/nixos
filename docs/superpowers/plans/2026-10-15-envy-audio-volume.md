# Envy: audio y micrófono150% por defecto

## Aplicado
Petición del usuario: volumen150% para salida y micrófono. Aplicado únicamente
a Envy. Ambas rutas predeterminadas muestran `Volume:1.50` después de recargar
WirePlumber y conservan ganancias nativas3.375 en el estado persistente.

`nixos/hosts/envy/audio.nix` declara los valores iniciales mediante propiedades
nativas por dispositivo para la tarjeta integrada PCI00:1f.3. No fuerza150%
en cada inicio: ajustes manuales posteriores y mute/balance guardados prevalecen.
USB/Bluetooth y otras rutas con preferencias existentes no se sobrescriben.
No se reinició equipo ni sesión gráfica; SDDM conservó proceso y fecha de inicio.

## Descubrimiento técnico
El150% de wpctl/PulseAudio corresponde a ganancia lineal `1.5³ =3.375`, no1.5.
La configuración global de defaults tiene máximo1.0 en WirePlumber0.5.14 fijado;
las propiedades oficiales por dispositivo son el mecanismo adecuado. Consultado
[WirePlumber: defaults de rutas](https://pipewire.pages.freedesktop.org/wireplumber/daemon/configuration/settings.html)
y comprobado el consumidor real `device/apply-routes.lua` del paquete fijado.

## Verificación
- RED por política ausente; GREEN al evaluar módulo real y ejecutar consumidor
  fijado: defaults de entrada/salida correctos y preferencias guardadas intactas.
- Coincidencia limitada a tarjeta integrada; USB/BT y otros cuatro hosts aislados.
- Suites envy-normal, lenovo-audio-policy, orgm-audio-policy y build completo Envy
  aprobados. No se afirma toda la batería histórica en verde.
- `nix flake check --no-build`: configura los cinco sistemas, pero falla después
  al evaluar `packages.x86_64-linux.orgm-todo` por licencia unfree. Reproducido
  también en el checkout original, sin esta modificación; no se cambió licencia.
- Switch terminó con código4 por Home Manager→SOPS sin identidad privada, aviso
  previo aceptado. El nuevo sistema, política y niveles de audio sí se verificaron
  activos. WirePlumber, PipeWire y Pulse activos. No se copiaron claves.
- Respaldo previo privado de rutas y volúmenes en
  `~/.local/state/envy/audio-volume150-20261015`.

## Límites
150% amplifica y puede producir saturación, ruido o distorsión, especialmente
el micrófono. No se afirma mejora de calidad ni prueba acústica. Los niveles se
pueden reducir normalmente en Ryoku/Pavucontrol. Sin cambios de mute, dispositivo
predeterminado, perfil de tarjeta, autenticación, discos ni pantallas.


## Corrección posterior: controles limitados a100%

El usuario detectó que el control seguía llegando solo a100%. La verificación
inicial de wpctl era insuficiente: `shell.json.qsbar.audioBoost` estaba enfalse,
y el helper real `ryoku-volume` limita entonces las teclas a100%, aunque
PipeWire acepte150%. El micrófono seguía en150%, pero la salida había vuelto a100%.

Se habilitó mediante la interfaz nativa `ryoku-shell bar set volume audioBoost on`.
La prueba real de `ryoku-volume up` desde145% terminó en150%, sin volver a100%.
La barra actual esqsbar, cuyo deslizador usa el mismo indicador para rango0..150.
El usuario confirmó después explícitamente que el control ya llega al150%.

La declaración inicial está en el dotfile específico de Envy
`orgm-ryoku/audio-defaults.json`. La preparación realiza una migración única bajo
el bloqueo nativo `shell.json.lock`, con copia previa y archivos atómicos0600.
Solo cambia `qsbar.audioBoost`; conserva layout/dock/claves desconocidas y las
preferencias posteriores del usuario, incluso desactivar el boost. No hay fork
de QML ni sobrescritura completa del archivo; otros hosts no reciben ese default.

Regresión:14casos Python de migración, incluyendo bloqueo/JSONmalformado/
preservación y cambio posterior; prueba del helper fijado con flagfalse limita100%
y con el default declarado true permite150%. Se conserva el uso normal de
controles para reducir el nivel; no se fija150% continuamente.

## Cierre Git solicitado

El usuario solicita commit y push de todos los cambios pendientes del repositorio,
incluidos Perplexity, la corrección previa GSettings y el borrador Windows.
Se publicará la rama aislada `feat/envy-normal`, sin merge automático a master,
ni forcepush. Los artefactos privados de `.superpowers/`, contraseñas, cachés y
sesiones quedan fuera. El resultado exacto del push se comunica al finalizar.
Los bloqueos/fallos previos de la batería general siguen declarados; no se afirma
una suite global verde ni se mezclan reparaciones ajenas para ocultarlos.
