# Hyprland Video Timer Design

## Goal

Provide a Hyprland shortcut that asks how many seconds to watch a video, switches to the previously active workspace, starts the first available MPRIS player, waits for the requested duration, and returns to the previously active workspace.

## Scope

The feature applies to both Hyprland dotfiles profiles:

- `hyprland`
- `hyprlandqs-caelestia`

The timer shortcut is `SUPER + SHIFT + TAB`. `SUPER + mouse wheel up` switches to the previous relative workspace, and `SUPER + mouse wheel down` switches to the next relative workspace.

## Components

### Helper

Install `hypr-video-timer` under `.local/bin` in both profiles. The helper owns prompting, validation, process replacement, workspace switching, media playback, waiting, cleanup, and user-facing errors.

### Hyprland bindings

Add the same timer and workspace-wheel bindings to both profiles' `lua/keybindings.lua` files. The timer binding launches `hypr-video-timer` without blocking Hyprland. The wheel bindings use relative workspace navigation (`r-1` and `r+1`).

### Tests

Add Bats coverage for input validation, cancellation, command ordering, timer completion, playback failure, and replacement of an active timer.

## Runtime Flow

1. The shortcut launches the helper.
2. Rofi prompts for `Segundos`.
3. The helper exits without side effects if the prompt is cancelled or the value is not an integer greater than zero.
4. A valid invocation replaces any currently active invocation using runtime state under `$XDG_RUNTIME_DIR`.
5. The helper runs `hyprctl dispatch workspace previous`.
6. The helper runs `playerctl play`, targeting the first player selected by Playerctl.
7. The helper waits for the requested number of seconds.
8. If this invocation is still current, it runs `hyprctl dispatch workspace previous` again and returns the user to the original workspace.
9. The helper removes only runtime state that still belongs to its invocation.

The two `workspace previous` operations intentionally use Hyprland's workspace history instead of fixed workspace numbers.

## Replacement Semantics

Only one timer may be active. Starting a new valid timer cancels the old timer before changing workspace. The cancelled process must not perform its final workspace switch or delete state belonging to the replacement process.

Runtime files must be user-scoped and live under `$XDG_RUNTIME_DIR`. Process identity checks must avoid signalling an unrelated process if a stale PID file exists.

## Error Handling

- Missing Hyprland session or failed initial workspace switch: report an error and exit.
- Cancelled prompt, empty input, zero, negative number, decimal, or nonnumeric input: exit without changing workspace.
- No available MPRIS player or failed `playerctl play`: show a brief notification, but continue the timer and return flow.
- Failure of the final workspace switch: report an error and clean owned runtime state.
- Signals and normal exits: clean only state owned by the current invocation.

Notifications should use the existing desktop notification mechanism when available and must not introduce a Caelestia-specific dependency.

## Dependencies

- POSIX-compatible shell or Bash, following repository conventions
- `rofi`
- `hyprctl`
- `playerctl`
- an optional notification command already available in the profiles

The implementation must remain independent of Caelestia IPC so it behaves the same in both Hyprland profiles.

## Testing

Tests isolate external commands with stubs and verify:

- cancellation causes no Hyprland or Playerctl calls;
- invalid values cause no side effects;
- valid input orders calls as switch, play, wait, switch;
- Playerctl failure still produces the final switch;
- a replacement prevents the old invocation's final switch;
- stale runtime state does not terminate unrelated processes;
- both profile bindings invoke the helper with `SUPER + SHIFT + TAB`;
- both profiles bind `SUPER + mouse wheel up/down` to previous/next relative workspace navigation.

Register the new helper in both Hyprland profile lists in `nixos/common-dotfiles.nix`. Existing profile files update live through out-of-store symlinks; run `sudo nixos-rebuild switch` once to create the new helper symlink, then reload Hyprland.

## Non-goals

- Selecting a specific browser tab or media player
- Associating an MPRIS player with the video workspace
- Pausing playback when the timer expires
- Supporting minutes, hours, or flexible duration syntax
- Using fixed workspace numbers
- Adding a persistent systemd user service
