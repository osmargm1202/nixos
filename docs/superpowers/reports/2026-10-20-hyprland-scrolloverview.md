# Restaurar ScrollOverview en Hyprland — 2026-10-20

## Objetivo y alcance

Restaurar el plugin anterior de yayuuu para una vista de Alt+Tab tipo Niri,
solo en Hyprland. Se mantienen scrolling, Win+R 33/50/66/100%, ventanas
flotantes y aperturas al 100%. Sway conserva su selector Quickshell.
No hay upgrade del compositor, nixpkgs, reboot ni `nixos-rebuild switch`.
Esta tarea no incluye commit/push.

## Diagnóstico y solución

- La receta existía, pero no estaba instalada ni registrada. Los perfiles
  base y personal enviaban Alt+Tab directamente a Quickshell.
- El [repositorio de yayuuu](https://github.com/yayuuu/hyprland-scroll-overview)
  usa API internas de Hyprland; no se puede cargar en Sway.
- Su [tabla oficial de compatibilidad](https://github.com/yayuuu/hyprland-scroll-overview/blob/main/hyprpm.toml)
  fija `cfc23b194ba9378d1606c7aa73060f6ffbe38445` para Hyprland
  `a0136d8c04687bb36eb8a28eb9d1ff92aea99704` (0.55.4), exactamente el instalado.
- Se usa `mkHyprlandPlugin` con el mismo paquete/stdenv del compositor y
  Lua 5.4. El hash del source se verifica; se conserva el guard ABI upstream.
  El binario real upstream `scrolloverview.so` se instala como
  `lib/libscrolloverview.so`, expuesto por NixOS en `/etc/scrolloverview.so`.
- `lua.overview.register()` usa el API nativo `hl.plugin.load` durante cada
  evaluación. El gestor reconcilia plugins y recarga la configuración; no
  depende de un `exec-once` asíncrono ni de `hyprpm` en paralelo.
- `/etc/scrolloverview.so` tiene prioridad; mientras no se active una nueva
  generación se admite el GC-root `$XDG_STATE_HOME/orgm-hyprland-tools/scrolloverview`
  (default `~/.local/state`). No se depende del worktree temporal.
- Alt+Tab y Alt+Shift+Tab alternan la vista vertical, escala 0.5, separación
  24. Flechas/Enter seleccionan; si falta el plugin o falla su acción, se
  ejecuta el selector anterior (`windows` / `windows prev`).

## Verificación específica

- RED Nix: faltaba la entrada `/etc/scrolloverview.so`; GREEN tras integrarla.
  Evaluación comprueba pin, binario, compositor exacto y exclusión de Envy/Sway.
- RED Lua: ambos Alt+Tab evitaban el plugin; GREEN con preferencia por plugin,
  ejecución directa/factory, errores y fallback exacto, archivo ausente,
  prioridad de `/etc` y registro idempotente.
- Paquete compilado correctamente, exporta `pluginInit`, `pluginExit`,
  `pluginAPIVersion` y función de comprobación ABI. Salida:
  `/nix/store/6039fn5ppqksk0wxxawnym8fy6dipi2a-hyprland-scroll-overview-cfc23b194ba9378d1606c7aa73060f6ffbe38445`.
- `hypr-native-dispatch.test.py` y `hypr-sway-bindings.lua`: pasan; Win+R y
  propiedad única del supervisor se conservan.
- **Prueba nativa privada pasa**: mismo Hyprland, carga declarativa real,
  doble registro, dos reloads, un solo plugin, configuración sin errores.
  Teclas reales Alt+Tab → Up → Enter y Shift+Alt+Tab → Up → Enter cambian
  la dirección activa a otra ventana en otro workspace, sin llamar al fallback.
  No se modifica el padre ni su bloqueo. Invocación:

```sh
rtk proxy env ORGM_TEST_PARENT_DISPLAY=/run/user/1000/wayland-1 \
ORGM_TEST_SCROLLOVERVIEW_PLUGIN="$HOME/.local/state/orgm-hyprland-tools/scrolloverview/lib/libscrolloverview.so" \
python3 tests/hypr-scroll-overview-session.test.py
```

No se afirma haber inspeccionado las miniaturas/animaciones visualmente:
el padre está bloqueado con qylock y puede retener callbacks de frame. No se
mata ni evita el bloqueo. La prueba nativa acredita carga y selección real,
no calidad de imágenes; eso queda para la prueba visual del usuario.

## Suite general

**178 scripts: 166 con exit 0, 12 con exit distinto de 0.** Exit 0 puede
incluir SKIP: no se afirma que toda la suite pase. Los tres scripts nuevos
se suman a los 175 anteriores; la integración nativa nueva también se ejecutó
separadamente con sus variables opt-in y pasó, no solo se omitió.

Dos workers, límite 120 s por script, SwayFX/Lua/swayidle y esquemas GSettings
explícitos; sin activar el compositor padre ni PAM en la invocación general.
Logs locales `/tmp/orgm-scrolloverview-suite/`, inventario `results.txt`.
Los doce resultados no satisfactorios coinciden exactamente con el baseline
anterior tras resolver sus ocho carencias de entorno; no hay scripts nuevos
fallando. Véase también el [informe anterior](2026-10-20-hyprland-dock-width.md).

| Script | Fallo previo observado |
| --- | --- |
| `hypr-device-support.bats.sh` | Contrato textual/evaluación de dispositivos. |
| `i3-bar-caffeine.bats.sh` | Fixture espera `resource_blocks` ausente. |
| `i3-cursor-size.bats.sh` | Ruta GTK esperada ausente. |
| `i3-firefox-tabs.bats.sh` | Contrato de despliegue personal. |
| `install-installer.bats.sh` | Inventario del menú de perfiles. |
| `nvim-x11-clipboard.bats.sh` | Contrato global de xclip. |
| `orgm-status.bats.sh` | Fixture indexa una estructura incompatible. |
| `qylock-session.test.py` | Integración opt-in sin `ORGM_TEST_QYLOCK_PACKAGE`/PAM. |
| `runtime-generated-desktop-config.bats.sh` | Activación retirada `initGeneratedConfigs`. |
| `ryoku-profile.bats.sh` | Espera `programs.ryoku` donde no existe. |
| `ryoku-provider-compat.bats.sh` | Espera Ryoku en Envy/Sway. |
| `ryoku-startup.bats.sh` | Espera máscaras autostart retiradas. |

No se reparan estos contratos ajenos a ScrollOverview en esta tarea.
Las pruebas reales de Sway (selector/cambio exacto de ventana, wallpapers,
control e inhibición, flotante VLC) sí pasan con sus dependencias explícitas.

## Revisión y aplicación

Revisión independiente: sin hallazgos críticos/importantes; confirmó además
que los errores del dispatcher se convierten en errores Lua capturados por el
fallback. El revisor no repitió la prueba gráfica ni modificó la sesión.

Se copiaron solo los 18 archivos propios al checkout principal, tras verificar
HEAD `fab9bb9`, bytes de los archivos base y ausencia de colisiones nuevas.
Se ejecutó `orgm-dot --repo /home/osmarg/Hobby/nixos pull hyprland` y
`hyprctl -i 0 reload` (respuesta `ok`). Backup completo de dotfiles:
`20261020T153544.962688848-hyprland-pull`.

En la sesión real: **un plugin scrolloverview cargado**, `configerrors` vacío,
valores efectivos `layout=vertical`, `scale=0.5`, `workspace_gap=24`,
`general.layout=scrolling`, `scrolling.fullscreen_on_one_column=false`.
`orgm-dot diff hyprland` vacío; dock activo; ninguna fuente de Sway modificada.
El paquete standalone permanece enraizado en el directorio de estado, sin
dependencia del worktree temporal. Se repitieron las pruebas específicas y
la integración nativa privada desde el checkout principal: pasan.

No se inyectan teclas en la sesión principal bloqueada. No se hace commit,
push, switch ni reboot. Siguiente paso: prueba visual del usuario al
volver a su sesión; commit/push solo si lo solicita.

## Archivos relevantes

- `nixos/profiles/hyprland/hyprland-scroll-overview.nix`: pin y build ABI.
- `nixos/profiles/hyprland/hyprland.nix`: exposición declarativa del plugin.
- `dotfiles/config/profiles/hyprland/.config/hypr/lua/overview.lua`: registro/dispatch/fallback.
- Módulos `autostart.lua` y `keybindings.lua` base/personales: integración.
- `tests/hypr-scroll-overview*`: contratos Nix/Lua y sesión nativa real.
