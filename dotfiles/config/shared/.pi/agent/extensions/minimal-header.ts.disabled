import { basename, dirname, extname, normalize } from "node:path";
import {
	isToolCallEventType,
	type ExtensionAPI,
	type ExtensionContext,
	type Theme,
} from "@mariozechner/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@mariozechner/pi-tui";

type SkillStatus = "loading" | "loaded" | "error";

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

function renderHeader(theme: Theme, width: number, loadedSkills: Map<string, SkillStatus>): string[] {
	if (width <= 0) return [""];

	const title = theme.fg("accent", "π skills");
	const separator = theme.fg("muted", " · ");
	const skillsLine = loadedSkills.size === 0
		? theme.fg("dim", "<none>")
		: Array.from(loadedSkills.entries())
			.map(([name, status]) => formatSkill(theme, name, status))
			.join(separator);
	const singleLine = `${title}${separator}${skillsLine}`;

	if (visibleWidth(singleLine) <= width) return [singleLine];
	return [truncateToWidth(title, width), truncateToWidth(skillsLine, width)];
}

export default function (pi: ExtensionAPI) {
	let headerEnabled = true;
	let headerHandle: { requestRender: () => void } | null = null;
	const loadedSkills = new Map<string, SkillStatus>();
	const pendingSkillReads = new Map<string, string>();

	const requestRender = () => {
		headerHandle?.requestRender();
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

	const clearTrackedSkills = () => {
		loadedSkills.clear();
		pendingSkillReads.clear();
		requestRender();
	};

	const installHeader = (ctx: ExtensionContext) => {
		ctx.ui.setHeader((tui, theme) => {
			headerHandle = tui;
			return {
				dispose: () => {
					if (headerHandle === tui) headerHandle = null;
				},
				invalidate() {},
				render(width: number): string[] {
					return renderHeader(theme, width, loadedSkills);
				},
			};
		});
	};

	pi.on("session_start", async (_event, ctx) => {
		pendingSkillReads.clear();
		if (!ctx.hasUI || !headerEnabled) return;
		installHeader(ctx);
	});

	pi.on("model_select", async (_event, ctx) => {
		if (!ctx.hasUI || !headerEnabled) return;
		installHeader(ctx);
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

	pi.on("tool_execution_end", async (event, ctx) => {
		if (!ctx.hasUI) return;

		const skillName = pendingSkillReads.get(event.toolCallId);
		if (!skillName) return;

		pendingSkillReads.delete(event.toolCallId);
		setSkillStatus(skillName, event.isError ? "error" : "loaded");
	});

	pi.on("session_shutdown", async () => {
		headerHandle = null;
		pendingSkillReads.clear();
	});

	pi.registerCommand("minimal-header", {
		description: "Reapply minimal skills header",
		handler: async (_args, ctx) => {
			if (!ctx.hasUI) return;
			headerEnabled = true;
			installHeader(ctx);
			ctx.ui.notify("Minimal header applied", "success");
		},
	});

	pi.registerCommand("minimal-header-clear", {
		description: "Clear tracked skills in minimal header",
		handler: async (_args, ctx) => {
			if (!ctx.hasUI) return;
			clearTrackedSkills();
			ctx.ui.notify("Minimal header skills cleared", "info");
		},
	});

	pi.registerCommand("minimal-header-builtin", {
		description: "Restore built-in header with keybinding hints",
		handler: async (_args, ctx) => {
			if (!ctx.hasUI) return;
			headerEnabled = false;
			headerHandle = null;
			ctx.ui.setHeader(undefined);
			ctx.ui.notify("Built-in header restored", "info");
		},
	});
}
