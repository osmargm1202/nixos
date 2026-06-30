# Waybar Edge-to-Edge Bars Design

**Date:** 2026-06-19
**Project:** dotfiles
**Status:** Approved design

## Goal

Modificar Waybar en variantes `waybar` y `waybar-hypr` para que barra superior y barra inferior queden pegadas a los bordes de la pantalla, con ancho completo real, sin bordes visibles, con fondo negro semitransparente y blur, manteniendo compatibilidad con light mode y dark mode.

## User Requirements

- Barra superior pegada a `top`, `left` y `right`.
- Barra inferior pegada a `bottom`, `left` y `right`.
- Sin márgenes contra bordes de pantalla.
- Fondo negro semitransparente.
- Sin bordes visibles.
- Blur activo sobre ambas barras.
- Reducir tamaño de letra del tiempo a ~70% del valor actual.
- Reducir altura de ambas barras a ~70% del valor actual.
- Mantener soporte para light mode y dark mode.
- `nwgdot` puede reservar espacio lateral derecho, pero no debe desplazar ni recortar el ancho real de las barras de Waybar.
- Waybar debe seguir reservando espacio arriba y abajo para ventanas.

## Current State

### Hyprland (`config/shared/.config/waybar-hypr`)

- `top_bar` usa `margin-top: 10`, `margin-left: 12`, `margin-right: 12`, `height: 47`.
- `bottom_bar` usa `margin-bottom: 10`, `margin-left: 12`, `margin-right: 12`, `height: 60`.
- CSS aplica bordes, radios y paddings internos pensados para barras flotantes.
- `custom/time` usa `font-size: 34px`.

### Sway (`config/shared/.config/waybar`)

- `top_bar` usa `margin-top: 10`, `margin-left: 12`, `margin-right: 12`, `height: 47`.
- `bottom_bar` usa `margin-bottom: 10`, `margin-left: 12`, `margin-right: 12`, `height: 52`.
- CSS aplica radios y paddings internos pensados para barras flotantes.
- `custom/time` usa `font-size: 34px`.

## Chosen Approach

Usar barras edge-to-edge reales en Waybar y separar el problema del dock lateral (`nwgdot`) de la geometría horizontal de las barras.

### Why this approach

1. Cumple el requisito visual de barras completas de lado a lado.
2. Mantiene la reserva vertical normal de Waybar para que las ventanas no queden debajo de las barras.
3. Evita que el dock lateral derecho achique o desplace el ancho de `top_bar` y `bottom_bar`.
4. Permite que light/dark sigan funcionando sin duplicar lógica de tema.

## Layout Design

### Top bar

- `position: top`
- `margin-top: 0`
- `margin-left: 0`
- `margin-right: 0`
- altura objetivo: `33px` aprox. (derivada de `47 * 0.7`)

### Bottom bar

- `position: bottom`
- `margin-bottom: 0`
- `margin-left: 0`
- `margin-right: 0`
- altura objetivo Hyprland: `42px` aprox. (derivada de `60 * 0.7`)
- altura objetivo Sway: `36px` aprox. (derivada de `52 * 0.7`)

### Clock module

- `#custom-time` debe bajar de `34px` a `24px` aprox. (`34 * 0.7`)
- paddings y márgenes internos del reloj deben reducirse para no desbordar la nueva altura de barra

## Visual Design

### Bar container styling

Aplicar a `window.top_bar#waybar` y `window.bottom_bar#waybar`:

- `background: rgba(0, 0, 0, 0.6)` o equivalente visual muy cercano
- `border: none`
- `border-radius: 0`
- `box-shadow: none`
- propiedades de blur/translucency en la ventana de Waybar

### Internal spacing

Reducir paddings y márgenes internos de contenedores y módulos para acompañar la menor altura:

- `.modules-left`
- `.modules-center`
- `.modules-right`
- `#group-workspaces` / `#workspaces`
- `#group-system` / `#system`
- módulos con `margin-top` y `margin-bottom` fijos de `7px` o similares

El objetivo no es rediseñar los módulos, sino compactarlos para que sigan centrados verticalmente dentro de barras más bajas.

## Theme Strategy

No tocar la lógica de toggle de tema.

### Keep unchanged

- `config/shared/.local/bin/waybar-theme-toggle`
- `@import "orgm-current.css"`
- archivos de paleta light/dark ya resueltos por `orgm-current.css`

### Change location

Los cambios visuales deben vivir en:

- `config/shared/.config/waybar/style.css`
- `config/shared/.config/waybar-hypr/style.css`

Los cambios geométricos deben vivir en:

- `config/shared/.config/waybar/config`
- `config/shared/.config/waybar-hypr/config`

Así, el mismo layout base aplica en light y dark mode sin duplicar reglas por tema.

## Dock / nwgdot Strategy

### Requirement

`nwgdot` puede reservar espacio lateral derecho para ventanas, pero no debe cambiar el ancho real de las barras de Waybar.

### Design

- Waybar seguirá reservando espacio arriba y abajo como ahora.
- El área derecha para dock debe resolverse aparte del ancho de las barras.
- La implementación puede usar un spacer/surface invisible o mecanismo equivalente de reserva lateral, siempre que:
  - no meta margen visible en las barras
  - no recorte `top_bar`
  - no recorte `bottom_bar`
  - mantenga libre el área derecha para el dock

### Acceptance rule

Si `nwgdot` está presente, las barras siguen viéndose de borde a borde; el espacio del dock se resuelve sin achicar su geometría horizontal.

## Files to Modify

### Hyprland

- `config/shared/.config/waybar-hypr/config`
- `config/shared/.config/waybar-hypr/style.css`

### Sway

- `config/shared/.config/waybar/config`
- `config/shared/.config/waybar/style.css`

## Non-Goals

- No rediseñar iconografía.
- No cambiar módulos activos/inactivos salvo que haga falta para compactar spacing.
- No cambiar lógica de `waybar-theme-toggle`.
- No cambiar colores de light/dark salvo el fondo negro semitransparente compartido para las barras.
- No modificar comportamiento funcional de módulos salvo geometría/estilo.

## Verification

### Config verification

- `distrobox-host-exec orgm-dot diff`
- revisar que solo cambien archivos Waybar esperados

### Apply

- `distrobox-host-exec orgm-dot sync`

### Visual verification

Confirmar en pantalla:

1. barra superior pega a top, left y right
2. barra inferior pega a bottom, left y right
3. no hay márgenes visibles contra bordes
4. no hay borde ni radio visible
5. fondo se percibe negro semitransparente
6. blur está activo
7. reloj se ve más pequeño (~70%)
8. altura de ambas barras bajó (~70%)
9. light mode y dark mode conservan layout idéntico
10. si `nwgdot` está presente, no deforma ancho de barras

## Risks

- Blur depende de soporte del compositor y de propiedades admitidas por Waybar/CSS GTK layer-shell.
- La reserva lateral para dock puede requerir ajuste adicional según cómo `nwgdot` publique exclusivity/anchors.
- Reducir altura puede exigir retocar padding en módulos concretos para evitar recorte vertical.

## Success Criteria

El cambio se considera exitoso cuando top y bottom bars ocupan ancho completo de pantalla sin márgenes, muestran fondo negro semitransparente sin borde, el reloj y altura se reducen a ~70% visual, el layout funciona igual en light/dark y la presencia de `nwgdot` no achica las barras.