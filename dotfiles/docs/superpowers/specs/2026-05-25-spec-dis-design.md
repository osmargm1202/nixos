# spec-dis Pi Extension Design

## Goal

Create a Pi extension named `spec-dis.ts` that lets the user read generated specs, designs, and task documents inside Pi without opening files manually.

## User Requirements

- Provide an `alt+4` shortcut that opens a list of existing spec/design/task documents.
- Show each document by a readable name and modification date.
- Let the user select a document and render it inside Pi.
- Automatically render newly created or modified spec/design/task documents after the current agent finishes.
- If a subagent creates the document, wait until the subagent tool cycle completes before rendering.
- Avoid rendering partially written files.
- Include OpenSpec, Superpowers, and task artifacts.

## Placement

The extension will live at:

```text
config/shared/.pi/agent/extensions/spec-dis.ts
```

Because `.pi/agent/extensions` is tracked in `config/dotfiles.json`, changes will be applied to the live Pi config with:

```bash
orgm-dot sync --host orgm
```

## Approach

Use a snapshot-at-start / compare-at-end design.

At the start of an agent turn, the extension records the current candidate document files and their modification times. It does not render anything while the agent is running. At `agent_end`, it scans again and identifies new or modified candidate documents. It renders only after the agent has fully finished.

For subagents, the extension listens for completed subagent tool results (`deploy_agent` and `query_team`). After those tool results finish, it scans for new or modified candidate documents. This waits until the subagent loop has returned control to the parent session.

This avoids the main failure mode of file watchers: opening a spec while it is still being written.

## Document Discovery

The extension will scan the current project for Markdown files in common spec/design/task locations:

- `docs/superpowers/specs/**/*.md`
- `specs/**/*.md`
- `openspec/**/*.md`
- `.openspec/**/*.md`
- `sdd-orchestrator/**/*.md` when filenames or parent directories indicate spec/design/task content
- General Markdown filename matches containing `spec`, `design`, `task`, or `tasks`

The scanner will ignore noisy directories:

- `.git`
- `node_modules`
- `.venv`
- `vendor`
- cache/build output directories

## Manual UI

`alt+4` and `/spec-dis` open the same selector.

The selector will use Pi TUI `SelectList` in an overlay. Each row shows:

- document kind (`spec`, `design`, `task`, or `doc`)
- relative path or readable title
- modification date/time

The list sorts by most recently modified first.

## Renderer UI

After selection, the document opens in a Pi overlay viewer.

The viewer will:

- render Markdown using Pi TUI Markdown support where practical
- show the relative path and modification date in the header
- support scrolling with arrow keys and `j/k`
- close with `Esc` or `q`
- handle missing/deleted files with a warning notification

Long files may be displayed in a scrollable window rather than inserted into chat context.

## Auto-render Behavior

The user selected **auto-render always**.

Rules:

1. At `agent_start`, take a baseline snapshot of candidate files.
2. At `agent_end`, scan again.
3. If exactly one candidate file is new or modified, open it directly.
4. If multiple candidate files changed, open a selector limited to those changed files.
5. If no candidate file changed, do nothing.
6. When `tool_result` indicates `deploy_agent` or `query_team` completed, scan again using the latest baseline and render changed candidate documents.
7. After rendering or presenting changed candidates, update the baseline to avoid repeatedly opening the same file.

## Error Handling

- If the extension runs without UI, it does nothing except avoid throwing.
- File read failures show a notification and return to Pi.
- Empty candidate lists show a warning notification.
- If a document changes again while the viewer is open, the viewer keeps the opened content stable for the current read.

## Testing / Verification

Manual verification will cover:

1. `/reload` loads the extension without errors.
2. `alt+4` opens a selector of existing specs/designs/tasks.
3. Selecting a document opens the Markdown viewer.
4. Viewer scroll and close keys work.
5. Creating or modifying a matching spec during an agent turn opens it after `agent_end`.
6. A subagent-created spec is rendered only after the subagent tool result completes.
7. No rendering occurs for unrelated Markdown files.

## Non-goals

- No continuous file watcher.
- No editing specs from the viewer.
- No model summarization of specs.
- No persistent user settings in the first version.
