# Pi Package Extraction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract the public Pi stack from dotfiles into two reviewable Pi package repositories under `~/Code`: `pi-harness` and `pi-skills`.

**Architecture:** `pi-harness` is the public harness package containing extensions, agents/subagents, prompts, themes, assets, and helper libs. `pi-skills` is the public skills package containing only public skills. Dotfiles remain the source of the current installed configuration until the user reviews and decides what to remove later.

**Tech Stack:** Pi package conventional directories plus `package.json` `pi` manifests, GitHub CLI, git, orgm-dot manifest.

---

## Current approved scope

- Create/use only two public repos: `osmargm1202/pi-harness` and `osmargm1202/pi-skills`.
- Do not create `osmargm1202/orgm-skills` now.
- Do not delete local dotfiles or installed Pi files.
- Do not commit inside the new repos until the user reviews.
- Checkpoint commit before work exists: `d79b9a0 chore: checkpoint pi agent prompts`.

## File structure

### `~/Code/pi-harness`

- `package.json` — Pi package manifest for extensions, agents, prompts, themes.
- `README.md` — purpose and install instructions.
- `extensions/` — copied from `config/shared/.pi/agent/extensions`.
- `agents/` — copied from `config/shared/.pi/agent/agents`.
- `prompts/` — copied from `config/shared/.pi/agent/prompts`.
- `themes/` — copied from `config/shared/.pi/agent/themes`.
- `assets/` — copied from `config/shared/.pi/agent/assets`.
- `lib/` — copied from `config/shared/.pi/agent/lib`.

### `~/Code/pi-skills`

- `package.json` — Pi package manifest for skills.
- `README.md` — purpose and install instructions.
- `skills/` — copied from `config/shared/.pi/agent/skills`.

### Dotfiles updates

- `config/dotfiles.json` — add package clone/install locations to `local_only.paths` so `orgm-dot sync --host orgm` does not remove package-managed content.

## Task 1: Create GitHub repos and local folders

**Files:**
- Create/update: `/home/osmarg/Code/pi-harness`
- Create/update: `/home/osmarg/Code/pi-skills`

- [ ] Check whether repos already exist:

```bash
gh repo view osmargm1202/pi-harness --json name,visibility,url || true
gh repo view osmargm1202/pi-skills --json name,visibility,url || true
```

- [ ] If missing, create public repos without initial files:

```bash
gh repo create osmargm1202/pi-harness --public --description "Pi harness extensions, agents, prompts, themes, and widgets" --confirm
gh repo create osmargm1202/pi-skills --public --description "Public Pi skills used by osmargm1202" --confirm
```

- [ ] Clone or initialize local folders under `~/Code`:

```bash
mkdir -p /home/osmarg/Code
[ -d /home/osmarg/Code/pi-harness/.git ] || gh repo clone osmargm1202/pi-harness /home/osmarg/Code/pi-harness
[ -d /home/osmarg/Code/pi-skills/.git ] || gh repo clone osmargm1202/pi-skills /home/osmarg/Code/pi-skills
```

## Task 2: Copy public harness stack

**Files:**
- Copy from: `config/shared/.pi/agent/{extensions,agents,prompts,themes,assets,lib}`
- Copy to: `/home/osmarg/Code/pi-harness/`
- Create: `/home/osmarg/Code/pi-harness/package.json`
- Create: `/home/osmarg/Code/pi-harness/README.md`

- [ ] Copy only, preserving dotfiles and not deleting source:

```bash
rsync -a --delete /home/osmarg/Hobby/dotfiles/config/shared/.pi/agent/extensions/ /home/osmarg/Code/pi-harness/extensions/
rsync -a --delete /home/osmarg/Hobby/dotfiles/config/shared/.pi/agent/agents/ /home/osmarg/Code/pi-harness/agents/
rsync -a --delete /home/osmarg/Hobby/dotfiles/config/shared/.pi/agent/prompts/ /home/osmarg/Code/pi-harness/prompts/
rsync -a --delete /home/osmarg/Hobby/dotfiles/config/shared/.pi/agent/themes/ /home/osmarg/Code/pi-harness/themes/
rsync -a --delete /home/osmarg/Hobby/dotfiles/config/shared/.pi/agent/assets/ /home/osmarg/Code/pi-harness/assets/
rsync -a --delete /home/osmarg/Hobby/dotfiles/config/shared/.pi/agent/lib/ /home/osmarg/Code/pi-harness/lib/
```

- [ ] Write `package.json` with `pi` manifest:

```json
{
  "name": "pi-harness",
  "version": "0.1.0",
  "private": false,
  "description": "Pi harness extensions, agents, prompts, themes, and widgets used by osmargm1202.",
  "keywords": ["pi-package", "pi", "extensions", "agents", "skills", "widgets"],
  "license": "MIT",
  "pi": {
    "extensions": ["./extensions"],
    "prompts": ["./prompts"],
    "themes": ["./themes"]
  },
  "peerDependencies": {
    "@earendil-works/pi-coding-agent": "*",
    "@earendil-works/pi-tui": "*",
    "typebox": "*"
  }
}
```

- [ ] README must include: what it contains, review-before-install security note, and `pi install git:github.com/osmargm1202/pi-harness`.

## Task 3: Copy public skills stack

**Files:**
- Copy from: `config/shared/.pi/agent/skills`
- Copy to: `/home/osmarg/Code/pi-skills/skills`
- Create: `/home/osmarg/Code/pi-skills/package.json`
- Create: `/home/osmarg/Code/pi-skills/README.md`

- [ ] Copy only, preserving dotfiles and not deleting source:

```bash
rsync -a --delete /home/osmarg/Hobby/dotfiles/config/shared/.pi/agent/skills/ /home/osmarg/Code/pi-skills/skills/
```

- [ ] Write `package.json` with skills manifest:

```json
{
  "name": "pi-skills",
  "version": "0.1.0",
  "private": false,
  "description": "Public Pi skills used by osmargm1202 for agentic work.",
  "keywords": ["pi-package", "pi", "skills", "agentic-ai"],
  "license": "MIT",
  "pi": {
    "skills": ["./skills"]
  }
}
```

- [ ] README must include: what it contains, note to remove private skills before publishing if found, and `pi install git:github.com/osmargm1202/pi-skills`.

## Task 4: Protect package install paths in dotfiles

**Files:**
- Modify: `config/dotfiles.json`

- [ ] Add missing `local_only.paths` entries:

```json
".pi/agent/git/github.com/osmargm1202/pi-harness",
".pi/agent/git/github.com/osmargm1202/pi-skills",
".pi/agent/npm/pi-harness",
".pi/agent/npm/pi-skills"
```

- [ ] Keep existing `.pi/agent/git` local-only entry; specific entries document intent and protect future narrowing.

## Task 5: Verify without committing new repos

**Files:**
- Inspect both repos and dotfiles manifest.

- [ ] Verify package manifests parse:

```bash
node -e 'JSON.parse(require("fs").readFileSync("/home/osmarg/Code/pi-harness/package.json", "utf8")); JSON.parse(require("fs").readFileSync("/home/osmarg/Code/pi-skills/package.json", "utf8")); console.log("package json ok")'
```

- [ ] Verify expected resources exist:

```bash
test -f /home/osmarg/Code/pi-harness/extensions/subagents.ts
test -f /home/osmarg/Code/pi-harness/extensions/agent-status.ts
test -f /home/osmarg/Code/pi-harness/extensions/awareness.ts
test -f /home/osmarg/Code/pi-harness/agents/teams.yaml
test -f /home/osmarg/Code/pi-skills/skills/caveman/SKILL.md
```

- [ ] Show review status, but do not commit:

```bash
git -C /home/osmarg/Code/pi-harness status --short
git -C /home/osmarg/Code/pi-skills status --short
git -C /home/osmarg/Hobby/dotfiles status --short
```
