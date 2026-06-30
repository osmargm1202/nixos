# Pi SDD Orchestrator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidate SDD/TDD into `sdd-orchestrator`, move ORGM flow ownership into `orgm.ts`, enable subagents, add host config and git guard, and fix Esc cancellation in model selection.

**Architecture:** `orgm.ts` remains the extension entry point and source of flow truth, while small `extensions/lib/orgm-*` modules handle config, flow, and extension counting. `sdd-orchestrator` becomes one primary agent containing SDD and TDD workers. Host-specific behavior lives in `config/hosts/lenovo/.pi/agent/orgm.json`.

**Tech Stack:** Pi TypeScript extensions, Markdown primary agents/subagents, dot.sh managed dotfiles, Git worktree workflow.

---

## File Map

### Move/create
- Create: `config/shared/.pi/agent/agents/sdd-orchestrator/`
- Move: `config/shared/.pi/agent/assets/orchestrator.md` → `config/shared/.pi/agent/agents/sdd-orchestrator/index.md`
- Move: `config/shared/.pi/agent/assets/agents/sdd-*.md` → `config/shared/.pi/agent/agents/sdd-orchestrator/sdd-*.md`
- Move: `config/shared/.pi/agent/agents/tdd-orgm/tdd-*.md` → `config/shared/.pi/agent/agents/sdd-orchestrator/tdd-*.md`
- Create: `config/shared/.pi/agent/extensions/lib/orgm-config.ts`
- Create: `config/shared/.pi/agent/extensions/lib/orgm-flow.ts`
- Create: `config/shared/.pi/agent/extensions/lib/orgm-extensions.ts`
- Create: `config/shared/.pi/agent/extensions/git.ts`
- Create: `config/hosts/lenovo/.pi/agent/orgm.json`

### Modify
- `config/shared/.pi/agent/extensions/orgm.ts` — host config, flow source, extension count, gentle-ai replacement commands/helpers as needed.
- `config/shared/.pi/agent/extensions/sdd-init.ts` — remove `gentle-ai.ts` import and update layout references.
- `config/shared/.pi/agent/lib/sdd-preflight.ts` — rename `.pi/gentle-ai` paths/config to ORGM/SDD paths.
- `config/shared/.pi/agent/assets/chains/sdd-full.chain.md` — point to `sdd-orchestrator` layout.
- `config/shared/.pi/agent/assets/chains/sdd-plan.chain.md` — point to `sdd-orchestrator` layout.
- `config/shared/.pi/agent/assets/chains/sdd-verify.chain.md` — point to `sdd-orchestrator` layout.
- `config/shared/.pi/agent/agents/teams.yaml` — replace `tdd-orgm` with `sdd-orchestrator` members.
- `config/shared/.pi/agent/extensions/agent-selector.ts` — Esc closes/cancels correctly.
- `config/shared/.pi/agent/extensions/model-primary.ts` — ensure primary-agent selector Esc cancel works consistently.
- `config/dotfiles.json` — add Lenovo `.pi/agent/orgm.json` path.

### Remove
- `config/shared/.pi/agent/extensions/gentle-ai.ts`
- `config/shared/.pi/agent/extensions/skill-registry.ts`
- `config/shared/.pi/agent/extensions/.atl/` if tracked/unwanted.
- `config/shared/.pi/agent/assets/agents/` after moving files.
- `config/shared/.pi/agent/agents/tdd-orgm/` after moving files.

---

## Task 1: Baseline and Test Discovery

**Files:** none changed.

- [ ] **Step 1: Inspect package/test commands**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles/.worktrees/pi-sdd-orchestrator
find . -maxdepth 3 \( -name package.json -o -name tsconfig.json -o -name vitest.config.* -o -name '*.test.ts' -o -name '*.spec.ts' \) -print
```

Expected: list available TS project/test files, or confirm there is no local test runner for Pi extensions.

- [ ] **Step 2: Record baseline status**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles/.worktrees/pi-sdd-orchestrator
git status --short --branch
```

Expected: branch `pi-sdd-orchestrator`, only design/plan docs currently modified if this plan was already written.

- [ ] **Step 3: Run baseline checks if available**

If `package.json` exists under extension root, run its test/typecheck command. If not, run syntax-oriented checks after implementation only.

Expected: baseline result recorded before code changes.

---

## Task 2: Add Host Config Loader

**Files:**
- Create: `config/shared/.pi/agent/extensions/lib/orgm-config.ts`
- Test: nearest available TS test file, or create `config/shared/.pi/agent/extensions/lib/orgm-config.test.ts` if runner exists.

- [ ] **Step 1: Write failing tests for config defaults and blocked roots**

Test expected behavior:
- missing config returns default primary `pi` or configured fallback;
- Lenovo config can set `defaultPrimaryAgent: "sdd-orchestrator"`;
- `~`, `~/Nextcloud`, and `~/Nextcloud/**` normalize to blocked paths.

Expected RED: imports/functions do not exist yet.

- [ ] **Step 2: Implement `orgm-config.ts`**

Export:

```ts
export interface OrgmHostConfig {
  defaultPrimaryAgent: string;
  flows: Record<string, "normal" | "pi-orchestrator" | "sdd-tdd" | string>;
  git: {
    autoInit: boolean;
    autoCommitCompletedWork: boolean;
    preferWorktreesForLongWork: boolean;
    ignoreRoots: string[];
  };
}

export const DEFAULT_ORGM_CONFIG: OrgmHostConfig = {
  defaultPrimaryAgent: "pi",
  flows: {
    pi: "normal",
    "pi-orchestrator": "pi-orchestrator",
    "sdd-orchestrator": "sdd-tdd"
  },
  git: {
    autoInit: false,
    autoCommitCompletedWork: false,
    preferWorktreesForLongWork: true,
    ignoreRoots: ["~", "~/Nextcloud", "~/Nextcloud/**"]
  }
};
```

Include `loadOrgmConfig(cwdOrHome: string): OrgmHostConfig`, `expandHomePath`, and `isBlockedGitRoot` helpers.

- [ ] **Step 3: Verify GREEN**

Run selected tests or typecheck.

Expected: config tests pass.

---

## Task 3: Add Lenovo Host Config

**Files:**
- Create: `config/hosts/lenovo/.pi/agent/orgm.json`
- Modify: `config/dotfiles.json`

- [ ] **Step 1: Create host config**

Write:

```json
{
  "defaultPrimaryAgent": "sdd-orchestrator",
  "flows": {
    "pi": "normal",
    "pi-orchestrator": "pi-orchestrator",
    "sdd-orchestrator": "sdd-tdd"
  },
  "git": {
    "autoInit": true,
    "autoCommitCompletedWork": false,
    "preferWorktreesForLongWork": true,
    "ignoreRoots": ["~", "~/Nextcloud", "~/Nextcloud/**"]
  }
}
```

- [ ] **Step 2: Add dotfiles path**

In `config/dotfiles.json`, add `.pi/agent/orgm.json` to `hosts.lenovo.paths`.

- [ ] **Step 3: Validate JSON**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles/.worktrees/pi-sdd-orchestrator
python -m json.tool config/hosts/lenovo/.pi/agent/orgm.json >/dev/null
python -m json.tool config/dotfiles.json >/dev/null
```

Expected: both commands exit 0.

---

## Task 4: Move SDD/TDD Agents Under `sdd-orchestrator`

**Files:**
- Move/create under `config/shared/.pi/agent/agents/sdd-orchestrator/`
- Modify: `config/shared/.pi/agent/agents/teams.yaml`
- Remove old directories.

- [ ] **Step 1: Move files**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles/.worktrees/pi-sdd-orchestrator
mkdir -p config/shared/.pi/agent/agents/sdd-orchestrator
git mv config/shared/.pi/agent/assets/orchestrator.md config/shared/.pi/agent/agents/sdd-orchestrator/index.md
git mv config/shared/.pi/agent/assets/agents/sdd-*.md config/shared/.pi/agent/agents/sdd-orchestrator/
git mv config/shared/.pi/agent/agents/tdd-orgm/tdd-*.md config/shared/.pi/agent/agents/sdd-orchestrator/
rmdir config/shared/.pi/agent/assets/agents config/shared/.pi/agent/agents/tdd-orgm
```

Expected: old directories removed if empty.

- [ ] **Step 2: Update `index.md` frontmatter/name**

Ensure `index.md` identifies as `sdd-orchestrator`, not el Gentleman generic-only. It should state:
- primary coordinator only;
- route SDD phases to `sdd-*` workers;
- route TDD work to `tdd-*` workers;
- use worktrees/commits for long work after approval;
- keep Pi normal workflow outside this agent.

- [ ] **Step 3: Update `teams.yaml`**

Remove `tdd-orgm:` block. Add:

```yaml
sdd-orchestrator:
  - sdd-init
  - sdd-explore
  - sdd-proposal
  - sdd-spec
  - sdd-design
  - sdd-tasks
  - sdd-apply
  - sdd-verify
  - sdd-archive
  - tdd-brainstormer
  - tdd-planner
  - tdd-implementer
  - tdd-reviewer
  - tdd-verifier
  - tdd-worktree-manager
```

- [ ] **Step 4: Verify moved files**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles/.worktrees/pi-sdd-orchestrator
find config/shared/.pi/agent/agents/sdd-orchestrator -maxdepth 1 -type f | sort
find config/shared/.pi/agent/assets/agents config/shared/.pi/agent/agents/tdd-orgm -maxdepth 1 -type f 2>/dev/null
```

Expected: new folder contains all SDD/TDD files; second command prints nothing or errors because folders are gone.

---

## Task 5: Update Chains, Support, and SDD Init References

**Files:**
- Modify: `config/shared/.pi/agent/assets/chains/sdd-full.chain.md`
- Modify: `config/shared/.pi/agent/assets/chains/sdd-plan.chain.md`
- Modify: `config/shared/.pi/agent/assets/chains/sdd-verify.chain.md`
- Modify: `config/shared/.pi/agent/extensions/sdd-init.ts`
- Modify: `config/shared/.pi/agent/lib/sdd-preflight.ts`

- [ ] **Step 1: Search old references**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles/.worktrees/pi-sdd-orchestrator
rg -n "assets/orchestrator|assets/agents|agents/tdd-orgm|gentle-ai|\.pi/gentle-ai|sdd-" config/shared/.pi/agent/assets config/shared/.pi/agent/extensions config/shared/.pi/agent/lib config/shared/.pi/agent/agents/sdd-orchestrator
```

Expected: old layout references identified.

- [ ] **Step 2: Update chains**

Modify chains so agent names and paths resolve from `sdd-orchestrator`. Preserve phase order:
- full: init → explore → proposal → spec/design/tasks → apply → verify → archive;
- plan: init → proposal → spec/design/tasks;
- verify: init → apply → verify → archive.

- [ ] **Step 3: Update `sdd-preflight.ts`**

Replace `.pi/gentle-ai/...` support/config paths with `.pi/agent/orgm...` or `.pi/sdd...` names that match new ORGM ownership.

- [ ] **Step 4: Update `sdd-init.ts`**

Remove:

```ts
import { applySavedModelConfig } from "./gentle-ai.ts";
```

Replace helper with import from `./lib/orgm-flow.ts` or local no-op if model config is not needed.

- [ ] **Step 5: Verify no stale old-layout references**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles/.worktrees/pi-sdd-orchestrator
rg -n "assets/orchestrator|assets/agents|agents/tdd-orgm|\.pi/gentle-ai|from \"\./gentle-ai" config/shared/.pi/agent || true
```

Expected: no output.

---

## Task 6: Remove Gentle AI and Skill Registry Extensions

**Files:**
- Remove: `config/shared/.pi/agent/extensions/gentle-ai.ts`
- Remove: `config/shared/.pi/agent/extensions/skill-registry.ts`
- Remove: generated registry files if tracked.

- [ ] **Step 1: Remove extension files**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles/.worktrees/pi-sdd-orchestrator
git rm config/shared/.pi/agent/extensions/gentle-ai.ts config/shared/.pi/agent/extensions/skill-registry.ts
```

- [ ] **Step 2: Remove generated `.atl` artifacts if tracked**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles/.worktrees/pi-sdd-orchestrator
git ls-files config/shared/.pi/agent/extensions/.atl
```

If output exists:

```bash
git rm -r config/shared/.pi/agent/extensions/.atl
```

- [ ] **Step 3: Verify no imports depend on removed files**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles/.worktrees/pi-sdd-orchestrator
rg -n "gentle-ai|skill-registry" config/shared/.pi/agent/extensions config/shared/.pi/agent/lib config/shared/.pi/agent/agents || true
```

Expected: only documentation/skill text references if intentionally retained; no TS imports.

---

## Task 7: Enable Subagents Extension

**Files:**
- Move: `config/shared/.pi/agent/extensions/subagents.ts.disabled` → `config/shared/.pi/agent/extensions/subagents.ts`

- [ ] **Step 1: Rename extension**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles/.worktrees/pi-sdd-orchestrator
git mv config/shared/.pi/agent/extensions/subagents.ts.disabled config/shared/.pi/agent/extensions/subagents.ts
```

- [ ] **Step 2: Verify no stale disabled reference**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles/.worktrees/pi-sdd-orchestrator
test -f config/shared/.pi/agent/extensions/subagents.ts
test ! -f config/shared/.pi/agent/extensions/subagents.ts.disabled
```

Expected: both commands exit 0.

---

## Task 8: Patch ORGM Flow and Extension Count

**Files:**
- Modify: `config/shared/.pi/agent/extensions/orgm.ts`
- Create/modify: `config/shared/.pi/agent/extensions/lib/orgm-flow.ts`
- Create/modify: `config/shared/.pi/agent/extensions/lib/orgm-extensions.ts`

- [ ] **Step 1: Write failing tests or harness checks**

Test expected behavior:
- extension count includes `.ts` files in extensions dir except `.disabled` and dot cache folders;
- default primary agent loads from host config;
- `sdd-orchestrator` flow maps to SDD/TDD prompt handling.

Expected RED: helpers absent or count wrong.

- [ ] **Step 2: Implement extension count helper**

`orgm-extensions.ts` should export `countActiveExtensions(extensionDir: string, settingsExtensions?: unknown): number`.

Rules:
- count `*.ts` files in extension dir;
- exclude `*.disabled`;
- exclude dot directories/caches;
- if `settings.json` has extensions, combine/dedupe rather than report 0.

- [ ] **Step 3: Implement flow helper**

`orgm-flow.ts` should export functions to resolve:
- current default primary agent;
- flow type for selected primary;
- optional compatibility aliases formerly in `gentle-ai.ts` that are still required by `sdd-init.ts`.

- [ ] **Step 4: Patch `orgm.ts`**

Use helpers to:
- show correct `EXTENSIONS: N active`;
- apply host default primary-agent state on session start if no explicit current selection exists;
- keep normal Pi and `pi-orchestrator` behavior unchanged.

- [ ] **Step 5: Verify GREEN**

Run tests/typecheck or syntax checks.

Expected: no TS import errors, extension count helper passes tests.

---

## Task 9: Add `git.ts` Extension

**Files:**
- Create: `config/shared/.pi/agent/extensions/git.ts`
- Use: `config/shared/.pi/agent/extensions/lib/orgm-config.ts`

- [ ] **Step 1: Write failing tests for root blocking**

Test expected behavior:
- `$HOME` blocked;
- `~/Nextcloud` blocked;
- `~/Nextcloud/project` blocked;
- normal project path allowed.

Expected RED if helper missing.

- [ ] **Step 2: Implement read-only detection first**

`git.ts` should:
- inspect cwd with `git rev-parse --is-inside-work-tree`;
- if inside git, no-op;
- if outside git and cwd blocked, notify and no-op;
- if outside git and allowed, ask/perform `git init` only according to config.

- [ ] **Step 3: Implement long-work and completion policy**

Add conservative behavior:
- recommend worktree for long work when config says so;
- suggest commit at task/process completion;
- auto-commit only if config and session approval allow.

- [ ] **Step 4: Verify no destructive behavior**

Run in temp dirs:

```bash
TMP=$(mktemp -d)
HOME_CASE="$HOME"
NEXT_CASE="$HOME/Nextcloud/test-pi-git-ext"
PROJECT_CASE="$TMP/project"
mkdir -p "$NEXT_CASE" "$PROJECT_CASE"
```

Use helper tests or manual dry-run mode to verify blocked/allowed decisions. Do not run `git init` in `$HOME` or Nextcloud.

---

## Task 10: Fix Agent Model Selector Esc Cancel

**Files:**
- Modify: `config/shared/.pi/agent/extensions/agent-selector.ts`
- Modify if needed: `config/shared/.pi/agent/extensions/model-primary.ts`

- [ ] **Step 1: Root-cause check current handlers**

Inspect handlers around:
- bare Esc handling;
- arrow escape sequence detection;
- `SelectList.handleInput` fallback;
- model mode behavior.

Hypothesis to test: model mode Esc only goes back to agent list and may never close, while some Esc payloads are not recognized.

- [ ] **Step 2: Add failing test or minimal helper test**

If test runner exists, extract pure helper:

```ts
export function isEscapeKey(data: string): boolean {
  return data === "\u001B" || data === "Escape" || data === "escape";
}
```

Test:
- `"\u001B"` true;
- `"Escape"` true;
- arrow sequences false;
- printable chars false.

Expected RED before helper exists.

- [ ] **Step 3: Patch selector behavior**

In `agent-selector.ts`:
- handle escape before passing to `SelectList`;
- in agents mode:
  - if filter exists, first Esc clears filter;
  - next Esc closes with `done()`;
- in models mode:
  - Esc closes/cancels the selector, or at minimum second Esc closes after returning to agents;
  - do not trap user in menu.

In `model-primary.ts`:
- ensure `selectList.onCancel = () => done(null)` works;
- if needed, intercept Esc and call `done(null)` before `selectList.handleInput(data)`.

- [ ] **Step 4: Update help text**

Use clear text:

```text
↑↓ navigate · Enter save · Esc cancel/close
```

- [ ] **Step 5: Verify Esc behavior manually**

After sync/temporary runtime test, open model selector and verify:
- Esc closes from agent list;
- Esc closes from model list;
- Esc does not break arrow navigation.

---

## Task 11: Final Verification

**Files:** all changed files.

- [ ] **Step 1: Search stale references**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles/.worktrees/pi-sdd-orchestrator
rg -n "assets/orchestrator|assets/agents|agents/tdd-orgm|extensions/gentle-ai|extensions/skill-registry|\.pi/gentle-ai|subagents.ts.disabled" config/shared/.pi/agent config/hosts/lenovo config/dotfiles.json || true
```

Expected: no stale runtime references.

- [ ] **Step 2: Validate frontmatter/team membership**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles/.worktrees/pi-sdd-orchestrator
grep -n "^name:\|^description:\|^tools:\|^output:" config/shared/.pi/agent/agents/sdd-orchestrator/*.md
grep -n '^sdd-orchestrator:' -A20 config/shared/.pi/agent/agents/teams.yaml
```

Expected: every agent has valid frontmatter; team includes SDD and TDD members.

- [ ] **Step 3: Run type/test checks**

Run discovered test/typecheck command from Task 1. If no runner exists, run static syntax checks available in repo.

Expected: no import/type errors from removed files or renamed subagents.

- [ ] **Step 4: Dot diff for Lenovo**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles/.worktrees/pi-sdd-orchestrator
./dot.sh diff --host lenovo
```

Expected: diff shows intended Pi agent/extension/config changes only.

- [ ] **Step 5: Review workload and commit strategy**

Run:

```bash
cd /home/osmarg/Hobby/dotfiles/.worktrees/pi-sdd-orchestrator
git diff --stat
git status --short
```

Expected: if diff is large, split commits by work unit:
1. docs/design-plan;
2. agent file moves/layout;
3. ORGM config/flow/gentle removal;
4. git extension;
5. Esc bug fix;
6. verification cleanup.

Do not commit without explicit user approval.
