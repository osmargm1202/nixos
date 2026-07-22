# Pi OmniRoute Model Configuration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expose OmniRoute's `auto` router as `omniroute/auto` in Pi through the managed dotfiles configuration.

**Architecture:** Store Pi's custom provider declaration in the shared dotfiles tree and register that path with the existing Home Manager out-of-store symlink mechanism. Keep the API key outside Nix by resolving `$OMNIROUTE_API_KEY` at Pi runtime.

**Tech Stack:** NixOS, Home Manager, JSON, Pi 0.81 custom models, OmniRoute OpenAI-compatible API.

## Global Constraints

- Base URL must be `http://localhost:20128/v1`.
- Provider ID must be `omniroute`.
- Only model `auto` is in scope.
- Never place the real OmniRoute API key in tracked files or Nix expressions.
- Preserve all unrelated working-tree changes.
- Apply newly registered Home Manager path with `nh os switch`.

---

### Task 1: Add managed OmniRoute model configuration

**Files:**

- Create: `dotfiles/config/shared/.pi/agent/models.json`
- Modify: `nixos/common-dotfiles.nix:155-158`
- Modify: `dotfiles/config/dotfiles.json:65-68`

**Interfaces:**

- Consumes: Pi's `~/.pi/agent/models.json` provider schema and Home Manager's existing `sharedPaths` mapping.
- Produces: Provider/model identifier `omniroute/auto` and managed symlink `~/.pi/agent/models.json`.

- [ ] **Step 1: Verify the configuration is absent before implementation**

Run:

```bash
test ! -e dotfiles/config/shared/.pi/agent/models.json
! rg -n '"\.pi/agent/models\.json"' nixos/common-dotfiles.nix dotfiles/config/dotfiles.json
```

Expected: both commands exit 0, proving the model file and registrations do not yet exist.

- [ ] **Step 2: Create the Pi provider configuration**

Create `dotfiles/config/shared/.pi/agent/models.json` with exactly:

```json
{
  "providers": {
    "omniroute": {
      "baseUrl": "http://localhost:20128/v1",
      "api": "openai-completions",
      "apiKey": "$OMNIROUTE_API_KEY",
      "models": [
        {
          "id": "auto",
          "name": "OmniRoute Auto",
          "reasoning": false,
          "input": ["text", "image"],
          "contextWindow": 128000,
          "maxTokens": 8192
        }
      ]
    }
  }
}
```

- [ ] **Step 3: Register the shared path in Home Manager**

In `nixos/common-dotfiles.nix`, add this entry beside the existing Pi files:

```nix
    ".pi/agent/models.json"
```

The resulting Pi block must be:

```nix
    ".pi/agent/AGENTS.md"
    ".pi/agent/RTK.md"
    ".pi/agent/ask.jsonc"
    ".pi/agent/models.json"
```

- [ ] **Step 4: Register the path in the dotfiles manifest**

In `dotfiles/config/dotfiles.json`, add this entry beside the existing Pi files:

```json
      ".pi/agent/models.json",
```

The resulting Pi block must be:

```json
      ".pi/agent/AGENTS.md",
      ".pi/agent/RTK.md",
      ".pi/agent/ask.jsonc",
      ".pi/agent/models.json",
```

- [ ] **Step 5: Validate source files before activation**

Run:

```bash
jq empty dotfiles/config/shared/.pi/agent/models.json
jq empty dotfiles/config/dotfiles.json
nix-instantiate --parse nixos/common-dotfiles.nix >/dev/null
git diff --check -- \
  dotfiles/config/shared/.pi/agent/models.json \
  dotfiles/config/dotfiles.json \
  nixos/common-dotfiles.nix
```

Expected: every command exits 0 with no validation errors.

- [ ] **Step 6: Apply Home Manager through NixOS**

Run from `/home/osmarg/Hobby/nixos`:

```bash
nh os switch
```

Expected: switch exits 0 and activates the current host configuration.

- [ ] **Step 7: Verify managed path and Pi model discovery**

Run:

```bash
test "$(readlink -f ~/.pi/agent/models.json)" = \
  "/home/osmarg/Hobby/nixos/dotfiles/config/shared/.pi/agent/models.json"
pi --list-models omniroute | rg 'omniroute\s+auto'
```

Expected: symlink assertion exits 0 and Pi prints provider `omniroute` with model `auto`.

- [ ] **Step 8: Commit only the implementation files**

```bash
git add \
  dotfiles/config/shared/.pi/agent/models.json \
  dotfiles/config/dotfiles.json \
  nixos/common-dotfiles.nix
git commit -m "config: add OmniRoute model to Pi"
```

Expected: one focused commit; unrelated existing changes remain unstaged.
