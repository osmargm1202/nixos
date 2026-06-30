# Wallpaper Icon Random Click Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Waybar-Hypr wallpaper icon choose a random wallpaper for all Hyprland screens on left click.

**Architecture:** Use the active `orgm-wallpaper` backend directly rather than the old Hyprpaper helper. Update the Waybar `custom/wallpaper` left and right click commands, then add focused shell test assertions so click behavior cannot regress.

**Tech Stack:** Waybar JSONC-style config, Bash helper tests, existing dotfiles `orgm-dot` workflow.

---

## File structure

- Modify: `config/shared/.config/waybar-hypr/config`
  - Owns Waybar-Hypr module configuration.
  - Change only `custom/wallpaper` left-click command, right-click command, and tooltip.
- Modify: `tests/helpers/waybar-hypr-custom-icons.bats.sh`
  - Existing Waybar-Hypr smoke test.
  - Add assertions for wallpaper click command and tooltip text.
- Read-only verification: `/run/current-system/sw/bin/orgm-wallpaper`
  - Active wallpaper backend used by Hyprland autostart. Do not modify in this plan.

---

### Task 1: Test and implement Waybar wallpaper random click

**Files:**
- Modify: `tests/helpers/waybar-hypr-custom-icons.bats.sh`
- Modify: `config/shared/.config/waybar-hypr/config`

- [ ] **Step 1: Write the failing test**

Edit `tests/helpers/waybar-hypr-custom-icons.bats.sh`. After this existing block:

```bash
grep -q 'margin-left": 12' "$root/config/shared/.config/waybar-hypr/config" || fail "Waybar should keep Hyprland-like side gap"
grep -q 'margin-right": 12' "$root/config/shared/.config/waybar-hypr/config" || fail "Waybar should keep Hyprland-like side gap"
```

Add these assertions:

```bash
grep -q '"on-click": "orgm-wallpaper random-static"' "$root/config/shared/.config/waybar-hypr/config" || fail "wallpaper icon left click should use the active orgm-wallpaper backend"
grep -q '"on-click-right": "orgm-wallpaper pick"' "$root/config/shared/.config/waybar-hypr/config" || fail "wallpaper icon right click should open picker"
grep -q '"tooltip-format": "Wallpaper aleatorio"' "$root/config/shared/.config/waybar-hypr/config" || fail "wallpaper icon tooltip should describe random behavior"
if grep -q '"on-click": "hypr-random-wallpaper next"' "$root/config/shared/.config/waybar-hypr/config"; then
  fail "wallpaper icon left click should not use old hyprpaper helper"
fi
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
bash tests/helpers/waybar-hypr-custom-icons.bats.sh
```

Expected result before implementation:

```text
FAIL: wallpaper icon left click should use the active orgm-wallpaper backend
```

- [ ] **Step 3: Write minimal implementation**

Edit `config/shared/.config/waybar-hypr/config`. Change only the `custom/wallpaper` block from:

```json
    "custom/wallpaper": {
      "format": "",
      "tooltip": true,
      "tooltip-format": "Wallpaper aleatorio",
      "on-click": "hypr-random-wallpaper next"
    },
```

to:

```json
    "custom/wallpaper": {
      "format": "",
      "tooltip": true,
      "tooltip-format": "Wallpaper aleatorio",
      "on-click": "orgm-wallpaper random-static",
      "on-click-right": "orgm-wallpaper pick"
    },
```

- [ ] **Step 4: Run focused tests to verify pass**

Run:

```bash
bash tests/helpers/waybar-hypr-custom-icons.bats.sh
distrobox-host-exec sh -lc 'before=$(orgm-wallpaper status | sed -n "s/^path=//p"); orgm-wallpaper random-static >/tmp/orgm-wallpaper-random-static-test.log 2>&1; after=$(orgm-wallpaper status | sed -n "s/^path=//p"); test -n "$after"; printf "before=%s\nafter=%s\n" "$before" "$after"'
```

Expected result: first command prints `PASS: Waybar-Hypr custom icons configured`; second command exits 0 and prints non-empty `before=` and `after=` wallpaper paths.

- [ ] **Step 5: Review dotfiles diff**

Run:

```bash
distrobox-host-exec orgm-dot diff
```

Expected: diff shows the Waybar-Hypr config click command and tooltip changing. If it shows unrelated files, stop and inspect before syncing.

- [ ] **Step 6: Apply dotfiles**

Run:

```bash
distrobox-host-exec orgm-dot sync
```

Expected: sync completes without errors.

- [ ] **Step 7: Commit implementation**

Run:

```bash
git status --short
git add config/shared/.config/waybar-hypr/config tests/helpers/waybar-hypr-custom-icons.bats.sh
git commit -m "feat(hypr): randomize wallpaper from Waybar icon"
```

Expected: commit includes only the Waybar config and test change.
