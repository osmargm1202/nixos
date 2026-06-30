import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { basename, dirname, extname, join, normalize } from "node:path";
import type { AssistantMessage } from "@mariozechner/pi-ai";
import {
	getAgentDir,
	isToolCallEventType,
	type ExtensionAPI,
	type ExtensionContext,
	type Theme,
} from "@mariozechner/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@mariozechner/pi-tui";
import {
	CAVEMAN_STATE_EVENT,
	type CavemanLevel,
	formatCavemanStatus,
	loadCavemanConfig,
	resolveInitialCavemanState,
} from "./lib/caveman-state";
import {
	formatPrimaryLabel,
	PRIMARY_STATE_EVENT,
	restorePrimaryState,
	SYSTEM_AGENT,
} from "./lib/agent-discovery";

type SkillStatus = "loading" | "loaded" | "error";
type MinimalSkillsAction = "on" | "off" | "toggle" | "clear";

interface MinimalSkillsConfig {
	enabled: boolean;
}

const MINIMAL_SKILLS_CONFIG_DEFAULTS: MinimalSkillsConfig = {
	enabled: true,
};

function getMinimalSkillsConfigPath(): string {
	return join(getAgentDir(), "minimal-skills.json");
}

function loadMinimalSkillsConfig(): MinimalSkillsConfig {
	const configPath = getMinimalSkillsConfigPath();
	if (!existsSync(configPath)) return { ...MINIMAL_SKILLS_CONFIG_DEFAULTS };

	try {
		const parsed = JSON.parse(readFileSync(configPath, "utf8")) as Partial<MinimalSkillsConfig>;
		return {
			enabled: typeof parsed.enabled === "boolean"
				? parsed.enabled
				: MINIMAL_SKILLS_CONFIG_DEFAULTS.enabled,
		};
	} catch {
		return { ...MINIMAL_SKILLS_CONFIG_DEFAULTS };
	}
}

function saveMinimalSkillsConfig(config: MinimalSkillsConfig): void {
	writeFileSync(getMinimalSkillsConfigPath(), `${JSON.stringify(config, null, 2)}\n`, "utf8");
}

function sanitizeSkillName(name: string): string | undefined {
	const trimmed = name.trim();
	return trimmed ? trimmed : undefined;
}

function getSkillNameFromPath(path: string): string | undefined {
	const normalizedPath = normalize(path).replace(/\\/g, "/");
	if (extname(normalizedPath).toLowerCase() !== ".md") return undefined;

	if (basename(normalizedPath) === "SKILL.md") {
		const skillName = basename(dirname(normalizedPath));
		if (skillName === "skills") return undefined;
		return sanitizeSkillName(skillName);
	}

	if (basename(dirname(normalizedPath)) !== "skills") return undefined;
	return sanitizeSkillName(basename(normalizedPath, extname(normalizedPath)));
}

function formatSkill(theme: Theme, name: string, status: SkillStatus): string {
	if (status === "loading") return theme.fg("warning", `${name}…`);
	if (status === "error") return theme.fg("error", `${name}!`);
	return theme.fg("text", name);
}

function renderSkillsLine(theme: Theme, width: number, loadedSkills: Map<string, SkillStatus>): string {
	const separator = theme.fg("muted", " · ");
	const line = loadedSkills.size === 0
		? `${theme.fg("muted", "skills:")}${separator}${theme.fg("dim", "<none>")}`
		: `${theme.fg("muted", "skills:")}${separator}${Array.from(loadedSkills.entries())
			.map(([name, status]) => formatSkill(theme, name, status))
			.join(separator)}`;
	return truncateToWidth(line, Math.max(0, width));
}

function formatCompactNumber(value: number): string {
	if (!Number.isFinite(value)) return "0";
	if (value < 1000) return `${Math.round(value)}`;
	if (value < 1_000_000) return `${(value / 1000).toFixed(value < 10_000 ? 1 : 0)}k`;
	return `${(value / 1_000_000).toFixed(1)}m`;
}

function formatCurrency(value: number): string {
	if (!Number.isFinite(value) || value <= 0) return "$0.000";
	if (value < 0.001) return `$${value.toFixed(4)}`;
	return `$${value.toFixed(3)}`;
}

function buildContextBar(percent: number, width = 10): string {
	const clamped = Math.max(0, Math.min(100, percent));
	const filled = Math.max(0, Math.min(width, Math.round((clamped / 100) * width)));
	return `[${"#".repeat(filled)}${"-".repeat(width - filled)}]${Math.round(clamped)}%`;
}

function getFolderLabel(cwd: string): string {
	const trimmed = cwd.replace(/[\\/]+$/, "");
	const folder = basename(trimmed) || trimmed || ".";
	return ` ${folder}`;
}

function formatDuration(ms: number): string {
	const totalSeconds = Math.max(0, Math.floor(ms / 1000));
	const hours = Math.floor(totalSeconds / 3600);
	const minutes = Math.floor((totalSeconds % 3600) / 60);
	const seconds = totalSeconds % 60;

	if (hours > 0) return `${hours}h ${minutes}m ${seconds}s`;
	if (minutes > 0) return `${minutes}m ${seconds}s`;
	return `${seconds}s`;
}

function normalizeMinimalSkillsAction(value: string): MinimalSkillsAction | undefined {
	const normalized = value.trim().toLowerCase();
	if (normalized === "on" || normalized === "off" || normalized === "toggle" || normalized === "clear") {
		return normalized;
	}
	return undefined;
}

function buildMinimalSkillsUsage(): string {
	return "Usage: /minimal-skills <on|off|toggle|clear>";
}

export default function (pi: ExtensionAPI) {
	let currentPrimary: string = SYSTEM_AGENT;
	let currentCaveman: CavemanLevel = "off";
	let showCavemanStatus = loadCavemanConfig().showStatus;
	let showSkillsStatus = loadMinimalSkillsConfig().enabled;
	let timerStartedAt = 0;
	let timerLabel = "";
	let timerHasError = false;
	let timerHandle: ReturnType<typeof setInterval> | undefined;
	let footerHandle: { requestRender: () => void } | null = null;
	const loadedSkills = new Map<string, SkillStatus>();
	const pendingSkillReads = new Map<string, string>();

	const requestRender = () => {
		footerHandle?.requestRender();
	};

	const setTimerLabel = (icon: "⏱" | "✓" | "✕") => {
		if (timerStartedAt === 0) return;
		timerLabel = `${icon} ${formatDuration(Date.now() - timerStartedAt)}`;
		requestRender();
	};

	const stopTimer = () => {
		if (timerHandle) clearInterval(timerHandle);
		timerHandle = undefined;
	};

	const clearTrackedSkills = () => {
		loadedSkills.clear();
		pendingSkillReads.clear();
		requestRender();
	};

	const setSkillStatus = (name: string, status: SkillStatus) => {
		const skillName = sanitizeSkillName(name);
		if (!skillName) return;

		const previous = loadedSkills.get(skillName);
		if (previous === status) return;
		if (status === "loading" && previous === "loaded") return;

		loadedSkills.set(skillName, status);
		requestRender();
	};

	const setSkillsEnabled = (enabled: boolean) => {
		showSkillsStatus = enabled;
		saveMinimalSkillsConfig({ enabled });
		requestRender();
	};

	const installFooter = (ctx: ExtensionContext) => {
		currentPrimary = restorePrimaryState(ctx.sessionManager.getEntries(), ctx.cwd, "both");
		currentCaveman = resolveInitialCavemanState(ctx.sessionManager.getEntries()).level;
		showCavemanStatus = loadCavemanConfig().showStatus;
		showSkillsStatus = loadMinimalSkillsConfig().enabled;

		ctx.ui.setFooter((tui, theme, footerData) => {
			footerHandle = tui;
			const folderLabel = getFolderLabel(ctx.cwd);
			const unsubscribeBranch = footerData.onBranchChange(() => tui.requestRender());

			return {
				dispose: () => {
					unsubscribeBranch();
					if (footerHandle === tui) footerHandle = null;
				},
				invalidate() {},
				render(width: number): string[] {
					const usage = ctx.getContextUsage();
					const percent = usage?.percent ?? 0;
					const contextText = buildContextBar(percent);

					let inputTokens = 0;
					let outputTokens = 0;
					let totalCost = 0;

					for (const entry of ctx.sessionManager.getBranch()) {
						if (entry.type === "message" && entry.message.role === "assistant") {
							const message = entry.message as AssistantMessage;
							inputTokens += message.usage?.input ?? 0;
							outputTokens += message.usage?.output ?? 0;
							totalCost += message.usage?.cost?.total ?? 0;
						}
					}

					const modelName = ctx.model?.name || ctx.model?.id || "no-model";
					const thinking = pi.getThinkingLevel();
					const tokenSummary = `↑${formatCompactNumber(inputTokens)} ↓${formatCompactNumber(outputTokens)}`;
					const primaryLabel = formatPrimaryLabel(currentPrimary);
					const agentStatus = timerLabel ? `${primaryLabel} · ${timerLabel}` : primaryLabel;
					const cavemanStatus = formatCavemanStatus(currentCaveman);
					const cavemanStyled = currentCaveman === "off"
						? theme.fg("dim", cavemanStatus)
						: theme.fg("accent", cavemanStatus);

					const leftParts = [
						theme.fg("accent", contextText),
						theme.fg("text", modelName),
						theme.fg("muted", `${thinking} · ${agentStatus}`),
					];
					const left = leftParts.join(theme.fg("muted", " · "));
					const centerRaw = folderLabel;
					const rightParts = [
						showCavemanStatus ? cavemanStyled : "",
						theme.fg("muted", tokenSummary),
						theme.fg("warning", formatCurrency(totalCost)),
					].filter(Boolean);
					const right = rightParts.join(theme.fg("muted", " · "));

					const minSpaces = 2;
					const leftWidth = visibleWidth(left);
					const rightWidth = visibleWidth(right);
					const reservedWidth = leftWidth + rightWidth + minSpaces * 2;
					const centerAvailable = width - reservedWidth;
					let firstLine: string;

					if (centerAvailable >= 1) {
						const centerText = truncateToWidth(centerRaw, centerAvailable);
						const centerWidth = visibleWidth(centerText);
						const extra = centerAvailable - centerWidth;
						const padBefore = " ".repeat(minSpaces + Math.floor(extra / 2));
						const padAfter = " ".repeat(minSpaces + Math.ceil(extra / 2));
						const center = theme.fg("text", centerText);
						firstLine = left + padBefore + center + padAfter + right;
					} else {
						const compact = showCavemanStatus
							? `${contextText} ${modelName} · ${thinking} · ${agentStatus} · ${folderLabel} · ${cavemanStatus} · ${tokenSummary} ${formatCurrency(totalCost)}`
							: `${contextText} ${modelName} · ${thinking} · ${agentStatus} · ${folderLabel} · ${tokenSummary} ${formatCurrency(totalCost)}`;
						const styledCompact = showCavemanStatus
							? theme.fg("accent", `${contextText} `) +
								theme.fg("text", modelName) +
								theme.fg("muted", ` · ${thinking} · ${agentStatus} · `) +
								theme.fg("text", folderLabel) +
								theme.fg("muted", " · ") +
								cavemanStyled +
								theme.fg("muted", ` · ${tokenSummary} `) +
								theme.fg("warning", formatCurrency(totalCost))
							: theme.fg("accent", `${contextText} `) +
								theme.fg("text", modelName) +
								theme.fg("muted", ` · ${thinking} · ${agentStatus} · `) +
								theme.fg("text", folderLabel) +
								theme.fg("muted", ` · ${tokenSummary} `) +
								theme.fg("warning", formatCurrency(totalCost));

						if (visibleWidth(compact) <= width) {
							firstLine = styledCompact;
						} else {
							const compactBar = theme.fg("accent", `${contextText} `);
							const compactTail = showCavemanStatus
								? theme.fg("text", modelName) +
									theme.fg("muted", ` · ${thinking} · ${agentStatus} · `) +
									theme.fg("text", folderLabel) +
									theme.fg("muted", " · ") +
									cavemanStyled
								: theme.fg("text", modelName) +
									theme.fg("muted", ` · ${thinking} · ${agentStatus} · `) +
									theme.fg("text", folderLabel);

							const availableTailWidth = Math.max(0, width - visibleWidth(compactBar));
							firstLine = compactBar + truncateToWidth(compactTail, availableTailWidth);
						}
					}

					if (!showSkillsStatus || loadedSkills.size === 0) return [firstLine];
					const skillsLine = renderSkillsLine(theme, width, loadedSkills);
					return [firstLine, skillsLine];
				},
			};
		});
	};

	pi.events.on(PRIMARY_STATE_EVENT, (data: { selectedName: string }) => {
		currentPrimary = data?.selectedName ?? SYSTEM_AGENT;
		requestRender();
	});

	pi.events.on(CAVEMAN_STATE_EVENT, (data: { level?: CavemanLevel }) => {
		if (data?.level) currentCaveman = data.level;
		showCavemanStatus = loadCavemanConfig().showStatus;
		requestRender();
	});

	pi.on("session_start", async (_event, ctx) => {
		pendingSkillReads.clear();
		if (!ctx.hasUI) return;
		showSkillsStatus = loadMinimalSkillsConfig().enabled;
		installFooter(ctx);
	});

	pi.on("model_select", async (_event, ctx) => {
		if (!ctx.hasUI) return;
		installFooter(ctx);
	});

	pi.on("input", async (event, ctx) => {
		if (!ctx.hasUI) return;
		const match = event.text.trimStart().match(/^\/skill:([^\s]+)/);
		if (!match) return;
		setSkillStatus(match[1] ?? "", "loaded");
	});

	pi.on("tool_call", async (event, ctx) => {
		if (!ctx.hasUI) return;
		if (!isToolCallEventType("read", event)) return;

		const skillName = getSkillNameFromPath(event.input.path);
		if (!skillName) return;

		pendingSkillReads.set(event.toolCallId, skillName);
		setSkillStatus(skillName, "loading");
	});

	pi.on("before_agent_start", async (_event, ctx) => {
		if (!ctx.hasUI) return;
		stopTimer();
		timerStartedAt = Date.now();
		timerHasError = false;
		setTimerLabel("⏱");
		timerHandle = setInterval(() => setTimerLabel(timerHasError ? "✕" : "⏱"), 1000);
	});

	pi.on("tool_execution_end", async (event, ctx) => {
		if (!ctx.hasUI) return;

		const skillName = pendingSkillReads.get(event.toolCallId);
		if (skillName) {
			pendingSkillReads.delete(event.toolCallId);
			setSkillStatus(skillName, event.isError ? "error" : "loaded");
		}

		if (!event.isError) return;
		timerHasError = true;
		setTimerLabel("✕");
	});

	pi.on("after_provider_response", async (event, ctx) => {
		if (!ctx.hasUI || event.status < 400) return;
		timerHasError = true;
		setTimerLabel("✕");
	});

	pi.on("agent_end", async (_event, ctx) => {
		if (!ctx.hasUI) return;
		stopTimer();
		setTimerLabel(timerHasError ? "✕" : "✓");
	});

	pi.on("session_shutdown", async () => {
		stopTimer();
		footerHandle = null;
		pendingSkillReads.clear();
	});

	pi.registerCommand("minimal-footer", {
		description: "Reapply minimal custom footer",
		handler: async (_args, ctx) => {
			if (!ctx.hasUI) return;
			installFooter(ctx);
			ctx.ui.notify("Minimal footer applied", "success");
		},
	});

	pi.registerCommand("minimal-skills", {
		description: "Manage minimal footer skills line: on, off, toggle, clear",
		handler: async (args, ctx) => {
			if (!ctx.hasUI) return;
			const value = args.trim();
			if (!value) {
				ctx.ui.notify(`minimal-skills: ${showSkillsStatus ? "on" : "off"}`, "info");
				ctx.ui.notify(buildMinimalSkillsUsage(), "info");
				return;
			}

			const action = normalizeMinimalSkillsAction(value);
			if (!action) {
				ctx.ui.notify(`Unknown minimal-skills arg: ${value}`, "error");
				ctx.ui.notify(buildMinimalSkillsUsage(), "warning");
				return;
			}

			if (action === "clear") {
				clearTrackedSkills();
				ctx.ui.notify("Minimal footer skills cleared", "info");
				return;
			}

			if (action === "toggle") {
				setSkillsEnabled(!showSkillsStatus);
				ctx.ui.notify(`Minimal footer skills ${showSkillsStatus ? "enabled" : "disabled"}`, "success");
				return;
			}

			setSkillsEnabled(action === "on");
			ctx.ui.notify(`Minimal footer skills ${action === "on" ? "enabled" : "disabled"}`, "success");
		},
	});
}
