import type { AutocompleteItem } from "@mariozechner/pi-tui";
import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import {
	CAVEMAN_STATE_ENTRY,
	CAVEMAN_STATE_EVENT,
	CAVEMAN_LEVELS,
	type CavemanLevel,
	type CavemanState,
	formatCavemanStatus,
	normalizeCavemanLevel,
	readCavemanSkillBody,
	resolveInitialCavemanState,
} from "./lib/caveman-state";

const OFF_ALIASES = new Set(["off", "stop", "disable", "normal", "normal-mode", "stop-caveman"]);

function buildUsage(): string {
	return `Usage: /caveman <${CAVEMAN_LEVELS.join("|")}>`;
}

function normalizeCommandArg(args: string): CavemanLevel | undefined {
	const normalized = args.trim().toLowerCase().replace(/\s+/g, "-");
	if (!normalized) return undefined;
	if (OFF_ALIASES.has(normalized)) return "off";
	return normalizeCavemanLevel(normalized);
}

function buildPromptOverlay(state: CavemanState, skillBody: string): string {
	return `
## Caveman Runtime Mode
Caveman mode is active for this runtime.
Selected level: ${state.level}
Behavior source: ${state.skillPath}
Apply the caveman rules below to every response in this turn.
Only the selected level is active; ignore style rules for other levels.
If the user asks to stop caveman or switch back to normal style, comply with the request and expect the runtime command to change the persistent level.

${skillBody}
`.trim();
}

function getLevelCompletions(prefix: string): AutocompleteItem[] | null {
	const normalizedPrefix = prefix.trim().toLowerCase().replace(/\s+/g, "-");
	const items = CAVEMAN_LEVELS
		.filter((level) => !normalizedPrefix || level.startsWith(normalizedPrefix))
		.map((level) => ({ value: level, label: level }));
	return items.length > 0 ? items : null;
}

export default function (pi: ExtensionAPI) {
	let state: CavemanState = resolveInitialCavemanState([]);
	let missingSkillNotice: string | null = null;

	const emitState = () => {
		pi.events.emit(CAVEMAN_STATE_EVENT, { ...state });
	};

	const persistState = () => {
		pi.appendEntry(CAVEMAN_STATE_ENTRY, { level: state.level, enabled: state.enabled });
	};

	const setState = (level: CavemanLevel, options?: { persist?: boolean; ctx?: ExtensionContext; notify?: boolean }) => {
		state = {
			...state,
			level,
			enabled: level !== "off",
		};
		if (options?.persist !== false) persistState();
		emitState();

		if (options?.notify !== false && options?.ctx?.hasUI) {
			const color = level === "off" ? "info" : "success";
			options.ctx.ui.notify(`Caveman ${level === "off" ? "disabled" : `set to ${level}`}`, color);
		}
	};

	const ensureSkillBody = (ctx?: ExtensionContext): string | undefined => {
		const result = readCavemanSkillBody(state.skillPath, state.level);
		if (result.body !== undefined) {
			missingSkillNotice = null;
			return result.body;
		}

		if (ctx?.hasUI && missingSkillNotice !== result.error) {
			ctx.ui.notify(result.error || "Caveman skill file missing", "error");
		}
		missingSkillNotice = result.error || "missing";
		return undefined;
	};

	pi.on("session_start", async (_event, ctx) => {
		state = resolveInitialCavemanState(ctx.sessionManager.getEntries());
		emitState();
	});

	pi.on("input", async (event, ctx) => {
		if (event.source === "extension") return { action: "continue" };
		const normalized = event.text.trim().toLowerCase();
		if (normalized !== "stop caveman" && normalized !== "normal mode") {
			return { action: "continue" };
		}

		setState("off", { ctx, notify: true });
		return { action: "handled" };
	});

	pi.on("before_agent_start", async (event, ctx) => {
		if (!state.enabled || state.level === "off") return;
		const skillBody = ensureSkillBody(ctx);
		if (!skillBody) return;

		return {
			systemPrompt: `${event.systemPrompt}\n\n${buildPromptOverlay(state, skillBody)}`,
		};
	});

	pi.registerCommand("caveman", {
		description: "Set caveman response mode: off, lite, full, ultra, wenyan-*",
		getArgumentCompletions: getLevelCompletions,
		handler: async (args, ctx) => {
			const value = args.trim();
			if (!value) {
				const status = formatCavemanStatus(state.level);
				const skillBody = state.enabled ? ensureSkillBody(ctx) : undefined;
				const suffix = state.enabled && !skillBody ? ` · missing skill: ${state.skillPath}` : "";
				ctx.ui.notify(`${status}${suffix}`, state.enabled ? "info" : "warning");
				ctx.ui.notify(buildUsage(), "info");
				return;
			}

			const level = normalizeCommandArg(value);
			if (!level) {
				ctx.ui.notify(`Unknown caveman level: ${value}`, "error");
				ctx.ui.notify(buildUsage(), "warning");
				return;
			}

			setState(level, { ctx, notify: true });
			if (level !== "off") ensureSkillBody(ctx);
		}
	});
}
