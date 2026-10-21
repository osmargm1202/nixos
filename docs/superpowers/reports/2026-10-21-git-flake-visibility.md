# OrgM: Git-flake source visibility repair

## Cause

`nh os switch .#orgm` evaluates the Git flake, which excludes untracked
files. Previous implementation added imports for `nixos/osk` and
`nixos/tablet.nix`, but left those new sources outside the Git index.
Previous checks used `path:$PWD`, which included them and missed the defect.

## Repair

Selectively added 23 new runtime source files to the canonical repository
index: OSK module/engine, tablet module, secure keyboard theme generator,
shared keyboard sources, tablet dock/tools, launcher helper, overview module,
OSK app manifest and i3 binding. No existing modified files were staged;
ignored Python bytecode and unrelated docs/tests were excluded. No commit,
push, system activation, login/lock restart or credential use occurred.

## Verification

- Before repair, `nix eval .#nixosConfigurations.orgm.config.system.build.toplevel.drvPath`
  reproduced the exact untracked `nixos/osk` error.
- After repair, the same Git-flake evaluation passed.
- `python3 tests/launcher-deployment.test.py`: passed (three host subcases).
- `git diff --cached --check`: passed.
- `nix build .#nixosConfigurations.orgm.config.system.build.toplevel --no-link --print-out-paths`: passed.
  Built `/nix/store/d8696fsbs33jxyh1g6s80hhzwcaxiw0f-nixos-system-orgm-hyprland`.
- `NIXPKGS_ALLOW_UNFREE=1 nix flake check --impure --no-build .`: all checks passed.
  The initial invocation without the temporary allowance stopped on the existing
  unfree `orgm-todo` package. No persistent license settings were changed.

## Key Learnings

1. Validate the same Git-flake reference users build; `path:` checks alone
   cannot catch missing index entries.
2. New imported Nix files and packaged/deployed resources must be visible
   to Git before testing the actual system source.
