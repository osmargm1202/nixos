# Spec Delta: Hyprland Lua and orgm-hypr migration

## ADDED Requirements

### Requirement: Migration inventory and classification

The migration plan MUST inventory each in-scope Hyprland-adjacent file or entrypoint and classify it as exactly one primary owner: Hyprland Lua module, `orgm-hypr` command/subcommand, retained script, or deferred/plugin. Each classification MUST include behavior domain, current path, proposed owner, migration rationale, parity checks, rollback notes, and review-slice assignment. Items with uncertain side effects MUST be marked deferred or retained until the side effects are verified.

#### Scenario: classify all in-scope entries before implementation

- Given files under `config/shared/.config/hypr/**`, `config/shared/.config/hypr/scripts/**`, `config/shared/.local/bin/hypr-*`, `config/shared/.local/bin/fuzzel-*`, Hyprland-tied OSD/Waybar helpers, and the `orgm-hypr` Go module
- When the migration inventory is prepared
- Then every discovered file or entrypoint is listed with one primary owner
- And each listed item includes behavior domain, rationale, parity checks, rollback notes, and review-slice assignment
- And no implementation slice starts while any discovered in-scope item lacks classification or an explicit deferral reason

#### Scenario: preserve undocumented behavior until verified

- Given an existing script or config entry has side effects that are not understood
- When the item is classified
- Then the item is retained or deferred
- And the classification records what evidence is required before it can move to Lua or `orgm-hypr`

### Requirement: Hyprland Lua ownership criteria

Compositor-local behavior SHOULD be owned by Hyprland Lua when it concerns bindings, dispatchers, events, timers, rules, workspace logic, monitor logic, window actions, or reusable compositor action modules. Hyprland Lua modules MUST remain fast, non-blocking, and safe to load during compositor startup or reload. Hyprland Lua MUST NOT own long-running shell pipelines, network calls, interactive menus, blocking prompts, package/build operations, or flows that can freeze compositor responsiveness unless later validation proves a non-blocking integration.

#### Scenario: route compositor-local behavior to Lua

- Given a behavior only reads or changes compositor-local state through Hyprland-supported Lua APIs
- When the item is classified
- Then the proposed owner is Hyprland Lua unless a documented API/runtime limitation blocks it
- And the classification identifies the Lua module or domain that will own it

#### Scenario: reject blocking compositor Lua

- Given a behavior launches an interactive menu, waits on subprocess output, performs network or disk-heavy work, or can block for user input
- When the item is classified for possible Lua migration
- Then Hyprland Lua is rejected as primary owner unless a later design specifies an asynchronous/non-blocking boundary
- And the item is classified as `orgm-hypr`, retained script, or deferred with rationale

### Requirement: `orgm-hypr` ownership criteria

External session orchestration SHOULD be owned by `orgm-hypr` when it benefits from typed code, focused tests, reusable CLI actions, structured error handling, or composition as stable subcommands. `orgm-hypr` commands MUST expose user-visible behavior with documented arguments, exit status expectations, and safe failure behavior. Go changes MUST have focused tests where practical, and untestable host/runtime dependencies MUST be isolated behind interfaces or documented as validation-only.

#### Scenario: route typed orchestration to orgm-hypr

- Given a behavior coordinates system tools, parses structured state, applies reusable decision logic, or needs testable error handling outside the compositor
- When the item is classified
- Then the proposed owner is an `orgm-hypr` command or subcommand
- And the classification records expected CLI inputs, outputs, failures, and test approach

#### Scenario: validate command parity

- Given a script behavior is replaced by an `orgm-hypr` subcommand
- When the implementation slice is verified later
- Then the new command preserves the documented user-facing behavior or records an approved intentional change
- And focused Go tests pass or documented runtime blockers explain why validation is manual

### Requirement: Retained script criteria

Scripts SHOULD be retained when they remain the simplest and safest interface for interactive launchers, fuzzel/menu flows, subprocess wrappers, compositor-agnostic Unix glue, or compatibility entrypoints used by external tools. Retained scripts MUST have explicit rationale, expected dependencies, and ownership boundaries. Retained scripts MUST NOT be kept only by omission from the inventory.

#### Scenario: retain interactive launcher wrapper

- Given an existing helper primarily opens fuzzel or another interactive menu
- When the item is classified
- Then it is retained as a script unless a later design provides an equal or safer non-blocking replacement
- And the rationale records why Lua or `orgm-hypr` is not the primary owner

#### Scenario: retain compatibility entrypoint intentionally

- Given an existing path is referenced by keybindings, Waybar, desktop files, or user muscle memory
- When underlying behavior migrates to Lua or `orgm-hypr`
- Then the path is either preserved as a compatibility wrapper or removed only after parity and caller updates are verified
- And the removal or wrapper decision is documented in the slice plan

### Requirement: Deprecation and removal safety

Existing scripts, config entries, and entrypoints MUST NOT be removed or behaviorally changed until equivalent replacement behavior is implemented, validated, and assigned a rollback path. Deprecations MUST be staged: additive replacement first, caller migration second, cleanup last. Any removal MUST list previous path, replacement path or command, affected callers, validation evidence, and rollback action.

#### Scenario: additive replacement before cleanup

- Given a behavior is planned to move from a standalone script to Lua or `orgm-hypr`
- When the first implementation slice for that behavior is planned
- Then the replacement is introduced alongside the existing entrypoint
- And the existing entrypoint remains available until callers and parity checks pass

#### Scenario: remove only after validated parity

- Given a script has a proposed replacement
- When a cleanup slice removes or shrinks it
- Then the slice includes evidence that callers use the replacement
- And the slice includes a rollback step that restores the previous path or behavior without unrelated changes

### Requirement: Behavior parity and user-visible preservation

Each migration slice MUST preserve current user-visible Hyprland behavior unless an intentional change is explicitly approved in a later design or task. Parity checks MUST cover keybindings, launcher flows, workspace/monitor/window behavior, OSD/Waybar interactions, startup/reload behavior, and failure messages for affected domains.

#### Scenario: verify domain parity after slice

- Given an implementation slice migrates a behavior domain
- When validation is run for that slice
- Then affected user-visible actions still work through their documented entrypoints
- And any changed behavior is listed as approved scope rather than accidental drift

#### Scenario: preserve core behavior during partial migration

- Given only some behavior domains have migrated
- When the user starts or reloads Hyprland
- Then unmigrated domains continue to use existing scripts/config paths
- And migrated domains do not break unrelated keybindings, launchers, Waybar modules, OSD helpers, or session startup

### Requirement: Rollback path

Every implementation slice MUST include a rollback path that restores previous script/config behavior for that slice without broad unrelated changes. Rollback MUST prefer reverting the slice, re-enabling old callers, or restoring compatibility wrappers. The plan MUST keep old scripts/config paths until replacement behavior is validated.

#### Scenario: rollback failed Lua migration

- Given a Lua module migration causes startup, reload, or runtime failure
- When rollback is needed
- Then the old hyprlang/script behavior can be restored by reverting that slice or disabling the Lua entrypoint/module
- And unrelated dotfiles remain unchanged

#### Scenario: rollback failed orgm-hypr migration

- Given an `orgm-hypr` replacement fails validation or runtime use
- When rollback is needed
- Then callers can return to the previous script path or compatibility wrapper
- And the failed subcommand can remain unused or be reverted without removing unrelated commands

### Requirement: Validation evidence

Later implementation and verification phases MUST record validation evidence for affected slices. Required validation SHOULD include `nix flake check`, `nix fmt`, focused `orgm-hypr` build/test commands, Hyprland Lua entrypoint/module loading on Hyprland 0.55+ or documented runtime blocker, and `orgm-dot diff --host orgm` showing only expected managed dotfile changes. `orgm-dot sync --host orgm` MUST NOT run during spec/design phases and MUST only run during later implementation/verification when applying managed dotfiles is intentional.

#### Scenario: validation commands are recorded

- Given a slice changes managed dotfiles, Lua modules, scripts, or `orgm-hypr`
- When the slice reaches verification
- Then validation output or documented blockers are recorded for the relevant required commands
- And `orgm-dot diff --host orgm` shows only expected changes before any sync is considered

#### Scenario: Lua runtime blocked by local version

- Given local Hyprland cannot load the planned Lua entrypoint or lacks required 0.55+ runtime support
- When Lua validation is attempted
- Then the blocker is documented with observed error or version evidence
- And destructive replacement of existing behavior is blocked until compatible runtime validation is available

### Requirement: Review slicing

Implementation MUST be planned as reviewable slices within the 400 changed-line review budget. If forecasted or actual changes exceed the budget, work MUST split into chained slices that preserve behavior after each slice. Slices SHOULD follow inventory/test harness, Lua foundation, compositor behavior domains, `orgm-hypr` CLI domains, script cleanup, and docs/verification. Each slice MUST have acceptance checks and rollback notes.

#### Scenario: split oversized migration

- Given the forecasted migration exceeds 400 changed lines
- When tasks are planned
- Then the work is split into chained review slices
- And each slice is independently reviewable, validates behavior, and can be rolled back

#### Scenario: cleanup follows validated replacements

- Given scripts are candidates for removal or simplification
- When review slices are ordered
- Then cleanup occurs after inventory, foundation, replacement, caller migration, and parity validation
- And retained wrappers are documented instead of removed opportunistically
