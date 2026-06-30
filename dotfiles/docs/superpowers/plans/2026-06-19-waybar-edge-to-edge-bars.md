# Waybar Edge-to-Edge Bars Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `waybar` and `waybar-hypr` top/bottom bars span edge-to-edge with zero screen-edge margins, black semi-transparent blurred background, smaller clock/bar height, and a Hyprland right-side spacer so `nwg-dock-hyprland` does not shrink the visible bar width.

**Architecture:** Keep theme switching untouched by changing only shared Waybar geometry and base CSS. Split work into three deliverables: JSON bar geometry, CSS visual compaction, and Hyprland dock-reservation behavior plus dotfiles apply/verify. Use small structural checks before edits so each task has a red/green verification loop even though this is configuration work.

**Tech Stack:** Waybar JSON config, GTK CSS, Hyprland/nwg-dock helper shell, orgm-dot diff/sync, Python 3 JSON validation, grep-based config assertions.

## Global Constraints

- Keep light/dark mode support through existing `@import "orgm-current.css"`; do not change `config/shared/.local/bin/waybar-theme-toggle`.
- Top bars must end with `margin-top: 0`, `margin-left: 0`, `margin-right: 0`, and `height: 33` in both `config/shared/.config/waybar/config` and `config/shared/.config/waybar-hypr/config`.
- Bottom bars must end with `margin-bottom: 0`, `margin-left: 0`, `margin-right: 0`, with `height: 36` in `config/shared/.config/waybar/config` and `height: 42` in `config/shared/.config/waybar-hypr/config`.
- `#custom-time` must end at `font-size: 24px` in both CSS files.
- `window.top_bar#waybar` and `window.bottom_bar#waybar` must end with black semi-transparent background, `border: none`, `border-radius: 0`, and `box-shadow: none`.
- Internal vertical spacing must be compacted so modules stay visually centered in the shorter bars; do not redesign module membership or theme palette logic.
- Hyprland must reserve right-side dock space without shrinking the visible width of `top_bar` and `bottom_bar`.
- Waybar must keep reserving top/bottom space for windows.
- Use dotfiles workflow commands from this repo: `distrobox-host-exec orgm-dot diff` and `distrobox-host-exec orgm-dot sync`.
- Because this is configuration work, TDD exception applies; use structural red/green config checks and focused validation commands instead of adding automated unit tests.

---

## File Structure

- `config/shared/.config/waybar/config` — Sway bar geometry for top/bottom bars.
- `config/shared/.config/waybar/style.css` — Sway bar base visual styling and spacing.
- `config/shared/.config/waybar-hypr/config` — Hyprland bar geometry plus right-side spacer bar reservation.
- `config/shared/.config/waybar-hypr/style.css` — Hyprland bar base visual styling and spacer invisibility.
- `config/shared/.local/bin/hypr-nwg-dock` — Hyprland dock launcher flags so dock itself does not own the exclusion zone that shrinks Waybar.
- `docs/superpowers/specs/2026-06-19-waybar-edge-to-edge-bars-design.md` — approved design; read-only reference.

### Task 1: Make Waybar top/bottom geometry edge-to-edge in Sway and Hyprland

**Files:**
- Modify: `config/shared/.config/waybar/config`
- Modify: `config/shared/.config/waybar-hypr/config`

**Interfaces:**
- Consumes: Existing two-bar Waybar JSON arrays in both config files.
- Produces: Updated `top_bar`/`bottom_bar` geometry with edge-to-edge margins and target heights; Hyprland config also exposes a new `dock_spacer` bar name for Task 3 CSS/styling.

- [ ] **Step 1: Write the failing structural checks**

```bash
python - <<'PY'
import json, pathlib
checks = [
    ("config/shared/.config/waybar/config", "top_bar", {"height": 33, "margin-top": 0, "margin-left": 0, "margin-right": 0}),
    ("config/shared/.config/waybar/config", "bottom_bar", {"height": 36, "margin-bottom": 0, "margin-left": 0, "margin-right": 0}),
    ("config/shared/.config/waybar-hypr/config", "top_bar", {"height": 33, "margin-top": 0, "margin-left": 0, "margin-right": 0}),
    ("config/shared/.config/waybar-hypr/config", "bottom_bar", {"height": 42, "margin-bottom": 0, "margin-left": 0, "margin-right": 0}),
]
failed = []
for path, name, expected in checks:
    bars = {bar["name"]: bar for bar in json.loads(pathlib.Path(path).read_text())}
    bar = bars[name]
    for key, value in expected.items():
        if bar.get(key) != value:
            failed.append(f"{path}:{name}:{key}={bar.get(key)!r} expected {value!r}")
if not failed:
    raise SystemExit("unexpected pass: geometry already matches target")
print("\n".join(failed))
PY
```

- [ ] **Step 2: Run the checks to verify they fail**

Run: same command from Step 1
Expected: FAIL-style output showing current margins `10/12/12` and heights `47/52/60` instead of target values.

- [ ] **Step 3: Implement the minimal geometry changes**

Edit both JSON configs so they end in this shape:

```json
{
  "name": "top_bar",
  "position": "top",
  "height": 33,
  "spacing": 5,
  "margin-top": 0,
  "margin-left": 0,
  "margin-right": 0
}
```

```json
{
  "name": "bottom_bar",
  "position": "bottom",
  "height": 36,
  "spacing": 5,
  "margin-bottom": 0,
  "margin-left": 0,
  "margin-right": 0
}
```

```json
{
  "name": "bottom_bar",
  "position": "bottom",
  "height": 42,
  "spacing": 5,
  "margin-bottom": 0,
  "margin-left": 0,
  "margin-right": 0
}
```

In `config/shared/.config/waybar-hypr/config`, also add a third bar object named `dock_spacer`:

```json
{
  "name": "dock_spacer",
  "layer": "top",
  "position": "right",
  "width": 80,
  "exclusive": true,
  "passthrough": true,
  "modules-center": ["custom/dock_spacer"],
  "custom/dock_spacer": {
    "format": ""
  }
}
```

Keep existing module lists unchanged for `top_bar` and `bottom_bar`.

- [ ] **Step 4: Run validation to verify JSON and geometry pass**

Run:

```bash
python - <<'PY'
import json, pathlib
for path in [
    "config/shared/.config/waybar/config",
    "config/shared/.config/waybar-hypr/config",
]:
    json.loads(pathlib.Path(path).read_text())
print("json ok")
PY
python - <<'PY'
import json, pathlib
checks = [
    ("config/shared/.config/waybar/config", "top_bar", {"height": 33, "margin-top": 0, "margin-left": 0, "margin-right": 0}),
    ("config/shared/.config/waybar/config", "bottom_bar", {"height": 36, "margin-bottom": 0, "margin-left": 0, "margin-right": 0}),
    ("config/shared/.config/waybar-hypr/config", "top_bar", {"height": 33, "margin-top": 0, "margin-left": 0, "margin-right": 0}),
    ("config/shared/.config/waybar-hypr/config", "bottom_bar", {"height": 42, "margin-bottom": 0, "margin-left": 0, "margin-right": 0}),
]
for path, name, expected in checks:
    bars = {bar["name"]: bar for bar in json.loads(pathlib.Path(path).read_text())}
    for key, value in expected.items():
        assert bars[name].get(key) == value, (path, name, key, bars[name].get(key), value)
assert "dock_spacer" in {bar["name"] for bar in json.loads(pathlib.Path("config/shared/.config/waybar-hypr/config").read_text())}
print("geometry ok")
PY
```
Expected: `json ok` and `geometry ok`.

- [ ] **Step 5: Commit**

```bash
git add config/shared/.config/waybar/config config/shared/.config/waybar-hypr/config
git commit -m "feat(waybar): make bar geometry edge-to-edge"
```

### Task 2: Restyle both bars for compact black translucent look

**Files:**
- Modify: `config/shared/.config/waybar/style.css`
- Modify: `config/shared/.config/waybar-hypr/style.css`

**Interfaces:**
- Consumes: Task 1 geometry targets and existing theme import `@import "orgm-current.css"`.
- Produces: Shared bar CSS with `#custom-time` at `24px`, edge-to-edge container styling, tighter paddings/margins, and invisible `dock_spacer` styling in Hyprland CSS.

- [ ] **Step 1: Write the failing structural checks**

```bash
python - <<'PY'
from pathlib import Path
checks = {
    "config/shared/.config/waybar/style.css": [
        "window.top_bar#waybar,",
        "background: rgba(0, 0, 0, 0.6);",
        "border-radius: 0;",
        "box-shadow: none;",
        "font-size: 24px;",
    ],
    "config/shared/.config/waybar-hypr/style.css": [
        "window.top_bar#waybar,",
        "background: rgba(0, 0, 0, 0.6);",
        "border-radius: 0;",
        "box-shadow: none;",
        "font-size: 24px;",
        "window.dock_spacer#waybar",
    ],
}
missing = []
for path, needles in checks.items():
    text = Path(path).read_text()
    for needle in needles:
        if needle not in text:
            missing.append(f"{path} missing {needle}")
if not missing:
    raise SystemExit("unexpected pass: css already matches target")
print("\n".join(missing))
PY
```

- [ ] **Step 2: Run the checks to verify they fail**

Run: same command from Step 1
Expected: missing target background/radius/time-size/spacer rules.

- [ ] **Step 3: Implement the minimal CSS changes**

Update both CSS files to enforce this container shape:

```css
window.top_bar#waybar,
window.bottom_bar#waybar {
  background: rgba(0, 0, 0, 0.6);
  border: none;
  border-radius: 0;
  box-shadow: none;
}
```

Update the clock rule in both files to end with:

```css
#custom-time {
  font-size: 24px;
  padding: 0 10px;
  margin: 0 4px;
}
```

Compact the vertical spacing of the main module containers and high-margin widgets so the shorter bars do not clip content. Reduce `min-height`, `padding`, and `margin-top`/`margin-bottom` values that are still tuned for the old 47/52/60px bars.

In `config/shared/.config/waybar-hypr/style.css`, add an invisible spacer rule:

```css
window.dock_spacer#waybar,
window.dock_spacer#waybar * {
  background: transparent;
  color: transparent;
  border: none;
  box-shadow: none;
}
```

If blur is supported by the existing Waybar/GTK stack, use the lightest working property already accepted by the file without introducing theme-specific duplication. Do not touch `@import "orgm-current.css"`.

- [ ] **Step 4: Run validation to verify CSS targets pass**

Run:

```bash
python - <<'PY'
from pathlib import Path
for path in [
    "config/shared/.config/waybar/style.css",
    "config/shared/.config/waybar-hypr/style.css",
]:
    text = Path(path).read_text()
    assert 'background: rgba(0, 0, 0, 0.6);' in text, path
    assert 'border-radius: 0;' in text, path
    assert 'box-shadow: none;' in text, path
    assert 'font-size: 24px;' in text, path
assert 'window.dock_spacer#waybar' in Path('config/shared/.config/waybar-hypr/style.css').read_text()
print('css ok')
PY
```
Expected: `css ok`.

- [ ] **Step 5: Commit**

```bash
git add config/shared/.config/waybar/style.css config/shared/.config/waybar-hypr/style.css
git commit -m "feat(waybar): restyle compact edge-to-edge bars"
```

### Task 3: Reserve Hyprland dock space separately and apply dotfiles

**Files:**
- Modify: `config/shared/.local/bin/hypr-nwg-dock`
- Modify: `config/shared/.config/waybar-hypr/config`
- Modify: `config/shared/.config/waybar-hypr/style.css`

**Interfaces:**
- Consumes: `dock_spacer` bar from Task 1 and invisible spacer CSS from Task 2.
- Produces: Hyprland dock process that no longer owns the right-side exclusion zone, while `dock_spacer` reserves the space for windows.

- [ ] **Step 1: Write the failing structural checks**

```bash
python - <<'PY'
from pathlib import Path
import json
script = Path('config/shared/.local/bin/hypr-nwg-dock').read_text()
assert '-x' in script, 'unexpected: dock script already changed'
bars = {bar['name']: bar for bar in json.loads(Path('config/shared/.config/waybar-hypr/config').read_text())}
spacer = bars.get('dock_spacer')
assert spacer is not None, 'dock_spacer missing; finish Task 1 first'
assert spacer.get('width') != 80 or spacer.get('exclusive') is not True, 'unexpected pass: spacer already finalized'
print('dock still owns exclusion or spacer still incomplete')
PY
```

- [ ] **Step 2: Run the checks to verify they fail**

Run: same command from Step 1
Expected: confirms the current dock launcher still carries old ownership of exclusion behavior or spacer still needs final shape.

- [ ] **Step 3: Implement the reservation split**

Update `config/shared/.local/bin/hypr-nwg-dock` so the dock launches as overlay-only and does not reserve the right-side exclusive zone itself. Preserve monitor targeting, reload behavior, launcher options, icon size, and margins. The resulting exec block must still look like this structurally, minus the dock-owned exclusion flag:

```bash
exec nwg-dock-hyprland \
  "${dock_output_args[@]}" \
  -r \
  -p right \
  -a center \
  -i "${HYPR_NWG_DOCK_ICON_SIZE:-56}" \
  -g "Claude Code URL Handler" \
  -mr "${HYPR_NWG_DOCK_MARGIN_RIGHT:-8}" \
  -mt "${HYPR_NWG_DOCK_MARGIN_TOP:-0}" \
  -mb "${HYPR_NWG_DOCK_MARGIN_BOTTOM:-0}" \
  -lp "${HYPR_NWG_DOCK_LAUNCHER_POSITION:-start}" \
  -ico "${HYPR_NWG_DOCK_LAUNCHER_ICON:-$HOME/.local/share/icons/nixos.svg}" \
  -c "${HYPR_NWG_DOCK_LAUNCHER_COMMAND:-$HOME/.local/bin/hypr-app-launcher}"
```

Finalize `dock_spacer` in `config/shared/.config/waybar-hypr/config` with:

```json
{
  "name": "dock_spacer",
  "layer": "top",
  "position": "right",
  "width": 80,
  "exclusive": true,
  "passthrough": true,
  "modules-center": ["custom/dock_spacer"],
  "custom/dock_spacer": { "format": "" }
}
```

Keep the spacer visually invisible through the CSS added in Task 2.

- [ ] **Step 4: Run focused validation and dotfiles workflow**

Run:

```bash
python - <<'PY'
from pathlib import Path
import json
script = Path('config/shared/.local/bin/hypr-nwg-dock').read_text()
assert '\n  -x \\\n' not in script, 'dock exclusion flag still present'
bars = {bar['name']: bar for bar in json.loads(Path('config/shared/.config/waybar-hypr/config').read_text())}
spacer = bars['dock_spacer']
assert spacer['position'] == 'right'
assert spacer['width'] == 80
assert spacer['exclusive'] is True
assert spacer['passthrough'] is True
print('dock reservation split ok')
PY
bash -n config/shared/.local/bin/hypr-nwg-dock

# show host diff

distrobox-host-exec orgm-dot diff

# apply to home

distrobox-host-exec orgm-dot sync
```
Expected: `dock reservation split ok`; `bash -n` silent success; `orgm-dot diff` shows only Waybar/dock changes; `orgm-dot sync` completes without error.

- [ ] **Step 5: Commit**

```bash
git add config/shared/.local/bin/hypr-nwg-dock config/shared/.config/waybar-hypr/config config/shared/.config/waybar-hypr/style.css
git commit -m "feat(hypr): reserve dock space without shrinking waybar"
```

## Self-Review Checklist

- Task 1 covers edge-to-edge geometry and target heights in both Waybar variants.
- Task 2 covers black translucent look, no borders/radius, clock reduction, and tighter internal spacing in both CSS files.
- Task 3 covers the Hyprland-only dock reservation split plus required `orgm-dot diff`/`sync` workflow.
- No task touches `config/shared/.local/bin/waybar-theme-toggle`.
- Every required file path from the spec appears in at least one task.
- Each task has explicit validation commands and commit commands.

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-06-19-waybar-edge-to-edge-bars.md`.

Two execution options:

1. **Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration
2. **Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

User already requested subagentes. Use **Subagent-Driven** for execution.