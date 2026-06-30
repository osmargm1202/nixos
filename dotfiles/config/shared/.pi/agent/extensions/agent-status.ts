import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { DynamicBorder } from "@mariozechner/pi-coding-agent";
import {
	CAVEMAN_STATE_EVENT,
	formatCavemanStatus,
	resolveInitialCavemanState,
	type CavemanLevel,
} from "./lib/caveman-state";
import { Container, SelectList, Text, type SelectItem, truncateToWidth, visibleWidth } from "@mariozechner/pi-tui";
import {
	type AgentStatusConfig,
	loadAgentStatusConfig,
	saveAgentStatusConfig,
} from "./lib/agent-status-config";


const SUBAGENTS_EVENT = "subagents:deployments-changed";
const WIDGET_KEY = "pdd-orgm-agents";
const STATUS_KEY = "pdd-orgm-agents";
const DEPLOYMENT_GRID_MAX_COLUMNS = 6;
const DEPLOYMENT_CARD_MIN_WIDTH = 24;
const DEPLOYMENT_GRID_GAP = 2;
const DEPLOYMENT_SELECTOR_MAX_HEIGHT = 12;

type DeploymentStatus = "running" | "idle" | "done" | "error" | "paused_provider_error" | "awaiting_user_input";

type RuntimeStatus = "idle" | "busy";
type AgentLaunchBackend = "embedded";
type TerminalState = "attached" | "missing" | "closed";
type RecoverableReason = "provider_error";

interface UsageStats {
	input: number;
	output: number;
	cacheRead: number;
	cacheWrite: number;
	cost: number;
	contextTokens: number;
	turns: number;
}

interface DeploymentState {
	deploymentId: string;
	agent: string;
	instanceNumber?: number;
	source: "user" | "project";
	tools: string[];
	model?: string;
	mode?: "ephemeral" | "persistent";
	launchBackend?: AgentLaunchBackend;
	runtimeId?: string;
	reusedRuntime?: boolean;
	reuseSummary?: string;
	sessionFilePath?: string;
	ownerSessionFile?: string;
	parentRuntimeId?: string;
	depth?: number;
	contextWindow: number;
	contextTokens: number;
	status: DeploymentStatus;
	summary: string;
	currentActivity?: string;
	turns: number;
	usage: UsageStats;
	exitCode?: number;
	stopReason?: string;
	errorMessage?: string;
	failureKind?: "task_error" | "provider_error" | "orchestrator_error";
	recoverableReason?: RecoverableReason;
	expectedArtifactTopicKey?: string;
	persistedArtifactTopicKey?: string;
	persistedToPddMemory?: boolean;
	pddMemoryWrites: number;
	attemptedModels: string[];
	primaryModel?: string;
	fallbackModel?: string;
	fallbackUsed: boolean;
}

interface RuntimeSnapshot {
	runtimeId: string;
	agent: string;
	source: "user" | "project";
	mode: "ephemeral" | "persistent";
	launchBackend: AgentLaunchBackend;
	model?: string;
	sessionFilePath?: string;
	ownerSessionFile?: string;
	contextWindow: number;
	contextTokens: number;
	status: RuntimeStatus;
	busyDeploymentId?: string;
	lastUsedAt: number;
	createdAt: number;
	runs: number;
	reuseCount: number;
	parentRuntimeId?: string;
	depth?: number;
	lastStopReason?: string;
	lastErrorMessage?: string;
	terminalState?: TerminalState;
	tmuxWindowId?: string;
	tmuxPaneId?: string;
	recoverableReason?: RecoverableReason;
	awaitingUserInput?: boolean;
	lastVisibleState?: DeploymentStatus;
}

type DeploymentTranscriptKind = "task" | "assistant" | "thinking" | "tool_call" | "tool_result" | "status" | "stderr" | "error";

interface DeploymentTranscriptEntry {
	kind: DeploymentTranscriptKind;
	title: string;
	text?: string;
	toolName?: string;
	ts: number;
}

type DeploymentTranscriptMap = Record<string, DeploymentTranscriptEntry[]>;

function normalizeTranscriptEntries(entries: unknown): DeploymentTranscriptEntry[] {
	if (!Array.isArray(entries)) return [];
	return entries.map((entry): DeploymentTranscriptEntry => {
		if (typeof entry === "string") {
			return { kind: "status", title: entry, ts: Date.now() };
		}
		const value = (entry && typeof entry === "object") ? entry as Partial<DeploymentTranscriptEntry> : {};
		return {
			kind: value.kind ?? "status",
			title: typeof value.title === "string" && value.title.trim() ? value.title : "event",
			text: typeof value.text === "string" ? value.text : undefined,
			toolName: typeof value.toolName === "string" ? value.toolName : undefined,
			ts: typeof value.ts === "number" ? value.ts : Date.now(),
		};
	});
}

function safeRequestRender(handle: { requestRender: () => void } | null | undefined): boolean {
	if (!handle) return false;
	try {
		handle.requestRender();
		return true;
	} catch {
		return false;
	}
}

function truncate(text: string, max = 96): string {
	const clean = text.replace(/\s+/g, " ").trim();
	if (clean.length <= max) return clean;
	return `${clean.slice(0, Math.max(0, max - 1))}…`;
}

function formatTokens(count: number): string {
	if (!Number.isFinite(count) || count <= 0) return "0";
	if (count < 1000) return `${count}`;
	if (count < 10_000) return `${(count / 1000).toFixed(1)}k`;
	if (count < 1_000_000) return `${Math.round(count / 1000)}k`;
	return `${(count / 1_000_000).toFixed(1)}M`;
}

function formatBar(percent: number): string {
	const normalized = Math.max(0, Math.min(100, Math.round(percent)));
	const filled = Math.max(0, Math.min(10, Math.round(normalized / 10)));
	return `[${"#".repeat(filled)}${"-".repeat(10 - filled)}]${normalized}%`;
}

function shortenMiddle(text: string, maxWidth: number): string {
	if (visibleWidth(text) <= maxWidth) return text;
	if (maxWidth <= 1) return "…";
	if (maxWidth <= 6) return truncateToWidth(text, maxWidth);
	const keep = Math.max(1, Math.floor((maxWidth - 1) / 2));
	return `${text.slice(0, keep)}…${text.slice(-keep)}`;
}


function withInstanceNumbers(deployments: DeploymentState[]): DeploymentState[] {
	const counters = new Map<string, number>();
	return deployments.map((deployment) => {
		const next = (counters.get(deployment.agent) ?? 0) + 1;
		counters.set(deployment.agent, next);
		return { ...deployment, instanceNumber: deployment.instanceNumber ?? next };
	});
}

function formatDeploymentLabel(deployment: DeploymentState): string {
	return `${deployment.agent} ${deployment.instanceNumber ?? 1}`;
}

function deriveRuntimePlaceholder(runtime: RuntimeSnapshot): DeploymentState {
	return {
		deploymentId: `runtime:${runtime.runtimeId}`,
		agent: runtime.agent,
		instanceNumber: 1,
		source: runtime.source,
		tools: [],
		model: runtime.model,
		mode: runtime.mode,
		launchBackend: runtime.launchBackend,
		runtimeId: runtime.runtimeId,
		reusedRuntime: runtime.reuseCount > 0,
		reuseSummary: `runtime ${runtime.runtimeId} idle · ${runtime.reuseCount} reuses`,
		sessionFilePath: runtime.sessionFilePath,
		ownerSessionFile: runtime.ownerSessionFile,
		parentRuntimeId: runtime.parentRuntimeId,
		depth: runtime.depth ?? 0,
		contextWindow: runtime.contextWindow,
		contextTokens: runtime.contextTokens,
		status: runtime.awaitingUserInput ? "awaiting_user_input" : runtime.recoverableReason === "provider_error" ? "paused_provider_error" : "idle",
		summary: runtime.recoverableReason === "provider_error"
			? `provider paused · ${runtime.agent}`
			: runtime.awaitingUserInput
				? `awaiting input · ${runtime.agent}`
				: `persistent runtime idle · ${runtime.runs} runs`,
		currentActivity: runtime.recoverableReason === "provider_error"
			? `paused · provider error${runtime.tmuxPaneId ? ` · ${runtime.tmuxPaneId}` : ""}`
			: runtime.awaitingUserInput
				? "awaiting user input"
				: `idle · reusable · ${runtime.reuseCount} reuses`,
		turns: 0,
		usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, contextTokens: runtime.contextTokens, turns: 0 },
		stopReason: runtime.lastStopReason,
		errorMessage: runtime.lastErrorMessage,
		recoverableReason: runtime.recoverableReason,
		pddMemoryWrites: 0,
		attemptedModels: [],
		fallbackUsed: false,
	};
}

function belongsToSession(entity: { ownerSessionFile?: string }, currentSessionFile?: string | null): boolean {
	if (!currentSessionFile) return true;
	return entity.ownerSessionFile === currentSessionFile;
}

function filterSessionState(
	deployments: DeploymentState[],
	runtimes: RuntimeSnapshot[],
	currentSessionFile?: string | null,
): { deployments: DeploymentState[]; runtimes: RuntimeSnapshot[] } {
	if (!currentSessionFile) return { deployments, runtimes };
	return {
		deployments: deployments.filter((deployment) => belongsToSession(deployment, currentSessionFile)),
		runtimes: runtimes.filter((runtime) => belongsToSession(runtime, currentSessionFile)),
	};
}

function deriveDisplayDeployments(deployments: DeploymentState[], runtimes: RuntimeSnapshot[]): DeploymentState[] {
	const runtimeById = new Map(runtimes.map((runtime) => [runtime.runtimeId, runtime]));
	const lastDeploymentIndexByRuntime = new Map<string, number>();
	for (let index = 0; index < deployments.length; index += 1) {
		const runtimeId = deployments[index]?.runtimeId;
		if (runtimeId) lastDeploymentIndexByRuntime.set(runtimeId, index);
	}

	const displayDeployments: DeploymentState[] = [];
	const coveredRuntimeIds = new Set<string>();
	for (let index = 0; index < deployments.length; index += 1) {
		const deployment = deployments[index]!;
		const runtime = deployment.runtimeId ? runtimeById.get(deployment.runtimeId) : undefined;
		if (runtime?.runtimeId) coveredRuntimeIds.add(runtime.runtimeId);
		if (deployment.status === "running" || deployment.status === "awaiting_user_input" || deployment.status === "paused_provider_error") {
			displayDeployments.push({ ...deployment });
			continue;
		}
		if (runtime?.status === "idle" && deployment.runtimeId && lastDeploymentIndexByRuntime.get(deployment.runtimeId) === index) {
			displayDeployments.push({
				...deployment,
				status: runtime.awaitingUserInput ? "awaiting_user_input" : runtime.recoverableReason === "provider_error" ? "paused_provider_error" : "idle",
				contextTokens: runtime.contextTokens,
				contextWindow: runtime.contextWindow,
				summary: runtime.recoverableReason === "provider_error"
					? deployment.summary || deployment.errorMessage || `provider paused · ${runtime.agent}`
					: deployment.summary || `runtime ${runtime.runtimeId} idle`,
				currentActivity: runtime.recoverableReason === "provider_error"
					? deployment.currentActivity || `paused · provider error${runtime.tmuxPaneId ? ` · ${runtime.tmuxPaneId}` : ""}`
					: runtime.awaitingUserInput
						? "awaiting user input"
						: (deployment.currentActivity === "completed" ? `idle · reusable · ${runtime.reuseCount} reuses` : (deployment.currentActivity || `idle · reusable · ${runtime.reuseCount} reuses`)),
				reuseSummary: deployment.reuseSummary || `runtime ${runtime.runtimeId} idle`,
				recoverableReason: runtime.recoverableReason,
			});
		}
	}

	for (const runtime of runtimes) {
		if (runtime.mode !== "persistent" || runtime.status !== "idle") continue;
		if (coveredRuntimeIds.has(runtime.runtimeId)) continue;
		displayDeployments.push(deriveRuntimePlaceholder(runtime));
	}

	return displayDeployments;
}

function deriveInspectDeployments(deployments: DeploymentState[], runtimes: RuntimeSnapshot[]): DeploymentState[] {
	const combined = [...deployments];
	const runtimeIds = new Set(deployments.map((deployment) => deployment.runtimeId).filter(Boolean));
	for (const runtime of runtimes) {
		if (runtime.mode !== "persistent" || runtime.status !== "idle") continue;
		if (runtimeIds.has(runtime.runtimeId)) continue;
		combined.push(deriveRuntimePlaceholder(runtime));
	}
	return combined;
}

function getWidgetViewModel(
	deployments: DeploymentState[],
	runtimes: RuntimeSnapshot[],
	currentSessionFile?: string | null,
) {
	const sessionState = filterSessionState(deployments, runtimes, currentSessionFile);
	const runningDeployments = sessionState.deployments.filter((deployment) => deployment.status !== "done");
	const displayDeployments = deriveDisplayDeployments(runningDeployments, sessionState.runtimes);
	const numberedDeployments = withInstanceNumbers(displayDeployments);
	const statusRank = (status: DeploymentStatus): number => {
		if (status === "running") return 0;
		if (status === "awaiting_user_input") return 1;
		if (status === "paused_provider_error") return 2;
		if (status === "idle") return 3;
		if (status === "error") return 4;
		return 5;
	};
	const sortedDeployments = [...numberedDeployments].sort((a, b) => {
		const rankDiff = statusRank(a.status) - statusRank(b.status);
		if (rankDiff !== 0) return rankDiff;
		if (a.agent !== b.agent) return a.agent.localeCompare(b.agent);
		return (a.instanceNumber ?? 0) - (b.instanceNumber ?? 0);
	});
	const running = sortedDeployments.filter((deployment) => deployment.status === "running").length;
	const waiting = sortedDeployments.filter((deployment) => deployment.status === "awaiting_user_input").length;
	const paused = sortedDeployments.filter((deployment) => deployment.status === "paused_provider_error").length;
	const idle = sortedDeployments.filter((deployment) => deployment.status === "idle").length;
	return { displayDeployments, sortedDeployments, running, waiting, paused, idle };
}

function buildWidgetStatus(view: ReturnType<typeof getWidgetViewModel>): { text: string; color: string } {
	const { running, waiting, paused, idle, displayDeployments } = view;
	const text = running > 0
		? `🤖 ${running} running${waiting > 0 ? ` · ${waiting} waiting` : ""}${paused > 0 ? ` · ${paused} paused` : ""}${idle > 0 ? ` · ${idle} idle` : ""}`
		: waiting > 0
			? `🤖 ${waiting} waiting${paused > 0 ? ` · ${paused} paused` : ""}${idle > 0 ? ` · ${idle} idle` : ""}`
			: paused > 0
				? `🤖 ${paused} paused${idle > 0 ? ` · ${idle} idle` : ""}`
				: idle > 0
					? `🤖 ${idle} idle`
					: `🤖 ${displayDeployments.length} active`;
	const color = running > 0 ? "accent" : waiting > 0 || idle > 0 ? "warning" : paused > 0 ? "error" : "accent";
	return { text, color };
}

function buildWidgetLines(
	theme: any,
	width: number,
	deployments: DeploymentState[],
	runtimes: RuntimeSnapshot[],
	config: AgentStatusConfig,
	cavemanLevel: CavemanLevel,
	currentSessionFile?: string | null,
): string[] {
	const view = getWidgetViewModel(deployments, runtimes, currentSessionFile);
	if (view.sortedDeployments.length === 0) return [];
	const padCell = (text: string, cellWidth: number) => {
		const truncated = truncateToWidth(text, cellWidth);
		const remaining = Math.max(0, cellWidth - visibleWidth(truncated));
		return truncated + " ".repeat(remaining);
	};
	const buildCard = (deployment: DeploymentState, cardWidth: number): string[] => {
		const isActive = deployment.status === "running";
		const isIdle = deployment.status === "idle";
		const isWaiting = deployment.status === "awaiting_user_input";
		const isPaused = deployment.status === "paused_provider_error";
		const innerWidth = Math.max(8, cardWidth - 2);
		const percent = deployment.contextWindow > 0 ? (deployment.contextTokens / deployment.contextWindow) * 100 : 0;
		const statusColor = deployment.status === "done"
			? "success"
			: deployment.status === "error" || isPaused
				? "error"
				: isActive
					? "accent"
					: "warning";
		const modelLabel = shortenMiddle(deployment.model ?? "default-model", Math.max(10, innerWidth - 2));
		const runtimeLabel = deployment.mode === "persistent"
			? `${deployment.reusedRuntime ? "reuse" : "persist"} ${shortenMiddle(deployment.runtimeId ?? "session", Math.max(10, innerWidth - 9))}`
			: "ephemeral";
		const backendLabel = "embedded";
		const persistenceLabel = deployment.persistedToPddMemory
			? `engram ✓ ${shortenMiddle(deployment.persistedArtifactTopicKey ?? "saved", Math.max(8, innerWidth - 11))}`
			: `engram … ${shortenMiddle(deployment.expectedArtifactTopicKey ?? (isIdle ? "idle" : "pending"), Math.max(8, innerWidth - 11))}`;
		const summaryLabel = deployment.summary || (deployment.status === "running" ? "waiting for result..." : isWaiting ? "awaiting user input" : isPaused ? "provider paused" : isIdle ? "idle persistent runtime" : "done");
		const activityLabel = deployment.currentActivity ? truncate(deployment.currentActivity, innerWidth - 1) : isWaiting ? "awaiting user input" : isPaused ? "paused · provider error" : isIdle ? "idle · reusable" : "thinking...";
		const titleText = ` ${formatDeploymentLabel(deployment)} `;
		const titleWidth = Math.max(0, innerWidth - visibleWidth(titleText));
		const usageTokens = isIdle || isPaused || isWaiting ? `ctx ${formatTokens(deployment.contextTokens)}` : `↑${formatTokens(deployment.usage.input)} ↓${formatTokens(deployment.usage.output)}`;
		const usageCost = isIdle || isPaused || isWaiting ? `reuse ${deployment.reusedRuntime ? "yes" : "new"}` : `$${deployment.usage.cost.toFixed(3)}`;
		const cavemanLabel = shortenMiddle(formatCavemanStatus(cavemanLevel), Math.max(10, innerWidth - 5));
		const borderColor = deployment.status === "error" || isPaused ? "error" : isActive ? "borderAccent" : isWaiting || isIdle ? "warning" : "borderMuted";
		const lines = [
			theme.fg(borderColor, `╭${titleText}${"─".repeat(titleWidth)}╮`),
			theme.fg(borderColor, "│") + theme.fg(statusColor, padCell(` ${deployment.status}`, innerWidth)) + theme.fg(borderColor, "│"),
		];
		if (config.showModel) lines.push(theme.fg(borderColor, "│") + theme.fg("muted", padCell(` ${modelLabel}`, innerWidth)) + theme.fg(borderColor, "│"));
		if (config.showActivity) {
			lines.push(theme.fg(borderColor, "│") + theme.fg("accent", padCell(` ${activityLabel}`, innerWidth)) + theme.fg(borderColor, "│"));
			lines.push(theme.fg(borderColor, "│") + theme.fg("muted", padCell(` ${runtimeLabel}`, innerWidth)) + theme.fg(borderColor, "│"));
			lines.push(theme.fg(borderColor, "│") + theme.fg("dim", padCell(` ${backendLabel}`, innerWidth)) + theme.fg(borderColor, "│"));
		}
		if (config.showCaveman) {
			const cavemanColor = cavemanLevel === "off" ? "muted" : "accent";
			lines.push(theme.fg(borderColor, "│") + theme.fg(cavemanColor, padCell(` ${cavemanLabel}`, innerWidth)) + theme.fg(borderColor, "│"));
		}
		lines.push(theme.fg(borderColor, "│") + theme.fg("accent", padCell(` ${formatBar(percent)}`, innerWidth)) + theme.fg(borderColor, "│"));
		if (config.showTokens) lines.push(theme.fg(borderColor, "│") + theme.fg("muted", padCell(` ${usageTokens}`, innerWidth)) + theme.fg(borderColor, "│"));
		if (config.showCost) lines.push(theme.fg(borderColor, "│") + theme.fg("warning", padCell(` cost ${usageCost}`, innerWidth)) + theme.fg(borderColor, "│"));
		if (config.showPersistence) lines.push(theme.fg(borderColor, "│") + theme.fg(deployment.persistedToPddMemory ? "success" : "warning", padCell(` ${persistenceLabel}`, innerWidth)) + theme.fg(borderColor, "│"));
		if (config.showSummary) lines.push(theme.fg(borderColor, "│") + theme.fg("text", padCell(` ${summaryLabel}`, innerWidth)) + theme.fg(borderColor, "│"));
		lines.push(theme.fg(borderColor, `╰${"─".repeat(innerWidth)}╯`));
		return lines;
	};
	const header = theme.fg("accent", "PDD agent deployments");
	const gap = DEPLOYMENT_GRID_GAP;
	const cardWidth = DEPLOYMENT_CARD_MIN_WIDTH;
	const maxColumns = Math.min(DEPLOYMENT_GRID_MAX_COLUMNS, view.sortedDeployments.length);
	const computedColumns = Math.max(1, Math.min(maxColumns, Math.floor((width + gap) / (cardWidth + gap)) || 1));
	const cards = view.sortedDeployments.map((deployment) => buildCard(deployment, cardWidth));
	const lines: string[] = [truncateToWidth(header, width)];
	for (let rowStart = 0; rowStart < cards.length; rowStart += computedColumns) {
		const rowCards = cards.slice(rowStart, rowStart + computedColumns);
		const rowHeight = Math.max(...rowCards.map((card) => card.length));
		for (let lineIndex = 0; lineIndex < rowHeight; lineIndex += 1) {
			const rowLine = rowCards.map((card) => card[lineIndex] ?? " ".repeat(cardWidth)).join(" ".repeat(gap));
			lines.push(truncateToWidth(rowLine, width));
		}
		if (rowStart + computedColumns < cards.length) lines.push("");
	}
	return lines;
}

function buildConfigOptions(config: AgentStatusConfig): Array<{ key: keyof AgentStatusConfig | "close"; title: string }> {
	const mark = (value: boolean) => (value ? "[on]" : "[off]");
	return [
		{ key: "showWidget", title: `${mark(config.showWidget)} Widget cards` },
		{ key: "showModel", title: `${mark(config.showModel)} Show model` },
		{ key: "showTokens", title: `${mark(config.showTokens)} Show tokens` },
		{ key: "showCost", title: `${mark(config.showCost)} Show cost` },
		{ key: "showPersistence", title: `${mark(config.showPersistence)} Show memory persistence` },
		{ key: "showSummary", title: `${mark(config.showSummary)} Show summary` },
		{ key: "showActivity", title: `${mark(config.showActivity)} Show current activity` },
		{ key: "showCaveman", title: `${mark(config.showCaveman)} Show caveman state` },
		{ key: "close", title: "Done" },
	];
}

function normalizeCommandAction(args: string): "settings" | "clear" | "inspect" | undefined {
	const value = args.trim().toLowerCase();
	if (!value || value === "settings" || value === "config" || value === "menu") return "settings";
	if (value === "clear") return "clear";
	if (value === "inspect" || value === "view" || value === "logs" || value === "transcript") return "inspect";
	return undefined;
}

function inspectStatusIcon(status: DeploymentStatus): string {
	switch (status) {
		case "running": return "⏳";
		case "idle": return "◌";
		case "awaiting_user_input": return "?";
		case "paused_provider_error": return "⏸";
		case "done": return "✓";
		case "error": return "✗";
		default: return "•";
	}
}

function buildInspectOptions(deployments: DeploymentState[]): Array<{ label: string; deploymentId: string }> {
	return withInstanceNumbers([...deployments].filter((deployment) => deployment.status !== "done"))
		.sort((a, b) => a.deploymentId.localeCompare(b.deploymentId))
		.map((deployment) => ({
			deploymentId: deployment.deploymentId,
			label: `${inspectStatusIcon(deployment.status)} ${formatDeploymentLabel(deployment)} · ${deployment.status} · ${truncate(deployment.currentActivity || deployment.summary || "idle", 56)}`,
		}));
}

async function openDeploymentPanel(ctx: ExtensionContext, deployments: DeploymentState[]): Promise<string | null> {
	if (!ctx.hasUI) return null;
	const options = buildInspectOptions(deployments);
	if (options.length === 0) {
		ctx.ui.notify("No subagent deployments available", "warning");
		return null;
	}
	const items: SelectItem[] = options.map((option) => ({
		value: option.deploymentId,
		label: option.label,
		description: option.deploymentId,
	}));
	return await ctx.ui.custom<string | null>((tui, theme, _kb, done) => {
		const container = new Container();
		container.addChild(new DynamicBorder((s: string) => theme.fg("accent", s)));
		container.addChild(new Text(theme.fg("accent", theme.bold("Subagent Deployments")), 1, 0));
		container.addChild(new Text(theme.fg("muted", "Select deployment · Enter inspect · Esc close"), 1, 0));
		const selectList = new SelectList(items, Math.min(items.length, DEPLOYMENT_SELECTOR_MAX_HEIGHT), {
			selectedPrefix: (text) => theme.fg("accent", text),
			selectedText: (text) => theme.fg("accent", text),
			description: (text) => theme.fg("muted", text),
			scrollInfo: (text) => theme.fg("dim", text),
			noMatch: (text) => theme.fg("warning", text),
		});
		selectList.onSelect = (item) => done(item.value);
		selectList.onCancel = () => done(null);
		container.addChild(selectList);
		container.addChild(new Text(theme.fg("dim", "↑↓ navigate • enter inspect • esc close"), 1, 0));
		container.addChild(new DynamicBorder((s: string) => theme.fg("accent", s)));
		return {
			render: (width: number) => container.render(width),
			invalidate: () => container.invalidate(),
			handleInput: (data: string) => {
				selectList.handleInput(data);
				tui.requestRender();
			},
		};
	}, {
		overlay: true,
		overlayOptions: { anchor: "center", width: "80%", maxHeight: "70%", margin: 1 },
	});
}

function normalizeDisplayText(text: string): string {
	return text
		.replace(/\t/g, "    ")
		.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, "");
}

function wrapPlainText(text: string, width: number): string[] {
	if (width <= 0) return [""];
	const lines: string[] = [];
	for (const rawLine of normalizeDisplayText(text).split("\n")) {
		if (!rawLine) {
			lines.push("");
			continue;
		}
		let remaining = rawLine;
		while (visibleWidth(remaining) > width) {
			const chunk = truncateToWidth(remaining, width);
			lines.push(chunk);
			remaining = remaining.slice(chunk.length);
		}
		lines.push(remaining);
	}
	return lines;
}

function flattenTranscriptEntries(entries: DeploymentTranscriptEntry[], width: number, theme: any): string[] {
	const normalizedEntries = normalizeTranscriptEntries(entries);
	const innerWidth = Math.max(20, width - 4);
	const pad = (text: string) => {
		const clipped = truncateToWidth(text, innerWidth);
		return clipped + " ".repeat(Math.max(0, innerWidth - visibleWidth(clipped)));
	};
	const blocks: string[] = [];
	const blockStyle = (kind: DeploymentTranscriptKind) => {
		switch (kind) {
			case "task": return { border: "accent", title: "accent", body: "text" };
			case "assistant": return { border: "success", title: "success", body: "text" };
			case "thinking": return { border: "warning", title: "warning", body: "muted" };
			case "tool_call": return { border: "accent", title: "toolTitle", body: "muted" };
			case "tool_result": return { border: "borderMuted", title: "text", body: "text" };
			case "stderr": return { border: "warning", title: "warning", body: "warning" };
			case "error": return { border: "error", title: "error", body: "error" };
			default: return { border: "borderMuted", title: "muted", body: "muted" };
		}
	};
	for (const entry of normalizedEntries) {
		const style = blockStyle(entry.kind);
		blocks.push(theme.fg(style.border, `╭${"─".repeat(innerWidth)}╮`));
		blocks.push(theme.fg(style.border, "│") + pad(theme.fg(style.title, ` ${entry.title}`)) + theme.fg(style.border, "│"));
		if (entry.text) {
			for (const line of wrapPlainText(entry.text, innerWidth - 1)) {
				blocks.push(theme.fg(style.border, "│") + pad(theme.fg(style.body, ` ${line}`)) + theme.fg(style.border, "│"));
			}
		}
		blocks.push(theme.fg(style.border, `╰${"─".repeat(innerWidth)}╯`));
	}
	return blocks.length > 0 ? blocks : [theme.fg("muted", "No transcript yet")];
}

async function openTranscriptViewer(
	ctx: ExtensionContext,
	deploymentId: string,
	getDeployment: () => DeploymentState | undefined,
	getTranscriptLines: () => DeploymentTranscriptEntry[],
	onOpen: (handle: { requestRender: () => void }) => void,
	onClose: () => void,
): Promise<void> {
	if (!ctx.hasUI) return;
	const WINDOW_LINES = 26;
	await ctx.ui.custom<void>((tui, theme, _kb, done) => {
		onOpen(tui);
		let scrollOffset = 0;
		const close = () => {
			onClose();
			done();
		};
		return {
			render(width: number): string[] {
				try {
					const deployment = getDeployment();
					const transcript = normalizeTranscriptEntries(getTranscriptLines());
				const innerWidth = Math.max(20, width - 2);
				const top = theme.fg("accent", `╭${"─".repeat(innerWidth)}╮`);
				const bottom = theme.fg("accent", `╰${"─".repeat(innerWidth)}╯`);
				const pad = (text: string) => {
					const clipped = truncateToWidth(text, innerWidth);
					return clipped + " ".repeat(Math.max(0, innerWidth - visibleWidth(clipped)));
				};
				const meta = deployment
					? [
						`${deployment.deploymentId} · ${deployment.status}`,
						`${deployment.agent} · ${deployment.model ?? "default"}`,
						`mode: ${deployment.mode ?? "ephemeral"}${deployment.runtimeId ? ` · runtime ${deployment.runtimeId}` : ""}${deployment.reusedRuntime ? " · reused" : ""}`,
						`activity: ${deployment.currentActivity || deployment.summary || "idle"}`,
						deployment.parentRuntimeId ? `parent runtime: ${deployment.parentRuntimeId}` : `depth: ${deployment.depth ?? 0}`,
					]
					: [`${deploymentId} · finished/cleared`, "deployment metadata unavailable", "activity: n/a"];
				const rendered = flattenTranscriptEntries(transcript, innerWidth, theme);
				const maxScroll = Math.max(0, rendered.length - WINDOW_LINES);
				const clampedOffset = Math.max(0, Math.min(scrollOffset, maxScroll));
				if (clampedOffset !== scrollOffset) scrollOffset = clampedOffset;
				const start = Math.max(0, rendered.length - WINDOW_LINES - scrollOffset);
				const visible = rendered.slice(start, start + WINDOW_LINES);
				const lines = [top];
				for (const line of meta) {
					lines.push(theme.fg("accent", "│") + pad(theme.fg("text", ` ${line}`)) + theme.fg("accent", "│"));
				}
				lines.push(theme.fg("accent", "│") + pad(theme.fg("muted", ` events ${transcript.length} · lines ${rendered.length} · offset ${scrollOffset}`)) + theme.fg("accent", "│"));
				for (let i = 0; i < WINDOW_LINES; i += 1) {
					const line = visible[i] ?? "";
					lines.push(theme.fg("accent", "│") + pad(line) + theme.fg("accent", "│"));
				}
				lines.push(theme.fg("accent", "│") + pad(theme.fg("dim", " ↑↓/j/k scroll · esc/q close ")) + theme.fg("accent", "│"));
					lines.push(bottom);
					return lines.map((line) => truncateToWidth(line, width));
				} catch (error) {
					const message = error instanceof Error ? error.message : String(error);
					return [theme.fg("error", `Transcript viewer error: ${message}`)];
				}
			},
			invalidate() {},
			handleInput(data: string) {
				if (data === "\u001b" || data === "q") return close();
				const rendered = flattenTranscriptEntries(normalizeTranscriptEntries(getTranscriptLines()), 120, theme);
				if (data === "k" || data === "\u001b[A") {
					scrollOffset = Math.min(scrollOffset + 1, Math.max(0, rendered.length - WINDOW_LINES));
					tui.requestRender();
					return;
				}
				if (data === "j" || data === "\u001b[B") {
					scrollOffset = Math.max(0, scrollOffset - 1);
					tui.requestRender();
				}
			},
		};
	}, {
		overlay: true,
		overlayOptions: { anchor: "center", width: "90%", maxHeight: "85%", margin: 1 },
	});
	onClose();
}

export default function (pi: ExtensionAPI) {
	let currentCaveman: CavemanLevel = "off";
	let currentCtx: ExtensionContext | null = null;
	let deployments: DeploymentState[] = [];
	let runtimes: RuntimeSnapshot[] = [];
	let transcripts: DeploymentTranscriptMap = {};
	let widgetHandle: { requestRender: () => void } | null = null;
	let widgetMounted = false;
	let transcriptViewerHandle: { deploymentId: string; requestRender: () => void } | null = null;
	let config = loadAgentStatusConfig();
	let lastWidgetStateSignature = "";

	const syncWidget = (ctx: ExtensionContext) => {
		if (!ctx.hasUI) return;
		const nextSignature = JSON.stringify({
			config,
			caveman: currentCaveman,
			sessionFile: ctx.sessionManager.getSessionFile() ?? null,
			deployments,
			runtimes,
		});
		if (lastWidgetStateSignature === nextSignature) return;
		lastWidgetStateSignature = nextSignature;
		const view = getWidgetViewModel(deployments, runtimes, ctx.sessionManager.getSessionFile());
		if (!config.showWidget || view.sortedDeployments.length === 0) {
			if (widgetMounted) {
				ctx.ui.setWidget(WIDGET_KEY, undefined);
				widgetMounted = false;
				widgetHandle = null;
			}
			ctx.ui.setStatus(STATUS_KEY, undefined);
			return;
		}
		if (!widgetMounted) {
			ctx.ui.setWidget(
				WIDGET_KEY,
				(tui, theme) => {
					widgetHandle = { requestRender: () => tui.requestRender() };
					return {
						render(width: number): string[] {
							return buildWidgetLines(theme, width, deployments, runtimes, config, currentCaveman, currentCtx?.sessionManager.getSessionFile());
						},
						invalidate() {},
					};
				},
				{ placement: "belowEditor" },
			);
			widgetMounted = true;
		} else if (!safeRequestRender(widgetHandle)) {
			widgetMounted = false;
			widgetHandle = null;
			lastWidgetStateSignature = "";
			syncWidget(ctx);
			return;
		}
		const status = buildWidgetStatus(view);
		ctx.ui.setStatus(STATUS_KEY, ctx.ui.theme.fg(status.color, status.text));
	};

	const rerenderWidget = () => {
		config = loadAgentStatusConfig();
		lastWidgetStateSignature = "";
		if (currentCtx) syncWidget(currentCtx);
	};

	const rerenderTranscriptViewer = () => {
		if (!safeRequestRender(transcriptViewerHandle)) transcriptViewerHandle = null;
	};

	const clearRuntimeState = (ctx: ExtensionContext) => {
		deployments = [];
		runtimes = [];
		transcripts = {};
		lastWidgetStateSignature = "";
		syncWidget(ctx);
		rerenderTranscriptViewer();
	};

	pi.on("session_start", async (_event, ctx) => {
		currentCtx = ctx;
		deployments = [];
		runtimes = [];
		transcripts = {};
		widgetHandle = null;
		widgetMounted = false;
		lastWidgetStateSignature = "";
		currentCaveman = resolveInitialCavemanState(ctx.sessionManager.getEntries()).level;
		if (ctx.hasUI) syncWidget(ctx);
	});

	pi.on("model_select", async (_event, ctx) => {
		currentCtx = ctx;
		if (!ctx.hasUI) return;
		rerenderWidget();
	});

	pi.events.on(CAVEMAN_STATE_EVENT, (data: { level?: CavemanLevel }) => {
		currentCaveman = data?.level ?? "off";
		rerenderWidget();
	});

	pi.events.on(SUBAGENTS_EVENT, (data: { deployments?: DeploymentState[]; runtimes?: RuntimeSnapshot[]; transcripts?: DeploymentTranscriptMap }) => {
		const nextDeployments = Array.isArray(data?.deployments) ? data.deployments.filter((deployment) => deployment.status !== "done") : [];
		const nextRuntimes: RuntimeSnapshot[] = [];
		const nextTranscripts = data?.transcripts && typeof data.transcripts === "object"
			? Object.fromEntries(Object.entries(data.transcripts).map(([deploymentId, entries]) => [deploymentId, normalizeTranscriptEntries(entries)]))
			: {};
		const widgetStateChanged = JSON.stringify(nextDeployments) !== JSON.stringify(deployments)
			|| JSON.stringify(nextRuntimes) !== JSON.stringify(runtimes);
		const transcriptStateChanged = JSON.stringify(nextTranscripts) !== JSON.stringify(transcripts);
		deployments = nextDeployments;
		runtimes = nextRuntimes;
		transcripts = nextTranscripts;
		if (widgetStateChanged) rerenderWidget();
		if (transcriptStateChanged) rerenderTranscriptViewer();
	});

	const inspectDeployment = async (ctx: ExtensionContext, deploymentId?: string | null) => {
		const sessionState = filterSessionState(deployments, runtimes, ctx.sessionManager.getSessionFile());
		const inspectDeployments = deriveInspectDeployments(sessionState.deployments, sessionState.runtimes);
		const selectedDeploymentId = deploymentId ?? await openDeploymentPanel(ctx, inspectDeployments);
		if (!selectedDeploymentId) return;
		await openTranscriptViewer(
			ctx,
			selectedDeploymentId,
			() => inspectDeployments.find((deployment) => deployment.deploymentId === selectedDeploymentId) ?? deployments.find((deployment) => deployment.deploymentId === selectedDeploymentId),
			() => transcripts[selectedDeploymentId] ?? [],
			(handle) => {
				transcriptViewerHandle = {
					deploymentId: selectedDeploymentId,
					requestRender: () => handle.requestRender(),
				};
			},
			() => {
				if (transcriptViewerHandle?.deploymentId === selectedDeploymentId) transcriptViewerHandle = null;
			},
		);
	};

	pi.registerCommand("agents", {
		description: "Open subagent deployments panel",
		handler: async (_args, ctx) => {
			if (!ctx.hasUI) return;
			await inspectDeployment(ctx);
		},
	});

	pi.registerShortcut("alt+3", {
		description: "Open subagent deployments panel",
		handler: async (ctx) => {
			if (!ctx.hasUI) return;
			await inspectDeployment(ctx);
		},
	});

	pi.registerCommand("agent-status", {
		description: "Manage agent status UI: /agent-status [settings|inspect|clear]",
		getArgumentCompletions: (prefix) => {
			const value = prefix.trim().toLowerCase();
			const options = [
				{ value: "settings", label: "settings — open status settings menu" },
				{ value: "inspect", label: "inspect — open live transcript viewer for a deployment" },
				{ value: "clear", label: "clear — clear current deployment runtime state" },
			].filter((option) => option.value.startsWith(value));
			return options.length > 0 ? options : null;
		},
		handler: async (args, ctx) => {
			if (!ctx.hasUI) return;
			const action = normalizeCommandAction(args);
			if (!action) {
				ctx.ui.notify(`Unknown /agent-status arg: ${args.trim()}`, "error");
				ctx.ui.notify("Usage: /agent-status [settings|inspect|clear]", "warning");
				return;
			}
			if (!args.trim()) {
				await inspectDeployment(ctx);
				return;
			}
			if (action === "clear") {
				clearRuntimeState(ctx);
				ctx.ui.notify("Agent status runtime state cleared", "info");
				return;
			}
			if (action === "inspect") {
				await inspectDeployment(ctx);
				return;
			}
			while (true) {
				config = loadAgentStatusConfig();
				const options = buildConfigOptions(config);
				const selected = await ctx.ui.select(
					"Agent status settings",
					options.map((option) => option.title),
				);
				if (!selected) break;
				const chosen = options.find((option) => option.title === selected);
				if (!chosen || chosen.key === "close") break;
				config = { ...config, [chosen.key]: !config[chosen.key] };
				saveAgentStatusConfig(config);
				lastWidgetStateSignature = "";
				syncWidget(ctx);
				ctx.ui.notify(`agent-status: ${chosen.key} ${config[chosen.key] ? "on" : "off"}`, "info");
			}
			lastWidgetStateSignature = "";
			syncWidget(ctx);
			ctx.ui.notify("Agent status settings applied", "success");
		},
	});
}
