# Pi Todo Extension Design

## Goal

Replace `npm:@juicesharp/rpiv-todo` with a shared, lightweight-but-complete Pi extension at `config/shared/.pi/agent/extensions/todo.ts`.

## Scope

The extension provides the same practical user-facing features needed from `rpiv-todo`:

- `todo` tool for task mutations and queries.
- `/todos` command for a grouped task summary.
- Live overlay above the editor.
- In-session state that survives `/reload` and compaction by replaying previous `todo` tool results from the current branch.
- Task dependencies via `blockedBy` with cycle detection.
- Status state machine with tombstoned deletes.

No `@juicesharp/*` dependency is allowed.

## Public Tool API

Tool name: `todo`.

Actions:

- `create`
- `update`
- `list`
- `get`
- `delete`
- `clear`

Task fields:

- `id: number`
- `subject: string`
- `description?: string`
- `activeForm?: string`
- `status: "pending" | "in_progress" | "completed" | "deleted"`
- `blockedBy?: number[]`
- `owner?: string`
- `metadata?: Record<string, unknown>`

Input fields:

- `action` — required.
- `subject` — required for `create`.
- `description`, `activeForm`, `owner`, `metadata` — create/update.
- `status` — update target or list filter.
- `blockedBy` — create-only initial dependencies.
- `addBlockedBy`, `removeBlockedBy` — update-only additive dependency changes.
- `id` — required for `get`, `update`, `delete`.
- `includeDeleted` — list includes tombstones when true.

## Behavior Rules

### Status transitions

Allowed:

- `pending -> in_progress`
- `in_progress -> pending`
- `pending -> completed`
- `in_progress -> completed`
- any non-deleted status -> `deleted`

Disallowed:

- `completed -> pending`
- `completed -> in_progress`
- `deleted -> anything`

`delete` is a tombstone operation: set status to `deleted`; do not remove the task from the stored list.

### Dependencies

- `blockedBy` task IDs must refer to existing non-deleted tasks.
- A task may not block itself.
- Dependency graph must not contain cycles.
- `addBlockedBy` and `removeBlockedBy` update dependencies additively; callers must not resend the full list.

### In-progress discipline

The tool should allow only one task to be `in_progress` at a time. When updating one task to `in_progress`, any other currently in-progress task should move back to `pending` unless it is completed/deleted.

## State and Replay

The extension keeps state in memory:

```ts
{
  tasks: Task[];
  nextId: number;
}
```

Every successful or validation-error tool result returns a full snapshot under `details`:

```ts
{
  action: TaskAction;
  params: Record<string, unknown>;
  tasks: Task[];
  nextId: number;
  error?: string;
}
```

On `session_start` and reload, `todo.ts` reconstructs state by scanning the current branch for the latest `toolResult` message where `toolName === "todo"` and `details.tasks` / `details.nextId` are present.

This keeps state scoped to the conversation branch and avoids writing extra state files.

## Overlay

The overlay uses `ctx.ui.setWidget("orgm-todos", ..., { placement: "aboveEditor" })`.

Rendering rules:

- Hide when there are no visible tasks.
- Show heading: `Todos (completed/total)`.
- Show status icons:
  - pending: `○`
  - in_progress: `◐`
  - completed: `✓`
- Hide `deleted` tasks.
- Completed tasks may remain visible briefly, but the first version may keep them visible until cleared/list changes if that keeps the code simpler.
- Limit to about 12 lines and show `+N more` when truncated.

## Slash Command

Command: `/todos`

Behavior:

- In interactive mode, notify grouped tasks by status.
- If no visible tasks exist, notify `No todos yet.`
- Groups:
  - Pending
  - In Progress
  - Completed

## Rendering

The tool should implement `renderCall` and `renderResult` for compact readable display.

Examples:

- Call: `todo create: Write spec`
- Result: `✓ #1 Write spec [pending]`
- List: multiple compact lines.

## File Plan

Create one file:

- `config/shared/.pi/agent/extensions/todo.ts`

Modify configuration only after the extension is verified:

- remove `npm:@juicesharp/rpiv-todo` from `~/.pi/agent/settings.json` via `pi remove npm:@juicesharp/rpiv-todo`, or manually from managed settings if later added to dotfiles.

## Testing / Verification

Manual and import verification are acceptable for the first version:

1. Load extension with Pi in print mode or temporary `--extension` run.
2. Verify `todo create` returns task snapshot.
3. Verify `todo update` changes status.
4. Verify only one task can be `in_progress`.
5. Verify cycle detection rejects cyclic `blockedBy`.
6. Verify `delete` tombstones task.
7. Verify `/todos` works in interactive mode.
8. Verify overlay appears when tasks exist.
9. Verify `/reload` reconstructs state from the branch.
10. After verification, remove `npm:@juicesharp/rpiv-todo` and reload.

## Out of Scope

- i18n.
- Exact visual parity with `rpiv-todo`.
- Disk persistence outside Pi session history.
- Multiple todo lists per session.
