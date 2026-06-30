# Pi Ask Awareness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build shared Pi extensions `ask.ts` and `awareness.ts`, plus `ask.jsonc`, to replace the external ask package and inject startup environment context.

**Architecture:** Use two standalone TypeScript extensions under `config/shared/.pi/agent/extensions`. `awareness.ts` gathers environment data with Node APIs and `git` subprocesses, then injects one custom context message on new sessions. `ask.ts` registers `ask_user_question`, implements a small TUI questionnaire, and gates only agent `bash` calls using regex rules loaded from JSONC.

**Tech Stack:** Pi extension API, `@earendil-works/pi-tui`, `typebox`, Node built-ins, orgm-dot.

---

## File structure

- Create `config/shared/.pi/agent/extensions/awareness.ts` — new-session environment collection and message injection.
- Create `config/shared/.pi/agent/extensions/ask.ts` — `ask_user_question` tool and bash gate.
- Create `config/shared/.pi/agent/ask.jsonc` — example/live YOLO-by-default gate config.
- Modify `config/dotfiles.json` — add `.pi/agent/ask.jsonc` to `shared.paths`.

## Task 1: Add awareness extension

**Files:**
- Create: `config/shared/.pi/agent/extensions/awareness.ts`

- [ ] **Step 1: Write the extension**

Create `config/shared/.pi/agent/extensions/awareness.ts` with this content:

```ts
import { execFile } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { promisify } from "node:util";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const execFileAsync = promisify(execFile);
const CUSTOM_TYPE = "awareness";

async function runGit(args: string[], cwd: string): Promise<string> {
  try {
    const { stdout } = await execFileAsync("git", args, { cwd, timeout: 2000 });
    return stdout.trim();
  } catch {
    return "";
  }
}

function readOsPrettyName(): string {
  try {
    const raw = readFileSync("/etc/os-release", "utf8");
    const match = raw.match(/^PRETTY_NAME=(.*)$/m);
    if (!match) return "unknown";
    return match[1]!.replace(/^['\"]|['\"]$/g, "");
  } catch {
    return "unknown";
  }
}

function containerMarker(): string {
  if (existsSync("/.dockerenv")) return "docker";
  return process.env.container || "none";
}

export async function buildAwarenessText(ctx: Pick<ExtensionContext, "cwd">): Promise<string> {
  const gitRoot = (await runGit(["rev-parse", "--show-toplevel"], ctx.cwd)) || "no git";
  const branch = await runGit(["branch", "--show-current"], ctx.cwd);
  return [
    `pwd: ${ctx.cwd}`,
    `git: ${gitRoot}`,
    `branch: ${branch}`,
    `tmux: ${process.env.TMUX ? "yes" : "no"}`,
    `nix-shell: ${process.env.IN_NIX_SHELL ? "yes" : "no"}`,
    `container markers: ${containerMarker()}`,
    `os: ${readOsPrettyName()}`,
  ].join("\n");
}

function alreadyInjected(ctx: ExtensionContext): boolean {
  return ctx.sessionManager.getEntries().some((entry: any) =>
    entry?.type === "custom" && entry?.customType === CUSTOM_TYPE
  );
}

function isNewSessionReason(reason: unknown): boolean {
  return reason === "startup" || reason === "new";
}

export default function (pi: ExtensionAPI) {
  pi.registerMessageRenderer(CUSTOM_TYPE, (message, _options, theme) => {
    const { Text } = require("@earendil-works/pi-tui") as typeof import("@earendil-works/pi-tui");
    return new Text(theme.fg("muted", "awareness\n") + String(message.content ?? ""), 0, 0);
  });

  pi.on("session_start", async (event: { reason?: string }, ctx: ExtensionContext) => {
    if (!isNewSessionReason(event.reason)) return;
    if (alreadyInjected(ctx)) return;

    const content = await buildAwarenessText(ctx);
    pi.sendMessage({
      customType: CUSTOM_TYPE,
      content,
      display: true,
      details: { source: "startup-awareness" },
    }, { deliverAs: "nextTurn" });
  });
}
```

- [ ] **Step 2: Run syntax sanity check**

Run:

```bash
node --check config/shared/.pi/agent/extensions/awareness.ts
```

Expected: Node may reject TypeScript syntax. If so, run the Pi/Jiti check instead:

```bash
pi -p --extension ./config/shared/.pi/agent/extensions/awareness.ts "respond ok" --no-builtin-tools
```

Expected: extension loads; no import/runtime error from `awareness.ts`.

- [ ] **Step 3: Commit**

```bash
git add config/shared/.pi/agent/extensions/awareness.ts
git commit -m "feat: add pi awareness extension"
```

## Task 2: Add ask config and dotfiles tracking

**Files:**
- Create: `config/shared/.pi/agent/ask.jsonc`
- Modify: `config/dotfiles.json`

- [ ] **Step 1: Create ask.jsonc**

Create `config/shared/.pi/agent/ask.jsonc`:

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

- [ ] **Step 2: Track ask.jsonc in shared paths**

Modify `config/dotfiles.json` and add this entry near other `.pi/agent/*` shared paths:

```json
".pi/agent/ask.jsonc",
```

- [ ] **Step 3: Verify JSON still parses**

Run:

```bash
node -e 'JSON.parse(require("fs").readFileSync("config/dotfiles.json","utf8")); console.log("ok")'
```

Expected: `ok`.

- [ ] **Step 4: Commit**

```bash
git add config/shared/.pi/agent/ask.jsonc config/dotfiles.json
git commit -m "config: add pi ask command gates"
```

## Task 3: Add ask extension

**Files:**
- Create: `config/shared/.pi/agent/extensions/ask.ts`

- [ ] **Step 1: Write ask.ts**

Create `config/shared/.pi/agent/extensions/ask.ts`. The implementation must include:

```ts
import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Editor, type EditorTheme, Key, matchesKey, Text, truncateToWidth } from "@earendil-works/pi-tui";
import { Type } from "typebox";
```

Define constants and schemas:

```ts
const MAX_QUESTIONS = 4;
const MIN_OPTIONS = 2;
const MAX_OPTIONS = 4;
const ASK_CONFIG = join(homedir(), ".pi", "agent", "ask.jsonc");

const OptionSchema = Type.Object({
  label: Type.String({ maxLength: 60 }),
  description: Type.String(),
  preview: Type.Optional(Type.String()),
});

const QuestionSchema = Type.Object({
  question: Type.String(),
  header: Type.String({ maxLength: 16 }),
  options: Type.Array(OptionSchema, { minItems: MIN_OPTIONS, maxItems: MAX_OPTIONS }),
  multiSelect: Type.Optional(Type.Boolean()),
});

const QuestionParamsSchema = Type.Object({
  questions: Type.Array(QuestionSchema, { minItems: 1, maxItems: MAX_QUESTIONS }),
});
```

Implement JSONC helpers:

```ts
type ConfirmRule = { name: string; match: string; message?: string };
type AskConfig = { bash?: { confirm?: ConfirmRule[] } };

export function stripJsonc(input: string): string {
  return input
    .replace(/\/\*[\s\S]*?\*\//g, "")
    .replace(/(^|\s)\/\/.*$/gm, "$1");
}

export function loadAskConfig(path = ASK_CONFIG): AskConfig {
  if (!existsSync(path)) return {};
  try {
    return JSON.parse(stripJsonc(readFileSync(path, "utf8"))) as AskConfig;
  } catch {
    return {};
  }
}

function matchingRule(command: string, config: AskConfig): ConfirmRule | undefined {
  for (const rule of config.bash?.confirm ?? []) {
    try {
      if (new RegExp(rule.match, "i").test(command)) return rule;
    } catch {
      continue;
    }
  }
  return undefined;
}
```

Implement questionnaire state types and a `runQuestionnaire(ctx, params)` custom UI using the official `questionnaire.ts` example as the base:

- tab/arrow navigation between questions and Submit tab
- up/down option navigation
- enter to select single option
- space to toggle multi-select option
- enter on multi-select question to save selected labels
- `Type something.` editor for single-select only
- `Chat about this` sentinel for single-select only
- escape cancels

Return details with this shape:

```ts
type Answer = {
  questionIndex: number;
  question: string;
  kind: "option" | "custom" | "chat" | "multi";
  answer: string | null;
  selected?: string[];
  preview?: string;
};
type QuestionnaireResult = { answers: Answer[]; cancelled: boolean; error?: string };
```

Register the extension:

```ts
export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName !== "bash") return;
    const command = String((event.input as { command?: unknown }).command ?? "");
    const rule = matchingRule(command, loadAskConfig());
    if (!rule) return;
    if (!ctx.hasUI) return { block: true, reason: `Command matched ask rule: ${rule.name}` };
    const ok = await ctx.ui.confirm(`Confirm command: ${rule.name}`, `${rule.message ?? "Allow command?"}\n\n${command}`);
    if (!ok) return { block: true, reason: "Blocked by ask.ts" };
  });

  pi.registerTool({
    name: "ask_user_question",
    label: "Ask User Question",
    description: "Ask the user one or more structured questions with tabs, multi-select, and text answers.",
    promptSnippet: "Ask the user up to 4 structured questions when requirements are ambiguous",
    promptGuidelines: [
      "Use ask_user_question when the user's request is underspecified and you need concrete decisions.",
      "Group related questions in one ask_user_question call instead of stacking multiple calls.",
      "Use multiSelect when multiple answers are valid; otherwise allow the user to pick an option, type an answer, or chat about it.",
    ],
    parameters: QuestionParamsSchema,
    async execute(_id, params, _signal, _onUpdate, ctx) {
      if (!ctx.hasUI) {
        return { content: [{ type: "text", text: "Error: UI not available" }], details: { answers: [], cancelled: true, error: "no_ui" } };
      }
      return runQuestionnaire(ctx, params as any);
    },
    renderCall(args, theme) {
      const count = Array.isArray((args as any).questions) ? (args as any).questions.length : 0;
      return new Text(theme.fg("toolTitle", theme.bold("ask_user_question ")) + theme.fg("muted", `${count} question(s)`), 0, 0);
    },
    renderResult(result, _options, theme) {
      const details = result.details as QuestionnaireResult | undefined;
      if (!details || details.cancelled) return new Text(theme.fg("warning", "Cancelled"), 0, 0);
      return new Text(details.answers.map((a) => `${theme.fg("success", "✓")} ${a.question}: ${a.selected?.join(", ") ?? a.answer ?? "chat"}`).join("\n"), 0, 0);
    },
  });
}
```

- [ ] **Step 2: Sanity-load extension**

Run:

```bash
pi -p --extension ./config/shared/.pi/agent/extensions/ask.ts "respond ok" --no-builtin-tools
```

Expected: extension loads; no import/runtime error from `ask.ts`.

- [ ] **Step 3: Commit**

```bash
git add config/shared/.pi/agent/extensions/ask.ts
git commit -m "feat: add lightweight pi ask extension"
```

## Task 4: Verify dotfiles sync diff

**Files:**
- No code changes expected unless verification finds a defect.

- [ ] **Step 1: Check managed diff**

Run:

```bash
orgm-dot diff --host orgm
```

Expected: diff shows `ask.ts`, `awareness.ts`, `ask.jsonc`, and `dotfiles.json` changes intended for shared config.

- [ ] **Step 2: Do not sync unless user asks**

Do not run `orgm-dot sync --host orgm` without explicit user approval.

## Self-review

Spec coverage:

- `awareness.ts` new-session context injection: Task 1.
- `ask.ts` replacement tool: Task 3.
- `ask.jsonc` YOLO-by-default bash gate config: Task 2 and Task 3.
- Shared dotfiles tracking: Task 2.
- Verification with orgm-dot diff: Task 4.

Placeholder scan: no placeholder markers remain.

Type consistency: `QuestionnaireResult`, `Answer`, config rule names, and file paths are consistent across tasks.
