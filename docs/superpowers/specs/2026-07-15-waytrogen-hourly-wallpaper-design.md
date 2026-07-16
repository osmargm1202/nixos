# Waytrogen hourly wallpaper design

## Goal

Keep the restored wallpaper stable after Hyprland login, then change it through Waytrogen at every wall-clock hour (`12:00`, `13:00`, `14:00`, and so on). The Waybar wallpaper button must launch Waytrogen.

## Scope

This change applies only to the `hyprland` profile. The `hyprlandqs-caelestia` profile and its wallpaper stack remain unchanged.

## Current problem

The Hyprland autostart currently asks `hypr-random-wallpaper` to restore state and then starts its daemon. The daemon changes the wallpaper immediately and then every 1800 seconds. Its automatic path calls `waytrogen --random`, incorrectly parses Waytrogen's array-shaped JSON with `jq '.path'`, and then manipulates Hyprpaper directly. This creates two controllers for the same wallpaper process and does not meet the requested schedule.

Waytrogen 0.8.0 currently has a saved wallpaper under `~/Pictures/Wallpapers/.thumb`. That stale state must be replaced with a real wallpaper during deployment without deleting original wallpapers.

## Design

### Startup

Hyprland autostart runs `waytrogen --restore --startup-delay 3` directly. The delay lets outputs initialize before Waytrogen restores its saved state. Failure is logged and does not block the rest of session startup.

After scheduling restoration, autostart starts one `hypr-random-wallpaper daemon` process. Existing PID ownership checks remain in place so stale or unrelated processes are not killed.

### Hourly scheduler

The daemon does not change the wallpaper immediately. It computes the delay from current local time to the next minute `00`, sleeps for that delay, invokes the automatic change, and repeats. This keeps changes aligned to wall-clock hours rather than one-hour intervals measured from login.

The automatic change and the manual `hypr-random-wallpaper next` command both execute `waytrogen --random`. They do not follow that call with direct `hyprctl hyprpaper` operations. A Waytrogen failure is logged and leaves the current wallpaper unchanged until the next scheduled attempt.

Legacy explicit `set` commands remain available for the existing right-click picker, but are outside the automatic restore/change path.

### Waybar

The left click of `custom/wallpaper` launches `waytrogen`. The existing right-click picker remains unchanged. Existing configuration already has the desired left-click command; tests continue to protect it.

### Stale thumbnail state

Deployment inspects Waytrogen's saved state. If the selected path is under a `.thumb` directory, Waytrogen is advanced to a real wallpaper and the resulting state is verified. No source wallpaper is deleted. Thumbnail cleanup or relocation is outside this focused change.

## Error handling

- Missing or failing Waytrogen returns a non-zero status from manual `next` and writes a clear error.
- Scheduled failures are logged, but the daemon remains alive for the next hour.
- Restore failure cannot stop Hyprland autostart.
- PID files are accepted only when they belong to this helper.

## Testing

Automated shell tests verify:

1. Autostart directly runs delayed Waytrogen restore before starting the helper daemon.
2. The daemon sleeps before its first change.
3. Delay calculation targets the next wall-clock hour.
4. Automatic and manual changes call `waytrogen --random`.
5. Automatic changes do not call Hyprpaper directly.
6. Daemon PID ownership protections remain intact.
7. Waybar left click launches `waytrogen`.

Verification also includes shell syntax checks, relevant Bats scripts, Nix evaluation/checks where practical, `orgm-diff`, and `orgm-sync` after reviewing the generated system changes.
