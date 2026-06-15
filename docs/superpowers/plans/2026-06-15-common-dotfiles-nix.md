# Common Dotfiles Nix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `orgm-dot` sync with a shared NixOS/Home Manager module that clones/updates the dotfiles repo and links every `dotfiles.json` managed path live.

**Architecture:** Add `nixos/common-dotfiles.nix` with path lists copied from `dotfiles.json`, a `orgm-dotfiles-repo.service` oneshot clone/update service, and Home Manager out-of-store symlinks. Import it from `nixos/common.nix` and remove `orgmDot` from installed system packages.

**Tech Stack:** NixOS modules, Home Manager, systemd, git, Python verification scripts, Nix flake eval.

---

## File Structure

- Create: `scripts/check-common-dotfiles.py`
  - Compares `/home/osmarg/Hobby/dotfiles/config/dotfiles.json` with `nixos/common-dotfiles.nix`.
  - Verifies shared paths, host paths, local-only paths/patterns/types, and local defaults exist in Nix.
- Create: `scripts/check-orgm-dot-not-installed.sh`
  - Fails if `orgmDot` remains in `environment.systemPackages` of `nixos/common.nix` or `nixos/profiles/hyprland.nix`.
- Create: `nixos/common-dotfiles.nix`
  - Defines repo clone settings, path lists, local-only lists, update service, and Home Manager symlinks.
- Modify: `nixos/common.nix`
  - Import `./common-dotfiles.nix`.
  - Remove common `orgmDot` package and its local let binding.
- Modify: `nixos/profiles/hyprland.nix`
  - Remove `orgmDot` package and its local let binding.

---

### Task 1: Add dotfiles inventory verification

**Files:**
- Create: `scripts/check-common-dotfiles.py`
- Test target: `nixos/common-dotfiles.nix`

- [ ] **Step 1: Write the failing test**

Create `scripts/check-common-dotfiles.py`:

```python
#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOTFILES_JSON = Path("/home/osmarg/Hobby/dotfiles/config/dotfiles.json")
NIX_FILE = ROOT / "nixos" / "common-dotfiles.nix"


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    sys.exit(1)


def extract_list(source: str, name: str) -> list[str]:
    match = re.search(rf"\n\s*{re.escape(name)}\s*=\s*\[(.*?)\];", source, re.S)
    if not match:
        fail(f"missing list {name} in {NIX_FILE}")
    return re.findall(r'"((?:[^"\\]|\\.)*)"', match.group(1))


def extract_host_lists(source: str) -> dict[str, list[str]]:
    match = re.search(r"\n\s*hostPaths\s*=\s*\{(.*?)\n\s*\};", source, re.S)
    if not match:
        fail(f"missing hostPaths attrset in {NIX_FILE}")
    body = match.group(1)
    hosts: dict[str, list[str]] = {}
    for host_match in re.finditer(r"\n\s*([A-Za-z0-9_-]+)\s*=\s*\[(.*?)\];", body, re.S):
        hosts[host_match.group(1)] = re.findall(r'"((?:[^"\\]|\\.)*)"', host_match.group(2))
    return hosts


def assert_same(label: str, expected: list[str], actual: list[str]) -> None:
    expected_set = set(expected)
    actual_set = set(actual)
    missing = sorted(expected_set - actual_set)
    extra = sorted(actual_set - expected_set)
    if missing or extra:
        details = []
        if missing:
            details.append(f"missing={missing}")
        if extra:
            details.append(f"extra={extra}")
        fail(f"{label} mismatch: {'; '.join(details)}")


def main() -> None:
    if not DOTFILES_JSON.exists():
        fail(f"missing {DOTFILES_JSON}")
    if not NIX_FILE.exists():
        fail(f"missing {NIX_FILE}")

    data = json.loads(DOTFILES_JSON.read_text())
    nix = NIX_FILE.read_text()

    assert_same("sharedPaths", data["shared"]["paths"], extract_list(nix, "sharedPaths"))
    assert_same("localOnlyPaths", data["local_only"]["paths"], extract_list(nix, "localOnlyPaths"))
    assert_same("localOnlyPatterns", data["local_only"]["patterns"], extract_list(nix, "localOnlyPatterns"))
    assert_same("localOnlyTypes", data["local_only"]["types"], extract_list(nix, "localOnlyTypes"))
    assert_same("localDefaultsPaths", data["local_defaults"]["paths"], extract_list(nix, "localDefaultsPaths"))

    actual_hosts = extract_host_lists(nix)
    expected_hosts = data["hosts"]
    if set(actual_hosts) != set(expected_hosts):
        fail(f"host set mismatch: expected={sorted(expected_hosts)} actual={sorted(actual_hosts)}")
    for host, host_data in expected_hosts.items():
        assert_same(f"hostPaths.{host}", host_data["paths"], actual_hosts[host])

    print("OK: common-dotfiles.nix matches dotfiles.json inventory")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd /home/osmarg/Hobby/nixos
python3 scripts/check-common-dotfiles.py
```

Expected:

```text
FAIL: missing /home/osmarg/Hobby/nixos/nixos/common-dotfiles.nix
```

---

### Task 2: Add common-dotfiles.nix

**Files:**
- Create: `nixos/common-dotfiles.nix`
- Test: `scripts/check-common-dotfiles.py`

- [ ] **Step 1: Write implementation with generated exact inventory**

Run this generator from the NixOS repo. It reads the current `dotfiles.json` and writes complete Nix path lists plus module logic:

```bash
cd /home/osmarg/Hobby/nixos
python3 - <<'PY'
import json
from pathlib import Path

json_path = Path('/home/osmarg/Hobby/dotfiles/config/dotfiles.json')
out_path = Path('nixos/common-dotfiles.nix')
data = json.loads(json_path.read_text())


def nix_string(value: str) -> str:
    return '"' + value.replace('\\', '\\\\').replace('"', '\\"') + '"'


def nix_list(name: str, values: list[str], indent: str = '  ') -> str:
    lines = [f'{indent}{name} = [']
    lines += [f'{indent}  {nix_string(value)}' for value in values]
    lines.append(f'{indent}];')
    return '\n'.join(lines)


def nix_host_paths(hosts: dict) -> str:
    lines = ['  hostPaths = {']
    for host in sorted(hosts):
        lines.append(f'    {host} = [')
        lines += [f'      {nix_string(value)}' for value in hosts[host]['paths']]
        lines.append('    ];')
    lines.append('  };')
    return '\n'.join(lines)

content = f'''{{
  config,
  pkgs,
  lib,
  userName ? "osmarg",
  ...
}}:

let
  dotfilesRepo = "https://github.com/osmargm1202/dotfiles.git";
  dotfilesBranch = "master";
  dotfilesPath = "/home/${{userName}}/Hobby/dotfiles";
  dotfilesParent = "/home/${{userName}}/Hobby";
  hostName = config.networking.hostName;
{nix_list('sharedPaths', data['shared']['paths'])}
{nix_host_paths(data['hosts'])}
{nix_list('localOnlyPaths', data['local_only']['paths'])}
{nix_list('localOnlyPatterns', data['local_only']['patterns'])}
{nix_list('localOnlyTypes', data['local_only']['types'])}
{nix_list('localDefaultsPaths', data['local_defaults']['paths'])}

  pathsForHost = hostPaths.${{hostName}} or [ ];
  mkSharedFile = path: {{
    name = path;
    value.source = config.home-manager.users.${{userName}}.lib.file.mkOutOfStoreSymlink "${{dotfilesPath}}/config/shared/${{path}}";
  }};
  mkHostFile = path: {{
    name = path;
    value = lib.mkForce {{
      source = config.home-manager.users.${{userName}}.lib.file.mkOutOfStoreSymlink "${{dotfilesPath}}/config/hosts/${{hostName}}/${{path}}";
    }};
  }};
in
{{
  systemd.tmpfiles.rules = [
    "d ${{dotfilesParent}} 0755 ${{userName}} users - -"
  ];

  systemd.services.orgm-dotfiles-repo = {{
    description = "Clone and update ORGM dotfiles repository";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    before = [ "home-manager-${{userName}}.service" ];
    wantedBy = [ "multi-user.target" ];
    path = with pkgs; [
      bash
      coreutils
      git
      gnugrep
      openssh
      util-linux
    ];
    serviceConfig = {{
      Type = "oneshot";
      RemainAfterExit = true;
    }};
    script = ''
      set -euo pipefail

      install -d -m 0755 -o ${{userName}} -g users "${{dotfilesParent}}"

      as_user() {{
        runuser -u ${{userName}} -- "$@"
      }}

      if [ ! -e "${{dotfilesPath}}/.git" ]; then
        if [ -e "${{dotfilesPath}}" ]; then
          echo "${{dotfilesPath}} exists but is not a git repository" >&2
          exit 1
        fi
        as_user git clone --branch "${{dotfilesBranch}}" "${{dotfilesRepo}}" "${{dotfilesPath}}"
      else
        as_user git -C "${{dotfilesPath}}" fetch origin "${{dotfilesBranch}}"
        as_user git -C "${{dotfilesPath}}" checkout "${{dotfilesBranch}}"
        as_user git -C "${{dotfilesPath}}" pull --ff-only origin "${{dotfilesBranch}}"
      fi

      chown -R ${{userName}}:users "${{dotfilesPath}}"
    '';
  }};

  home-manager.users.${{userName}} = {{
    home.file = lib.mkMerge [
      (builtins.listToAttrs (map mkSharedFile sharedPaths))
      (builtins.listToAttrs (map mkHostFile pathsForHost))
    ];
  }};

  assertions = [
    {{
      assertion = localOnlyPaths != [ ] && localOnlyPatterns != [ ] && localOnlyTypes != [ ];
      message = "common-dotfiles.nix must keep local_only inventory from dotfiles.json as exclusions/documentation";
    }}
    {{
      assertion = localDefaultsPaths != [ ];
      message = "common-dotfiles.nix must keep local_defaults inventory from dotfiles.json as documentation";
    }}
  ];
}}
'''

out_path.write_text(content)
PY
```

- [ ] **Step 2: Run inventory test to verify it passes**

Run:

```bash
cd /home/osmarg/Hobby/nixos
python3 scripts/check-common-dotfiles.py
```

Expected:

```text
OK: common-dotfiles.nix matches dotfiles.json inventory
```

- [ ] **Step 3: Commit inventory module and test**

Run:

```bash
git add scripts/check-common-dotfiles.py nixos/common-dotfiles.nix
git commit -m "feat: add common dotfiles nix module"
```

---

### Task 3: Import module and stop installing orgm-dot for sync

**Files:**
- Create: `scripts/check-orgm-dot-not-installed.sh`
- Modify: `nixos/common.nix`
- Modify: `nixos/profiles/hyprland.nix`

- [ ] **Step 1: Write failing test**

Create `scripts/check-orgm-dot-not-installed.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failed=0

if grep -nE '^\s*orgmDot\b|orgmDot\s*=\s*pkgs\.callPackage .*orgm-dot\.nix' "$root/nixos/common.nix"; then
  echo "FAIL: nixos/common.nix still installs or defines orgmDot" >&2
  failed=1
fi

if grep -nE '^\s*orgmDot\b|orgmDot\s*=\s*pkgs\.callPackage .*orgm-dot\.nix' "$root/nixos/profiles/hyprland.nix"; then
  echo "FAIL: nixos/profiles/hyprland.nix still installs or defines orgmDot" >&2
  failed=1
fi

if ! grep -q './common-dotfiles.nix' "$root/nixos/common.nix"; then
  echo "FAIL: nixos/common.nix does not import ./common-dotfiles.nix" >&2
  failed=1
fi

if [ "$failed" -ne 0 ]; then
  exit 1
fi

echo "OK: common-dotfiles imported and orgmDot not installed for sync"
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd /home/osmarg/Hobby/nixos
chmod +x scripts/check-orgm-dot-not-installed.sh
./scripts/check-orgm-dot-not-installed.sh
```

Expected includes:

```text
FAIL: nixos/common.nix still installs or defines orgmDot
FAIL: nixos/profiles/hyprland.nix still installs or defines orgmDot
FAIL: nixos/common.nix does not import ./common-dotfiles.nix
```

- [ ] **Step 3: Modify `nixos/common.nix`**

Apply these edits:

1. Remove the top-level `let ... in` that only defines `dotfilesOrgmSource` and `orgmDot`.
2. Add `./common-dotfiles.nix` to `imports` in the `inputs != null` branch.
3. Remove `orgmDot` from `environment.systemPackages`.

Target shape near top:

```nix
{
  config,
  pkgs,
  lib,
  inputs ? null,
  userName ? "osmarg",
  ...
}:

{
  imports =
    lib.optionals (inputs != null) [
      inputs.home-manager.nixosModules.home-manager
      inputs.nix-flatpak.nixosModules.nix-flatpak
      ./flatpak.nix
      ./common-dotfiles.nix
    ]
    ++ lib.optionals (inputs == null) [ <home-manager/nixos> ];
```

Target shape in packages:

```nix
  environment.systemPackages = with pkgs; [
    wget
    curl
    rsync
    vim
```

No `orgmDot` entry should remain in that list.

- [ ] **Step 4: Modify `nixos/profiles/hyprland.nix`**

Remove this let binding:

```nix
  orgmDot = pkgs.callPackage ../packages/orgm-dot.nix { inherit dotfilesOrgmSource; };
```

Remove this package entry:

```nix
    orgmDot
```

Keep `orgmWallpaper` and `orgmThemes` unchanged.

- [ ] **Step 5: Run test to verify it passes**

Run:

```bash
cd /home/osmarg/Hobby/nixos
./scripts/check-orgm-dot-not-installed.sh
```

Expected:

```text
OK: common-dotfiles imported and orgmDot not installed for sync
```

- [ ] **Step 6: Commit import/removal**

Run:

```bash
git add scripts/check-orgm-dot-not-installed.sh nixos/common.nix nixos/profiles/hyprland.nix
git commit -m "feat: replace orgm-dot sync with common dotfiles module"
```

---

### Task 4: Evaluate NixOS config and compare deployment diff

**Files:**
- Verify: `flake.nix`, `flake.lock`, `nixos/common-dotfiles.nix`, `nixos/common.nix`, `nixos/profiles/hyprland.nix`

- [ ] **Step 1: Run formatter**

Run:

```bash
cd /home/osmarg/Hobby/nixos
nix fmt
```

Expected: command exits `0`.

- [ ] **Step 2: Re-run script tests**

Run:

```bash
cd /home/osmarg/Hobby/nixos
python3 scripts/check-common-dotfiles.py
./scripts/check-orgm-dot-not-installed.sh
```

Expected:

```text
OK: common-dotfiles.nix matches dotfiles.json inventory
OK: common-dotfiles imported and orgmDot not installed for sync
```

- [ ] **Step 3: Evaluate orgm system**

Run:

```bash
cd /home/osmarg/Hobby/nixos
nix eval .#nixosConfigurations.orgm.config.system.build.toplevel.drvPath
```

Expected: command exits `0` and prints a `/nix/store/...-nixos-system-orgm-...drv` path.

- [ ] **Step 4: Check deployment diff**

Run:

```bash
orgm-diff
```

Expected: diff shows new `common-dotfiles` module behavior, `orgm-dotfiles-repo.service`, and removal of `orgmDot` package from installed system packages.

- [ ] **Step 5: Apply only if diff is correct**

Run only after reviewing `orgm-diff` output:

```bash
orgm-sync
```

Expected: system switch succeeds.

- [ ] **Step 6: Commit verification fixes if formatter changed files**

If `nix fmt` changed files, run:

```bash
git add nixos/common-dotfiles.nix nixos/common.nix nixos/profiles/hyprland.nix scripts/check-common-dotfiles.py scripts/check-orgm-dot-not-installed.sh
git commit -m "style: format common dotfiles module"
```

If no files changed, do not create an empty commit.
