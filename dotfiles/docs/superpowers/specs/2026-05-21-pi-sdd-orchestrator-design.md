# Pi SDD Orchestrator Consolidation Design

## Goal
Consolidate Pi workflow control around host-aware primary agents: normal Pi stays light, `pi-orchestrator` keeps Pi-maintenance flow, and `sdd-orchestrator` owns SDD/TDD orchestration without globally loading too many extensions.

## Current Problems
- SDD lives as loose assets under `config/shared/.pi/agent/assets`, while primary-agent workflows live under `config/shared/.pi/agent/agents`.
- `gentle-ai.ts` duplicates orchestration behavior that should be owned by ORGM runtime config and the `sdd-orchestrator` primary agent.
- `tdd-orgm` is separate from SDD, but user wants one SDD/TDD primary workflow.
- `subagents.ts.disabled` prevents delegated SDD/TDD execution.
- `orgm.ts` reports `EXTENSIONS: 0 active` because it only counts `settings.json` extensions.
- `skill-registry.ts` creates `.atl`/registry artifacts and should be removed.
- Agent model selector can get stuck: Esc does not reliably exit/cancel menu.
- No host-level default primary-agent config exists for Lenovo.
- No automatic git guard exists for non-git project directories.

## Target Architecture

### Primary-agent routing
`orgm.ts` becomes the runtime source of truth for ORGM flow selection. It should:
- load host config from `.pi/agent/orgm.json` when present;
- select default primary agent from host config;
- expose/coordinate flow modes:
  - `pi`: normal Pi behavior and skills;
  - `pi-orchestrator`: existing Pi maintenance flow;
  - `sdd-orchestrator`: SDD/TDD controlled flow;
- keep header/status accurate, including extension count.

Implementation detail: keep `orgm.ts` as extension entry point, but move reusable logic into small libs:
- `extensions/lib/orgm-config.ts` — load/validate host config, expand `~`, defaults.
- `extensions/lib/orgm-flow.ts` — resolve primary-agent flow and prompt behavior.
- `extensions/lib/orgm-extensions.ts` — count active/discoverable extensions.

This keeps `orgm.ts` authoritative without making it a large, tangled file.

### SDD/TDD agent layout
Create:

```text
config/shared/.pi/agent/agents/sdd-orchestrator/
  index.md
  sdd-init.md
  sdd-explore.md
  sdd-proposal.md
  sdd-spec.md
  sdd-design.md
  sdd-tasks.md
  sdd-apply.md
  sdd-verify.md
  sdd-archive.md
  tdd-brainstormer.md
  tdd-planner.md
  tdd-implementer.md
  tdd-reviewer.md
  tdd-verifier.md
  tdd-worktree-manager.md
```

Move:
- `assets/orchestrator.md` → `agents/sdd-orchestrator/index.md`
- `assets/agents/sdd-*.md` → `agents/sdd-orchestrator/sdd-*.md`
- `agents/tdd-orgm/tdd-*.md` → `agents/sdd-orchestrator/tdd-*.md`

Remove:
- `assets/agents/` after move
- `agents/tdd-orgm/` after move

Update `agents/teams.yaml`:
- remove `tdd-orgm` team;
- add/expand `sdd-orchestrator` team with SDD and TDD members.

### SDD chains and support
Keep shared assets:

```text
config/shared/.pi/agent/assets/chains/sdd-full.chain.md
config/shared/.pi/agent/assets/chains/sdd-plan.chain.md
config/shared/.pi/agent/assets/chains/sdd-verify.chain.md
config/shared/.pi/agent/assets/support/strict-tdd.md
config/shared/.pi/agent/assets/support/strict-tdd-verify.md
```

Update chains so phases target agents under `agents/sdd-orchestrator/` and no longer depend on `assets/agents` or `gentle-ai` naming.

Update `lib/sdd-preflight.ts` to stop using `.pi/gentle-ai/...`; use ORGM/SDD config names instead.

Update `extensions/sdd-init.ts`:
- remove import from `gentle-ai.ts`;
- reference current layout: `agents/sdd-orchestrator`, `assets/chains`, `assets/support`;
- if model/persona config helper is still needed, move helper to `extensions/lib/orgm-config.ts` or `extensions/lib/orgm-flow.ts`.

### Extensions to remove/enable
Enable:
- `extensions/subagents.ts.disabled` → `extensions/subagents.ts`

Remove:
- `extensions/gentle-ai.ts`
- `extensions/skill-registry.ts`
- generated `.atl` cache/registry files inside `extensions/` if present and tracked/unwanted.

### Lenovo host config
Create:

```text
config/hosts/lenovo/.pi/agent/orgm.json
```

Content:

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

Add `.pi/agent/orgm.json` to `hosts.lenovo.paths` in `config/dotfiles.json`.

Default `autoCommitCompletedWork` should start as `false` until the extension has explicit session approval for automatic commits. This protects against surprise commits while keeping the policy configurable.

### New git extension
Create `config/shared/.pi/agent/extensions/git.ts`.

Responsibilities:
- on session/project start, detect if cwd is inside git;
- if not in git and host config allows `autoInit`, initialize git unless cwd is blocked;
- blocked roots:
  - `$HOME` exactly;
  - `~/Nextcloud` and children;
  - any configured `git.ignoreRoots`;
- for long work, recommend worktree flow and require approval before creating worktree;
- at process completion, suggest commit with concise message;
- only auto-commit when host config allows it and user has approved auto-commit for the session;
- never run destructive git operations without explicit confirmation.

### Model selector Esc bug
Investigate and fix `config/shared/.pi/agent/extensions/agent-selector.ts` and possibly `model-primary.ts`.

Observed likely root cause:
- `agent-selector.ts` handles `"\u001B"` only, but terminal Esc can arrive as different key payloads or be swallowed by `SelectList.handleInput` depending on mode.
- In model mode Esc currently only returns to agent list, not cancel/close. User expectation: Esc should exit cleanly when stuck, not trap the menu.

Design:
- Add shared `isEscapeKey(data: string)` helper for `"\u001B"`, `"escape"`, `"Escape"`, and non-arrow escape sequences as needed.
- In both agent list and model list modes:
  - first Esc closes menu if no filter/state needs clearing;
  - optional secondary behavior may clear filter only when typing filter exists, but must allow repeated Esc to close;
  - never pass bare Esc to `SelectList.handleInput` after already handling it.
- Update help text to show `Esc cancel/close`.
- Add regression test or minimal harness script if test framework exists; otherwise document manual verification.

## Acceptance Criteria
- `sdd-orchestrator` exists under `agents/` and contains SDD + TDD subagents.
- Old `assets/agents` and `agents/tdd-orgm` are gone.
- `gentle-ai.ts` and `skill-registry.ts` are removed.
- `subagents.ts` is enabled.
- `sdd-init.ts`, chains, support references, and `sdd-preflight.ts` use new layout/naming.
- Lenovo has `.pi/agent/orgm.json` tracked and dotfiles config includes it.
- `orgm.ts` reports extension count accurately.
- `git.ts` guards non-git directories and skips `$HOME`/Nextcloud.
- Model/subagent selector closes with Esc.
- `./dot.sh diff --host lenovo` shows expected Pi changes only.

## Risks
- Removing `gentle-ai.ts` may break commands currently used by muscle memory (`/gentle-ai:*`). Keep aliases in `orgm.ts` only if needed.
- Pi extension APIs may not expose all lifecycle hooks needed for “process completed”; implement conservative command/session hooks first.
- Auto git init/commit is risky; keep blocked roots and session approval strict.
- Large file moves may hide behavior changes; verify with git diff using rename detection.
