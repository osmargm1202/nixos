# Pi Ask + Awareness Extensions Design

## Goal

Replace `@juicesharp/rpiv-ask-user-question` with a lightweight shared Pi extension and add an `awareness.ts` extension that injects environment context at the start of new sessions.

## Scope

This design covers two shared dotfiles artifacts:

- `config/shared/.pi/agent/extensions/ask.ts`
- `config/shared/.pi/agent/extensions/awareness.ts`

And one shared configuration file:

- `config/shared/.pi/agent/ask.jsonc`

The existing `config/dotfiles.json` already tracks `.pi/agent/extensions`, so new extension files under that directory will sync as shared config. `ask.jsonc` must also be tracked by adding `.pi/agent/ask.jsonc` to `shared.paths` unless a broader tracked path already covers it.

## Environment Awareness Extension

### Behavior

`awareness.ts` runs only when Pi starts a fresh/new session, not when resuming an existing session.

At session start it gathers:

```bash
printf 'pwd: '; pwd
printf 'git: '; git rev-parse --show-toplevel 2>/dev/null || echo 'no git'
printf 'branch: '; git branch --show-current 2>/dev/null || true
printf 'tmux: '; [ -n "$TMUX" ] && echo yes || echo no
printf 'nix-shell: '; [ -n "$IN_NIX_SHELL" ] && echo yes || echo no
printf 'container markers: '; if [ -f /.dockerenv ]; then echo docker; elif [ -n "$container" ]; then echo "$container"; else echo none; fi
printf 'os: '; . /etc/os-release && echo "$PRETTY_NAME"
```

It injects the result as an initial context message so the agent knows:

- current working directory
- whether it is in a git repo and branch
- whether tmux/nix-shell/container markers are present
- detected OS

### Session rule

The extension should inject only for new sessions. It should not duplicate awareness context when:

- `/resume` opens an existing session
- `/reload` reloads extensions
- a previous branch/session already has an awareness entry

Implementation should use Pi session metadata/entries defensively: check `session_start` reason and/or existing custom entries before injecting.

### Message shape

Use a displayed custom message, for example:

```ts
pi.sendMessage({
  customType: "awareness",
  content: "...command output...",
  display: true,
  details: { source: "startup-awareness" },
}, { deliverAs: "nextTurn" });
```

If this does not participate in model context as desired, use the documented message injection mechanism available for extension messages in the current Pi API.

## Ask Extension

### Behavior

`ask.ts` replaces the installed npm package `@juicesharp/rpiv-ask-user-question` for the needed subset.

It provides:

1. A custom tool named `ask_user_question`.
2. A bash confirmation gate configured by `ask.jsonc`.

### Bash gate

Only agent `bash` tool calls are gated. User `!` / `!!` commands are out of scope.

Default behavior is YOLO: if a bash command does not match `ask.jsonc`, it runs without asking.

When a rule matches, the extension asks for confirmation. If no UI is available, block the matched command by default.

### Example config

`config/shared/.pi/agent/ask.jsonc` should be an example and live config:

```jsonc
{
  // YOLO by default: commands not matched here run without asking.
  "bash": {
    "confirm": [
      {
        "name": "dangerous delete",
        "match": "\\brm\\s+(-rf?|--recursive)\\b",
        "message": "Este comando puede borrar archivos. ¿Permitir?"
      },
      {
        "name": "sudo",
        "match": "\\bsudo\\b",
        "message": "Este comando usa sudo. ¿Permitir?"
      },
      {
        "name": "permission changes",
        "match": "\\b(chmod|chown)\\b",
        "message": "Este comando cambia permisos o propietarios. ¿Permitir?"
      }
    ]
  }
}
```

### Questionnaire tool

The tool keeps the current public name and a compatible enough schema:

- `questions`: 1 to 4 questions
- each question has:
  - `question`
  - `header`
  - `options` with `label`, `description`, optional `preview`
  - optional `multiSelect`

UI behavior:

- Single question: option list.
- Multiple questions: tabbed TUI.
- Single-select: includes `Type something.` and `Chat about this` sentinel rows.
- Multi-select: supports selecting multiple options and submitting them.
- Optional previews may be shown in a simple side pane or compact preview block, but full parity with the npm package is not required.

### Output format

Return a concise text answer for the LLM and structured details:

```ts
{
  answers: [
    {
      questionIndex: 0,
      question: "...",
      kind: "option" | "custom" | "chat" | "multi",
      answer: "..." | null,
      selected?: string[],
      preview?: string
    }
  ],
  cancelled: boolean,
  error?: string
}
```

## Architecture

Keep implementation lightweight:

- Prefer single-file extensions.
- Use only Pi/Pi-TUI APIs and Node built-ins.
- Avoid package dependencies from `@juicesharp/*`.
- Parse JSONC locally with a small comment stripper rather than adding dependencies.
- Use `ctx.ui.custom()` for grouped questions.
- Use `ctx.ui.select()` or `ctx.ui.confirm()` for bash confirmations.

## Error Handling

- Invalid `ask.jsonc`: notify in UI and fall back to YOLO, except do not crash Pi.
- Invalid regex rule: skip that rule and notify once.
- Matched dangerous command with no UI: block by default.
- `ask_user_question` with no UI: return a structured `no_ui` error.
- Empty/invalid questionnaire: return structured validation errors.

## Testing / Verification

Manual verification is acceptable for the first version:

1. Run type/import sanity check if available.
2. Start Pi with the shared extension loaded.
3. Confirm `awareness.ts` injects context in a new session.
4. Confirm `awareness.ts` does not duplicate context after `/resume` or `/reload`.
5. Trigger `bash` with a safe command and verify it runs without prompt.
6. Trigger `bash` with a configured match and verify confirmation appears.
7. Call `ask_user_question` with one question.
8. Call `ask_user_question` with multiple questions and multi-select.
9. Run `orgm-dot diff --host orgm` before syncing.

## Out of Scope

- Full visual parity with `@juicesharp/rpiv-ask-user-question`.
- i18n integration.
- Gating `user_bash` (`!` / `!!`).
- Gating non-bash tools in this first version.
