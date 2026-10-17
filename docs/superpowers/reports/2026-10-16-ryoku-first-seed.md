# Ryoku first-seed — verificación y entrega

Fecha: 2026-10-16. Alcance: `envy`, `lenovo`, `orgm`, usuario `osmarg`.
**Cambios de código; no se ha desplegado ni activado en los hosts.**

## Resultado funcional

- Preferencias personales sembradas por ausencia de archivo; después pertenecen
  al usuario/Hub. No se reponen imports o reglas retiradas de un archivo existente.
- Migración solo de enlaces declarativos demostrados, con respaldo privado de
  bytes/procedencia. Archivos regulares y enlaces personales, incluso colgantes,
  tienen precedencia. Un directorio enlazado que impida materializar se informa
  sin escribir a través de él.
- Bash nativo de Ryoku empaquetado; funciones personales mediante imports sin
  un segundo prompt/banner. Save del Hub y una Bash nueva leen el mismo Fastfetch.
- Se conservan preferencias al entrar/salir del modo consola/servidor; i3 y los
  modos internos mantienen su configuración independiente.
- Proveedor Hyprland emite `action`, no `state`, para DPMS. Esto elimina el toggle
  accidental demostrado; no acredita todavía la recuperación física completa.

Inventario y comandos: [README Ryoku](../../../nixos/profiles/ryoku/README.md#inicialización-personal-y-edición-posterior).
Seguimiento físico: [Envy PENDING](../../../nixos/hosts/envy/PENDING.md).

## Pruebas de la implementación

21 entrypoints enfocados, sin fallos: cinco scripts Python (49 casos) y 16
scripts shell. No equivale a afirmar que toda la suite histórica del repo pase.

- Python: `ryoku-{dpms,native-resources,native-session,seed,seed-integration}.py`.
- Shell: `ryoku-{shortcuts,profile,runtime-path,startup,provider-compat,transition,folder-icons,rofi}.bats.sh`,
  `envy-normal`, `bash-blesh-emacs`, `omp-package-dir`, `sops-shared-secrets`,
  `dotfile-source`, `dotfile-disable-transition`, `bitwarden-cli` y
  `configuration-inventory` (todos `.bats.sh`).
- Se ejercitan el binario proveedor real, el materializador real, Save real del
  Hub, una nueva Bash y los validadores reales de Niri/Hyprland en fixtures aislados.
- Inventario de los cinco hosts canónicos y aislamiento de todos los modos
  internos evaluados; `git diff --check` sin errores.

Construcciones completas (`nix build --no-link`), sin activar:

| Host | Toplevel |
|---|---|
| envy | `/nix/store/h5ad6japaicfxgrdi0194kzgdsrq4w2v-nixos-system-envy-ryoku` |
| lenovo | `/nix/store/zs1p6gv6yd2yd41wjcnhxwz13jflvjwl-nixos-system-lenovo-ryoku` |
| orgm | `/nix/store/rvvbwwiy1vnlak97sdygrzsq1i0i2kqv-nixos-system-orgm-ryoku` |

Limitaciones históricas observadas aparte: el check global evalúa el paquete
unfree `orgm-todo`; `hypr-waybar-profile` espera una ruta antigua de helper;
`nvim-x11-clipboard` espera xclip en Cinnamon histórico; y
`sunshine-lenovo-autostart` / `user-program-isolation` conservan expectativas
incompatibles con el inventario actual de Jarq. No se modifican esos contratos
ajenos ni se declara una suite global verde.

## Revisión

Revisor independiente de contexto nuevo, rango `3d6bb38..b7e1d3e`: dos hallazgos
importantes confirmados con pruebas RED y corregidos antes de integrar:

1. Ancestros enlazados de los destinos de preparación/materialización: guardas
   completas de los destinos antes de escribir, también en el CLI nativo y
   `ryoku-terminal`; pruebas reales mantienen intactos los destinos externos.
2. Directorios antiguos: registro destino→fuentes permitidas por usuario/host,
   reconocimiento de generaciones anteriores por la misma ruta relativa,
   respaldo privado y procedencia del enlace antes de retirarlo. Fuentes ajenas
   del Store y ancestros enlazados se conservan y bloquean de forma explícita.

La corrección se valida por regresiones RED→GREEN y suite enfocada, sin una
segunda revisión del autor disfrazada de revisión independiente.

Menor diferido: un comentario con `ryoku.bash` puede ocultar el aviso de import
inactivo (no altera el archivo personal). Limitaciones aceptadas: validación
física pendiente, scripts de rollback históricos no reescribibles y aliases
históricos sin migración automática. Véase el README para consecuencias.

## Pendiente después de aplicar manualmente

1. Actualizar `master`, ejecutar `nh os switch . -H envy`, revisar la salida.
2. Guardar un cambio desde Fastfetch Hub y abrir una terminal nueva.
3. Probar lock/unlock y sleep/resume con pantalla interna y luego LG por USB-C.
4. Diagnosticar por separado HDMI sin señal y contenido recortado; siguen abiertos.

No se han leído ni versionado credenciales. La ausencia aceptada de identidad
privada SOPS no se resuelve aquí y puede seguir afectando la activación.

## Decisiones de ejecución

- Conservar el atributo real `ryoku-cli`, aunque el plan dijera `ryoku`:
  evita otra API. Coste si no era lo esperado: renombrar un atributo.
- Prueba histórica `orgm-i3` reemplazada por el canónico `ero` (mismo usuario/i3):
  no reintroducir variantes retiradas. Coste: cobertura específica del host antiguo.
- Dejar sleep/HDMI/recorte a la comprobación física: no tocar la sesión viva.
  Coste: el síntoma completo puede necesitar más diagnóstico.
- No reescribir scripts de generaciones históricas de rollback. Coste: una
  vuelta antigua puede requerir restaurar el snapshot privado manualmente.
- Conservar aliases históricos de las bibliotecas importadas. Coste: alguno que
  use variantes retiradas necesitará una actualización posterior.
