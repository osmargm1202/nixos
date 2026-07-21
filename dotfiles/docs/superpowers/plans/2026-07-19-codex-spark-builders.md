# Codex Spark Builder Routing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Route `builder`, `sdd-builder`, and `tdd-builder` to `openai-codex/gpt-5.3-codex-spark` while every other subagent continues inheriting the active orchestrator model.

**Architecture:** Keep model routing exclusively in global `subagents.json`. Strengthen the existing contract test first so current effort-only builder profiles fail RED, then add exact model fields and verify the complete 14-agent catalog.

**Tech Stack:** JSON, Bash, embedded Python 3, `pi-subagents-j0k3r`.

## Global Constraints

- Pin exactly `builder`, `sdd-builder`, and `tdd-builder` to `openai-codex/gpt-5.3-codex-spark`.
- Keep builder effort at `high`.
- Do not add a `model` field to the other eleven profiles.
- Do not add model or effort frontmatter to Markdown agent definitions.
- Do not change tool allowlists, prompts, Home Manager registration, or legacy agents.
- Existing out-of-store symlinks apply the source edit after merge; no `nh os switch` is required because no path is added.
- Use a new commit; never amend shared history.

---

### Task 1: Enforce and apply Codex Spark builder routing

**Files:**
- Modify: `dotfiles/tests/helpers/pi-subagents.bats.sh`
- Modify: `dotfiles/config/shared/.pi/agent/subagents.json`

**Interfaces:**
- Consumes: the 14-name `model_profiles` object and the existing `all` contract group.
- Produces: exact builder profiles `{ "model": "openai-codex/gpt-5.3-codex-spark", "effort": "high" }` and effort-only profiles for all other agents.

- [ ] **Step 1: Change the contract before configuration**

In `check_config()` within `dotfiles/tests/helpers/pi-subagents.bats.sh`, replace:

```python
    medium = {"sdd-explorer", "sdd-tasks", "sdd-verifier", "tdd-verifier"}
    for name, profile in profiles.items():
        wanted = "medium" if name in medium else "high"
        if profile != {"effort": wanted}:
            fail(f"subagents.json: {name} profile must be effort={wanted} only")
```

with:

```python
    medium = {"sdd-explorer", "sdd-tasks", "sdd-verifier", "tdd-verifier"}
    spark_builders = {"builder", "sdd-builder", "tdd-builder"}
    for name, profile in profiles.items():
        effort = "medium" if name in medium else "high"
        wanted = {"effort": effort}
        if name in spark_builders:
            wanted = {
                "model": "openai-codex/gpt-5.3-codex-spark",
                "effort": "high",
            }
        if profile != wanted:
            fail(f"subagents.json: {name} profile must equal {wanted!r}")
```

- [ ] **Step 2: Run contract to verify RED**

Run:

```bash
bash dotfiles/tests/helpers/pi-subagents.bats.sh all
```

Expected: FAIL on `builder` because its current profile lacks `model: openai-codex/gpt-5.3-codex-spark`.

- [ ] **Step 3: Add exact model routing**

In `dotfiles/config/shared/.pi/agent/subagents.json`, replace only these three profiles:

```json
"builder": { "effort": "high" }
"sdd-builder": { "effort": "high" }
"tdd-builder": { "effort": "high" }
```

with:

```json
"builder": { "model": "openai-codex/gpt-5.3-codex-spark", "effort": "high" }
"sdd-builder": { "model": "openai-codex/gpt-5.3-codex-spark", "effort": "high" }
"tdd-builder": { "model": "openai-codex/gpt-5.3-codex-spark", "effort": "high" }
```

Preserve commas and the surrounding JSON object.

- [ ] **Step 4: Verify GREEN and scope**

Run:

```bash
python3 -m json.tool dotfiles/config/shared/.pi/agent/subagents.json >/dev/null
bash -n dotfiles/tests/helpers/pi-subagents.bats.sh
bash dotfiles/tests/helpers/pi-subagents.bats.sh all
git diff --check
git diff --name-only
```

Expected:

```text
pi subagents contract passed: all
```

Changed implementation paths must be exactly:

```text
dotfiles/config/shared/.pi/agent/subagents.json
dotfiles/tests/helpers/pi-subagents.bats.sh
```

The design and this plan are separate documentation commits/changes.

- [ ] **Step 5: Commit implementation**

```bash
git add dotfiles/config/shared/.pi/agent/subagents.json \
  dotfiles/tests/helpers/pi-subagents.bats.sh
git commit -m "config(pi): use Codex Spark for builders"
```

- [ ] **Step 6: Integrate and verify runtime**

After review and user-approved merge to `master`, run `/reload` in Pi and call `subagent_list_agents`.

Expected:

- `builder`, `sdd-builder`, `tdd-builder`: model `openai-codex/gpt-5.3-codex-spark`, effort `high`.
- Other eleven agents: inherit active orchestrator model and preserve configured effort.
