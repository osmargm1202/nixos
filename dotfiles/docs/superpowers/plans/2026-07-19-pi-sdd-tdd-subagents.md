# Pi SDD and TDD Subagents Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install 14 globally available, dotfiles-managed Pi subagents for general planning/building plus explicit SDD and TDD phase workflows.

**Architecture:** Store direct Markdown definitions under `dotfiles/config/shared/.pi/agent/subagents/`, configure isolated execution and role effort in adjacent `subagents.json`, and expose both through Home Manager `sharedPaths` in `nixos/common-dotfiles.nix`. A focused shell/Python contract test drives each catalog slice before deployment; Pi runtime discovery is verified only after `/reload`.

**Tech Stack:** Pi Markdown subagent definitions, `pi-subagents-j0k3r`, JSON, Bash, Python 3, NixOS/Home Manager out-of-store symlinks.

## Global Constraints

- Create exactly 14 direct Markdown definitions: `planner`, `builder`, eight `sdd-*` roles, and four `tdd-*` roles.
- Keep legacy `dotfiles/config/shared/.pi/agent/agents/` unchanged.
- Keep `dotfiles/config/dotfiles.json` unchanged; its `shared` and `hosts` sections are legacy.
- Register `.pi/agent/subagents` and `.pi/agent/subagents.json` only in `nixos/common-dotfiles.nix` under `sharedPaths`.
- Use `session_resources: "lean"` and `debug: false`.
- Inherit the active orchestrator model; model profiles set only `effort`.
- Never allow any `subagent_*` tool in a subagent allowlist.
- Do not grant memory tools to these subagents; the orchestrator passes explicit context and artifact paths.
- Reviewers and verifiers are read-only: no `write` or `edit` tools.
- `tdd-builder` owns the complete RED → GREEN → REFACTOR cycle.
- Subagents never delegate to other subagents.
- Do not commit unrelated dirty files already present in the monorepo.
- Do not use `git commit --amend`; other Pi sessions may commit concurrently.

## File Map

### Create

- `dotfiles/tests/helpers/pi-subagents.bats.sh` — focused static contract tests for each agent group, config, and Home Manager registration.
- `dotfiles/config/shared/.pi/agent/subagents.json` — global runtime isolation, shortcuts, concurrency, and role-based effort profiles.
- `dotfiles/config/shared/.pi/agent/subagents/planner.md` — general read-only implementation planner.
- `dotfiles/config/shared/.pi/agent/subagents/builder.md` — general single-task implementation worker.
- `dotfiles/config/shared/.pi/agent/subagents/sdd-explorer.md` — SDD discovery phase.
- `dotfiles/config/shared/.pi/agent/subagents/sdd-spec.md` — SDD normative requirements phase.
- `dotfiles/config/shared/.pi/agent/subagents/sdd-design.md` — SDD technical design phase.
- `dotfiles/config/shared/.pi/agent/subagents/sdd-plan.md` — SDD implementation strategy phase.
- `dotfiles/config/shared/.pi/agent/subagents/sdd-tasks.md` — SDD task decomposition phase.
- `dotfiles/config/shared/.pi/agent/subagents/sdd-builder.md` — SDD one-task implementation phase.
- `dotfiles/config/shared/.pi/agent/subagents/sdd-reviewer.md` — SDD task-scoped spec and quality review.
- `dotfiles/config/shared/.pi/agent/subagents/sdd-verifier.md` — SDD final acceptance verification.
- `dotfiles/config/shared/.pi/agent/subagents/tdd-planner.md` — TDD behavior-cycle planning.
- `dotfiles/config/shared/.pi/agent/subagents/tdd-builder.md` — strict RED/GREEN/REFACTOR implementation.
- `dotfiles/config/shared/.pi/agent/subagents/tdd-reviewer.md` — TDD evidence and code-quality review.
- `dotfiles/config/shared/.pi/agent/subagents/tdd-verifier.md` — independent final TDD verification.

### Modify

- `nixos/common-dotfiles.nix` — add the two global Pi paths to `sharedPaths` beside existing `.pi/agent/*` entries.

---

### Task 1: Add executable catalog contract test

**Files:**
- Create: `dotfiles/tests/helpers/pi-subagents.bats.sh`

**Interfaces:**
- Consumes: planned agent names, role classes, exact tool contracts, and config fields from the approved design.
- Produces: `bash dotfiles/tests/helpers/pi-subagents.bats.sh <group>` with groups `generic`, `sdd-planning`, `sdd-execution`, `tdd`, `deployment`, and `all`.

- [ ] **Step 1: Create the contract test**

Create `dotfiles/tests/helpers/pi-subagents.bats.sh` with this exact content:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SUBAGENTS="$ROOT/config/shared/.pi/agent/subagents"
CONFIG="$ROOT/config/shared/.pi/agent/subagents.json"
NIX_MODULE="$ROOT/../nixos/common-dotfiles.nix"
GROUP=${1:-all}

python3 - "$GROUP" "$SUBAGENTS" "$CONFIG" "$NIX_MODULE" <<'PY'
import json
import re
import sys
from pathlib import Path

group, subagents_arg, config_arg, nix_arg = sys.argv[1:]
subagents = Path(subagents_arg)
config_path = Path(config_arg)
nix_module = Path(nix_arg)

groups = {
    "generic": ["planner", "builder"],
    "sdd-planning": ["sdd-explorer", "sdd-spec", "sdd-design", "sdd-plan", "sdd-tasks"],
    "sdd-execution": ["sdd-builder", "sdd-reviewer", "sdd-verifier"],
    "tdd": ["tdd-planner", "tdd-builder", "tdd-reviewer", "tdd-verifier"],
}
expected = [name for names in groups.values() for name in names]
readonly = {
    "planner", "sdd-explorer", "sdd-reviewer", "sdd-verifier",
    "tdd-reviewer", "tdd-verifier",
}
artifact_writers = {"sdd-spec", "sdd-design", "sdd-plan", "sdd-tasks", "tdd-planner"}
builders = {"builder", "sdd-builder", "tdd-builder"}
required_navigation = {"read", "grep", "find", "ls", "bash", "symbol_search", "module_report", "read_symbol", "read_enclosing"}
required_diagnostics = {"lsp_diagnostics", "lens_diagnostics"}


def fail(message: str) -> None:
    raise AssertionError(message)


def parse_agent(name: str) -> tuple[dict[str, str], list[str], str]:
    path = subagents / f"{name}.md"
    if not path.is_file():
        fail(f"missing agent definition: {path}")
    text = path.read_text()
    lines = text.splitlines()
    if not lines or lines[0] != "---":
        fail(f"missing opening frontmatter delimiter: {path}")
    try:
        end = lines.index("---", 1)
    except ValueError:
        fail(f"missing closing frontmatter delimiter: {path}")
    metadata: dict[str, str] = {}
    tools: list[str] = []
    in_tools = False
    for line in lines[1:end]:
        if line == "tools:":
            in_tools = True
            continue
        if in_tools and line.startswith("  - "):
            tools.append(line[4:])
            continue
        in_tools = False
        match = re.fullmatch(r"([A-Za-z_][A-Za-z0-9_]*):\s*(.*)", line)
        if match:
            metadata[match.group(1)] = match.group(2)
    body = "\n".join(lines[end + 1:]).strip()
    return metadata, tools, body


def check_agent(name: str) -> None:
    metadata, tools, body = parse_agent(name)
    if metadata.get("name") != name:
        fail(f"{name}: frontmatter name mismatch")
    if not metadata.get("description"):
        fail(f"{name}: missing trigger-focused description")
    if not tools:
        fail(f"{name}: empty tool allowlist")
    if any(tool.startswith("subagent_") for tool in tools):
        fail(f"{name}: subagent delegation tool is forbidden")
    missing_navigation = required_navigation - set(tools)
    if missing_navigation:
        fail(f"{name}: missing navigation tools {sorted(missing_navigation)}")
    if name in readonly and ({"write", "edit"} & set(tools)):
        fail(f"{name}: read-only role contains write/edit")
    if name in artifact_writers and not {"write", "edit"}.issubset(tools):
        fail(f"{name}: artifact writer requires write and edit")
    if name in builders:
        required = {"write", "edit"} | required_diagnostics
        if not required.issubset(tools):
            fail(f"{name}: builder missing {sorted(required - set(tools))}")
    if name in {"sdd-reviewer", "sdd-verifier", "tdd-reviewer", "tdd-verifier"}:
        if not required_diagnostics.issubset(tools):
            fail(f"{name}: reviewer/verifier missing diagnostics")
    context7 = {"context7_resolve-library-id", "context7_query-docs"}
    if name == "sdd-explorer" and not context7.issubset(tools):
        fail("sdd-explorer: missing Context7 tools")
    if name != "sdd-explorer" and context7 & set(tools):
        fail(f"{name}: Context7 must be limited to sdd-explorer")
    for marker in ("## Boundaries", "## Output contract", "next_recommended"):
        if marker not in body:
            fail(f"{name}: missing body contract marker {marker}")
    if "subagent_*" not in body:
        fail(f"{name}: missing explicit no-delegation rule")


def check_config() -> None:
    if not config_path.is_file():
        fail(f"missing config: {config_path}")
    config = json.loads(config_path.read_text())
    if config.get("session_resources") != "lean":
        fail("subagents.json: session_resources must be lean")
    if config.get("debug") is not False:
        fail("subagents.json: debug must be false")
    if config.get("default_tools") != ["read"]:
        fail("subagents.json: default_tools must be ['read']")
    profiles = config.get("model_profiles")
    if not isinstance(profiles, dict) or set(profiles) != set(expected):
        fail("subagents.json: model_profiles must match all 14 agents exactly")
    medium = {"sdd-explorer", "sdd-tasks", "sdd-verifier", "tdd-verifier"}
    for name, profile in profiles.items():
        wanted = "medium" if name in medium else "high"
        if profile != {"effort": wanted}:
            fail(f"subagents.json: {name} profile must be effort={wanted} only")


def check_deployment() -> None:
    if not nix_module.is_file():
        fail(f"missing Nix module: {nix_module}")
    text = nix_module.read_text()
    for path in (".pi/agent/subagents", ".pi/agent/subagents.json"):
        marker = f'"{path}"'
        if text.count(marker) != 1:
            fail(f"common-dotfiles.nix: expected exactly one {marker}")


if group not in {*groups, "deployment", "all"}:
    fail(f"unknown group: {group}")

if group == "all":
    check_config()
    for name in expected:
        check_agent(name)
    check_deployment()
elif group == "deployment":
    check_deployment()
else:
    if group == "generic":
        check_config()
    for name in groups[group]:
        check_agent(name)

print(f"pi subagents contract passed: {group}")
PY
```

- [ ] **Step 2: Make test executable**

Run:

```bash
chmod +x dotfiles/tests/helpers/pi-subagents.bats.sh
```

Expected: command exits `0`.

- [ ] **Step 3: Run generic group to verify RED**

Run:

```bash
bash dotfiles/tests/helpers/pi-subagents.bats.sh generic
```

Expected: non-zero exit with `missing config` or `missing agent definition`; global subagent files do not exist yet.

- [ ] **Step 4: Commit test only**

```bash
git add dotfiles/tests/helpers/pi-subagents.bats.sh
git commit -m "test(pi): define global subagent contracts"
```

Expected: new commit contains only the test script.

---

### Task 2: Add global config and generic agents

**Files:**
- Create: `dotfiles/config/shared/.pi/agent/subagents.json`
- Create: `dotfiles/config/shared/.pi/agent/subagents/planner.md`
- Create: `dotfiles/config/shared/.pi/agent/subagents/builder.md`
- Test: `dotfiles/tests/helpers/pi-subagents.bats.sh`

**Interfaces:**
- Consumes: current Pi model/effort inheritance and explicit delegated task/context.
- Produces: generic `planner` and `builder` definitions plus all 14 role effort profiles.

- [ ] **Step 1: Re-run focused test to confirm RED**

Run:

```bash
bash dotfiles/tests/helpers/pi-subagents.bats.sh generic
```

Expected: FAIL because `subagents.json`, `planner.md`, or `builder.md` is missing.

- [ ] **Step 2: Create global subagent config**

Create `dotfiles/config/shared/.pi/agent/subagents.json`:

```json
{
  "mode": "opencode",
  "timeout_ms": 1200000,
  "stall_timeout_ms": 240000,
  "max_concurrency": 5,
  "debug": false,
  "session_resources": "lean",
  "history_panel_shortcut": "ctrl+,",
  "detail_cancel_shortcut": "x",
  "background_handoff_shortcut": "ctrl+h",
  "default_tools": [
    "read"
  ],
  "model_profiles": {
    "planner": { "effort": "high" },
    "builder": { "effort": "high" },
    "sdd-explorer": { "effort": "medium" },
    "sdd-spec": { "effort": "high" },
    "sdd-design": { "effort": "high" },
    "sdd-plan": { "effort": "high" },
    "sdd-tasks": { "effort": "medium" },
    "sdd-builder": { "effort": "high" },
    "sdd-reviewer": { "effort": "high" },
    "sdd-verifier": { "effort": "medium" },
    "tdd-planner": { "effort": "high" },
    "tdd-builder": { "effort": "high" },
    "tdd-reviewer": { "effort": "high" },
    "tdd-verifier": { "effort": "medium" }
  }
}
```

- [ ] **Step 3: Create generic planner**

Create `dotfiles/config/shared/.pi/agent/subagents/planner.md`:

```markdown
---
name: planner
description: Use for planning one general implementation task when full SDD or TDD ceremony is not required.
tools:
  - read
  - grep
  - find
  - ls
  - bash
  - symbol_search
  - module_report
  - read_symbol
  - read_enclosing
---

# General Planner

Create a concrete implementation plan for one bounded task. Explore enough code to identify exact files, interfaces, risks, and verification commands. Do not implement.

## Boundaries

- Remain read-only. Use `bash` only for inspection; never mutate files, Git index, HEAD, or branches.
- Never call or request `subagent_*` tools. The main agent owns delegation.
- Prefer existing project patterns. Do not add SDD ceremony to small work.
- If requirements are ambiguous, return `NEEDS_CONTEXT` instead of guessing.

## Process

1. Restate goal and acceptance criteria.
2. Inspect relevant files and tests.
3. Produce an ordered file map and small executable steps.
4. Include exact validation commands and expected outcomes.
5. Route behavior changes to TDD in the plan.

## Output contract

Return `status`, `executive_summary`, `artifacts`, `verification`, `risks`, and `next_recommended`. Use `DONE`, `DONE_WITH_CONCERNS`, `NEEDS_CONTEXT`, or `BLOCKED`. Set `next_recommended` to `builder` when plan is executable.
```

- [ ] **Step 4: Create generic builder**

Create `dotfiles/config/shared/.pi/agent/subagents/builder.md`:

```markdown
---
name: builder
description: Use for implementing one approved general task outside strict SDD or TDD workflows.
tools:
  - read
  - grep
  - find
  - ls
  - bash
  - write
  - edit
  - symbol_search
  - module_report
  - read_symbol
  - read_enclosing
  - lsp_diagnostics
  - lens_diagnostics
---

# General Builder

Implement exactly one approved task in the supplied working directory. Keep changes small, follow existing patterns, test the behavior, and report evidence.

## Boundaries

- Never call or request `subagent_*` tools. The main agent owns delegation.
- Do not redesign, expand scope, or modify unrelated files.
- Do not commit unless the delegated task explicitly authorizes a commit.
- For features and bug fixes, write a failing test first, observe expected RED, implement minimal GREEN, then refactor while green.
- If requirements or repository state are unclear, return `NEEDS_CONTEXT` before editing.

## Process

1. Read the task, referenced artifacts, and affected code.
2. Capture baseline and focused RED evidence when behavior changes.
3. Implement the minimum change.
4. Run focused tests, diagnostics, then required broader checks.
5. Self-review the diff for scope, correctness, and test quality.

## Output contract

Return `status`, `executive_summary`, `artifacts`, `verification`, `risks`, and `next_recommended`. Include changed paths and exact commands/results. Use `DONE`, `DONE_WITH_CONCERNS`, `NEEDS_CONTEXT`, or `BLOCKED`. Set `next_recommended` to the main agent for review.
```

- [ ] **Step 5: Verify GREEN**

Run:

```bash
python3 -m json.tool dotfiles/config/shared/.pi/agent/subagents.json >/dev/null
bash dotfiles/tests/helpers/pi-subagents.bats.sh generic
```

Expected: both commands exit `0`; test prints `pi subagents contract passed: generic`.

- [ ] **Step 6: Commit generic catalog slice**

```bash
git add dotfiles/config/shared/.pi/agent/subagents.json \
  dotfiles/config/shared/.pi/agent/subagents/planner.md \
  dotfiles/config/shared/.pi/agent/subagents/builder.md
git commit -m "feat(pi): add generic planner and builder agents"
```

---

### Task 3: Add SDD discovery and planning agents

**Files:**
- Create: `dotfiles/config/shared/.pi/agent/subagents/sdd-explorer.md`
- Create: `dotfiles/config/shared/.pi/agent/subagents/sdd-spec.md`
- Create: `dotfiles/config/shared/.pi/agent/subagents/sdd-design.md`
- Create: `dotfiles/config/shared/.pi/agent/subagents/sdd-plan.md`
- Create: `dotfiles/config/shared/.pi/agent/subagents/sdd-tasks.md`
- Test: `dotfiles/tests/helpers/pi-subagents.bats.sh`

**Interfaces:**
- Consumes: explicit project context and artifact paths from the main orchestrator.
- Produces: phase chain `exploration → spec → design → plan → task briefs` through `next_recommended`.

- [ ] **Step 1: Verify focused RED**

Run:

```bash
bash dotfiles/tests/helpers/pi-subagents.bats.sh sdd-planning
```

Expected: FAIL naming the first missing SDD planning definition.

- [ ] **Step 2: Create `sdd-explorer.md`**

```markdown
---
name: sdd-explorer
description: Use at the first SDD step to investigate current behavior, constraints, risks, and unknowns before requirements are written.
tools:
  - read
  - grep
  - find
  - ls
  - bash
  - symbol_search
  - module_report
  - read_symbol
  - read_enclosing
  - context7_resolve-library-id
  - context7_query-docs
---

# SDD Explorer

Investigate one proposed change without editing or committing to a solution. Return evidence another isolated agent can use without repeating broad exploration.

## Boundaries

- Remain read-only. Use `bash` only for inspection.
- Never call or request `subagent_*` tools.
- Use Context7 only when library behavior needs authoritative external documentation.
- Separate facts, assumptions, risks, and open questions.
- Return `NEEDS_CONTEXT` when a missing decision prevents useful exploration.

## Deliverable

Report current behavior, relevant files/symbols, constraints, dependencies, risks, unknowns, and suggested acceptance boundaries. Cite paths and documentation sources.

## Output contract

Return `status`, `executive_summary`, `artifacts`, `verification`, `risks`, and `next_recommended`. Use the four standard statuses. Set `next_recommended` to `sdd-spec` when evidence is sufficient.
```

- [ ] **Step 3: Create `sdd-spec.md`**

```markdown
---
name: sdd-spec
description: Use after SDD exploration to write normative, testable requirements and observable acceptance scenarios.
tools:
  - read
  - grep
  - find
  - ls
  - bash
  - write
  - edit
  - symbol_search
  - module_report
  - read_symbol
  - read_enclosing
---

# SDD Spec Writer

Convert approved exploration and user decisions into precise requirements. Write only the artifact path supplied by the orchestrator.

## Boundaries

- Never call or request `subagent_*` tools.
- Use `bash` only for inspection.
- Do not design architecture or implement production code.
- Limit `write` and `edit` to the requested spec artifact.
- Do not invent behavior; return `NEEDS_CONTEXT` for unresolved requirements.

## Deliverable

Define scope, non-goals, RFC 2119 requirements, Given/When/Then scenarios, compatibility constraints, errors, and measurable acceptance criteria. Every scenario must be observable and verifiable.

## Output contract

Return `status`, `executive_summary`, `artifacts`, `verification`, `risks`, and `next_recommended`. Include the exact written path. Set `next_recommended` to `sdd-design` when requirements are complete.
```

- [ ] **Step 4: Create `sdd-design.md`**

```markdown
---
name: sdd-design
description: Use after SDD requirements are approved to design architecture, interfaces, data flow, errors, tests, and rollout.
tools:
  - read
  - grep
  - find
  - ls
  - bash
  - write
  - edit
  - symbol_search
  - module_report
  - read_symbol
  - read_enclosing
---

# SDD Designer

Design the smallest technical approach that satisfies the approved spec. Write only the design artifact path supplied by the orchestrator.

## Boundaries

- Never call or request `subagent_*` tools.
- Use `bash` only for inspection.
- Do not implement production code.
- Limit `write` and `edit` to the requested design artifact.
- Preserve project patterns and state explicit tradeoffs.

## Deliverable

Document components, responsibilities, interfaces, data flow, error handling, file structure, testing strategy, migration or rollout, risks, and rejected alternatives. Resolve design choices before planning; return `NEEDS_CONTEXT` for human decisions.

## Output contract

Return `status`, `executive_summary`, `artifacts`, `verification`, `risks`, and `next_recommended`. Include the exact written path. Set `next_recommended` to `sdd-plan` when design is actionable.
```

- [ ] **Step 5: Create `sdd-plan.md`**

```markdown
---
name: sdd-plan
description: Use after SDD design approval to create an implementation strategy, file map, dependencies, and exact verification sequence.
tools:
  - read
  - grep
  - find
  - ls
  - bash
  - write
  - edit
  - symbol_search
  - module_report
  - read_symbol
  - read_enclosing
---

# SDD Planner

Translate approved spec and design into an executable implementation strategy. Write only the plan artifact path supplied by the orchestrator.

## Boundaries

- Never call or request `subagent_*` tools.
- Use `bash` only for inspection.
- Do not implement production code.
- Limit `write` and `edit` to the requested plan artifact.
- Keep the plan within approved scope and identify dependency order.

## Deliverable

Provide goal, constraints, exact file map, interfaces between work units, test-first sequence, commands with expected outcomes, rollback boundaries, and commit/review boundaries. Do not leave placeholders.

## Output contract

Return `status`, `executive_summary`, `artifacts`, `verification`, `risks`, and `next_recommended`. Include the exact written path. Set `next_recommended` to `sdd-tasks` when strategy is complete.
```

- [ ] **Step 6: Create `sdd-tasks.md`**

```markdown
---
name: sdd-tasks
description: Use after SDD planning to split the approved plan into dependency-ordered, independently verifiable builder tasks.
tools:
  - read
  - grep
  - find
  - ls
  - bash
  - write
  - edit
  - symbol_search
  - module_report
  - read_symbol
  - read_enclosing
---

# SDD Task Decomposer

Convert one approved plan into small task briefs suitable for fresh isolated builders. Write only the tasks artifact path supplied by the orchestrator.

## Boundaries

- Never call or request `subagent_*` tools.
- Use `bash` only for inspection.
- Do not implement production code.
- Limit `write` and `edit` to the requested tasks artifact.
- One task must be executable and reviewable without the full conversation.

## Deliverable

For each task include purpose, exact files, input artifacts, produced interfaces, RED/GREEN verification, dependencies, acceptance criteria, and report path. Order tasks sequentially and split oversized work.

## Output contract

Return `status`, `executive_summary`, `artifacts`, `verification`, `risks`, and `next_recommended`. Include the exact written path and first ready task. Set `next_recommended` to `sdd-builder`.
```

- [ ] **Step 7: Verify GREEN**

Run:

```bash
bash dotfiles/tests/helpers/pi-subagents.bats.sh sdd-planning
```

Expected: `pi subagents contract passed: sdd-planning`.

- [ ] **Step 8: Commit SDD planning slice**

```bash
git add dotfiles/config/shared/.pi/agent/subagents/sdd-explorer.md \
  dotfiles/config/shared/.pi/agent/subagents/sdd-spec.md \
  dotfiles/config/shared/.pi/agent/subagents/sdd-design.md \
  dotfiles/config/shared/.pi/agent/subagents/sdd-plan.md \
  dotfiles/config/shared/.pi/agent/subagents/sdd-tasks.md
git commit -m "feat(pi): add SDD planning phase agents"
```

---

### Task 4: Add SDD build, review, and verification agents

**Files:**
- Create: `dotfiles/config/shared/.pi/agent/subagents/sdd-builder.md`
- Create: `dotfiles/config/shared/.pi/agent/subagents/sdd-reviewer.md`
- Create: `dotfiles/config/shared/.pi/agent/subagents/sdd-verifier.md`
- Test: `dotfiles/tests/helpers/pi-subagents.bats.sh`

**Interfaces:**
- Consumes: one SDD task brief, approved spec/design, implementer report, and diff/review package paths.
- Produces: task implementation, independent task review, and final acceptance evidence.

- [ ] **Step 1: Verify focused RED**

Run:

```bash
bash dotfiles/tests/helpers/pi-subagents.bats.sh sdd-execution
```

Expected: FAIL naming a missing SDD execution definition.

- [ ] **Step 2: Create `sdd-builder.md`**

```markdown
---
name: sdd-builder
description: Use to implement exactly one approved SDD task with test-first evidence and a bounded report.
tools:
  - read
  - grep
  - find
  - ls
  - bash
  - write
  - edit
  - symbol_search
  - module_report
  - read_symbol
  - read_enclosing
  - lsp_diagnostics
  - lens_diagnostics
---

# SDD Builder

Implement exactly one supplied SDD task against its approved spec, design, and task brief. Preserve completed work and keep the diff inside task boundaries.

## Boundaries

- Never call or request `subagent_*` tools.
- Do not redesign, broaden scope, or start another task.
- Do not commit unless the delegated task explicitly authorizes it.
- For behavior changes, capture expected RED before production code, then minimal GREEN and safe REFACTOR.
- Return `NEEDS_CONTEXT` before editing when inputs conflict or are incomplete.

## Process

1. Read task brief and referenced artifacts.
2. Record baseline and RED evidence.
3. Implement minimal scope.
4. Run focused tests, diagnostics, and required broader checks.
5. Self-review and write the requested report artifact.

## Output contract

Return `status`, `executive_summary`, `artifacts`, `verification`, `risks`, and `next_recommended`. Report changed files, exact RED/GREEN commands/results, and concerns. Use the four standard statuses. Set `next_recommended` to `sdd-reviewer` only when work is ready for independent review.
```

- [ ] **Step 3: Create `sdd-reviewer.md`**

```markdown
---
name: sdd-reviewer
description: Use after each SDD builder task to review spec compliance and code quality without modifying the checkout.
tools:
  - read
  - grep
  - find
  - ls
  - bash
  - symbol_search
  - module_report
  - read_symbol
  - read_enclosing
  - lsp_diagnostics
  - lens_diagnostics
---

# SDD Reviewer

Review one task-scoped diff against its task brief, approved spec/design constraints, and builder report. Treat the builder report as unverified claims.

## Boundaries

- Remain read-only. Never mutate files, Git index, HEAD, or branches.
- Never call or request `subagent_*` tools.
- Use `bash` for read-only inspection and focused validation only.
- Do not broaden into whole-branch review.
- Do not fix findings.

## Review contract

Return separate verdicts for spec compliance and task quality. Cite file and line evidence. Classify findings as Critical, Important, or Minor. Check missing/extra behavior, test quality, error handling, scope, architecture fit, and maintainability.

## Output contract

Return `status`, `executive_summary`, `artifacts`, `verification`, `risks`, and `next_recommended`. Use `DONE` only when both verdicts pass. Set `next_recommended` to `sdd-builder` for Critical/Important fixes, the next task's `sdd-builder` when more tasks remain, or `sdd-verifier` after the final clean task review.
```

- [ ] **Step 4: Create `sdd-verifier.md`**

```markdown
---
name: sdd-verifier
description: Use after all SDD task reviews pass to run final acceptance, regression, diagnostics, and evidence checks without fixing issues.
tools:
  - read
  - grep
  - find
  - ls
  - bash
  - symbol_search
  - module_report
  - read_symbol
  - read_enclosing
  - lsp_diagnostics
  - lens_diagnostics
---

# SDD Verifier

Verify completed work against approved requirements, task completion, review outcomes, and required commands. Produce fresh evidence immediately before any completion claim.

## Boundaries

- Remain read-only. Never mutate files, Git index, HEAD, or branches.
- Never call or request `subagent_*` tools.
- Run declared validation commands exactly and report failures verbatim.
- Do not repair defects or weaken acceptance criteria.
- Return `BLOCKED` when any required gate fails.

## Verification contract

Check requirement coverage, completed task/review status, focused and full tests, diagnostics, clean test output, TDD evidence where required, and scope boundaries. Distinguish verified facts from unavailable checks.

## Output contract

Return `status`, `executive_summary`, `artifacts`, `verification`, `risks`, and `next_recommended`. Include exact commands and outcomes. Set `next_recommended` to `sdd-builder` for a confirmed defect or `complete` only when every required gate passes.
```

- [ ] **Step 5: Verify GREEN**

Run:

```bash
bash dotfiles/tests/helpers/pi-subagents.bats.sh sdd-execution
```

Expected: `pi subagents contract passed: sdd-execution`.

- [ ] **Step 6: Commit SDD execution slice**

```bash
git add dotfiles/config/shared/.pi/agent/subagents/sdd-builder.md \
  dotfiles/config/shared/.pi/agent/subagents/sdd-reviewer.md \
  dotfiles/config/shared/.pi/agent/subagents/sdd-verifier.md
git commit -m "feat(pi): add SDD execution gate agents"
```

---

### Task 5: Add strict TDD agents

**Files:**
- Create: `dotfiles/config/shared/.pi/agent/subagents/tdd-planner.md`
- Create: `dotfiles/config/shared/.pi/agent/subagents/tdd-builder.md`
- Create: `dotfiles/config/shared/.pi/agent/subagents/tdd-reviewer.md`
- Create: `dotfiles/config/shared/.pi/agent/subagents/tdd-verifier.md`
- Test: `dotfiles/tests/helpers/pi-subagents.bats.sh`

**Interfaces:**
- Consumes: explicit behavior requirements and test runner commands.
- Produces: cycle plan, strict RED/GREEN/REFACTOR implementation, independent evidence review, and final verification.

- [ ] **Step 1: Verify focused RED**

Run:

```bash
bash dotfiles/tests/helpers/pi-subagents.bats.sh tdd
```

Expected: FAIL naming a missing TDD definition.

- [ ] **Step 2: Create `tdd-planner.md`**

```markdown
---
name: tdd-planner
description: Use before strict TDD implementation to split behavior into minimal RED, GREEN, and REFACTOR cycles with exact commands.
tools:
  - read
  - grep
  - find
  - ls
  - bash
  - write
  - edit
  - symbol_search
  - module_report
  - read_symbol
  - read_enclosing
---

# TDD Planner

Convert approved behavior requirements into a sequence of minimal test-first cycles. Write only the plan artifact path supplied by the orchestrator.

## Boundaries

- Never call or request `subagent_*` tools.
- Use `bash` only for inspection.
- Do not write production code or tests during planning.
- Limit `write` and `edit` to the requested plan artifact.
- Return `NEEDS_CONTEXT` when desired behavior or test runner is unclear.

## Deliverable

For each behavior specify the test file, test name, expected RED reason/output, minimal GREEN target, REFACTOR boundary, exact focused command, and broader regression command. Keep each cycle independent and ordered.

## Output contract

Return `status`, `executive_summary`, `artifacts`, `verification`, `risks`, and `next_recommended`. Include the exact written path. Set `next_recommended` to `tdd-builder` when every cycle is executable.
```

- [ ] **Step 3: Create `tdd-builder.md`**

```markdown
---
name: tdd-builder
description: Use to implement one approved behavior through the complete strict RED, GREEN, and REFACTOR cycle.
tools:
  - read
  - grep
  - find
  - ls
  - bash
  - write
  - edit
  - symbol_search
  - module_report
  - read_symbol
  - read_enclosing
  - lsp_diagnostics
  - lens_diagnostics
---

# TDD Builder

Implement one approved behavior. No production code may be written before a test has failed for the expected missing behavior.

## Boundaries

- Never call or request `subagent_*` tools.
- Own the complete RED → GREEN → REFACTOR cycle; do not hand off between phases.
- Do not commit unless explicitly authorized.
- Do not change a valid test merely to accommodate an implementation.
- If a test passes immediately, errors instead of failing, or requirements are unclear, stop and correct RED or return `NEEDS_CONTEXT`.

## Cycle

1. Write one behavioral test using real code.
2. Run it and record expected RED.
3. Implement the minimum production change.
4. Run focused and regression tests for GREEN.
5. Refactor only while all tests remain green.
6. Run diagnostics and self-review.

## Output contract

Return `status`, `executive_summary`, `artifacts`, `verification`, `risks`, and `next_recommended`. Evidence must include exact RED command/output/reason, GREEN command/output, refactor verification, and changed paths. Set `next_recommended` to `tdd-reviewer` only after a valid complete cycle.
```

- [ ] **Step 4: Create `tdd-reviewer.md`**

```markdown
---
name: tdd-reviewer
description: Use after a TDD builder cycle to audit test-first evidence, behavioral test quality, minimal implementation, and maintainability.
tools:
  - read
  - grep
  - find
  - ls
  - bash
  - symbol_search
  - module_report
  - read_symbol
  - read_enclosing
  - lsp_diagnostics
  - lens_diagnostics
---

# TDD Reviewer

Review one completed TDD cycle and diff. Verify evidence rather than trusting the builder summary.

## Boundaries

- Remain read-only. Never mutate files, Git index, HEAD, or branches.
- Never call or request `subagent_*` tools.
- Use `bash` only for read-only inspection or one focused check tied to a concrete doubt.
- Do not fix findings.
- Missing valid RED evidence is an Important or Critical finding, not a documentation nit.

## Review contract

Check that the test failed for the intended missing behavior, tests real behavior instead of mocks, GREEN is minimal, edge cases match requirements, refactor stayed green, output is pristine, and no scope creep occurred. Cite file and line evidence.

## Output contract

Return `status`, `executive_summary`, `artifacts`, `verification`, `risks`, and `next_recommended`. Classify findings as Critical, Important, or Minor. Set `next_recommended` to `tdd-builder` for blocking fixes or `tdd-verifier` when review passes.
```

- [ ] **Step 5: Create `tdd-verifier.md`**

```markdown
---
name: tdd-verifier
description: Use after TDD review passes to run fresh focused and regression checks and verify complete test-first evidence without editing.
tools:
  - read
  - grep
  - find
  - ls
  - bash
  - symbol_search
  - module_report
  - read_symbol
  - read_enclosing
  - lsp_diagnostics
  - lens_diagnostics
---

# TDD Verifier

Run final independent verification for completed TDD work immediately before completion is claimed.

## Boundaries

- Remain read-only. Never mutate files, Git index, HEAD, or branches.
- Never call or request `subagent_*` tools.
- Run exact focused and broader commands; report failures verbatim.
- Do not fix code, tests, or evidence.
- Return `BLOCKED` when RED evidence is absent or any required GREEN gate fails.

## Verification contract

Cross-check reported RED evidence with changed tests, run focused tests and required regression suites, run diagnostics, confirm clean output, and verify tests cover observable behavior. State unavailable checks explicitly.

## Output contract

Return `status`, `executive_summary`, `artifacts`, `verification`, `risks`, and `next_recommended`. Include exact commands/results. Set `next_recommended` to `tdd-builder` for confirmed defects or `complete` only when all gates pass.
```

- [ ] **Step 6: Verify GREEN**

Run:

```bash
bash dotfiles/tests/helpers/pi-subagents.bats.sh tdd
```

Expected: `pi subagents contract passed: tdd`.

- [ ] **Step 7: Commit TDD slice**

```bash
git add dotfiles/config/shared/.pi/agent/subagents/tdd-planner.md \
  dotfiles/config/shared/.pi/agent/subagents/tdd-builder.md \
  dotfiles/config/shared/.pi/agent/subagents/tdd-reviewer.md \
  dotfiles/config/shared/.pi/agent/subagents/tdd-verifier.md
git commit -m "feat(pi): add strict TDD phase agents"
```

---

### Task 6: Register Home Manager paths and verify complete catalog

**Files:**
- Modify: `nixos/common-dotfiles.nix` in the `sharedPaths` list beside existing `.pi/agent/*` entries.
- Test: `dotfiles/tests/helpers/pi-subagents.bats.sh`

**Interfaces:**
- Consumes: complete 14-agent source catalog and global config.
- Produces: Home Manager symlinks at `~/.pi/agent/subagents` and `~/.pi/agent/subagents.json`.

- [ ] **Step 1: Verify deployment RED**

Run:

```bash
bash dotfiles/tests/helpers/pi-subagents.bats.sh deployment
```

Expected: FAIL with `common-dotfiles.nix: expected exactly one ".pi/agent/subagents"`.

- [ ] **Step 2: Register both shared paths**

In `nixos/common-dotfiles.nix`, change the Pi block in `sharedPaths` to this exact content:

```nix
    ".pi/agent/AGENTS.md"
    ".pi/agent/RTK.md"
    ".pi/agent/ask.jsonc"
    ".pi/agent/subagents"
    ".pi/agent/subagents.json"
```

Do not modify `dotfiles/config/dotfiles.json`.

- [ ] **Step 3: Verify static GREEN**

Run:

```bash
bash dotfiles/tests/helpers/pi-subagents.bats.sh deployment
bash dotfiles/tests/helpers/pi-subagents.bats.sh all
python3 -m json.tool dotfiles/config/shared/.pi/agent/subagents.json >/dev/null
git diff --check
```

Expected:

```text
pi subagents contract passed: deployment
pi subagents contract passed: all
```

JSON and `git diff --check` exit `0`.

- [ ] **Step 4: Verify no legacy manifest or agent changes**

Run:

```bash
git diff --name-only 2f79b79..HEAD -- dotfiles/config/dotfiles.json dotfiles/config/shared/.pi/agent/agents
```

Expected: no output. If execution starts from a different base, substitute the recorded implementation base commit.

- [ ] **Step 5: Commit deployment registration**

```bash
git add nixos/common-dotfiles.nix
git commit -m "feat(pi): deploy global subagent catalog"
```

Expected: commit contains only `nixos/common-dotfiles.nix`.

- [ ] **Step 6: Run Nix/Home Manager deployment**

Run from `/home/osmarg/Hobby/nixos`:

```bash
nh os switch
```

Expected: NixOS/Home Manager switch succeeds and creates both new symlinks. If unrelated pre-existing Nix failures block the switch, record exact output and do not claim deployment success.

- [ ] **Step 7: Verify deployed symlink targets**

Run:

```bash
readlink -f ~/.pi/agent/subagents
readlink -f ~/.pi/agent/subagents.json
```

Expected exact targets:

```text
/home/osmarg/Hobby/nixos/dotfiles/config/shared/.pi/agent/subagents
/home/osmarg/Hobby/nixos/dotfiles/config/shared/.pi/agent/subagents.json
```

- [ ] **Step 8: Reload Pi and verify runtime discovery**

In the active Pi session, run:

```text
/reload
```

Then call `subagent_list_agents`.

Expected: all 14 unique names are listed:

```text
planner
builder
sdd-explorer
sdd-spec
sdd-design
sdd-plan
sdd-tasks
sdd-builder
sdd-reviewer
sdd-verifier
tdd-planner
tdd-builder
tdd-reviewer
tdd-verifier
```

Do not run a builder merely to test discovery. Optional smoke test: delegate a read-only planning question to `planner` in `mode=task`.

- [ ] **Step 9: Final repository verification**

Run:

```bash
bash dotfiles/tests/helpers/pi-subagents.bats.sh all
git status --short
git log --oneline --decorate -8
```

Expected: catalog test passes; status shows only known unrelated pre-existing changes; new commits are separate and no `--amend` rewrote concurrent commits.
