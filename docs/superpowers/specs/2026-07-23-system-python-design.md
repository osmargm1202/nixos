# System Python Design

## Goal

Make the standard Python 3 interpreter available on every NixOS host that imports `nixos/common.nix`.

## Design

Add `python3` to `environment.systemPackages` in `nixos/common.nix`, adjacent to `uv`. Use the standard full interpreter rather than `python3Minimal` or a global `python3.withPackages` environment.

Project-specific Python dependencies remain managed by project flakes or `uv`; this change only provides the global interpreter and standard library.

## Testing

Add a focused shell test that verifies `python3` is present in the common system package list next to `uv`. Run that test, parse `nixos/common.nix` with `nix-instantiate`, and check Nix language diagnostics.

## Rollout

Commit and push the source and test changes. Do not run `nh os switch`; the user performs system activation.
