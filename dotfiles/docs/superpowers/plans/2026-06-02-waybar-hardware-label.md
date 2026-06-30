# Waybar Hardware Fastfetch Button Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a top-right blue Waybar hardware button that opens a detailed Fastfetch hardware report in Kitty and leaves an interactive shell available.

**Architecture:** Waybar stays simple and only launches Fastfetch. A dedicated Fastfetch config owns the detailed hardware/system view. The hardware button is a standalone top-right module, separate from the bottom CPU/memory usage group. The launched terminal keeps the normal Kitty class/styling and uses a unique title for Hyprland floating rules.

**Tech Stack:** Waybar custom module JSON, Fastfetch JSONC config, Kitty, POSIX `sh`, `orgm-dot`.

---

## File Structure

- Create: `config/shared/.config/fastfetch/hardware.jsonc`
  - Dedicated detailed hardware Fastfetch view.
- Modify: `config/shared/.config/waybar-hypr/config`
  - Add standalone `custom/hardware_fetch` to `top_bar.modules-right` and remove it from the bottom CPU/memory area.
- Modify: `config/shared/.config/hypr/lua/windows-workspaces.lua`
  - Float, size, and center Kitty windows titled `hardware-fastfetch`.
- Modify: `docs/superpowers/specs/2026-06-02-waybar-hardware-label-design.md`
  - Replace old direct-label design with the approved Fastfetch button design.

## Task 1: Add Fastfetch hardware config

**Files:**
- Create: `config/shared/.config/fastfetch/hardware.jsonc`

- [ ] **Step 1: Verify config does not exist yet**

Run:

```bash
test ! -e config/shared/.config/fastfetch/hardware.jsonc
```

Expected: command exits with status 0 before implementation. If the file already exists, inspect it and merge instead of overwriting blindly.

- [ ] **Step 2: Create detailed Fastfetch config**

Create `config/shared/.config/fastfetch/hardware.jsonc` with hardware, system, display, storage, and session sections. Do not force the ORGM image logo; let Fastfetch use the system logo automatically.

- [ ] **Step 3: Validate Fastfetch config**

Run:

```bash
fastfetch --config config/shared/.config/fastfetch/hardware.jsonc >/tmp/waybar-hardware-fastfetch.out
```

Expected: command exits with status 0 and output includes CPU/GPU/system data.

## Task 2: Add Waybar hardware button group

**Files:**
- Modify: `config/shared/.config/waybar-hypr/config`

- [ ] **Step 1: Write failing config assertion before editing**

Run:

```bash
python3 - <<'PY'
import json
from pathlib import Path
text = Path('config/shared/.config/waybar-hypr/config').read_text()
clean = '\n'.join(line for line in text.splitlines() if not line.lstrip().startswith('//'))
config = json.loads(clean)
bottom = next(bar for bar in config if bar.get('name') == 'bottom_bar')
top = next(bar for bar in config if bar.get('name') == 'top_bar')
assert 'custom/hardware_fetch' in top['modules-right']
assert top['custom/hardware_fetch']['format'] == '󰌢'
assert 'kitty --title hardware-fastfetch' in top['custom/hardware_fetch']['on-click']
assert 'exec fish -i' in top['custom/hardware_fetch']['on-click']
print('hardware button ok')
PY
```

Expected before editing: assertion failure because `custom/hardware_fetch` is not in the top bar yet.

- [ ] **Step 2: Add `custom/hardware_fetch` to the top-right controls**

Change `top_bar.modules-right` so `custom/hardware_fetch` appears near the other top-right control buttons, and remove hardware module refs from `bottom_bar.modules-right`.

- [ ] **Step 3: Add `custom/hardware_fetch` button definition**

Add a button with icon `󰌢`, tooltip `Hardware / Fastfetch`, and click command:

```sh
kitty --title hardware-fastfetch -e fish -lc 'fastfetch --config ~/.config/fastfetch/hardware.jsonc; echo; exec fish -i'
```

- [ ] **Step 4: Verify config assertion passes**

Run the Python assertion from Task 2 Step 1 again.

Expected output:

```text
hardware button ok
```

## Task 3: Sync and runtime verify

**Files:**
- No source changes unless verification finds a concrete bug.

- [ ] **Step 1: Check status without staging unrelated user changes**

Run:

```bash
git status --short
```

Expected: changed files include only Fastfetch, Waybar, spec, and plan files from this task, plus any pre-existing unrelated files left unstaged.

- [ ] **Step 2: Check host diff**

Run:

```bash
distrobox-host-exec orgm-dot diff
```

Expected: diff includes new Fastfetch config and Waybar config changes.

- [ ] **Step 3: Sync to host**

Run:

```bash
distrobox-host-exec orgm-dot sync
```

Expected: sync completes without errors.

- [ ] **Step 4: Verify host commands**

Run:

```bash
distrobox-host-exec sh -lc 'command -v kitty && command -v fastfetch && fastfetch --config ~/.config/fastfetch/hardware.jsonc >/tmp/hardware-fastfetch.out'
```

Expected: command exits with status 0. If `fastfetch` is missing, stop and report missing host package.

- [ ] **Step 5: Reload Waybar**

Run:

```bash
distrobox-host-exec sh -lc 'pkill -SIGUSR2 waybar || true'
```

Expected: command exits with status 0.

- [ ] **Step 6: Manual UI check**

Expected top-right controls include the blue `󰌢` hardware button, separate from the bottom CPU/memory usage group.

Click `󰌢`. Expected: Kitty opens detailed Fastfetch, then leaves an interactive Fish shell ready for more commands.

## Commit Plan

Use two focused commits, avoiding unrelated `config/shared/.pi/agent/AGENTS.md` if still modified:

```bash
git add docs/superpowers/specs/2026-06-02-waybar-hardware-label-design.md docs/superpowers/plans/2026-06-02-waybar-hardware-label.md
git commit -m "docs: revise waybar hardware fastfetch design"

git add config/shared/.config/fastfetch/hardware.jsonc config/shared/.config/waybar-hypr/config config/shared/.config/hypr/lua/windows-workspaces.lua
git commit -m "feat(waybar): add hardware fastfetch button"
```
