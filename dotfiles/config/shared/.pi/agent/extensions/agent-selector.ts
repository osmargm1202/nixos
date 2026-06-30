/**
 * agent-selector.ts
 *
 * Extension for selecting a specific agent and assigning one of the
 * configured models from the agents/ tree.
 */

import { readFileSync, writeFileSync } from "node:fs";
import { dirname, basename } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { DynamicBorder } from "@mariozechner/pi-coding-agent";
import { Container, Key, matchesKey, SelectList, Text, type SelectItem } from "@mariozechner/pi-tui";
import { discoverDeployableAgents, type AgentConfig } from "./lib/agent-discovery";

function collectConfiguredAgentModels(ctx: ExtensionContext, preferredModel?: string): string[] {
	const models = new Set<string>();

	for (const model of ctx.modelRegistry.getAvailable()) {
		models.add(`${model.provider}/${model.id}`);
	}

	for (const agent of discoverDeployableAgents(ctx.cwd, "both")) {
		if (agent.model?.trim()) models.add(agent.model.trim());
	}

	if (preferredModel?.trim()) models.add(preferredModel.trim());
	return Array.from(models).sort((a, b) => a.localeCompare(b));
}

function upsertAgentModelFrontmatter(markdown: string, model: string): string {
	const normalizedModel = model.trim();
	const match = markdown.match(/^(---\n)([\s\S]*?)(\n---\n?)([\s\S]*)$/);
	if (!match) {
		return `---\nmodel: ${normalizedModel}\n---\n\n${markdown.trimStart()}`;
	}

	const [, opening, frontmatterBlock, closing, body] = match;
	const lines = frontmatterBlock.split("\n");
	const modelLineIndex = lines.findIndex((line) => /^model\s*:/i.test(line.trim()));

	if (modelLineIndex >= 0) lines[modelLineIndex] = `model: ${normalizedModel}`;
	else lines.push(`model: ${normalizedModel}`);

	return `${opening}${lines.join("\n")}${closing}${body}`;
}

function saveAgentModel(agent: AgentConfig, model: string): AgentConfig {
	const raw = readFileSync(agent.filePath, "utf8");
	const next = upsertAgentModelFrontmatter(raw, model);
	if (next !== raw) writeFileSync(agent.filePath, next, "utf8");
	return { ...agent, model: model.trim() };
}

function isArrowEscapeSequence(key: string): boolean {
	return key === "\u001b[A" || key === "\u001b[B" || key === "\u001b[C" || key === "\u001b[D";
}

export function isEscapeKey(key: string): boolean {
	return (matchesKey(key, Key.escape) || key === "\u001B" || key === "Escape" || key === "escape" || key === "esc") && !isArrowEscapeSequence(key);
}

function isTextEditingKey(key: string): boolean {
	return (key.length === 1 && key >= " " && key !== "\u007F") || key === "\u007F" || key === "\u0015";
}

// ─── Agent model selector palette ──────────────────────────────────────────
interface AgentModelPaletteState {
	agents: AgentConfig[];
	mode: "agents" | "models";
	agentIndex: number;
	modelIndex: number;
	modelItems: Array<{ value: string; label: string }>;
}

function padCell(value: string, width: number): string {
	const clean = value.replace(/\s+/g, " ").trim();
	if (clean.length <= width) return clean.padEnd(width);
	return `${clean.slice(0, Math.max(0, width - 1))}…`;
}

function getAgentFolder(agent: AgentConfig): string {
	if (agent.namespace) return agent.namespace;
	const parent = basename(dirname(agent.filePath));
	if (parent && parent !== "agents") return parent;
	return agent.source;
}

function getAgentColumnWidths(width: number): { folder: number; agent: number; model: number } {
	const available = Math.max(42, width);
	const separators = 6;
	const columns = Math.max(30, available - separators);
	const folder = Math.max(10, Math.floor(columns * 0.24));
	const agent = Math.max(14, Math.floor(columns * 0.34));
	const model = Math.max(12, columns - folder - agent);
	return { folder, agent, model };
}

function buildAgentLabel(agent: AgentConfig, width: number): string {
	const columns = getAgentColumnWidths(width);
	return [
		padCell(getAgentFolder(agent), columns.folder),
		padCell(agent.displayName, columns.agent),
		padCell(agent.model || "default", columns.model),
	].join(" | ");
}

function buildAgentHeader(width: number): string {
	const columns = getAgentColumnWidths(width);
	return [
		padCell("carpeta", columns.folder),
		padCell("subagente", columns.agent),
		padCell("modelo actual", columns.model),
	].join(" | ");
}

async function openAgentModelPalette(ctx: ExtensionContext): Promise<void> {
	const agents = discoverDeployableAgents(ctx.cwd, "both");
	if (agents.length === 0) {
		ctx.ui.notify("No deployable subagents found in agents/", "warning");
		return;
	}

	const state: AgentModelPaletteState = {
		agents,
		mode: "agents",
		agentIndex: 0,
		modelIndex: 0,
		modelItems: [],
	};

	let container: Container | null = null;
	let selectList: SelectList | null = null;
	let closePalette: (() => void) | null = null;
	let lastRenderWidth = 100;

	const clampIndex = (value: number, length: number) => {
		if (length <= 0) return 0;
		return Math.max(0, Math.min(length - 1, value));
	};

	const getSelectedAgent = () => state.agents[clampIndex(state.agentIndex, state.agents.length)];
	const findAgentIndex = (name: string) => state.agents.findIndex((agent) => agent.name === name);

	const ensureModelItems = (agent: AgentConfig) => {
		const models = collectConfiguredAgentModels(ctx, agent.model);
		state.modelItems = models.map((model) => ({
			value: model,
			label: model === agent.model ? `${model}  ✓ current` : model,
		}));
		state.modelIndex = clampIndex(
			Math.max(0, state.modelItems.findIndex((item) => item.value === agent.model)),
			state.modelItems.length,
		);
	};

	const buildItems = (width = lastRenderWidth): SelectItem[] => {
		if (state.mode === "models") {
			return state.modelItems.map((model, idx) => ({
				value: String(idx),
				label: model.label,
			}));
		}

		return state.agents.map((agent) => ({
			value: agent.name,
			label: buildAgentLabel(agent, width),
		}));
	};

	const renderUI = (width = lastRenderWidth) => {
		if (!container) return;
		lastRenderWidth = width;
		const items = buildItems(width);
		const listTextWidth = Math.max(1, width - 4);
		selectList = new SelectList(items, Math.min(Math.max(items.length, 1), 12), {
			selectedPrefix: (text) => ctx.ui.theme.fg("accent", text),
			selectedText: (text) => ctx.ui.theme.fg("accent", text),
			description: (text) => ctx.ui.theme.fg("muted", text),
			scrollInfo: (text) => ctx.ui.theme.fg("dim", text),
			noMatch: (text) => ctx.ui.theme.fg("warning", text),
		}, {
			minPrimaryColumnWidth: listTextWidth,
			maxPrimaryColumnWidth: listTextWidth,
			truncatePrimary: ({ item, maxWidth, text }) => {
				if (state.mode !== "agents") return padCell(text, maxWidth);
				const agent = state.agents.find((candidate) => candidate.name === item.value);
				return agent ? buildAgentLabel(agent, maxWidth) : padCell(text, maxWidth);
			},
		});
		const selectedIndex = state.mode === "models"
			? clampIndex(state.modelIndex, items.length)
			: clampIndex(
				Math.max(0, items.findIndex((item) => item.value === getSelectedAgent()?.name)),
				items.length,
			);
		selectList.setSelectedIndex(selectedIndex);
		selectList.onCancel = () => closePalette?.();

		container.clear();
		container.addChild(new DynamicBorder((s) => ctx.ui.theme.fg("accent", s)));
		container.addChild(new Text(ctx.ui.theme.fg("accent", ctx.ui.theme.bold("Agent Model Selector"))));

		if (state.mode === "models") {
			const agent = getSelectedAgent();
			container.addChild(new Text(ctx.ui.theme.fg("text", `Agent: ${agent?.displayName || "unknown"}`)));
			container.addChild(new Text(ctx.ui.theme.fg("muted", "Select the model for this agent")));
			container.addChild(new Text(ctx.ui.theme.fg("dim", "↑↓ navigate · Enter save · Esc cancel/close")));
		} else {
			container.addChild(new Text(ctx.ui.theme.fg("text", buildAgentHeader(listTextWidth))));
			container.addChild(new Text(ctx.ui.theme.fg("dim", "↑↓ navigate · Enter open models · Esc close")));
		}

		container.addChild(selectList);
		container.invalidate();
	};

	await ctx.ui.custom<void>((tui, _theme, _kb, done) => {
		closePalette = done;
		container = new Container();
		renderUI();

		return {
			render: (w) => {
				if (w !== lastRenderWidth) renderUI(w);
				return container!.render(w);
			},
			invalidate: () => {
				container?.invalidate();
				renderUI(lastRenderWidth);
			},
			handleInput: (key) => {
				if (state.mode === "agents") {
					if (isEscapeKey(key)) {
						done();
						return;
					}

					if (key === "\n" || key === "\r") {
						const current = selectList?.getSelectedItem();
						if (!current) return;
						const idx = findAgentIndex(current.value);
						if (idx < 0) return;
						state.agentIndex = clampIndex(idx, state.agents.length);
						ensureModelItems(state.agents[state.agentIndex]);
						state.mode = "models";
						renderUI();
						tui.requestRender();
						return;
					}

					if (isTextEditingKey(key)) return;

					selectList?.handleInput(key);
					const current = selectList?.getSelectedItem();
					if (current) {
						const idx = findAgentIndex(current.value);
						if (idx >= 0) state.agentIndex = clampIndex(idx, state.agents.length);
					}
					renderUI();
					tui.requestRender();
					return;
				}

				if (isEscapeKey(key)) {
					done();
					return;
				}

				if (key === "\n" || key === "\r") {
					const agent = getSelectedAgent();
					const current = selectList?.getSelectedItem();
					if (!agent || !current) return;

					const idx = Number(current.value);
					if (!Number.isFinite(idx)) return;

					const modelValue = state.modelItems[idx]?.value;
					if (!modelValue) return;

					saveAgentModel(agent, modelValue);
					agent.model = modelValue;
					ctx.ui.notify(`Saved ${agent.displayName} → ${modelValue}`, "success");
					ensureModelItems(agent);
					state.mode = "agents";
					renderUI();
					tui.requestRender();
					return;
				}

				if (isTextEditingKey(key)) return;

				selectList?.handleInput(key);
				const current = selectList?.getSelectedItem();
				if (current) {
					const idx = Number(current.value);
					if (Number.isFinite(idx)) state.modelIndex = clampIndex(idx, state.modelItems.length);
				}
				renderUI();
				tui.requestRender();
			},
		};
	}, {
		overlay: true,
		overlayOptions: { width: "90%", minWidth: 90, maxHeight: "80%" },
	});
}

// ─── Extension Registration ─────────────────────────────────────────────────
export default function (pi: ExtensionAPI) {
	// Use non-/model prefix. Avoid Enter/autocomplete conflict with built-in /model menu.
	pi.registerCommand("agents-model", {
		description: "Select a subagent from agents/ and choose its model",
		handler: async (_args, ctx) => {
			if (!ctx.hasUI) {
				ctx.ui.notify("Visual selector requires interactive mode", "error");
				return;
			}
			await openAgentModelPalette(ctx);
		},
	});

	pi.registerShortcut("alt+2", {
		description: "Open agent model selector",
		handler: async (ctx) => {
			if (!ctx.hasUI) return;
			await openAgentModelPalette(ctx);
		},
	});
}
