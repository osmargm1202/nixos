# ORGMOS Installer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a safe interactive ORGMOS installer that creates a local NixOS flake using local hardware and this repository's profiles.

**Architecture:** The repository exposes `lib.mkGeneralHost` as the stable API for local installer flakes. `install.sh` generates `/etc/nixos/flake.nix` that calls that API, preserving `/etc/nixos/hardware-configuration.nix` and asking before rebuild. General branding lives in `nixos/general.nix` and a reusable Plymouth module.

**Tech Stack:** Nix flakes, NixOS modules, POSIX/Bash shell, existing Plymouth logo theme helper.

---

## File Structure

- Create: `install.sh` — interactive installer entrypoint for `curl ... | bash`.
- Create: `nixos/general.nix` — general non-hardware ORGMOS defaults.
- Create: `nixos/hosts/general/plymouth.nix` — general ORGMOS Plymouth branding module.
- Modify: `flake.nix` — expose `lib.mkGeneralHost`, profile map, and use general module in install API.
- Test by running Nix evaluation/build commands, not by mutating real `/etc/nixos`.

---

### Task 1: Add general NixOS modules

**Files:**
- Create: `nixos/general.nix`
- Create: `nixos/hosts/general/plymouth.nix`

- [ ] **Step 1: Create `nixos/general.nix`**

```nix
{ ... }:

{
  imports = [ ./hosts/general/plymouth.nix ];

  # General ORGMOS defaults for machines installed from the public installer.
  # Keep hardware-specific settings in each machine's local hardware-configuration.nix.
}
```

- [ ] **Step 2: Create `nixos/hosts/general/plymouth.nix`**

```nix
{ pkgs, ... }:

let
  themeName = "orgmos";
in
{
  boot.plymouth = {
    theme = themeName;
    themePackages = [
      (pkgs.callPackage ../../plymouth-logo-theme.nix {
        inherit themeName;
        logo = ../../plymouth-logos/orgm-nixos.png;
        background = "0.0, 0.0, 0.0";
        logoScale = 38;
      })
    ];
  };
}
```

- [ ] **Step 3: Run Nix formatting**

Run:

```bash
nix fmt nixos/general.nix nixos/hosts/general/plymouth.nix
```

Expected: command exits 0 and files remain valid Nix.

- [ ] **Step 4: Commit**

```bash
git add nixos/general.nix nixos/hosts/general/plymouth.nix
git commit -m "feat(nixos): add general ORGMOS module"
```

---

### Task 2: Expose `lib.mkGeneralHost`

**Files:**
- Modify: `flake.nix`

- [ ] **Step 1: Add profile map and selector in `let` block**

Insert after existing `defaultHardware = ./nixos/hosts/generic/hardware-configuration.nix;`:

```nix
      profiles = {
        gnome = ./nixos/profiles/gnome.nix;
        hyprland = ./nixos/profiles/hyprland.nix;
        labwc = ./nixos/profiles/labwc.nix;
        labwc-light = ./nixos/profiles/labwc-light.nix;
        sway = ./nixos/profiles/sway.nix;
        i3 = ./nixos/profiles/i3.nix;
      };
      getProfile = profileName:
        profiles.${profileName} or (throw "Unknown ORGMOS profile '${profileName}'. Valid profiles: ${builtins.concatStringsSep ", " (builtins.attrNames profiles)}");
```

- [ ] **Step 2: Add `mkGeneralHost` helper in `let` block**

Insert after existing `mkProfile = ...;` definition:

```nix
      mkGeneralHost =
        {
          hardware,
          profile,
          hostName,
          extraModules ? [ ],
        }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            ./nixos/common.nix
            ./nixos/general.nix
            hardware
            (getProfile profile)
            { networking.hostName = hostName; }
          ]
          ++ extraModules;
        };
```

- [ ] **Step 3: Expose helper from flake outputs**

Inside the output attrset, before `formatter.${system} = ...`, add:

```nix
      lib = {
        inherit mkGeneralHost;
      };
```

- [ ] **Step 4: Run format**

Run:

```bash
nix fmt flake.nix
```

Expected: command exits 0.

- [ ] **Step 5: Verify existing eval-only profile output still evaluates**

Run:

```bash
nix eval .#nixosConfigurations.hyprland.config.networking.hostName
```

Expected output:

```text
"nixos"
```

- [ ] **Step 6: Verify `mkGeneralHost` works with eval-only hardware**

Run:

```bash
tmpdir=$(mktemp -d)
cat > "$tmpdir/flake.nix" <<'EOF'
{
  inputs.orgmos.url = "path:/home/osmarg/Hobby/nixos";

  outputs = { self, orgmos, ... }: {
    nixosConfigurations.default = orgmos.lib.mkGeneralHost {
      hardware = orgmos + "/nixos/hosts/generic/hardware-configuration.nix";
      profile = "hyprland";
      hostName = "testhost";
    };
  };
}
EOF
nix eval "$tmpdir#nixosConfigurations.default.config.networking.hostName"
```

Expected output:

```text
"testhost"
```

- [ ] **Step 7: Verify invalid profile errors clearly**

Run:

```bash
tmpdir=$(mktemp -d)
cat > "$tmpdir/flake.nix" <<'EOF'
{
  inputs.orgmos.url = "path:/home/osmarg/Hobby/nixos";

  outputs = { self, orgmos, ... }: {
    nixosConfigurations.default = orgmos.lib.mkGeneralHost {
      hardware = orgmos + "/nixos/hosts/generic/hardware-configuration.nix";
      profile = "bad-profile";
      hostName = "testhost";
    };
  };
}
EOF
nix eval "$tmpdir#nixosConfigurations.default.config.networking.hostName" 2>&1 | grep "Unknown ORGMOS profile 'bad-profile'"
```

Expected: grep exits 0 and prints the clear error line.

- [ ] **Step 8: Commit**

```bash
git add flake.nix
git commit -m "feat(nixos): expose general host builder"
```

---

### Task 3: Add interactive installer script

**Files:**
- Create: `install.sh`

- [ ] **Step 1: Create `install.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${ORGMOS_REPO_URL:-github:osmargm1202/nixos}"
NIXOS_DIR="${ORGMOS_NIXOS_DIR:-/etc/nixos}"
FLAKE_PATH="$NIXOS_DIR/flake.nix"
HARDWARE_PATH="$NIXOS_DIR/hardware-configuration.nix"

profiles=(hyprland gnome labwc sway i3)

say() {
  printf '%s\n' "$*"
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

confirm() {
  local prompt="$1"
  local answer=""
  read -r -p "$prompt [y/N]: " answer
  case "$answer" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

require_nixos() {
  if [ ! -e /etc/NIXOS ]; then
    fail "this installer must run on NixOS"
  fi
  if ! command -v nixos-rebuild >/dev/null 2>&1; then
    fail "nixos-rebuild not found; this installer must run on NixOS"
  fi
}

choose_profile() {
  say "Choose ORGMOS profile:"
  local i
  for i in "${!profiles[@]}"; do
    printf '  %d) %s\n' "$((i + 1))" "${profiles[$i]}"
  done

  local choice=""
  while true; do
    read -r -p "Profile [1-${#profiles[@]}] default 1 (${profiles[0]}): " choice
    choice="${choice:-1}"
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#profiles[@]}" ]; then
      SELECTED_PROFILE="${profiles[$((choice - 1))]}"
      return 0
    fi
    say "Invalid profile selection."
  done
}

choose_hostname() {
  local current="orgmos"
  current="$(hostname 2>/dev/null || printf orgmos)"
  read -r -p "Hostname default ($current): " SELECTED_HOSTNAME
  SELECTED_HOSTNAME="${SELECTED_HOSTNAME:-$current}"

  if ! [[ "$SELECTED_HOSTNAME" =~ ^[a-zA-Z0-9-]+$ ]]; then
    fail "hostname may only contain letters, numbers, and hyphen"
  fi
}

backup_existing_flake() {
  if [ -e "$FLAKE_PATH" ]; then
    local backup="$FLAKE_PATH.backup.$(date +%Y%m%d-%H%M%S)"
    say "Backing up existing flake: $backup"
    sudo cp "$FLAKE_PATH" "$backup"
  fi
}

write_flake() {
  local tmp
  tmp="$(mktemp)"
  cat > "$tmp" <<EOF
{
  inputs.orgmos.url = "$REPO_URL";

  outputs = { self, orgmos, ... }: {
    nixosConfigurations.default = orgmos.lib.mkGeneralHost {
      hardware = ./hardware-configuration.nix;
      profile = "$SELECTED_PROFILE";
      hostName = "$SELECTED_HOSTNAME";
    };
  };
}
EOF

  say "Generated flake:"
  say "---"
  cat "$tmp"
  say "---"

  if confirm "Write this to $FLAKE_PATH?"; then
    backup_existing_flake
    sudo install -m 0644 "$tmp" "$FLAKE_PATH"
  else
    rm -f "$tmp"
    fail "aborted before writing flake"
  fi
  rm -f "$tmp"
}

main() {
  say "ORGMOS installer"
  require_nixos

  if [ ! -f "$HARDWARE_PATH" ]; then
    fail "missing $HARDWARE_PATH; run nixos-generate-config first"
  fi

  choose_profile
  choose_hostname

  say ""
  say "Install summary:"
  say "  Repository: $REPO_URL"
  say "  NixOS dir:  $NIXOS_DIR"
  say "  Hardware:   $HARDWARE_PATH"
  say "  Profile:    $SELECTED_PROFILE"
  say "  Hostname:   $SELECTED_HOSTNAME"
  say ""

  write_flake

  say ""
  say "Next command: sudo nixos-rebuild switch --flake $NIXOS_DIR#default"
  if confirm "Run rebuild now?"; then
    sudo nixos-rebuild switch --flake "$NIXOS_DIR#default"
  else
    say "Skipped rebuild. Run manually when ready:"
    say "  sudo nixos-rebuild switch --flake $NIXOS_DIR#default"
  fi
}

main "$@"
```

- [ ] **Step 2: Mark script executable**

```bash
chmod +x install.sh
```

- [ ] **Step 3: Run shell syntax check**

Run:

```bash
bash -n install.sh
```

Expected: command exits 0.

- [ ] **Step 4: Run installer in test mode against temp NixOS dir**

Run:

```bash
tmpdir=$(mktemp -d)
touch "$tmpdir/hardware-configuration.nix"
printf '1\ntesthost\ny\nn\n' | ORGMOS_NIXOS_DIR="$tmpdir" ORGMOS_REPO_URL="path:/home/osmarg/Hobby/nixos" bash install.sh
cat "$tmpdir/flake.nix"
```

Expected generated flake contains:

```nix
inputs.orgmos.url = "path:/home/osmarg/Hobby/nixos";
profile = "hyprland";
hostName = "testhost";
hardware = ./hardware-configuration.nix;
```

- [ ] **Step 5: Run non-NixOS guard check only if current environment is not host NixOS**

If `/etc/NIXOS` is absent in the execution environment, run:

```bash
set +e
ORGMOS_NIXOS_DIR="$(mktemp -d)" bash install.sh </dev/null 2>&1 | grep "this installer must run on NixOS"
status=$?
set -e
test "$status" -eq 0
```

Expected: command exits 0. If `/etc/NIXOS` exists, skip this guard check because host is NixOS.

- [ ] **Step 6: Commit**

```bash
git add install.sh
git commit -m "feat(nixos): add ORGMOS installer"
```

---

### Task 4: Full verification

**Files:**
- Verify repository state only.

- [ ] **Step 1: Format all changed Nix files**

Run:

```bash
nix fmt flake.nix nixos/general.nix nixos/hosts/general/plymouth.nix
```

Expected: command exits 0.

- [ ] **Step 2: Check shell script syntax**

Run:

```bash
bash -n install.sh
```

Expected: command exits 0.

- [ ] **Step 3: Evaluate existing host output**

Run:

```bash
nix eval .#nixosConfigurations.orgm-hyprland.config.networking.hostName
```

Expected output:

```text
"orgm"
```

- [ ] **Step 4: Evaluate generic profile output**

Run:

```bash
nix eval .#nixosConfigurations.hyprland.config.networking.hostName
```

Expected output:

```text
"nixos"
```

- [ ] **Step 5: Evaluate generated-flake model**

Run:

```bash
tmpdir=$(mktemp -d)
cat > "$tmpdir/flake.nix" <<'EOF'
{
  inputs.orgmos.url = "path:/home/osmarg/Hobby/nixos";

  outputs = { self, orgmos, ... }: {
    nixosConfigurations.default = orgmos.lib.mkGeneralHost {
      hardware = orgmos + "/nixos/hosts/generic/hardware-configuration.nix";
      profile = "hyprland";
      hostName = "testhost";
    };
  };
}
EOF
nix eval "$tmpdir#nixosConfigurations.default.config.networking.hostName"
```

Expected output:

```text
"testhost"
```

- [ ] **Step 6: Run Go tests to ensure unrelated repo tooling still passes**

Run:

```bash
go test ./...
```

Expected: all packages pass.

- [ ] **Step 7: Review final diff**

Run:

```bash
git diff --stat HEAD~3..HEAD
git status --short
```

Expected: only intentional files changed and no unstaged tracked changes.

- [ ] **Step 8: Commit any verification-only fixes if needed**

If formatting or syntax checks changed files, run:

```bash
git add flake.nix nixos/general.nix nixos/hosts/general/plymouth.nix install.sh
git commit -m "fix(nixos): polish ORGMOS installer"
```

If no files changed, do not create an empty commit.

---

## Self-Review

- Spec coverage: installer entrypoint, local hardware use, profile selection, hostname prompt, backup, explicit rebuild confirmation, general Plymouth, existing outputs unchanged, and eval-only outputs preserved are all covered.
- Placeholder scan: no TBD/TODO/fill-in placeholders remain.
- Type consistency: `mkGeneralHost`, `hardware`, `profile`, `hostName`, `extraModules`, and profile names match across Nix API, generated flake, and verification commands.
