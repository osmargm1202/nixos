import { StringEnum } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext, Theme } from "@earendil-works/pi-coding-agent";
import { Text, truncateToWidth } from "@earendil-works/pi-tui";
import { Type, type Static } from "typebox";

export type TaskStatus = "pending" | "in_progress" | "completed" | "deleted";
export type TaskAction = "create" | "update" | "list" | "get" | "delete" | "clear";

export interface Task {
	id: number;
	subject: string;
	description?: string;
	activeForm?: string;
	status: TaskStatus;
	blockedBy?: number[];
	owner?: string;
	metadata?: Record<string, unknown>;
}

export interface TaskState {
	tasks: Task[];
	nextId: number;
}

export interface TaskDetails {
	action: TaskAction;
	params: Record<string, unknown>;
	tasks: Task[];
	nextId: number;
	error?: string;
}

const TaskStatusSchema = StringEnum(["pending", "in_progress", "completed", "deleted"] as const);
const TaskActionSchema = StringEnum(["create", "update", "list", "get", "delete", "clear"] as const);

const TaskMutationParamsSchema = Type.Object({
	action: TaskActionSchema,
	id: Type.Optional(Type.Number({ description: "Task id for get, update, and delete" })),
	subject: Type.Optional(Type.String({ description: "Task subject; required for create" })),
	description: Type.Optional(Type.String({ description: "Task description" })),
	activeForm: Type.Optional(Type.String({ description: "Current active phrasing for the task" })),
	owner: Type.Optional(Type.String({ description: "Task owner" })),
	metadata: Type.Optional(Type.Record(Type.String(), Type.Unknown(), { description: "Arbitrary task metadata" })),
	status: Type.Optional(TaskStatusSchema),
	blockedBy: Type.Optional(Type.Array(Type.Number(), { description: "Initial dependency ids for create" })),
	addBlockedBy: Type.Optional(Type.Array(Type.Number(), { description: "Dependency ids to add" })),
	removeBlockedBy: Type.Optional(Type.Array(Type.Number(), { description: "Dependency ids to remove" })),
	includeDeleted: Type.Optional(Type.Boolean({ description: "Include deleted tasks when listing" })),
});

export type TaskMutationParams = Static<typeof TaskMutationParamsSchema>;

let state: TaskState = { tasks: [], nextId: 1 };
let overlayCtx: ExtensionContext | null = null;
let overlayMounted = false;
let overlayHandle: { requestRender(): void } | null = null;
let statusChangedThisTurn = false;
let autoReviewFollowUpCount = 0;
let autoReviewRequestedThisTurn = false;
let autoReviewTurn = false;
const AUTO_REVIEW_MAX_FOLLOWUPS = 1;

const OVERLAY_KEY = "orgm-todos";
const OVERLAY_TASK_LIMIT = 20;
const AUTO_REVIEW_MARKER = "[orgm-todo-auto-review]";
const AUTO_REVIEW_PROMPT = `${AUTO_REVIEW_MARKER} Before finishing this turn, review the current todo list. If any todo status should be updated, call the todo tool now. If everything is already correct, answer briefly: todo status already current.`;

export function cloneState(input: TaskState): TaskState {
	return {
		nextId: input.nextId,
		tasks: input.tasks.map((task) => ({
			...task,
			blockedBy: task.blockedBy ? [...task.blockedBy] : undefined,
			metadata: task.metadata ? { ...task.metadata } : undefined,
		})),
	};
}

export function visibleTasks(input: TaskState, includeDeleted = false): Task[] {
	const tasks = includeDeleted ? input.tasks : input.tasks.filter((task) => task.status !== "deleted");
	return cloneState({ tasks, nextId: input.nextId }).tasks;
}

function findTask(tasks: Task[], id: number): Task | undefined {
	return tasks.find((task) => task.id === id);
}

export function detectCycle(tasks: Task[]): boolean {
	const visible = tasks.filter((task) => task.status !== "deleted");
	const byId = new Map(visible.map((task) => [task.id, task]));
	const visiting = new Set<number>();
	const visited = new Set<number>();

	const visit = (id: number): boolean => {
		if (visiting.has(id)) return true;
		if (visited.has(id)) return false;
		const task = byId.get(id);
		if (!task) return false;

		visiting.add(id);
		for (const dependencyId of task.blockedBy ?? []) {
			if (byId.has(dependencyId) && visit(dependencyId)) return true;
		}
		visiting.delete(id);
		visited.add(id);
		return false;
	};

	return visible.some((task) => visit(task.id));
}

export function validateBlockedBy(taskId: number, blockedBy: number[] | undefined, tasks: Task[]): string | undefined {
	const unique = new Set(blockedBy ?? []);
	if (unique.has(taskId)) return `Task #${taskId} cannot block itself`;

	for (const dependencyId of unique) {
		const dependency = findTask(tasks, dependencyId);
		if (!dependency || dependency.status === "deleted") {
			return `Blocked-by task #${dependencyId} does not exist`;
		}
	}

	const candidate = tasks.map((task) =>
		task.id === taskId ? { ...task, blockedBy: [...unique] } : task,
	);
	if (detectCycle(candidate)) return "Blocked-by dependencies cannot contain cycles";
	return undefined;
}

function normalizeIds(ids: number[] | undefined): number[] {
	return Array.from(new Set(ids ?? [])).filter((id) => Number.isFinite(id));
}

function requireId(params: TaskMutationParams): number | string {
	return typeof params.id === "number" ? params.id : "id is required";
}

function validateTransition(from: TaskStatus, to: TaskStatus): string | undefined {
	if (from === "deleted") return "Deleted tasks cannot be updated";
	if (to === "deleted") return undefined;
	if (from === "completed" && to !== "completed") return `Invalid status transition: ${from} -> ${to}`;
	if (from === to) return undefined;
	if (from === "pending" && (to === "in_progress" || to === "completed")) return undefined;
	if (from === "in_progress" && (to === "pending" || to === "completed")) return undefined;
	return `Invalid status transition: ${from} -> ${to}`;
}

function taskLine(task: Task): string {
	return `#${task.id} ${task.subject} [${task.status}]`;
}

interface MutationResult {
	state: TaskState;
	tasks: Task[];
	summary: string;
	error?: string;
}

export function applyMutation(current: TaskState, action: TaskAction, params: TaskMutationParams): MutationResult {
	const next = cloneState(current);
	const fail = (error: string): MutationResult => ({
		state: cloneState(current),
		tasks: visibleTasks(current, params.includeDeleted),
		summary: `Error: ${error}`,
		error,
	});

	switch (action) {
		case "create": {
			const subject = params.subject?.trim();
			if (!subject) return fail("subject is required");

			const task: Task = {
				id: next.nextId,
				subject,
				description: params.description,
				activeForm: params.activeForm,
				owner: params.owner,
				metadata: params.metadata,
				status: "pending",
				blockedBy: normalizeIds(params.blockedBy),
			};
			next.tasks.push(task);
			const blockedByError = validateBlockedBy(task.id, task.blockedBy, next.tasks);
			if (blockedByError) return fail(blockedByError);
			next.nextId += 1;
			return { state: next, tasks: [cloneState({ tasks: [task], nextId: next.nextId }).tasks[0]!], summary: `Created ${taskLine(task)}` };
		}

		case "update": {
			const id = requireId(params);
			if (typeof id === "string") return fail(id);
			const task = findTask(next.tasks, id);
			if (!task) return fail(`Task #${id} not found`);
			if (task.status === "deleted") return fail("Deleted tasks cannot be updated");

			if (params.subject !== undefined) {
				const subject = params.subject.trim();
				if (!subject) return fail("subject cannot be empty");
				task.subject = subject;
			}
			if (params.description !== undefined) task.description = params.description;
			if (params.activeForm !== undefined) task.activeForm = params.activeForm;
			if (params.owner !== undefined) task.owner = params.owner;
			if (params.metadata !== undefined) task.metadata = params.metadata;

			if (params.status !== undefined) {
				const transitionError = validateTransition(task.status, params.status);
				if (transitionError) return fail(transitionError);
				if (params.status === "in_progress") {
					for (const other of next.tasks) {
						if (other.id !== task.id && other.status === "in_progress") other.status = "pending";
					}
				}
				task.status = params.status;
			}

			const existing = normalizeIds(task.blockedBy);
			const remove = new Set(normalizeIds(params.removeBlockedBy));
			const merged = new Set(existing.filter((dependencyId) => !remove.has(dependencyId)));
			for (const dependencyId of normalizeIds(params.addBlockedBy)) merged.add(dependencyId);
			task.blockedBy = Array.from(merged);
			const blockedByError = validateBlockedBy(task.id, task.blockedBy, next.tasks);
			if (blockedByError) return fail(blockedByError);

			return { state: next, tasks: [cloneState({ tasks: [task], nextId: next.nextId }).tasks[0]!], summary: `Updated ${taskLine(task)}` };
		}

		case "list": {
			let tasks = visibleTasks(next, params.includeDeleted);
			if (params.status) tasks = tasks.filter((task) => task.status === params.status);
			return {
				state: next,
				tasks,
				summary: tasks.length ? tasks.map(taskLine).join("\n") : "No todos",
			};
		}

		case "get": {
			const id = requireId(params);
			if (typeof id === "string") return fail(id);
			const task = findTask(next.tasks, id);
			if (!task || (!params.includeDeleted && task.status === "deleted")) return fail(`Task #${id} not found`);
			return { state: next, tasks: [cloneState({ tasks: [task], nextId: next.nextId }).tasks[0]!], summary: taskLine(task) };
		}

		case "delete": {
			const id = requireId(params);
			if (typeof id === "string") return fail(id);
			const task = findTask(next.tasks, id);
			if (!task) return fail(`Task #${id} not found`);
			if (task.status !== "deleted") task.status = "deleted";
			return { state: next, tasks: [cloneState({ tasks: [task], nextId: next.nextId }).tasks[0]!], summary: `Deleted ${taskLine(task)}` };
		}

		case "clear":
			return { state: { tasks: [], nextId: 1 }, tasks: [], summary: "Cleared all todos" };
	}
}

function detailsFor(action: TaskAction, params: TaskMutationParams, current: TaskState, error?: string): TaskDetails {
	return {
		action,
		params: { ...params },
		tasks: cloneState(current).tasks,
		nextId: current.nextId,
		error,
	};
}

function formatCall(args: Partial<TaskMutationParams>): string {
	const parts = [`todo ${args.action ?? ""}`.trim()];
	if (args.id !== undefined) parts.push(`#${args.id}`);
	if (args.subject) parts.push(args.subject);
	return parts.join(": ").replace(": #", " #");
}

function statusIcon(status: TaskStatus): string {
	if (status === "completed") return "✓";
	if (status === "in_progress") return "◐";
	if (status === "deleted") return "✕";
	return "○";
}

function taskSummary(task: Task): string {
	const owner = task.owner ? ` @${task.owner}` : "";
	const blockedBy = task.blockedBy && task.blockedBy.length > 0 ? ` blocked by ${task.blockedBy.map((id) => `#${id}`).join(", ")}` : "";
	return `#${task.id} ${statusIcon(task.status)} ${task.subject}${owner}${blockedBy}`;
}

function groupTasksByStatus(tasks: Task[]): string {
	const sections: Array<[TaskStatus, string]> = [
		["pending", "Pending"],
		["in_progress", "In Progress"],
		["completed", "Completed"],
	];
	const lines: string[] = [];
	for (const [status, label] of sections) {
		const group = tasks.filter((task) => task.status === status);
		if (group.length === 0) continue;
		if (lines.length > 0) lines.push("");
		lines.push(`${label}:`);
		lines.push(...group.map((task) => `  ${taskSummary(task)}`));
	}
	return lines.join("\n");
}

function renderTaskLines(tasks: Task[], theme: Theme, limit: number): string {
	const display = tasks.slice(0, limit);
	const lines = display.map((task) => {
		const icon = task.status === "completed" ? theme.fg("success", statusIcon(task.status)) : task.status === "in_progress" ? theme.fg("warning", statusIcon(task.status)) : task.status === "deleted" ? theme.fg("dim", statusIcon(task.status)) : theme.fg("dim", statusIcon(task.status));
		const subject = task.status === "completed" || task.status === "deleted" ? theme.fg("dim", task.subject) : theme.fg("muted", task.subject);
		return `${icon} ${theme.fg("accent", `#${task.id}`)} ${subject} ${theme.fg("dim", `[${task.status}]`)}`;
	});
	if (tasks.length > display.length) lines.push(theme.fg("dim", `… ${tasks.length - display.length} more`));
	return lines.join("\n");
}

function isTaskSnapshot(value: unknown): value is TaskState {
	if (!value || typeof value !== "object") return false;
	const candidate = value as { tasks?: unknown; nextId?: unknown };
	return Array.isArray(candidate.tasks) && typeof candidate.nextId === "number";
}

function detailsSnapshot(details: unknown): TaskState | undefined {
	if (!details || typeof details !== "object") return undefined;
	const candidate = details as { tasks?: unknown; nextId?: unknown };
	if (!isTaskSnapshot(candidate)) return undefined;
	return { tasks: candidate.tasks as Task[], nextId: candidate.nextId };
}

function replayFromBranch(ctx: ExtensionContext): void {
	let snapshot: TaskState | undefined;
	for (const entry of ctx.sessionManager.getBranch()) {
		if (entry.type !== "message") continue;
		const message = entry.message as { role?: string; toolName?: string; details?: unknown };
		if (message.role !== "toolResult" || message.toolName !== "todo") continue;
		const candidate = detailsSnapshot(message.details);
		if (candidate) snapshot = candidate;
	}
	state = snapshot ? cloneState(snapshot) : { tasks: [], nextId: 1 };
}

function buildOverlayLines(theme: Theme, width: number): string[] {
	const tasks = visibleTasks(state);
	if (tasks.length === 0) return [];
	const completed = tasks.filter((task) => task.status === "completed").length;
	const lines = [theme.fg("accent", `Todos (${completed}/${tasks.length})`)];
	const display = tasks.slice(0, OVERLAY_TASK_LIMIT);
	for (const task of display) {
		const color = task.status === "completed" ? "success" : task.status === "in_progress" ? "warning" : "muted";
		const blockedBy = task.blockedBy && task.blockedBy.length > 0 ? theme.fg("dim", ` ← ${task.blockedBy.map((id) => `#${id}`).join(",")}`) : "";
		lines.push(`${theme.fg(color, statusIcon(task.status))} ${theme.fg("accent", `#${task.id}`)} ${theme.fg(task.status === "completed" ? "dim" : "text", truncateToWidth(task.subject, Math.max(8, width - 12)))}${blockedBy}`);
	}
	if (tasks.length > display.length) lines.push(theme.fg("dim", `+${tasks.length - display.length} more`));
	return lines.map((line) => truncateToWidth(line, width));
}

function installOverlay(ctx: ExtensionContext): void {
	if (overlayCtx && overlayCtx !== ctx) {
		if (overlayMounted && overlayCtx.hasUI) overlayCtx.ui.setWidget(OVERLAY_KEY, undefined);
		overlayMounted = false;
		overlayHandle = null;
	}
	overlayCtx = ctx;
	if (!ctx.hasUI) {
		overlayMounted = false;
		overlayHandle = null;
		return;
	}
	const hasTasks = visibleTasks(state).length > 0;
	if (!hasTasks) {
		if (overlayMounted) ctx.ui.setWidget(OVERLAY_KEY, undefined);
		overlayMounted = false;
		overlayHandle = null;
		return;
	}
	if (overlayMounted) {
		overlayHandle?.requestRender();
		return;
	}
	ctx.ui.setWidget(
		OVERLAY_KEY,
		(tui, theme) => {
			overlayHandle = { requestRender: () => tui.requestRender() };
			return {
				render(width: number): string[] {
					return buildOverlayLines(theme, width);
				},
				invalidate() {},
			};
		},
		{ placement: "aboveEditor" },
	);
	overlayMounted = true;
}

function refreshOverlay(ctx = overlayCtx): void {
	if (!ctx) return;
	installOverlay(ctx);
}

function hasActiveTodos(): boolean {
	return state.tasks.some((task) => task.status === "in_progress");
}

function didStatusChange(before: TaskState, after: TaskState): boolean {
	const beforeStatuses = new Map(before.tasks.map((task) => [task.id, task.status]));
	for (const task of after.tasks) {
		if (beforeStatuses.get(task.id) !== task.status) return true;
	}
	return false;
}

function getMessageText(content: unknown): string {
	if (typeof content === "string") return content;
	if (Array.isArray(content)) return content.map(getMessageText).join(" ");
	if (!content || typeof content !== "object") return "";
	if (typeof (content as { text?: unknown }).text === "string") return String((content as { text?: unknown }).text);
	if ("content" in content && typeof (content as { content?: unknown }).content !== "undefined") return getMessageText((content as { content?: unknown }).content);
	return "";
}

function countExistingAutoReviewFollowUps(ctx: ExtensionContext): number {
	return ctx.sessionManager.getEntries().reduce((total, entry) => {
		if (entry.type !== "message") return total;
		const message = entry.message as { role?: string; content?: unknown };
		if (message.role !== "assistant") return total;
		return message.content && getMessageText(message.content).includes(AUTO_REVIEW_MARKER) ? total + 1 : total;
	}, 0);
}

function isMainAgentRuntime(): boolean {
	return process.env.PI_PDD_SUBAGENT !== "1";
}

export default function (pi: ExtensionAPI) {
	pi.on("session_start", async (_event, ctx) => {
		replayFromBranch(ctx);
		statusChangedThisTurn = false;
		autoReviewRequestedThisTurn = false;
		autoReviewTurn = false;
		autoReviewFollowUpCount = Math.min(countExistingAutoReviewFollowUps(ctx), AUTO_REVIEW_MAX_FOLLOWUPS);
		refreshOverlay(ctx);
	});

	pi.on("before_agent_start", async (event) => {
		autoReviewTurn = typeof event.prompt === "string" && event.prompt.includes(AUTO_REVIEW_MARKER);
		statusChangedThisTurn = false;
		autoReviewRequestedThisTurn = false;
	});

	pi.on("agent_end", async () => {
		if (!isMainAgentRuntime()) return;
		if (autoReviewTurn) {
			autoReviewTurn = false;
			statusChangedThisTurn = false;
			return;
		}
		if (!statusChangedThisTurn || autoReviewRequestedThisTurn || !hasActiveTodos()) return;
		if (autoReviewFollowUpCount >= AUTO_REVIEW_MAX_FOLLOWUPS) return;
		autoReviewRequestedThisTurn = true;
		statusChangedThisTurn = false;
		autoReviewFollowUpCount += 1;
		pi.sendUserMessage(AUTO_REVIEW_PROMPT, { deliverAs: "followUp" });
	});

	pi.registerCommand("todos", {
		description: "Show all todos on the current branch, grouped by status",
		handler: async (_args, ctx) => {
			if (!ctx.hasUI) return;
			const tasks = visibleTasks(state);
			if (tasks.length === 0) {
				ctx.ui.notify("No todos yet.", "info");
				return;
			}
			ctx.ui.notify(groupTasksByStatus(tasks), "info");
		},
	});

	pi.registerTool({
		name: "todo",
		label: "Todo",
		description: "Manage branch-scoped todos. Actions: create, update, list, get, delete, clear.",
		promptSnippet: "Manage branch-scoped todos with create, update, list, get, delete, and clear actions.",
		promptGuidelines: [
			"Use todo to track multi-step work requested by the user when a visible task list would help coordination.",
		],
		parameters: TaskMutationParamsSchema,

		async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
			const before = cloneState(state);
			const result = applyMutation(state, params.action, params);
			if (!result.error) {
				state = result.state;
				if (isMainAgentRuntime() && !autoReviewTurn && didStatusChange(before, state)) statusChangedThisTurn = true;
			}
			const details = detailsFor(params.action, params, state, result.error);
			refreshOverlay(ctx);
			return {
				content: [{ type: "text" as const, text: result.summary }],
				details,
			};
		},

		renderCall(args, theme) {
			return new Text(theme.fg("toolTitle", theme.bold("todo ")) + theme.fg("muted", formatCall(args)), 0, 0);
		},

		renderResult(result, { expanded }, theme) {
			const details = result.details as TaskDetails | undefined;
			if (!details) {
				const first = result.content[0];
				return new Text(first?.type === "text" ? first.text : "", 0, 0);
			}
			if (details.error) return new Text(theme.fg("error", `Error: ${details.error}`), 0, 0);

			const tasks = details.action === "list" ? visibleTasks({ tasks: details.tasks, nextId: details.nextId }, details.params.includeDeleted === true) : details.tasks;
			if (tasks.length === 0) return new Text(theme.fg("dim", "No todos"), 0, 0);
			const text = renderTaskLines(tasks, theme, expanded ? tasks.length : 6);
			return new Text(text, 0, 0);
		},
	});
}
