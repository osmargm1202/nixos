# Waytrogen Hourly Wallpaper Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore the saved Waytrogen wallpaper at Hyprland login and change it through Waytrogen at every wall-clock hour.

**Architecture:** Hyprland autostart delegates restoration directly to Waytrogen, then launches the existing PID-guarded helper daemon. The helper waits until the next local `:00`, calls `waytrogen --random`, rejects `.thumb` selections by retrying through Waytrogen, and never follows an automatic Waytrogen operation with direct Hyprpaper commands.

**Tech Stack:** Bash, Hyprland Lua autostart configuration, Waytrogen 0.8.0 CLI, Waybar JSON configuration, shell smoke tests.

## Global Constraints

- Apply only to the `hyprland` profile; do not modify `hyprlandqs-caelestia`.
- Scheduled changes occur at wall-clock minute `00`, not 3600 seconds after login.
- The daemon must wait before its first automatic change.
- Automatic restore/change operations use Waytrogen as the only Hyprpaper controller.
- Keep legacy explicit `set` commands for the existing right-click picker.
- Waybar left click launches `waytrogen`; right click remains unchanged.
- Do not delete original wallpapers.
- Preserve unrelated working-tree modifications.

---

### Task 1: Characterize Waytrogen automatic helper behavior

**Files:**

- Modify: `dotfiles/tests/helpers/hypr-random-wallpaper.bats.sh`
- Test: `dotfiles/tests/helpers/hypr-random-wallpaper.bats.sh`

**Interfaces:**

- Consumes: executable `dotfiles/config/profiles/hyprland/.local/bin/hypr-random-wallpaper`.
- Produces: regression coverage for `next`, hour alignment, sleep-before-change ordering, `.thumb` retry, and PID ownership.

- [ ] **Step 1: Replace stale script path and build deterministic command stubs**

Set:

```bash
SCRIPT="$ROOT/config/profiles/hyprland/.local/bin/hypr-random-wallpaper"
```

Create fake `waytrogen`, `date`, `sleep`, `hyprctl`, and `ps` commands under `$TMP/bin`. The Waytrogen stub must append every invocation to `$CALLS`; `--list-current-wallpapers` returns this array:

```json
[
  {"monitor":"","path":"","changer":"Hyprpaper"},
  {"monitor":"All","path":"/tmp/real-wallpaper.jpg","changer":"Hyprpaper"}
]
```

The date stub returns `17` for `+%M` and `25` for `+%S`. The sleep stub records its argument and exits successfully.

- [ ] **Step 2: Add failing assertions for manual automatic change**

Run `"$SCRIPT" next` with stubbed `PATH`. Assert:

```bash
grep -q '^waytrogen --random$' "$CALLS"
if grep -q '^hyprctl ' "$CALLS"; then
  fail "automatic next must not call Hyprpaper directly"
fi
```

Run: `bash dotfiles/tests/helpers/hypr-random-wallpaper.bats.sh`

Expected: FAIL because the current helper falls through to direct Hyprpaper handling after Waytrogen.

- [ ] **Step 3: Add failing assertion for next-hour calculation**

Source the helper, call `seconds_until_next_hour`, and assert that `17:25` produces `2555` seconds:

```bash
actual="$(PATH="$TMP/bin:$PATH" source "$SCRIPT"; seconds_until_next_hour)"
[ "$actual" = 2555 ] || fail "expected 2555 seconds, got $actual"
```

Run: `bash dotfiles/tests/helpers/hypr-random-wallpaper.bats.sh`

Expected: FAIL because `seconds_until_next_hour` and source-safe main dispatch do not exist.

- [ ] **Step 4: Add failing daemon-order assertion**

Run one daemon iteration with `HYPR_WALLPAPER_DAEMON_ONCE=1`. Assert call order is sleep first, Waytrogen random second:

```bash
first="$(sed -n '1p' "$CALLS")"
second="$(sed -n '2p' "$CALLS")"
[ "$first" = "sleep 2555" ] || fail "daemon must sleep until :00 before changing"
[ "$second" = "waytrogen --random" ] || fail "daemon must change through Waytrogen after sleeping"
```

Run: `bash dotfiles/tests/helpers/hypr-random-wallpaper.bats.sh`

Expected: FAIL because the current daemon changes before sleeping.

- [ ] **Step 5: Add failing `.thumb` retry assertion**

Make the Waytrogen stub return a `.thumb` path after its first `--random` and `/tmp/real-wallpaper.jpg` after its second. Assert two random calls and final success:

```bash
[ "$(grep -c '^waytrogen --random$' "$CALLS")" -eq 2 ] ||
  fail "next should retry a Waytrogen .thumb selection"
```

Run: `bash dotfiles/tests/helpers/hypr-random-wallpaper.bats.sh`

Expected: FAIL because current JSON parsing uses `.path` against an array and has no `.thumb` guard.

- [ ] **Step 6: Keep PID safety assertions**

Retain checks that `run_daemon` and `stop_daemon` call `is_own_daemon_pid` before killing a PID, and that ownership inspection uses `ps -p "$pid" -o args=`.

- [ ] **Step 7: Commit failing characterization tests**

```bash
git add dotfiles/tests/helpers/hypr-random-wallpaper.bats.sh
git commit -m "test(hypr): specify hourly Waytrogen wallpaper flow"
```

---

### Task 2: Implement the aligned Waytrogen helper

**Files:**

- Modify: `dotfiles/config/profiles/hyprland/.local/bin/hypr-random-wallpaper`
- Test: `dotfiles/tests/helpers/hypr-random-wallpaper.bats.sh`

**Interfaces:**

- Consumes: Waytrogen CLI operations `--random` and `--list-current-wallpapers`.
- Produces: `seconds_until_next_hour() -> integer seconds`, `next_wallpaper() -> status`, source-safe `main()`, and existing `daemon|stop|restore|set` CLI compatibility.

- [ ] **Step 1: Make the script source-safe and injectable**

Define command variables near the top:

```bash
waytrogen_bin="${WAYTROGEN_BIN:-waytrogen}"
date_bin="${DATE_BIN:-date}"
sleep_bin="${SLEEP_BIN:-sleep}"
random_attempts="${WAYTROGEN_RANDOM_ATTEMPTS:-10}"
```

Move the final `case` into `main()` and dispatch only when executed:

```bash
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
```

- [ ] **Step 2: Parse Waytrogen's array-shaped current state**

Implement:

```bash
waytrogen_current_path() {
  local payload
  payload="$($waytrogen_bin --list-current-wallpapers 2>/dev/null)" || return 1
  [ -n "$payload" ] || return 1

  if command -v jq >/dev/null 2>&1; then
    printf '%s\n' "$payload" |
      jq -r '[.[] | .path? // empty | select(length > 0)] | last // empty' 2>/dev/null
  else
    printf '%s\n' "$payload" |
      sed -n 's/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' |
      awk 'NF { path=$0 } END { print path }'
  fi
}
```

- [ ] **Step 3: Delegate automatic changes exclusively to Waytrogen**

Replace automatic fallback behavior with a bounded retry:

```bash
next_wallpaper() {
  local attempt current
  command -v "$waytrogen_bin" >/dev/null 2>&1 || {
    echo "hypr-random-wallpaper: waytrogen not found" >&2
    return 127
  }

  for ((attempt = 1; attempt <= random_attempts; attempt++)); do
    "$waytrogen_bin" --random || {
      echo "hypr-random-wallpaper: waytrogen --random failed" >&2
      return 1
    }
    current="$(waytrogen_current_path || true)"
    case "$current" in
      */.thumb/*) continue ;;
      "")
        echo "hypr-random-wallpaper: Waytrogen returned no current wallpaper" >&2
        return 1
        ;;
      *) return 0 ;;
    esac
  done

  echo "hypr-random-wallpaper: Waytrogen selected only .thumb entries after $random_attempts attempts" >&2
  return 1
}
```

Do not call `set_wallpaper` from `next_wallpaper` or `restore_wallpaper`. Keep `set_wallpaper` only for explicit picker compatibility.

- [ ] **Step 4: Add wall-clock alignment**

Implement:

```bash
seconds_until_next_hour() {
  local minute second
  minute="$($date_bin +%M)"
  second="$($date_bin +%S)"
  printf '%s\n' "$(( (60 - 10#$minute) * 60 - 10#$second ))"
}
```

Update `run_daemon()` loop:

```bash
while :; do
  "$sleep_bin" "$(seconds_until_next_hour)"
  next_wallpaper || true
  [ "${HYPR_WALLPAPER_DAEMON_ONCE:-0}" = 1 ] && break
done
```

This intentionally waits 3600 seconds when launched exactly at `HH:00:00`, preventing an immediate login change.

- [ ] **Step 5: Delegate compatibility restore to Waytrogen**

Implement `restore_wallpaper()` as:

```bash
restore_wallpaper() {
  command -v "$waytrogen_bin" >/dev/null 2>&1 || return 127
  "$waytrogen_bin" --restore
}
```

Autostart will call Waytrogen directly; this command remains for external compatibility.

- [ ] **Step 6: Run focused tests and syntax check**

Run:

```bash
bash -n dotfiles/config/profiles/hyprland/.local/bin/hypr-random-wallpaper
bash dotfiles/tests/helpers/hypr-random-wallpaper.bats.sh
```

Expected: syntax check exits 0 and test prints `hypr random wallpaper smoke test passed`.

- [ ] **Step 7: Commit helper implementation**

```bash
git add dotfiles/config/profiles/hyprland/.local/bin/hypr-random-wallpaper \
  dotfiles/tests/helpers/hypr-random-wallpaper.bats.sh
git commit -m "fix(hypr): align Waytrogen changes to hourly clock"
```

---

### Task 3: Fix current-wallpaper state parsing

**Files:**

- Modify: `dotfiles/config/profiles/hyprland/.local/bin/hypr-current-wallpaper`
- Create: `dotfiles/tests/helpers/hypr-current-wallpaper.bats.sh`

**Interfaces:**

- Consumes: Waytrogen `--list-current-wallpapers` array JSON.
- Produces: `$XDG_RUNTIME_DIR/hypr-current-wallpaper` symlink pointing to the last non-empty saved Waytrogen path.

- [ ] **Step 1: Write failing array-parsing test**

Create a temporary home, runtime directory, real wallpaper, and fake Waytrogen returning one empty entry followed by the real path. Run the helper and assert:

```bash
[ "$(readlink "$TMP/runtime/hypr-current-wallpaper")" = "$TMP/home/Pictures/Wallpapers/real.jpg" ] ||
  fail "lock wallpaper should use Waytrogen's last non-empty array path"
```

Run: `bash dotfiles/tests/helpers/hypr-current-wallpaper.bats.sh`

Expected: FAIL because current `jq '.path'` cannot index an array.

- [ ] **Step 2: Correct jq and sed fallback parsing**

Use the same last-non-empty array parser from Task 2:

```bash
jq -r '[.[] | .path? // empty | select(length > 0)] | last // empty'
```

For the no-jq fallback, pipe extracted paths through:

```bash
awk 'NF { path=$0 } END { print path }'
```

- [ ] **Step 3: Run test and syntax check**

```bash
bash -n dotfiles/config/profiles/hyprland/.local/bin/hypr-current-wallpaper
bash dotfiles/tests/helpers/hypr-current-wallpaper.bats.sh
```

Expected: both exit 0; test prints `hypr current wallpaper tests passed`.

- [ ] **Step 4: Commit lock-state fix**

```bash
git add dotfiles/config/profiles/hyprland/.local/bin/hypr-current-wallpaper \
  dotfiles/tests/helpers/hypr-current-wallpaper.bats.sh
git commit -m "fix(hypr): parse Waytrogen wallpaper state array"
```

---

### Task 4: Update Hyprland autostart and preserve Waybar launcher

**Files:**

- Modify: `dotfiles/config/profiles/hyprland/.config/hypr/lua/autostart.lua`
- Modify: `dotfiles/tests/helpers/hypr-autostart.bats.sh`
- Verify: `dotfiles/config/profiles/hyprland/.config/waybar-hypr/config`
- Verify: `dotfiles/tests/helpers/waybar-hypr-custom-icons.bats.sh`

**Interfaces:**

- Consumes: Waytrogen `--restore --startup-delay 3`; helper `daemon` command.
- Produces: session startup order and tested Waybar launcher behavior.

- [ ] **Step 1: Write failing autostart assertions**

Require direct restore and reject helper restore:

```bash
grep -Fq "waytrogen --restore --startup-delay 3" "$AUTOSTART" ||
  fail "Waytrogen should restore after monitor startup delay"
if grep -Fq "hypr-random-wallpaper restore" "$AUTOSTART"; then
  fail "autostart should restore directly through Waytrogen"
fi
```

Keep the assertion that the helper daemon starts.

Run: `bash dotfiles/tests/helpers/hypr-autostart.bats.sh`

Expected: FAIL because autostart currently invokes helper restore.

- [ ] **Step 2: Replace restore entry in autostart**

Use:

```lua
"sh -lc 'waytrogen --restore --startup-delay 3 >>/tmp/waytrogen-restore.log 2>&1 || true'",
"hypr-current-wallpaper",
"sh -lc 'hypr-random-wallpaper daemon >>/tmp/hypr-random-wallpaper.log 2>&1 &'",
```

Do not modify Caelestia autostart.

- [ ] **Step 3: Run autostart and Waybar tests**

```bash
bash dotfiles/tests/helpers/hypr-autostart.bats.sh
bash dotfiles/tests/helpers/waybar-hypr-custom-icons.bats.sh
```

Expected: both print PASS. The Waybar test confirms `"on-click": "waytrogen"` and unchanged right click.

- [ ] **Step 4: Commit autostart change**

```bash
git add dotfiles/config/profiles/hyprland/.config/hypr/lua/autostart.lua \
  dotfiles/tests/helpers/hypr-autostart.bats.sh
git commit -m "fix(hypr): restore wallpaper directly with Waytrogen"
```

---

### Task 5: Verify, synchronize, and repair stale runtime state

**Files:**

- Verify: all files modified in Tasks 1-4
- Runtime state: `~/.config/waytrogen/config.json`

**Interfaces:**

- Consumes: completed implementation and ORGM dotfile tooling.
- Produces: deployed profile files and a non-`.thumb` saved Waytrogen wallpaper.

- [ ] **Step 1: Run focused regression suite**

```bash
bash dotfiles/tests/helpers/hypr-random-wallpaper.bats.sh
bash dotfiles/tests/helpers/hypr-current-wallpaper.bats.sh
bash dotfiles/tests/helpers/hypr-autostart.bats.sh
bash dotfiles/tests/helpers/waybar-hypr-custom-icons.bats.sh
bash dotfiles/tests/helpers/hypr-shell-helpers.bats.sh
```

Expected: every script exits 0.

- [ ] **Step 2: Run static verification**

```bash
bash -n dotfiles/config/profiles/hyprland/.local/bin/hypr-random-wallpaper
git diff --check
nix flake check
```

Expected: all commands exit 0. If `nix flake check` reports a pre-existing unrelated failure, record exact output and do not hide it.

- [ ] **Step 3: Inspect source changes**

```bash
git diff -- dotfiles/config/profiles/hyprland dotfiles/tests/helpers
```

Expected: diff contains only intended Hyprland helper, current-wallpaper, autostart, and test-related source changes; unrelated user files remain untouched.

- [ ] **Step 4: Confirm live Home Manager links**

```bash
readlink -f ~/.local/bin/hypr-random-wallpaper
readlink -f ~/.local/bin/hypr-current-wallpaper
readlink -f ~/.config/hypr/lua/autostart.lua
```

Expected: each existing link resolves into this repository's `dotfiles/config/profiles/hyprland` source tree, so source edits are already live.

- [ ] **Step 5: Replace stale `.thumb` Waytrogen state through Waytrogen**

Run the helper manually up to its bounded retry:

```bash
hypr-random-wallpaper next
current="$(waytrogen --list-current-wallpapers | jq -r '[.[] | .path? // empty | select(length > 0)] | last // empty')"
case "$current" in
  */.thumb/*|"") printf 'invalid Waytrogen state: %s\n' "$current" >&2; exit 1 ;;
esac
printf 'Waytrogen state: %s\n' "$current"
```

Expected: final path is an existing wallpaper outside `.thumb`. No wallpaper file is deleted.

- [ ] **Step 6: Restart only the wallpaper daemon**

```bash
hypr-random-wallpaper stop
nohup hypr-random-wallpaper daemon >>/tmp/hypr-random-wallpaper.log 2>&1 &
```

Expected: one helper daemon process and no immediate wallpaper change.

- [ ] **Step 7: Final diagnostics and repository status**

```bash
pgrep -af 'hypr-random-wallpaper daemon'
git status --short --branch
git log -5 --oneline
```

Expected: one daemon, implementation commits present, and only pre-existing unrelated modifications remain uncommitted.
