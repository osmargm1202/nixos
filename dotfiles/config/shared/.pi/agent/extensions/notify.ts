import { spawn, spawnSync } from "node:child_process";
import { basename } from "node:path";
import type {
	AgentEndEvent,
	ExtensionAPI,
	ExtensionContext,
	ToolCallEvent,
} from "@earendil-works/pi-coding-agent";

const QUESTION_TOOL_NAMES = new Set(["ask_user_question", "question"]);
const DONE_TIMEOUT_MS = 5000;
const STICKY_TIMEOUT_MS = 0;
const MAX_BODY_LENGTH = 220;
const FOCUS_PID_HINT = "pi-focus-pid";
const KITTY_DESKTOP_ENTRY = "kitty";

type NotificationType = "question" | "done";

type NotifyCommand = {
	command: string;
	argsPrefix: string[];
};

let notifyCommandCache: NotifyCommand | null | undefined;

function isRecord(value: unknown): value is Record<string, unknown> {
	return typeof value === "object" && value !== null;
}

function cleanText(text: string): string {
	return text.replace(/\s+/g, " ").trim();
}

function truncate(text: string, maxLength = MAX_BODY_LENGTH): string {
	const clean = cleanText(text);
	if (clean.length <= maxLength) return clean;
	return `${clean.slice(0, Math.max(0, maxLength - 1))}…`;
}

function folderName(cwd: string): string {
	const trimmed = cwd.replace(/[\\/]+$/, "");
	return basename(trimmed) || trimmed || ".";
}

function isPositiveInteger(value: string | undefined): value is string {
	return typeof value === "string" && /^[1-9]\d*$/.test(value.trim());
}

function envFlag(name: string): boolean {
	const value = process.env[name]?.trim().toLowerCase();
	return value === "1" || value === "true";
}

function positiveEnvInt(name: string): boolean {
	const value = process.env[name]?.trim();
	if (!value || !/^\d+$/.test(value)) return false;
	return Number(value) > 0;
}

function isSubagentRuntime(): boolean {
	return Boolean(
		envFlag("PI_SUBAGENT_CHILD") ||
			positiveEnvInt("PI_SUBAGENT_DEPTH") ||
			process.env.PI_SUBAGENT_RUN_ID?.trim() ||
			process.env.PI_SUBAGENT_CHILD_AGENT?.trim() ||
			process.env.PI_SUBAGENT_CHILD_INDEX?.trim() ||
			process.env.PI_SUBAGENT_ORCHESTRATOR_TARGET?.trim() ||
			envFlag("PI_PDD_SUBAGENT") ||
			process.env.PI_SUBAGENT_RUNTIME_ID?.trim() ||
			positiveEnvInt("PI_SUBAGENT_RUNTIME_DEPTH") ||
			process.env.PI_SUBAGENT_PARENT_RUNTIME_ID?.trim() ||
			process.env.PI_SUBAGENT_OWNER_SESSION_FILE?.trim(),
	);
}

function getKittyPid(): string | undefined {
	const value = process.env.KITTY_PID?.trim();
	return isPositiveInteger(value) ? value : undefined;
}

function includesKitty(value: string | undefined): boolean {
	return typeof value === "string" && value.toLowerCase().includes("kitty");
}

function isKittyRuntime(): boolean {
	return Boolean(
		process.env.KITTY_PID ||
			process.env.KITTY_WINDOW_ID ||
			process.env.KITTY_LISTEN_ON ||
			includesKitty(process.env.TERM) ||
			includesKitty(process.env.TERM_PROGRAM) ||
			includesKitty(process.env.TERMINAL),
	);
}

function getNotificationHints(): string[] {
	const hints: string[] = [];
	const kittyPid = getKittyPid();

	if (kittyPid) {
		hints.push("-h", `int:${FOCUS_PID_HINT}:${kittyPid}`);
	}

	if (kittyPid || isKittyRuntime()) {
		hints.push("-h", `string:desktop-entry:${KITTY_DESKTOP_ENTRY}`);
	}

	return hints;
}

function isDistroboxRuntime(): boolean {
	return Boolean(
		process.env.DISTROBOX_ENTER_PATH ||
			process.env.DISTROBOX_HOST_HOME ||
			process.env.container === "distrobox" ||
			process.env.container === "podman" ||
			process.env.container === "docker",
	);
}

function commandExists(command: string): boolean {
	try {
		return (
			spawnSync("sh", ["-lc", `command -v ${command} >/dev/null 2>&1`], {
				stdio: "ignore",
				timeout: 500,
			}).status === 0
		);
	} catch {
		return false;
	}
}

function hostNotifySendExists(): boolean {
	try {
		return (
			spawnSync(
				"distrobox-host-exec",
				["sh", "-lc", "command -v notify-send >/dev/null 2>&1"],
				{ stdio: "ignore", timeout: 1000 },
			).status === 0
		);
	} catch {
		return false;
	}
}

function resolveNotifyCommand(): NotifyCommand | null {
	if (notifyCommandCache !== undefined) return notifyCommandCache;

	if (
		isDistroboxRuntime() &&
		commandExists("distrobox-host-exec") &&
		hostNotifySendExists()
	) {
		notifyCommandCache = {
			command: "distrobox-host-exec",
			argsPrefix: ["notify-send"],
		};
		return notifyCommandCache;
	}

	if (commandExists("notify-send")) {
		notifyCommandCache = { command: "notify-send", argsPrefix: [] };
		return notifyCommandCache;
	}

	notifyCommandCache = null;
	return notifyCommandCache;
}

function notify(
	type: NotificationType,
	ctx: ExtensionContext,
	text: string,
): void {
	try {
		const notifyCommand = resolveNotifyCommand();
		if (!notifyCommand) return;

		const folder = folderName(ctx.cwd);
		const sticky = type === "question";
		const title = `Pi ${type} · ${folder}`;
		const body = truncate(`${folder} · ${type} · ${text}`);
		const args = [
			...notifyCommand.argsPrefix,
			"-a",
			"Pi",
			"-u",
			sticky ? "critical" : "normal",
			"-t",
			String(sticky ? STICKY_TIMEOUT_MS : DONE_TIMEOUT_MS),
			...getNotificationHints(),
			title,
			body,
		];

		const child = spawn(notifyCommand.command, args, {
			detached: true,
			stdio: "ignore",
		});
		child.on("error", () => undefined);
		child.unref();
	} catch {
		// Notifications must never affect Pi tool execution.
	}
}

function getStringField(
	input: Record<string, unknown>,
	keys: string[],
): string | undefined {
	for (const key of keys) {
		const value = input[key];
		if (typeof value === "string" && value.trim()) return value;
	}
	return undefined;
}

function getQuestionText(event: ToolCallEvent): string {
	const fallback = "Pi is waiting for your answer.";
	if (!isRecord(event.input)) return fallback;

	const direct = getStringField(event.input, [
		"question",
		"prompt",
		"message",
		"text",
	]);
	if (direct) return direct;

	const questions = event.input.questions;
	if (!Array.isArray(questions)) return fallback;

	const labels = questions
		.map((question) => {
			if (!isRecord(question)) return undefined;
			return getStringField(question, ["question", "header", "title", "label"]);
		})
		.filter((question): question is string => Boolean(question));

	if (labels.length === 0) return fallback;
	if (labels.length === 1) return labels[0]!;
	return `${labels.length} questions: ${labels.slice(0, 2).join(" · ")}`;
}

function getAssistantText(event: AgentEndEvent): string {
	for (let index = event.messages.length - 1; index >= 0; index -= 1) {
		const message = event.messages[index];
		if (
			!isRecord(message) ||
			message.role !== "assistant" ||
			!Array.isArray(message.content)
		) {
			continue;
		}

		const text = message.content
			.map((part) => {
				if (!isRecord(part) || part.type !== "text") return undefined;
				return typeof part.text === "string" ? part.text : undefined;
			})
			.filter((part): part is string => Boolean(part && part.trim()))
			.join(" ");
		if (text.trim()) return text;
	}
	return "";
}

export default function (pi: ExtensionAPI) {
	pi.on("tool_call", (event, ctx) => {
		if (QUESTION_TOOL_NAMES.has(event.toolName)) {
			notify("question", ctx, getQuestionText(event));
			return undefined;
		}

		return undefined;
	});

	pi.on("agent_end", (event, ctx) => {
		if (isSubagentRuntime()) return;

		const text = getAssistantText(event);
		notify("done", ctx, text || "Agent loop finished.");
	});
}
