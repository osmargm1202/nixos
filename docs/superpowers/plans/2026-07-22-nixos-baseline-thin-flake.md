# NixOS Baseline and Thin Flake Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve all 40 current NixOS outputs while replacing stale text-based output tests, moving configuration data to an explicit inventory, and assembling every system through one constructor outside `flake.nix`.

**Architecture:** `configurations.nix` becomes the explicit registry of profiles, concrete configurations, and hostname aliases. `lib/mk-system.nix` owns one role-aware `mkSystem` constructor plus compatibility wrappers used by the installer. `flake.nix` retains inputs and output exposure, then maps inventory entries through the constructor without filesystem discovery.

**Tech Stack:** Nix flakes, NixOS module system, Home Manager as a NixOS module, Bash characterization tests, `nix eval`, `jq`, `nixfmt-rfc-style`, `statix`, and `deadnix`.

## Global Constraints

- Implement in a clean worktree created with `superpowers:using-git-worktrees`; the primary working tree contains unrelated edits.
- Preserve these 40 output names exactly: `cinnamon`, `ero-i3`, `ero-labwc`, `ero-server`, `ero-terminal`, `gnome`, `hyprland`, `i3`, `jarq`, `jarq-hyprland`, `jarq-hyprlandqs-caelestia`, `jarq-i3`, `jarq-labwc`, `jarq-mate`, `jarq-terminal`, `jarq-xfce`, `labwc`, `lenovo`, `lenovo-gnome`, `lenovo-hyprland`, `lenovo-hyprlandqs-caelestia`, `lenovo-i3`, `lenovo-labwc`, `lenovo-mate`, `lenovo-terminal`, `lenovo-xfce`, `mate`, `orgm`, `orgm-cinnamon`, `orgm-gnome`, `orgm-hyprland`, `orgm-hyprlandqs-caelestia`, `orgm-i3`, `orgm-labwc`, `orgm-mate`, `orgm-terminal`, `orgm-xfce`, `server`, `terminal`, and `xfce`.
- Preserve aliases exactly: `orgm -> orgm-hyprland`, `lenovo -> lenovo-hyprland`, and `jarq -> jarq-hyprland`.
- Preserve current module order, hostnames, profile names, usernames, hardware paths, host extras, and default hardware behavior.
- Keep Home Manager integrated through current NixOS modules; this plan does not create `homeConfigurations`.
- Keep every import and configuration entry explicit. Do not use `builtins.readDir`, recursive import helpers, or directory-driven output discovery.
- Do not change input declarations, input revisions, `flake.lock`, package definitions, service enablement, ports, secrets, or runtime policy.
- Keep installer compatibility exports: `mkGeneralHost`, `mkServerHost`, `mkMinimalHost`, and `mkTerminalHost`.
- Add `mkSystem`, `mkHost`, and `mkProfile` to `flake.lib`; removing exported helpers requires a later approved change.
- Use `nix eval` for behavioral assertions. Source-text checks are allowed only for structural boundaries such as “the matrix is not in `flake.nix`.”
- Commit only files named by each task. Never stage unrelated working-tree changes.

---

## File Map

- `tests/fixtures/nixos-configurations.txt` — canonical sorted list of the 40 public outputs.
- `tests/flake-outputs.bats.sh` — evaluated public-output and alias compatibility checks.
- `configurations.nix` — explicit profile registry, 37 concrete configuration specs, and three aliases.
- `tests/configuration-inventory.bats.sh` — inventory schema and public-name checks independent of flake wiring.
- `lib/mk-system.nix` — single constructor and compatibility wrappers.
- `tests/mk-system-library.bats.sh` — exported constructor contract and repaired `mkGeneralHost` evaluation.
- `flake.nix` — thin output wiring; no constructor implementation or configuration matrix.
- `tests/flake-architecture.bats.sh` — structural checks for explicit inventory and no autodiscovery.
- `tests/i3-profile.bats.sh` — evaluated i3 output checks instead of source-text assumptions.

---

### Task 1: Establish Evaluated Output Baseline

**Files:**
- Create: `tests/fixtures/nixos-configurations.txt`
- Modify: `tests/flake-outputs.bats.sh`

**Interfaces:**
- Consumes: current `.#nixosConfigurations` output set.
- Produces: sorted output-name fixture and evaluated alias contract used by every later task.

- [ ] **Step 1: Confirm the stale test fails for the wrong historical expectation**

Run:

```bash
bash tests/flake-outputs.bats.sh
```

Expected: exit non-zero with `FAIL: jarq-gnome output must exist`. This proves the current test describes removed outputs rather than current behavior.

- [ ] **Step 2: Create the canonical output fixture**

Create `tests/fixtures/nixos-configurations.txt` with exactly:

```text
cinnamon
ero-i3
ero-labwc
ero-server
ero-terminal
gnome
hyprland
i3
jarq
jarq-hyprland
jarq-hyprlandqs-caelestia
jarq-i3
jarq-labwc
jarq-mate
jarq-terminal
jarq-xfce
labwc
lenovo
lenovo-gnome
lenovo-hyprland
lenovo-hyprlandqs-caelestia
lenovo-i3
lenovo-labwc
lenovo-mate
lenovo-terminal
lenovo-xfce
mate
orgm
orgm-cinnamon
orgm-gnome
orgm-hyprland
orgm-hyprlandqs-caelestia
orgm-i3
orgm-labwc
orgm-mate
orgm-terminal
orgm-xfce
server
terminal
xfce
```

- [ ] **Step 3: Replace source-text output assertions with evaluated assertions**

Replace `tests/flake-outputs.bats.sh` completely with:

```bash
#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED="$REPO_DIR/tests/fixtures/nixos-configurations.txt"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_eq() {
  local actual="$1" expected="$2" name="$3"
  [[ "$actual" == "$expected" ]] || fail "$name: expected '$expected', got '$actual'"
}

actual_names="$(
  nix eval --json "$REPO_DIR#nixosConfigurations" --apply builtins.attrNames \
    | jq -r '.[]'
)"

diff -u "$EXPECTED" <(printf '%s\n' "$actual_names") \
  || fail 'evaluated nixosConfigurations differ from the public baseline'

if grep -qx 'TEMPLATE' <<<"$actual_names"; then
  fail 'host templates must never be exported as nixosConfigurations'
fi

for mapping in \
  'orgm orgm-hyprland' \
  'lenovo lenovo-hyprland' \
  'jarq jarq-hyprland'
do
  read -r alias target <<<"$mapping"
  alias_drv="$(nix eval --raw "$REPO_DIR#nixosConfigurations.$alias.config.system.build.toplevel.drvPath")"
  target_drv="$(nix eval --raw "$REPO_DIR#nixosConfigurations.$target.config.system.build.toplevel.drvPath")"
  assert_eq "$alias_drv" "$target_drv" "$alias must remain an alias of $target"
done

assert_eq \
  "$(nix eval --raw "$REPO_DIR#nixosConfigurations.ero-server.config.networking.hostName")" \
  'ero' \
  'ero-server hostname'
assert_eq \
  "$(nix eval --raw "$REPO_DIR#nixosConfigurations.jarq-hyprland.config.system.nixos.label")" \
  'hyprland' \
  'jarq-hyprland profile label'
assert_eq \
  "$(nix eval --raw "$REPO_DIR#nixosConfigurations.cinnamon.config.system.nixos.label")" \
  'cinnamon' \
  'generic cinnamon profile label'

printf 'PASS: evaluated flake output baseline\n'
```

- [ ] **Step 4: Run the corrected baseline test**

Run:

```bash
bash tests/flake-outputs.bats.sh
```

Expected: `PASS: evaluated flake output baseline` and exit zero.

- [ ] **Step 5: Commit the baseline**

```bash
git add tests/fixtures/nixos-configurations.txt tests/flake-outputs.bats.sh
git commit -m "test: capture NixOS output baseline"
```

---

### Task 2: Add Explicit Configuration Inventory

**Files:**
- Create: `configurations.nix`
- Create: `tests/configuration-inventory.bats.sh`
- Test: `tests/fixtures/nixos-configurations.txt`

**Interfaces:**
- Consumes: existing paths under `nixos/hosts`, `nixos/profiles`, `nixos/hardware`, and `nixos/gaming`.
- Produces: attrset `{ profiles, configurations, aliases }`; every `configurations.<name>` is a normalized spec accepted by `mkSystem` in Task 3.
- Spec fields: `role :: "desktop" | "terminal" | "server"`, `hostName :: string`, `hardware :: path`, `userName :: string`, `extraModules :: list path`, and desktop-only `profile :: path`, `profileName :: string`.

- [ ] **Step 1: Write the inventory test before the inventory exists**

Create `tests/configuration-inventory.bats.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INVENTORY="$ROOT/configurations.nix"
EXPECTED="$ROOT/tests/fixtures/nixos-configurations.txt"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

inventory_json="$(nix eval --json --file "$INVENTORY")"
actual_names="$(
  jq -r '[(.configurations | keys[]), (.aliases | keys[])] | sort | .[]' \
    <<<"$inventory_json"
)"

diff -u "$EXPECTED" <(printf '%s\n' "$actual_names") \
  || fail 'inventory names differ from public output baseline'

jq -e '
  .aliases == {
    jarq: "jarq-hyprland",
    lenovo: "lenovo-hyprland",
    orgm: "orgm-hyprland"
  }
' <<<"$inventory_json" >/dev/null \
  || fail 'alias map changed'

jq -e '
  all(.configurations[];
    (.role == "desktop" or .role == "terminal" or .role == "server")
    and (.hostName | type == "string")
    and (.hardware | type == "string")
    and (.userName | type == "string")
    and (.extraModules | type == "array")
    and (if .role == "desktop"
         then (.profile | type == "string") and (.profileName | type == "string")
         else (has("profile") | not) and (has("profileName") | not)
         end)
  )
' <<<"$inventory_json" >/dev/null \
  || fail 'configuration specs do not match normalized schema'

[[ "$(jq -r '.configurations["ero-server"].hostName' <<<"$inventory_json")" == 'ero' ]] \
  || fail 'ero-server hostname changed'
[[ "$(jq -r '.configurations["jarq-hyprland"].userName' <<<"$inventory_json")" == 'jarq' ]] \
  || fail 'jarq user changed'
[[ "$(jq -r '.configurations["orgm-hyprland"].extraModules | length' <<<"$inventory_json")" == '3' ]] \
  || fail 'orgm host extras changed'

printf 'PASS: explicit configuration inventory\n'
```

- [ ] **Step 2: Run the inventory test and verify missing-file failure**

Run:

```bash
bash tests/configuration-inventory.bats.sh
```

Expected: exit non-zero because `configurations.nix` does not exist.

- [ ] **Step 3: Create the normalized explicit inventory**

Create `configurations.nix`:

```nix
let
  genericHardware = ./nixos/hosts/generic/hardware-configuration.nix;

  profiles = {
    cinnamon = ./nixos/profiles/cinnamon.nix;
    gnome = ./nixos/profiles/gnome.nix;
    hyprland = ./nixos/profiles/hyprland.nix;
    hyprlandqs-caelestia = ./nixos/profiles/hyprlandqs-caelestia.nix;
    i3 = ./nixos/profiles/i3.nix;
    labwc = ./nixos/profiles/labwc.nix;
    mate = ./nixos/profiles/mate.nix;
    xfce = ./nixos/profiles/xfce.nix;
  };

  desktop =
    {
      profileName,
      hostName ? "nixos",
      hardware ? genericHardware,
      userName ? "osmarg",
      extraModules ? [ ],
    }:
    {
      role = "desktop";
      inherit
        hostName
        hardware
        userName
        extraModules
        profileName
        ;
      profile = profiles.${profileName};
    };

  terminal =
    {
      hostName ? "nixos",
      hardware ? genericHardware,
      userName ? "osmarg",
      extraModules ? [ ],
    }:
    {
      role = "terminal";
      inherit
        hostName
        hardware
        userName
        extraModules
        ;
    };

  server =
    {
      hostName ? "nixos",
      hardware ? genericHardware,
      userName ? "osmarg",
      extraModules ? [ ],
    }:
    {
      role = "server";
      inherit
        hostName
        hardware
        userName
        extraModules
        ;
    };

  jarqExtra = [
    ./nixos/hardware/gpu/intel.nix
    ./nixos/hosts/jarq/default.nix
  ];
  orgmExtra = [
    ./nixos/hardware/gpu/nvidia.nix
    ./nixos/hosts/orgm/ms-7d43.nix
    ./nixos/gaming/default.nix
  ];
  lenovoExtra = [
    ./nixos/hosts/lenovo/p14s-gen2i.nix
    ./nixos/hosts/lenovo/audio.nix
    ./nixos/gaming/steam.nix
    ./nixos/gaming/emulators.nix
  ];
in
{
  inherit profiles;

  aliases = {
    orgm = "orgm-hyprland";
    lenovo = "lenovo-hyprland";
    jarq = "jarq-hyprland";
  };

  configurations = {
    cinnamon = desktop { profileName = "cinnamon"; };
    gnome = desktop { profileName = "gnome"; };
    hyprland = desktop { profileName = "hyprland"; };
    i3 = desktop { profileName = "i3"; };
    labwc = desktop { profileName = "labwc"; };
    mate = desktop { profileName = "mate"; };
    xfce = desktop { profileName = "xfce"; };
    terminal = terminal { };
    server = server { };

    jarq-terminal = terminal {
      hostName = "jarq";
      hardware = ./nixos/hosts/jarq/hardware-configuration.nix;
      userName = "jarq";
    };
    jarq-xfce = desktop {
      hostName = "jarq";
      hardware = ./nixos/hosts/jarq/hardware-configuration.nix;
      profileName = "xfce";
      userName = "jarq";
      extraModules = jarqExtra;
    };
    jarq-mate = desktop {
      hostName = "jarq";
      hardware = ./nixos/hosts/jarq/hardware-configuration.nix;
      profileName = "mate";
      userName = "jarq";
      extraModules = jarqExtra;
    };
    jarq-i3 = desktop {
      hostName = "jarq";
      hardware = ./nixos/hosts/jarq/hardware-configuration.nix;
      profileName = "i3";
      userName = "jarq";
      extraModules = jarqExtra;
    };
    jarq-labwc = desktop {
      hostName = "jarq";
      hardware = ./nixos/hosts/jarq/hardware-configuration.nix;
      profileName = "labwc";
      userName = "jarq";
      extraModules = jarqExtra;
    };
    jarq-hyprland = desktop {
      hostName = "jarq";
      hardware = ./nixos/hosts/jarq/hardware-configuration.nix;
      profileName = "hyprland";
      userName = "jarq";
      extraModules = jarqExtra;
    };
    jarq-hyprlandqs-caelestia = desktop {
      hostName = "jarq";
      hardware = ./nixos/hosts/jarq/hardware-configuration.nix;
      profileName = "hyprlandqs-caelestia";
      userName = "jarq";
      extraModules = jarqExtra;
    };

    orgm-terminal = terminal {
      hostName = "orgm";
      hardware = ./nixos/hosts/orgm/hardware-configuration.nix;
    };
    orgm-gnome = desktop {
      hostName = "orgm";
      hardware = ./nixos/hosts/orgm/hardware-configuration.nix;
      profileName = "gnome";
      extraModules = orgmExtra;
    };
    orgm-cinnamon = desktop {
      hostName = "orgm";
      hardware = ./nixos/hosts/orgm/hardware-configuration.nix;
      profileName = "cinnamon";
      extraModules = orgmExtra;
    };
    orgm-hyprland = desktop {
      hostName = "orgm";
      hardware = ./nixos/hosts/orgm/hardware-configuration.nix;
      profileName = "hyprland";
      extraModules = orgmExtra;
    };
    orgm-hyprlandqs-caelestia = desktop {
      hostName = "orgm";
      hardware = ./nixos/hosts/orgm/hardware-configuration.nix;
      profileName = "hyprlandqs-caelestia";
      extraModules = orgmExtra;
    };
    orgm-labwc = desktop {
      hostName = "orgm";
      hardware = ./nixos/hosts/orgm/hardware-configuration.nix;
      profileName = "labwc";
      extraModules = orgmExtra;
    };
    orgm-i3 = desktop {
      hostName = "orgm";
      hardware = ./nixos/hosts/orgm/hardware-configuration.nix;
      profileName = "i3";
      extraModules = orgmExtra;
    };
    orgm-xfce = desktop {
      hostName = "orgm";
      hardware = ./nixos/hosts/orgm/hardware-configuration.nix;
      profileName = "xfce";
      extraModules = orgmExtra;
    };
    orgm-mate = desktop {
      hostName = "orgm";
      hardware = ./nixos/hosts/orgm/hardware-configuration.nix;
      profileName = "mate";
      extraModules = orgmExtra;
    };

    ero-terminal = terminal {
      hostName = "ero";
      hardware = ./nixos/hosts/ero/hardware-configuration.nix;
    };
    ero-labwc = desktop {
      hostName = "ero";
      hardware = ./nixos/hosts/ero/hardware-configuration.nix;
      profileName = "labwc";
      extraModules = [ ./nixos/hardware/gpu/intel.nix ];
    };
    ero-i3 = desktop {
      hostName = "ero";
      hardware = ./nixos/hosts/ero/hardware-configuration.nix;
      profileName = "i3";
      extraModules = [ ./nixos/hardware/gpu/intel.nix ];
    };
    ero-server = server {
      hostName = "ero";
      hardware = ./nixos/hosts/ero/hardware-configuration.nix;
    };

    lenovo-terminal = terminal {
      hostName = "lenovo";
      hardware = ./nixos/hosts/lenovo/hardware-configuration.nix;
    };
    lenovo-labwc = desktop {
      hostName = "lenovo";
      hardware = ./nixos/hosts/lenovo/hardware-configuration.nix;
      profileName = "labwc";
      extraModules = lenovoExtra;
    };
    lenovo-gnome = desktop {
      hostName = "lenovo";
      hardware = ./nixos/hosts/lenovo/hardware-configuration.nix;
      profileName = "gnome";
      extraModules = lenovoExtra;
    };
    lenovo-hyprland = desktop {
      hostName = "lenovo";
      hardware = ./nixos/hosts/lenovo/hardware-configuration.nix;
      profileName = "hyprland";
      extraModules = lenovoExtra;
    };
    lenovo-hyprlandqs-caelestia = desktop {
      hostName = "lenovo";
      hardware = ./nixos/hosts/lenovo/hardware-configuration.nix;
      profileName = "hyprlandqs-caelestia";
      extraModules = lenovoExtra;
    };
    lenovo-i3 = desktop {
      hostName = "lenovo";
      hardware = ./nixos/hosts/lenovo/hardware-configuration.nix;
      profileName = "i3";
      extraModules = lenovoExtra;
    };
    lenovo-xfce = desktop {
      hostName = "lenovo";
      hardware = ./nixos/hosts/lenovo/hardware-configuration.nix;
      profileName = "xfce";
      extraModules = lenovoExtra;
    };
    lenovo-mate = desktop {
      hostName = "lenovo";
      hardware = ./nixos/hosts/lenovo/hardware-configuration.nix;
      profileName = "mate";
      extraModules = lenovoExtra;
    };
  };
}
```

- [ ] **Step 4: Format and run the inventory test**

Run:

```bash
nix fmt -- --check configurations.nix || nix fmt configurations.nix
bash tests/configuration-inventory.bats.sh
```

Expected: formatter exits zero after any required formatting; test prints `PASS: explicit configuration inventory`.

- [ ] **Step 5: Confirm inventory has 37 concrete specs and 3 aliases**

Run:

```bash
nix eval --json --file configurations.nix \
  | jq -e '(.configurations | length) == 37 and (.aliases | length) == 3'
```

Expected: `true` and exit zero.

- [ ] **Step 6: Commit the inventory**

```bash
git add configurations.nix tests/configuration-inventory.bats.sh
git commit -m "refactor: add explicit NixOS configuration inventory"
```

---

### Task 3: Extract One System Constructor

**Files:**
- Create: `lib/mk-system.nix`
- Create: `tests/mk-system-library.bats.sh`
- Modify: `flake.nix:79-217`
- Test: `tests/install-installer.bats.sh`
- Test: `tests/flake-outputs.bats.sh`

**Interfaces:**
- Consumes: `inputs`, `nixpkgs`, `system`, `defaultHardware`, and `configurations.nix.profiles`.
- Produces: `mkSystem spec -> NixOS configuration` and compatibility wrappers `mkHost`, `mkProfile`, `mkGeneralHost`, `mkServerHost`, `mkMinimalHost`, `mkTerminalHost`.
- `mkSystem` accepts the normalized specs defined in Task 2.

- [ ] **Step 1: Write the exported-library contract test**

Create `tests/mk-system-library.bats.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

expected_exports='["mkGeneralHost","mkHost","mkMinimalHost","mkProfile","mkServerHost","mkSystem","mkTerminalHost"]'
actual_exports="$(nix eval --json "$ROOT#lib" --apply builtins.attrNames)"
[[ "$actual_exports" == "$expected_exports" ]] \
  || fail "unexpected flake.lib exports: $actual_exports"

general_host="$(
  nix eval --impure --raw --expr "
    let
      flake = builtins.getFlake (toString $ROOT);
    in
    (flake.lib.mkGeneralHost {
      hardware = $ROOT/nixos/hosts/generic/hardware-configuration.nix;
      profile = \"i3\";
      hostName = \"compat-general\";
    }).config.networking.hostName
  "
)"
[[ "$general_host" == 'compat-general' ]] \
  || fail "mkGeneralHost did not evaluate: $general_host"

printf 'PASS: unified system constructor exports\n'
```

- [ ] **Step 2: Run the contract test and verify it fails**

Run:

```bash
bash tests/mk-system-library.bats.sh
```

Expected: exit non-zero because current `flake.lib` lacks `mkSystem`, `mkHost`, and `mkProfile`; evaluating current `mkGeneralHost` would also reference missing `nixos/general.nix`.

- [ ] **Step 3: Create the unified constructor and wrappers**

Create `lib/mk-system.nix`:

```nix
{
  inputs,
  nixpkgs,
  system,
  defaultHardware,
  profiles,
}:

let
  inherit (nixpkgs) lib;

  getProfile =
    profileName:
    profiles.${profileName}
      or (throw "Unknown ORGMOS profile '${profileName}'. Valid profiles: ${builtins.concatStringsSep ", " (builtins.attrNames profiles)}");

  mkSystem =
    {
      hostName,
      role,
      hardware ? defaultHardware,
      profile ? null,
      profileName ? null,
      extraModules ? [ ],
      userName ? "osmarg",
    }:
    let
      effectiveProfileName =
        if profileName != null then profileName else if role == "terminal" then "terminal" else null;
      roleModules =
        if role == "desktop" then
          [
            ../nixos/common.nix
            ../nixos/ai/default.nix
            hardware
            (if profile != null then profile else throw "Desktop role requires a profile module")
            { networking.hostName = hostName; }
          ]
        else if role == "server" then
          [
            hardware
            ../nixos/server.nix
            { networking.hostName = hostName; }
          ]
        else if role == "terminal" then
          [
            hardware
            ../nixos/terminal.nix
            { networking.hostName = hostName; }
          ]
        else
          throw "Unknown ORGMOS role '${role}'. Valid roles: desktop, server, terminal";
    in
    lib.nixosSystem {
      specialArgs =
        {
          inherit inputs userName;
        }
        // lib.optionalAttrs (effectiveProfileName != null) {
          profileName = effectiveProfileName;
        };
      modules = [
        { nixpkgs.hostPlatform = system; }
        ../nixos/binary-cache.nix
      ]
      ++ roleModules
      ++ extraModules;
    };

  mkHost =
    args:
    mkSystem (
      args
      // {
        role = "desktop";
      }
    );

  mkProfile =
    args:
    mkSystem (
      args
      // {
        role = "desktop";
        hardware = defaultHardware;
        hostName = args.hostName or "nixos";
      }
    );

  mkGeneralHost =
    {
      hardware,
      profile,
      hostName,
      extraModules ? [ ],
      userName ? "osmarg",
    }:
    mkSystem {
      role = "desktop";
      inherit
        hardware
        hostName
        extraModules
        userName
        ;
      profile = getProfile profile;
      profileName = profile;
    };

  mkServerHost =
    args:
    mkSystem (
      args
      // {
        role = "server";
      }
    );

  mkMinimalHost =
    args:
    mkSystem (
      args
      // {
        role = "terminal";
      }
    );

  mkTerminalHost = mkMinimalHost;
in
{
  inherit
    mkSystem
    mkHost
    mkProfile
    mkGeneralHost
    mkServerHost
    mkMinimalHost
    mkTerminalHost
    ;
}
```

- [ ] **Step 4: Replace constructor definitions in `flake.nix` with the library import**

Keep existing package setup and `defaultHardware`. Remove the local `profiles`, `getProfile`, `mkHost`, `mkProfile`, `mkGeneralHost`, `mkServerHost`, and `mkMinimalHost` definitions. Insert after `defaultHardware`:

```nix
      configurationInventory = import ./configurations.nix;
      systemBuilders = import ./lib/mk-system.nix {
        inherit
          inputs
          nixpkgs
          system
          defaultHardware
          ;
        profiles = configurationInventory.profiles;
      };
      inherit (systemBuilders)
        mkHost
        mkProfile
        mkServerHost
        mkMinimalHost
        ;
```

Replace the current `lib = { ... };` output with:

```nix
      lib = systemBuilders;
```

The existing `nixosConfigurations` matrix remains unchanged in this task and continues calling `mkHost`, `mkProfile`, `mkServerHost`, and `mkMinimalHost` from `systemBuilders`.

- [ ] **Step 5: Format changed Nix files**

Run:

```bash
nix fmt -- --check flake.nix lib/mk-system.nix || nix fmt flake.nix lib/mk-system.nix
```

Expected: both files conform to `nixfmt-rfc-style`.

- [ ] **Step 6: Run constructor and compatibility tests**

Run:

```bash
bash tests/mk-system-library.bats.sh
bash tests/flake-outputs.bats.sh
bash tests/install-installer.bats.sh
```

Expected:

- `PASS: unified system constructor exports`
- `PASS: evaluated flake output baseline`
- installer tests exit zero and generated flakes still reference working `orgmos.lib.mkGeneralHost`, `mkServerHost`, and `mkTerminalHost`.

- [ ] **Step 7: Confirm no input lock change**

Run:

```bash
git diff --exit-code -- flake.lock
```

Expected: no output and exit zero.

- [ ] **Step 8: Commit the constructor extraction**

```bash
git add lib/mk-system.nix tests/mk-system-library.bats.sh flake.nix
git commit -m "refactor: extract unified NixOS system constructor"
```

---

### Task 4: Wire Inventory and Finish Thin Flake

**Files:**
- Create: `tests/flake-architecture.bats.sh`
- Modify: `flake.nix:267-426`
- Modify: `tests/i3-profile.bats.sh:12-18`
- Test: `tests/flake-outputs.bats.sh`
- Test: `tests/configuration-inventory.bats.sh`
- Test: `tests/mk-system-library.bats.sh`

**Interfaces:**
- Consumes: `configurationInventory.configurations`, `configurationInventory.aliases`, and `systemBuilders.mkSystem`.
- Produces: `nixosConfigurations = builtConfigurations // configurationAliases` with the same 40 public outputs.

- [ ] **Step 1: Write the thin-flake structural test**

Create `tests/flake-architecture.bats.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLAKE="$ROOT/flake.nix"
INVENTORY="$ROOT/configurations.nix"
BUILDER="$ROOT/lib/mk-system.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local needle="$1" file="$2" name="$3"
  grep -Fq -- "$needle" "$file" || fail "$name"
}

assert_not_contains() {
  local needle="$1" file="$2" name="$3"
  if grep -Fq -- "$needle" "$file"; then
    fail "$name"
  fi
}

assert_contains \
  'configurationInventory = import ./configurations.nix;' \
  "$FLAKE" \
  'flake must load explicit configuration inventory'
assert_contains \
  'builtConfigurations =' \
  "$FLAKE" \
  'flake must define built configurations'
assert_contains \
  'nixpkgs.lib.mapAttrs (_: systemBuilders.mkSystem) configurationInventory.configurations;' \
  "$FLAKE" \
  'flake must map inventory specs through mkSystem'
assert_contains \
  'nixosConfigurations = builtConfigurations // configurationAliases;' \
  "$FLAKE" \
  'flake must expose built configurations plus explicit aliases'

for old_matrix_entry in \
  'orgm-hyprland = mkHost' \
  'lenovo-hyprland = mkHost' \
  'jarq-hyprland = mkHost' \
  'ero-server ='
do
  assert_not_contains "$old_matrix_entry" "$FLAKE" "matrix entry remains in flake: $old_matrix_entry"
done

for file in "$FLAKE" "$INVENTORY" "$BUILDER"; do
  assert_not_contains 'builtins.readDir' "$file" "directory discovery forbidden in $file"
  assert_not_contains 'importAll' "$file" "recursive imports forbidden in $file"
done

assert_not_contains 'nixos/general.nix' "$FLAKE" 'broken general module path remains in flake'
assert_not_contains 'nixos/general.nix' "$BUILDER" 'broken general module path remains in builder'

printf 'PASS: thin flake architecture\n'
```

- [ ] **Step 2: Run the structural test and verify matrix failure**

Run:

```bash
bash tests/flake-architecture.bats.sh
```

Expected: exit non-zero because the output matrix still resides in `flake.nix` and `builtConfigurations` is absent.

- [ ] **Step 3: Build concrete configurations and aliases from inventory**

Inside the top-level `let` in `flake.nix`, immediately after `systemBuilders`, add:

```nix
      builtConfigurations =
        nixpkgs.lib.mapAttrs (_: systemBuilders.mkSystem) configurationInventory.configurations;
      configurationAliases = nixpkgs.lib.mapAttrs (
        _: target: builtConfigurations.${target}
      ) configurationInventory.aliases;
```

Remove the complete `nixosConfigurations = let configs = { ... }; in configs // { ... };` matrix and replace it with:

```nix
      nixosConfigurations = builtConfigurations // configurationAliases;
```

Do not change inputs, packages, formatter, development shell, `nixosModules`, or other outputs.

- [ ] **Step 4: Replace i3 source-text matrix checks with evaluated labels**

In `tests/i3-profile.bats.sh`, replace lines that grep `flake.nix` for `${host}-i3 = mkHost` and `profile = ./nixos/profiles/i3.nix` with:

```bash
for host in orgm lenovo ero jarq; do
  label="$(nix eval --raw ".#nixosConfigurations.${host}-i3.config.system.nixos.label" 2>/dev/null)"
  [[ "$label" == 'i3' ]] || fail "${host}-i3 does not evaluate the i3 profile"
done
```

Keep the remaining evaluated Xserver, startx, autologin, and profile behavior checks unchanged.

- [ ] **Step 5: Format and run focused tests**

Run:

```bash
nix fmt -- --check flake.nix configurations.nix lib/mk-system.nix \
  || nix fmt flake.nix configurations.nix lib/mk-system.nix
bash tests/flake-architecture.bats.sh
bash tests/configuration-inventory.bats.sh
bash tests/mk-system-library.bats.sh
bash tests/flake-outputs.bats.sh
bash tests/i3-profile.bats.sh
bash tests/install-installer.bats.sh
bash tests/binary-cache.bats.sh
```

Expected: every command exits zero; architecture test prints `PASS: thin flake architecture` and output test prints `PASS: evaluated flake output baseline`.

- [ ] **Step 6: Evaluate all 40 toplevel derivations**

Run:

```bash
while IFS= read -r output; do
  printf 'evaluating %s\n' "$output"
  nix eval --raw ".#nixosConfigurations.${output}.config.system.build.toplevel.drvPath" >/dev/null
done < tests/fixtures/nixos-configurations.txt
```

Expected: 40 `evaluating <name>` lines and exit zero. This evaluates derivations; it does not build or activate systems.

- [ ] **Step 7: Run Nix quality and flake checks**

Run:

```bash
statix check flake.nix configurations.nix lib/mk-system.nix
deadnix --fail flake.nix configurations.nix lib/mk-system.nix
timeout 10m nix flake check --no-build -L
```

Expected: all commands exit zero. `nix flake check` may be quiet but must complete before the 10-minute timeout.

- [ ] **Step 8: Verify lockfile and public output stability**

Run:

```bash
git diff --exit-code 4b9f97e5c1eb8537d9aee2f468e0dca2dfb6066a -- flake.lock
nix eval --json .#nixosConfigurations --apply builtins.attrNames \
  | jq -r '.[]' \
  | diff -u tests/fixtures/nixos-configurations.txt -
```

Expected: no diff and exit zero for both commands.

- [ ] **Step 9: Commit thin-flake wiring**

```bash
git add flake.nix tests/flake-architecture.bats.sh tests/i3-profile.bats.sh
git commit -m "refactor: assemble NixOS outputs from inventory"
```

- [ ] **Step 10: Record final verification evidence**

Run:

```bash
git status --short
git log --oneline -4
```

Expected: worktree contains no task-created uncommitted files; four focused commits appear for baseline, inventory, constructor, and thin-flake wiring. Any unrelated pre-existing changes mean the worktree isolation step was not followed and must be corrected before integration.

---

## Completion Boundary

This plan completes only design phases 0 and 1:

- Reliable evaluated baseline.
- Explicit configuration inventory.
- Unified constructor with working installer compatibility wrappers.
- Thin `flake.nix` with all 40 outputs preserved.

It does not move host files, split core modules, create role/session directories, separate Home Manager implementation, change inputs, or enable operational improvements. Those require separate plans after this phase passes review.
