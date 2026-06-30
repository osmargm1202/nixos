# Wallpaper Menu Unificado

## Objetivo

Crear un único menú de wallpapers para Hyprland, lanzado directamente desde Waybar mediante Quickshell, sin pasar por fuzzel/rofi. El menú permite elegir fondos normales y live desde una sola interfaz con dos pestañas: `NORMAL` y `LIVE`.

## Contexto actual

- `orgm-hypr wallpaper pick` todavía usa `MenuPick()`, que muestra opciones con fuzzel/rofi antes de abrir el carrusel Quickshell.
- Quickshell ya existe en `config/shared/.config/quickshell/wallpaper-picker/shell.qml`, pero trabaja con un solo modo por request (`static` o `video`).
- Waybar Hypr actualmente ejecuta `orgm-hypr wallpaper next` en `config/shared/.config/waybar-hypr/config` para cambiar a un fondo aleatorio.
- `internal/wallpaper/manager.go` ya tiene soporte para:
  - estáticos: `SetStatic`, `SetRandomStatic`, `OpenQuickshellCarousel("static")`
  - live/video: `SetVideo`, `SetRandomVideo`, `OpenQuickshellCarousel("video")`
  - data para Quickshell por modo: `GenerateQuickshellData` y `BuildPickerData`.

## Requisitos

1. Debe existir un solo menú de selección de wallpaper.
2. El botón de Waybar debe lanzar ese menú directamente, sin fuzzel/rofi.
3. El menú debe tener dos pestañas visibles:
   - `NORMAL` para wallpapers estáticos.
   - `LIVE` para wallpapers de video/live.
4. La pestaña inicial debe depender del wallpaper actual:
   - modo actual `video` => abrir en `LIVE`.
   - cualquier modo estático => abrir en `NORMAL`.
5. El botón `Random` debe estar abajo del menú.
6. `Random` debe actuar según la pestaña activa:
   - pestaña `NORMAL` => escoger/aplicar wallpaper normal aleatorio.
   - pestaña `LIVE` => escoger/aplicar wallpaper live aleatorio.
7. Al hacer click en un wallpaper de la grilla debe aplicarse el wallpaper del tipo correcto y cerrar el menú.
8. Los comandos existentes `carousel static` y `carousel video` deben seguir funcionando para no romper atajos o usos manuales.

## Enfoque elegido

Implementar un picker Quickshell dual respaldado por data generada por `orgm-hypr`.

Este enfoque es preferible a mantener dos carruseles internos porque el usuario percibe y usa un solo menú. También evita que Waybar siga funcionando como botón de random-only.

## Arquitectura

### Go: `internal/wallpaper`

Agregar soporte para generar data combinada para Quickshell.

La data nueva debe incluir ambos grupos de wallpapers y el modo inicial. Una forma compatible y simple:

```json
{
  "mode": "static",
  "initialMode": "video",
  "tabs": {
    "static": {
      "title": "Normal wallpapers",
      "applyCommand": "set-static",
      "randomCommand": "random-static",
      "current": "/path/current.png",
      "items": []
    },
    "video": {
      "title": "Live wallpapers",
      "applyCommand": "set-video",
      "randomCommand": "random-video",
      "current": "/path/current.mp4",
      "items": []
    }
  },
  "script": "orgm-hypr",
  "scriptArgs": ["wallpaper"]
}
```

Exact field names may vary during implementation, but the schema must preserve these concepts:

- both modes in one JSON file,
- active/initial mode,
- per-mode apply command,
- per-mode random command,
- per-mode items/current path.

Add explicit CLI commands for random by mode if needed, for example:

- `orgm-hypr wallpaper random static`
- `orgm-hypr wallpaper random video`

These should call existing `SetRandomStatic()` and `SetRandomVideo()`.

### Go: `MenuPick()` / picker launch

Change `MenuPick()` so `orgm-hypr wallpaper pick` opens the Quickshell picker directly. It should not invoke fuzzel/rofi.

The picker launch flow should:

1. Ensure wallpaper dirs/state dirs exist.
2. Generate a manifest containing static and video wallpapers.
3. Generate combined picker JSON.
4. Write the Quickshell request file.
5. Start or show the resident Quickshell picker.

`OpenQuickshellCarousel("static")` and `OpenQuickshellCarousel("video")` should remain available for existing commands.

### Quickshell UI

Update `config/shared/.config/quickshell/wallpaper-picker/shell.qml`.

UI structure:

- Header row:
  - title: `Wallpapers`
  - tabs: `NORMAL` and `LIVE`
  - pager/helper text
- Grid:
  - shows items for the active tab only.
  - preserves existing keyboard navigation where practical.
- Footer:
  - Previous / Next buttons for pagination.
  - `Random` button aligned at the bottom.

Behavior:

- Active tab is initialized from `initialMode` or, if absent, current mode.
- Clicking a tab switches the active item list and resets page/selection sensibly.
- Clicking a wallpaper runs the tab's apply command (`set-static` or `set-video`) and closes the panel.
- Clicking `Random` runs the tab's random command and closes the panel.
- Existing keyboard controls remain:
  - arrows select
  - PageUp/PageDown change page
  - Enter applies selected
  - Esc closes

### Waybar

Update `config/shared/.config/waybar-hypr/config`:

- `custom/wallpaper.tooltip-format`: from random-only wording to `Elegir wallpaper`.
- `custom/wallpaper.on-click`: `orgm-hypr wallpaper pick`.

The Sway Waybar config is out of scope unless explicitly requested.

## Error handling

- If there are no wallpapers in a tab, show an empty-state message instead of a blank grid.
- If LIVE has no videos, `Random` should surface the existing `No video wallpapers found` behavior via command failure/log; the menu can close after starting the command.
- If Quickshell is unavailable, keep the existing `quickshell not found` error path.
- Do not reintroduce fuzzel/rofi into `wallpaper pick`.

## Testing

Go tests:

- Add/adjust tests for combined picker data generation.
- Add CLI tests for new random subcommands if added.
- Add/adjust tests to verify `wallpaper pick` does not require fuzzel/rofi and plans/launches Quickshell directly if the existing test structure allows it.
- Keep existing tests for static/video picker data and existing menu commands passing.

Manual verification:

1. Run Go tests: `go test ./...`.
2. Sync dotfiles for host `orgm`: `orgm-dot diff --host orgm`, then `orgm-dot sync --host orgm` if diff is correct.
3. Restart/reload relevant desktop pieces:
   - Waybar or `orgm-hypr waybar watch` flow if used.
   - Quickshell picker if already running.
4. Click the Waybar wallpaper icon.
5. Confirm menu opens directly with no fuzzel.
6. Confirm initial tab matches current wallpaper mode.
7. Confirm NORMAL item click applies static wallpaper.
8. Confirm LIVE item click applies live wallpaper.
9. Confirm `Random` applies a normal wallpaper in NORMAL and a live wallpaper in LIVE.

## Out of scope

- Redesigning the whole Quickshell theme.
- Changing Sway wallpaper behavior.
- Replacing the underlying static/live wallpaper engines.
- Removing existing `carousel static/video` commands.
