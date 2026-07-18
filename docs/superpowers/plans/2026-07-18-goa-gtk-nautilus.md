# GNOME Online Accounts GTK alongside Nautilus Implementation Plan

<!-- markdownlint-disable MD013 -->

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install `gnome-online-accounts-gtk` in every NixOS profile that explicitly installs Nautilus.

**Architecture:** Keep package ownership beside Nautilus instead of adding a global GUI dependency. `common_hyprland.nix` covers both Hyprland variants; GNOME, i3, and Labwc receive matching entries in their own package lists.

**Tech Stack:** NixOS modules, Bash contract test, Nix evaluation, Git.

## Global Constraints

- Add only `gnome-online-accounts-gtk`; do not change GOA services.
- Modify `common_hyprland.nix`, `gnome.nix`, `i3.nix`, and `labwc.nix` only.
- Place the package immediately after each explicit `nautilus` package entry.
- Do not add the package to `nixos/common.nix`.
- Preserve unrelated Caelestia, Herdr, Kitty, and Yazi working-tree changes.
- Commit and push to `origin/master` after verification.

---

### Task 1: Install GOA GTK beside Nautilus

**Files:**

- Create: `tests/goa-gtk-nautilus.bats.sh`
- Modify: `nixos/profiles/common_hyprland.nix:319-321`
- Modify: `nixos/profiles/gnome.nix:38-43`
- Modify: `nixos/profiles/i3.nix:44-49`
- Modify: `nixos/profiles/labwc.nix:133-139`

**Interfaces:**

- Consumes: nixpkgs package `gnome-online-accounts-gtk`.
- Produces: GTK Online Accounts frontend in every explicit Nautilus-owning profile.

- [ ] **Step 1: Write the failing package-placement test**

Create `tests/goa-gtk-nautilus.bats.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_goa_after_nautilus() {
  local file="$1"
  awk '
    $1 == "nautilus" {
      getline
      if ($1 == "gnome-online-accounts-gtk") found = 1
    }
    END { exit found ? 0 : 1 }
  ' "$file" || fail "gnome-online-accounts-gtk must follow nautilus in $file"
}

for profile in \
  nixos/profiles/common_hyprland.nix \
  nixos/profiles/gnome.nix \
  nixos/profiles/i3.nix \
  nixos/profiles/labwc.nix; do
  assert_goa_after_nautilus "$ROOT/$profile"
done

if grep -Eq '^[[:space:]]+gnome-online-accounts-gtk([[:space:]]|$)' "$ROOT/nixos/common.nix"; then
  fail "gnome-online-accounts-gtk must not be global"
fi

printf 'PASS: GOA GTK follows every explicit Nautilus package\n'
```

Make it executable:

```bash
chmod +x tests/goa-gtk-nautilus.bats.sh
```

- [ ] **Step 2: Run the test and confirm RED**

Run:

```bash
bash tests/goa-gtk-nautilus.bats.sh
```

Expected: FAIL naming `nixos/profiles/common_hyprland.nix`.

- [ ] **Step 3: Add the package after Nautilus in all four owners**

In each affected package list, use this exact pair:

```nix
    nautilus
    gnome-online-accounts-gtk
```

Do not move or alter surrounding packages.

- [ ] **Step 4: Run focused verification**

Run:

```bash
bash tests/goa-gtk-nautilus.bats.sh
bash -n tests/goa-gtk-nautilus.bats.sh
git diff --check
nix eval --raw .#nixosConfigurations.hyprland.config.system.build.toplevel.drvPath >/dev/null
nix eval --raw .#nixosConfigurations.gnome.config.system.build.toplevel.drvPath >/dev/null
nix eval --raw .#nixosConfigurations.i3.config.system.build.toplevel.drvPath >/dev/null
nix eval --raw .#nixosConfigurations.labwc.config.system.build.toplevel.drvPath >/dev/null
```

Expected: test prints `PASS`; syntax, whitespace, and four evaluations exit 0.

- [ ] **Step 5: Commit and push**

```bash
git add \
  tests/goa-gtk-nautilus.bats.sh \
  nixos/profiles/common_hyprland.nix \
  nixos/profiles/gnome.nix \
  nixos/profiles/i3.nix \
  nixos/profiles/labwc.nix
git commit -m "feat(desktop): add GOA GTK beside Nautilus"
git push origin master
```
