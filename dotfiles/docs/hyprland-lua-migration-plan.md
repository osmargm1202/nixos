# Plan: migrar Hyprland de `hyprland.conf` a `hyprland.lua`

## Contexto

Hyprland 0.55 carga `hyprland.lua` antes que `hyprland.conf`. La config Hyprlang vieja sigue funcionando por 1–2 releases, pero queda deprecada. Migración debe hacerse después de actualizar y verificar `hyprctl version >= 0.55`.

## Objetivo

Mantener el flujo actual modular, pero migrar a Lua sin perder capacidad de probar/revertir.

## Fase 1 — Actualizar sin migrar

1. Usar Hyprland desde upstream git en Nix flake.
2. Rebuild `lenovo-hyprland`.
3. Verificar:
   - `hyprctl version`
   - Waybar inicia.
   - portals/screen sharing funcionan.
   - config actual `hyprland.conf` sigue cargando sin errores.

## Fase 2 — Preparar estructura Lua paralela

Crear:

```text
~/.config/hypr/hyprland.lua
~/.config/hypr/lua/
  monitors.lua
  programs.lua
  autostart.lua
  environment.lua
  permissions.lua
  look-and-feel.lua
  layout.lua
  input.lua
  keybindings.lua
  windows-workspaces.lua
  colors.lua
```

En repo:

```text
config/shared/.config/hypr/hyprland.lua
config/shared/.config/hypr/lua/*.lua
```

No borrar `.conf` todavía. Para probar Lua, crear `hyprland.lua`; para volver atrás, renombrarlo y reiniciar Hyprland.

## Fase 3 — Traducir bloques simples

Orden recomendado:

1. `30-environment.conf` → variables/env.
2. `00-monitors.conf` → outputs.
3. `10-programs.conf` → variables Lua locales.
4. `20-autostart.conf` → exec-once.
5. `60-input.conf` → `hl.config({ input = ... })`.
6. `50-look-and-feel.conf` → `general`, `decoration`, `animations`.
7. `55-layout.conf` → `scrolling`, `dwindle/master` si quedan.
8. `70-keybindings.conf` → binds.
9. `80-windows-workspaces.conf` → window/workspace rules.
10. `40-permissions.conf` y colores.

## Fase 4 — Activar scrolling layout

Cuando Hyprland 0.55 esté activo, cambiar layout global a scrolling:

```lua
hl.config({
  general = {
    layout = "scrolling",
  },
  scrolling = {
    fullscreen_on_one_column = true,
    column_width = 0.5,
    focus_fit_method = 0,
    follow_focus = true,
    follow_min_visible = 0.4,
    explicit_column_widths = "0.333, 0.5, 0.667, 1.0",
    direction = "right",
  },
})
```

Luego migrar binds de navegación a `layoutmsg focus/move/swapcol/promote/colresize`.

## Fase 5 — Validación

Comandos:

```sh
hyprctl version
hyprctl reload
hyprctl configerrors
hyprctl getoption general:layout
```

Pruebas manuales:

- login TTY1 inicia Hyprland.
- Waybar aparece.
- fuzzel abre.
- layout keyboard US/LATAM cambia.
- volumen/brillo OSD funciona.
- Windows RDP launcher funciona.
- screen share portal funciona.

## Reversión

Si Lua falla:

```sh
mv ~/.config/hypr/hyprland.lua ~/.config/hypr/hyprland.lua.disabled
Hyprland
```

Hyprland volverá a cargar `hyprland.conf` al iniciar.
