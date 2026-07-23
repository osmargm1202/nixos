# System Python Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install the standard Python 3 interpreter on every host importing `nixos/common.nix`.

**Architecture:** Add `python3` directly to the common `environment.systemPackages` list. A focused shell test enforces common placement and adjacency to `uv`, while Nix parsing and diagnostics validate module syntax.

**Tech Stack:** NixOS, Nix, Bash.

## Global Constraints

- Use `python3`, not `python3Minimal` or `python3.withPackages`.
- Do not add global Python libraries.
- Keep project dependencies managed through flakes or `uv`.
- Commit and push changes.
- Do not run `nh os switch`.

---

### Task 1: Add Python 3 to Common System Packages

**Files:**

- Create: `tests/common-system-python.bats.sh`
- Modify: `nixos/common.nix:231-245`

**Interfaces:**

- Consumes: `pkgs.python3` from nixpkgs.
- Produces: `python3` in the global system profile for every host importing `nixos/common.nix`.

- [ ] **Step 1: Write failing test**

Create `tests/common-system-python.bats.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMON="$ROOT/nixos/common.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

python_line="$(grep -nE '^    python3$' "$COMMON" | cut -d: -f1 || true)"
[ -n "$python_line" ] || fail 'common system packages must include python3'

uv_line="$(grep -nE '^    uv$' "$COMMON" | cut -d: -f1 || true)"
[ -n "$uv_line" ] || fail 'common system packages must include uv'
[ "$python_line" -eq $((uv_line + 1)) ] ||
  fail 'python3 must be adjacent to uv in common system packages'

printf 'PASS: common system packages include Python 3\n'
```

- [ ] **Step 2: Run test and verify red state**

```bash
chmod +x tests/common-system-python.bats.sh
bash tests/common-system-python.bats.sh
```

Expected: `FAIL: common system packages must include python3`.

- [ ] **Step 3: Add minimal package entry**

In `nixos/common.nix`, change:

```nix
    uv
    fd
```

to:

```nix
    uv
    python3
    fd
```

- [ ] **Step 4: Verify green state and module syntax**

```bash
bash tests/common-system-python.bats.sh
nix-instantiate --parse nixos/common.nix >/dev/null
git diff --check
```

Expected:

```text
PASS: common system packages include Python 3
```

No parse or whitespace errors.

- [ ] **Step 5: Check diagnostics**

Run LSP diagnostics for `nixos/common.nix` and `tests/common-system-python.bats.sh`.

Expected: zero diagnostics.

- [ ] **Step 6: Commit and push**

```bash
git add nixos/common.nix tests/common-system-python.bats.sh \
  docs/superpowers/plans/2026-07-23-system-python.md
git commit -m "feat(nixos): add Python to common system packages"
git push origin master
```

Expected: remote `master` advances to the implementation commit.

- [ ] **Step 7: Hand off activation**

Do not execute the switch. Tell the user:

```text
Python agregado y publicado. Ejecuta: nh os switch
```
