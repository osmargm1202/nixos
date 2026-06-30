# Waybar Follow-Up Tweaks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix right-edge gap, increase blur, regroup custom buttons, change power symbol to I/O red.

**Architecture:** Split into two tasks: Task 1 covers compositor blur + CSS layout/background + config reorder for Sway and Hyprland. Task 2 covers regrouping, gaps, power symbol/color, and targeted dotfiles sync.

**Tech Stack:** Waybar JSON, GTK CSS, Hyprland Lua, Sway config, Python structural checks, orgm-dot diff/sync.

## Global Constraints

- Keep light/dark mode support through existing `@import "orgm-current.css"`.
- Do not change `config/shared/.local/bin/waybar-theme-toggle`.
- Do not change module functions (exec, on-click, tooltip, etc.) — only format/position/grouping.
- Gaps between groups use CSS padding/margin only, no visual separators.
- `custom/logout_menu` format changes from `󰐥` to `⏻`; CSS adds `color: @red; font-weight: bold;`.
- Blur changes affect both Hyprland (`look-and-feel.lua`) and Sway (`config`).
- Because this is configuration work, use structural red/green checks instead of adding tests.

---

## File Structure

- `config/shared/.config/waybar/config` — Sway top-right power format, reorder modules-right
- `config/shared/.config/waybar/style.css` — Sway right-edge fix, power color, gaps
- `config/shared/.config/waybar-hypr/config` — Hyprland power format, reorder modules-right
- `config/shared/.config/waybar-hypr/style.css` — Hyprland right-edge fix, power color, gaps, translucent bg
- `config/shared/.config/hypr/lua/look-and-feel.lua` — blur size 5→8, passes 3→4, ignore_alpha 0.10→0.0
- `config/shared/.config/sway/config` — blur_radius 5→8, blur_passes 3→4

### Task 1: Blur + Layout Fix + Config Reorder

**Files:**
- Modify: `config/shared/.config/hypr/lua/look-and-feel.lua` (blur size 5→8, passes 3→4, ignore_alpha 0.10→0.0)
- Modify: `config/shared/.config/sway/config` (blur_radius 5→8, blur_passes 3→4)
- Modify: `config/shared/.config/waybar/style.css` (right-edge padding, bg more translucent)
- Modify: `config/shared/.config/waybar-hypr/style.css` (right-edge padding, bg more translucent)
- Modify: `config/shared/.config/waybar/config` (reorder modules-right, power format)
- Modify: `config/shared/.config/waybar-hypr/config` (reorder modules-right, power format)

**Interfaces:**
- Consumes: Current blur values, padding-right values, module lists from both configs.
- Produces: Blur tuned up, right-edge gap fixed, modules-right reordered.

- [ ] **Step 1: Write failing structural checks**

```bash
python - <<'PY'
from pathlib import Path
# Blur
hl = Path('config/shared/.config/hypr/lua/look-and-feel.lua').read_text()
assert 'size = 5' in hl or 'passes = 3' in hl or 'ignore_alpha = 0.10' in hl, 'blur already upgraded?'
sway = Path('config/shared/.config/sway/config').read_text()
assert 'blur_radius 5' in sway and 'blur_passes 3' in sway, 'sway blur already upgraded?'
# Right-edge padding
wcss = Path('config/shared/.config/waybar/style.css').read_text()
hcss = Path('config/shared/.config/waybar-hypr/style.css').read_text()
assert 'padding-right: 24px' in wcss, 'right padding already removed'
assert 'padding-right: 24px' in hcss, 'right padding already removed'
# Power format
wcfg = Path('config/shared/.config/waybar/config').read_text()
hcfg = Path('config/shared/.config/waybar-hypr/config').read_text()
assert '󰐥' in wcfg, 'power format already changed'
assert '󰐥' in hcfg, 'power format already changed'
print('red checks fail as expected')
PY
```

- [ ] **Step 2: Run checks to verify they fail**

Expected: `AssertionError` or print message about current values.

- [ ] **Step 3: Implement changes**

**Blur — Hyprland** (`config/shared/.config/hypr/lua/look-and-feel.lua`):
Change:
```lua
    blur = {
      enabled = true,
      size = 5,
      passes = 3,
      vibrancy = 0.17,
    },
```
To:
```lua
    blur = {
      enabled = true,
      size = 8,
      passes = 4,
      vibrancy = 0.17,
    },
```
And change:
```lua
hl.layer_rule({
  name = "blur-waybar",
  match = { namespace = "waybar" },
  blur = true,
  ignore_alpha = 0.10,
})
```
To:
```lua
hl.layer_rule({
  name = "blur-waybar",
  match = { namespace = "waybar" },
  blur = true,
  ignore_alpha = 0.0,
})
```

**Blur — Sway** (`config/shared/.config/sway/config`):
Change `blur_radius 5` to `blur_radius 8` and `blur_passes 3` to `blur_passes 4`.

**Background more translucent** (both CSS files):
Change `background: rgba(0, 0, 0, 0.6);` to `background: rgba(0, 0, 0, 0.45);` for both `window.top_bar#waybar` and `window.bottom_bar#waybar`.

**Right-edge padding** (both CSS files):
Change `padding-right: 24px;` to `padding-right: 0;` for `window.top_bar .modules-right`.

**Power format change** (both config JSONs):
In `custom/logout_menu`, change `"format": "󰐥"` to `"format": "⏻"`.

- [ ] **Step 4: Run validation**

```bash
python - <<'PY'
from pathlib import Path
# Blur upgraded
hl = Path('config/shared/.config/hypr/lua/look-and-feel.lua').read_text()
assert 'size = 8' in hl and 'passes = 4' in hl and 'ignore_alpha = 0.0' in hl, 'hypr blur not upgraded'
sway = Path('config/shared/.config/sway/config').read_text()
assert 'blur_radius 8' in sway and 'blur_passes 4' in sway, 'sway blur not upgraded'
# Right-edge padding removed
for p in ['config/shared/.config/waybar/style.css', 'config/shared/.config/waybar-hypr/style.css']:
    text = Path(p).read_text()
    assert 'padding-right: 0' in text, f'{p} right padding not fixed'
# Power format changed
for p in ['config/shared/.config/waybar/config', 'config/shared/.config/waybar-hypr/config']:
    text = Path(p).read_text()
    assert '⏻' in text, f'{p} power format not changed'
    assert '󰐥' not in text, f'{p} old power format still present'
# Background more translucent
for p in ['config/shared/.config/waybar/style.css', 'config/shared/.config/waybar-hypr/style.css']:
    text = Path(p).read_text()
    assert 'background: rgba(0, 0, 0, 0.45)' in text, f'{p} bg not translucent'
print('task1 checks ok')
PY
```

Expected: `task1 checks ok`

- [ ] **Step 5: Commit**

```bash
git add config/shared/.config/hypr/lua/look-and-feel.lua config/shared/.config/sway/config config/shared/.config/waybar/style.css config/shared/.config/waybar-hypr/style.css config/shared/.config/waybar/config config/shared/.config/waybar-hypr/config
git commit -m "fix(waybar): stronger blur, fix right-edge, change power to I/O"
```

### Task 2: Regroup custom buttons with gaps and apply

**Files:**
- Modify: `config/shared/.config/waybar/config` — reorder modules
- Modify: `config/shared/.config/waybar-hypr/config` — reorder modules, move custom buttons to bottom
- Modify: `config/shared/.config/waybar/style.css` — power color, group gaps
- Modify: `config/shared/.config/waybar-hypr/style.css` — power color, group gaps

**Interfaces:**
- Consumes: Task 1 produces correct blur/edge/power-format. 
- Produces: Custom buttons grouped with gaps, power button red, CSS spacing.

- [ ] **Step 1: Write failing structural checks**

```bash
python - <<'PY'
from pathlib import Path
# Power not red yet
wcss = Path('config/shared/.config/waybar/style.css').read_text()
hcss = Path('config/shared/.config/waybar-hypr/style.css').read_text()
assert 'color: @red' not in wcss or 'color: @red' not in hcss, 'power already red'
# No group gap CSS yet
assert 'group-gap' not in wcss and 'group-gap' not in hcss, 'gap already present'
# Top bar still has old custom buttons
wcfg = Path('config/shared/.config/waybar/config').read_text()
hcfg = Path('config/shared/.config/waybar-hypr/config').read_text()
assert 'custom/wallpaper' in wcfg, 'wallpaper still on top'
assert 'custom/wallpaper' in hcfg, 'wallpaper still on top'
print('red checks fail as expected')
PY
```

- [ ] **Step 2: Run checks to verify they fail**

- [ ] **Step 3: Implement regrouping**

**Config reorder — top bar `modules-right`:**

Sway (`config/shared/.config/waybar/config`):
```json
"modules-right": ["custom/power", "custom/theme_toggle", "custom/clipboard", ...]
```
Wait, need to think about this more carefully. The current top-right for Hypr is:
`modules-right`: `privacy`, `tray`, `custom/clipboard`, `custom/theme_toggle`, `custom/wallpaper`, `custom/usb_devices`, `custom/memclean`, `custom/nixclean`, `custom/hardware_fetch`, `custom/pi_status`, `custom/headset_reconnect`, `custom/hypr_config_editor`, `custom/logout_menu`

New top-right: `privacy`, `tray`, `custom/clipboard`, `custom/theme_toggle`, `custom/logout_menu`
New bottom-right: `custom/wallpaper`, `custom/usb_devices`, `custom/headset_reconnect`, `custom/memclean`, `custom/nixclean`, `custom/hardware_fetch`, `custom/pi_status`, `custom/hypr_config_editor` + existing bottom-right modules

Wait, the existing bottom-right already has: `custom/conky_toggle`, `custom/kbd_layout`, `custom/keybindings_help`, `custom/power_profile`

So new bottom-right: `custom/wallpaper`, `custom/usb_devices`, `custom/headset_reconnect`, `custom/memclean`, `custom/nixclean`, `custom/hardware_fetch`, `custom/pi_status`, `custom/hypr_config_editor`, `custom/conky_toggle`, `custom/kbd_layout`, `custom/keybindings_help`, `custom/power_profile`

**Config reorder — Hyprland top bar `modules-right`:**
Remove `custom/wallpaper`, `custom/usb_devices`, `custom/memclean`, `custom/nixclean`, `custom/hardware_fetch`, `custom/pi_status`, `custom/headset_reconnect`, `custom/hypr_config_editor` from top.
Keep only: `privacy`, `tray`, `custom/clipboard`, `custom/theme_toggle`, `custom/logout_menu`

Add removed modules to bottom `modules-right`: after existing bottom modules, insert the custom buttons.

**CSS — power red:**
In both CSS files, add or ensure:
```css
#custom-logout_menu {
  color: @red;
  font-weight: bold;
}
```

**CSS — group gaps:**
In both CSS files, add gap rules for bottom-right groups:
```css
/* First in wallpapers group */
#custom-wallet,
#custom-usb_devices,
#custom-headset_reconnect {
  margin-right: 12px;
}
/* First in cleanups group */
#custom-memclean {
  margin-left: 12px;
  margin-right: 12px;
}
/* First in system group */
#custom-hardware_fetch {
  margin-left: 12px;
  margin-right: 12px;
}
/* First in utilities group */
#custom-conky_toggle {
  margin-left: 12px;
}
```

Wait, this is a bit ad-hoc. Let me use a cleaner approach: give the first element in each group a `margin-left` to create the gap. I need to check what the actual module names will be in the bottom-right list order.

Bottom-right order by group:
1. `custom/wallpaper`, `custom/usb_devices`, `custom/headset_reconnect`
2. `custom/memclean`, `custom/nixclean`
3. `custom/hardware_fetch`, `custom/pi_status`, `custom/hypr_config_editor`
4. `custom/conky_toggle`, `custom/kbd_layout`, `custom/keybindings_help`, `custom/power_profile`

First elements of each group (2nd group onwards): `custom/memclean`, `custom/hardware_fetch`, `custom/conky_toggle`

CSS:
```css
#custom-memclean, #custom-hardware_fetch, #custom-conky_toggle {
  margin-left: 16px;
}
```

This adds 16px before the first element of each new group, creating visual separation.

- [ ] **Step 4: Run validation**

```bash
python - <<'PY'
from pathlib import Path
import json
# Power red
for p in ['config/shared/.config/waybar/style.css', 'config/shared/.config/waybar-hypr/style.css']:
    text = Path(p).read_text()
    assert '#custom-logout_menu' in text and 'color: @red' in text, f'{p} power not red'
# Group gap CSS present
for p in ['config/shared/.config/waybar/style.css', 'config/shared/.config/waybar-hypr/style.css']:
    text = Path(p).read_text()
    assert '#custom-memclean' in text and 'margin-left: 16px' in text, f'{p} group gap missing'
# Top bar: wallpaper removed, power format same
hypr = json.loads(Path('config/shared/.config/waybar-hypr/config').read_text())
top = [b for b in hypr if b['name']=='top_bar'][0]
assert 'custom/wallpaper' not in top['modules-right'], 'wallpaper still on top'
assert 'custom/logout_menu' in top['modules-right'], 'power not on top'
bottom = [b for b in hypr if b['name']=='bottom_bar'][0]
assert 'custom/wallpaper' in bottom['modules-right'], 'wallpaper not on bottom'
assert 'custom/logout_menu' not in bottom['modules-right'], 'power still on bottom'
print('task2 checks ok')
PY
# Apply dotfiles
bash -n config/shared/.local/bin/hypr-nwg-dock
./config/shared/.local/bin/hypr-orgm-dot sync .config/waybar-hypr/config --dry-run
./config/shared/.local/bin/hypr-orgm-dot sync .config/waybar-hypr/style.css --dry-run
./config/shared/.local/bin/hypr-orgm-dot sync .config/waybar/config --dry-run
./config/shared/.local/bin/hypr-orgm-dot sync .config/waybar/style.css --dry-run
```

Expected: `task2 checks ok`, shell syntax passes, dry-runs clean.

- [ ] **Step 5: Commit**

```bash
git add config/shared/.config/waybar-hypr/config config/shared/.config/waybar-hypr/style.css config/shared/.config/waybar/config config/shared/.config/waybar/style.css
git commit -m "feat(waybar): regroup custom buttons with gaps, power red I/O"
```

- [ ] **Step 6: Apply to host**

```bash
./config/shared/.local/bin/hypr-orgm-dot sync .config/waybar-hypr/config
./config/shared/.local/bin/hypr-orgm-dot sync .config/waybar-hypr/style.css
./config/shared/.local/bin/hypr-orgm-dot sync .config/waybar/config
./config/shared/.local/bin/hypr-orgm-dot sync .config/waybar/style.css
./config/shared/.local/bin/hypr-orgm-dot sync .config/hypr/lua/look-and-feel.lua
./config/shared/.local/bin/hypr-orgm-dot sync .config/sway/config
```

## Self-Review Checklist

- Task 1 covers: blur upgrade (Hyprland + Sway), right-edge padding fix, background translucency, power format change
- Task 2 covers: custom button regrouping (movement between bars), group gap CSS, power color red, host apply
- No task touches `waybar-theme-toggle`
- All planning files correct

## Execution Handoff

Plan complete at `docs/superpowers/plans/2026-06-19-waybar-follow-up-tweaks.md`.

Use **Subagent-Driven** for execution.
