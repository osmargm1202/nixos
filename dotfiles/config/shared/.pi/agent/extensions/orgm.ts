import type {
	ExtensionAPI,
	ExtensionContext,
	Theme,
} from "@earendil-works/pi-coding-agent";
import { VERSION } from "@earendil-works/pi-coding-agent";
import { exec } from "node:child_process";
import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";
import { countActiveExtensions } from "./lib/orgm-extensions";
import { registerSddCompatibilityCommands } from "./lib/orgm-flow";

const execAsync = promisify(exec);
const EXTENSIONS_DIR = dirname(fileURLToPath(import.meta.url));

const LOGO_LINES = [
	" ██████╗ ██████╗  ██████╗ ███╗   ███╗",
	"██╔═══██╗██╔══██╗██╔════╝ ████╗ ████║",
	"██║   ██║██████╔╝██║  ███╗██╔████╔██║",
	"██║   ██║██╔══██╗██║   ██║██║╚██╔╝██║",
	"╚██████╔╝██║  ██║╚██████╔╝██║ ╚═╝ ██║",
	" ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝",
] as const;

const TAGLINE = "or-gm.com";
const FRAME_MS = 55;
const HOLD_MS = 250;
const ANSI_RESET = "\u001b[0m";

const SHADOW_GRADIENT = [
	{ r: 3, g: 30, b: 92 }, // deep navy blue
	{ r: 10, g: 78, b: 185 }, // strong cobalt blue
	{ r: 54, g: 145, b: 255 }, // vivid sky blue highlight
] as const;

const NO_SHADOW_GRADIENT = [
	{ r: 8, g: 74, b: 170 }, // strong blue start, no near-black shadow
	{ r: 19, g: 103, b: 220 }, // saturated blue
	{ r: 82, g: 158, b: 255 }, // light sky blue finish
] as const;

type LogoGradient = readonly [
	{ readonly r: number; readonly g: number; readonly b: number },
	{ readonly r: number; readonly g: number; readonly b: number },
	{ readonly r: number; readonly g: number; readonly b: number },
];
type HeaderHandle = { requestRender: () => void };
type HeaderStats = {
	gitBranch: string;
	cwd: string;
	mcpServersCount: number;
	extensionsCount: number;
	packagesCount: number;
	skillsCount: number;
	customToolsCount: number;
};

function visibleWidth(text: string): number {
	return Array.from(text.replace(/\u001b\[[0-9;]*m/g, "")).length;
}

function truncateToWidth(text: string, width: number): string {
	if (width <= 0) return "";
	const chars = Array.from(text);
	if (chars.length <= width) return text;
	return chars.slice(0, Math.max(0, width - 1)).join("") + "…";
}

function centerLine(line: string, width: number): string {
	if (width <= 0) return "";
	const clipped = truncateToWidth(line, width);
	const pad = Math.max(0, Math.floor((width - visibleWidth(clipped)) / 2));
	return `${" ".repeat(pad)}${clipped}`;
}

function rgb({ r, g, b }: { r: number; g: number; b: number }): string {
	return `\u001b[38;2;${r};${g};${b}m`;
}

function mix(a: LogoGradient[number], b: LogoGradient[number], t: number) {
	return {
		r: Math.round(a.r + (b.r - a.r) * t),
		g: Math.round(a.g + (b.g - a.g) * t),
		b: Math.round(a.b + (b.b - a.b) * t),
	};
}

function gradientColor(gradient: LogoGradient, t: number) {
	const clamped = Math.max(0, Math.min(1, t));
	if (clamped < 0.56) return mix(gradient[0], gradient[1], clamped / 0.56);
	return mix(gradient[1], gradient[2], (clamped - 0.56) / 0.44);
}

function colorizeLogoLine(
	line: string,
	lineIndex: number,
	totalLines: number,
	gradient: LogoGradient,
): string {
	const chars = Array.from(line);
	const logoStart = chars.findIndex((char) => char !== " ");
	const first = logoStart < 0 ? 0 : logoStart;
	const last = Math.max(first, chars.length - 1);
	const rowRatio = totalLines <= 1 ? 0 : lineIndex / (totalLines - 1);

	return chars
		.map((char, index) => {
			if (char === " ") return char;
			const colRatio = (index - first) / Math.max(1, last - first);
			const t = colRatio * 0.72 + rowRatio * 0.28;
			return `${rgb(gradientColor(gradient, t))}${char}${ANSI_RESET}`;
		})
		.join("");
}

function colorizeTagline(line: string, gradient: LogoGradient): string {
	return line.replace(
		/[^\s✦]/g,
		(char, offset) =>
			`${rgb(gradientColor(gradient, offset / Math.max(1, line.length - 1)))}${char}${ANSI_RESET}`,
	);
}

function getVisibleLineCount(startedAt: number): number {
	const elapsed = Math.max(0, Date.now() - startedAt - HOLD_MS);
	return Math.min(
		LOGO_LINES.length,
		Math.max(1, Math.floor(elapsed / FRAME_MS) + 1),
	);
}

function fit(value: unknown, width: number): string {
	return truncateToWidth(
		String(value ?? "")
			.replace(/\s+/g, " ")
			.trim(),
		width,
	).padEnd(width);
}

function renderStats(
	theme: Theme,
	width: number,
	stats: HeaderStats,
): string[] {
	const rows: Array<[string, string]> = [
		["GIT:", stats.gitBranch],
		["PATH:", stats.cwd],
		["MCP:", `${stats.mcpServersCount} server(s)`],
		["PLUGINS:", `${stats.packagesCount} package(s)`],
		["AGENTS:", `${stats.skillsCount} loaded`],
		["EXTENSIONS:", `${stats.extensionsCount} active`],
		["VER:", `v${VERSION}`],
		["TOOLS:", `${stats.customToolsCount} custom`],
	];

	const colorRow = (text: string) => theme.fg("muted", centerLine(text, width));
	if (width >= 122) {
		const wideRows: Array<[string, string, string, string]> = [
			["GIT:", stats.gitBranch, "PATH:", stats.cwd],
			[
				"MCP:",
				`${stats.mcpServersCount} server(s)`,
				"PLUGINS:",
				`${stats.packagesCount} package(s)`,
			],
			[
				"AGENTS:",
				`${stats.skillsCount} loaded`,
				"EXTENSIONS:",
				`${stats.extensionsCount} active`,
			],
			["VER:", `v${VERSION}`, "TOOLS:", `${stats.customToolsCount} custom`],
		];
		return wideRows.map(([l1, v1, l2, v2]) =>
			colorRow(`${fit(l1, 10)} ${fit(v1, 48)}   ${fit(l2, 12)} ${fit(v2, 46)}`),
		);
	}

	const labelWidth = Math.max(...rows.map(([label]) => label.length));
	const valueWidth = Math.max(8, width - labelWidth - 4);
	return rows.map(([label, value]) =>
		colorRow(`${label.padEnd(labelWidth)}  ${fit(value, valueWidth)}`),
	);
}

function renderHeader(
	theme: Theme,
	width: number,
	startedAt: number,
	gradient: LogoGradient,
	stats: HeaderStats,
): string[] {
	const visibleLines = getVisibleLineCount(startedAt);
	const lines = LOGO_LINES.slice(0, visibleLines).map((line, index) => {
		const centered = centerLine(line, width);
		return colorizeLogoLine(centered, index, LOGO_LINES.length, gradient);
	});

	if (visibleLines >= LOGO_LINES.length) {
		const centeredTagline = centerLine(`✦ ${TAGLINE} ✦`, width);
		lines.push(theme.fg("muted", colorizeTagline(centeredTagline, gradient)));
		lines.push("");
		lines.push(...renderStats(theme, width, stats));
	}

	return lines;
}

async function refreshStats(
	ctx: ExtensionContext,
	pi: ExtensionAPI,
	stats: HeaderStats,
	requestRender: () => void,
): Promise<void> {
	const allCommands = pi.getCommands();
	stats.skillsCount = allCommands.filter(
		(command: { source?: string }) => command.source === "skill",
	).length;
	const allTools = pi.getAllTools();
	stats.customToolsCount = allTools.filter(
		(tool: { sourceInfo: { source: string } }) =>
			!["builtin", "sdk"].includes(tool.sourceInfo.source),
	).length;

	try {
		const { stdout } = await execAsync("git branch --show-current", {
			cwd: ctx.cwd,
		});
		const branch = stdout.trim();
		stats.gitBranch = branch ? `On branch ${branch}` : "Detached HEAD";
	} catch {
		stats.gitBranch = "Not a git repo";
	}

	try {
		const raw = await readFile(
			join(homedir(), ".pi", "agent", "mcp.json"),
			"utf8",
		);
		const cfg = JSON.parse(raw);
		stats.mcpServersCount = Object.keys(cfg.mcpServers || {}).length;
	} catch {
		stats.mcpServersCount = 0;
	}

	try {
		const raw = await readFile(
			join(homedir(), ".pi", "agent", "settings.json"),
			"utf8",
		);
		const cfg = JSON.parse(raw);
		stats.extensionsCount = countActiveExtensions(EXTENSIONS_DIR, cfg.extensions);
		stats.packagesCount = Array.isArray(cfg.packages) ? cfg.packages.length : 0;
	} catch {
		stats.extensionsCount = countActiveExtensions(EXTENSIONS_DIR);
		stats.packagesCount = 0;
	}

	requestRender();
}

export default function (pi: ExtensionAPI) {
	registerSddCompatibilityCommands(pi);
	let headerHandle: HeaderHandle | null = null;
	let animationTimer: ReturnType<typeof setInterval> | undefined;
	let startedAt = Date.now();
	let activeGradient: LogoGradient = NO_SHADOW_GRADIENT;
	let stats: HeaderStats = {
		gitBranch: "Loading git…",
		cwd: "",
		mcpServersCount: 0,
		extensionsCount: 0,
		packagesCount: 0,
		skillsCount: 0,
		customToolsCount: 0,
	};

	const stopAnimation = () => {
		if (animationTimer) clearInterval(animationTimer);
		animationTimer = undefined;
	};

	const startAnimation = () => {
		stopAnimation();
		startedAt = Date.now();
		animationTimer = setInterval(() => {
			headerHandle?.requestRender();
			if (getVisibleLineCount(startedAt) >= LOGO_LINES.length) stopAnimation();
		}, FRAME_MS);
	};

	const installHeader = (ctx: ExtensionContext) => {
		stats = { ...stats, cwd: ctx.cwd };
		startAnimation();
		ctx.ui.setHeader((tui: HeaderHandle, theme: Theme) => {
			headerHandle = tui;
			return {
				dispose: () => {
					if (headerHandle === tui) headerHandle = null;
				},
				invalidate() {},
				render(width: number): string[] {
					return renderHeader(theme, width, startedAt, activeGradient, stats);
				},
			};
		});
		void refreshStats(ctx, pi, stats, () => headerHandle?.requestRender());
	};

	pi.on("session_start", async (_event: unknown, ctx: ExtensionContext) => {
		if (!ctx.hasUI) return;
		installHeader(ctx);
	});

	pi.on("model_select", async (_event: unknown, ctx: ExtensionContext) => {
		if (!ctx.hasUI) return;
		installHeader(ctx);
	});

	pi.on("session_shutdown", async () => {
		stopAnimation();
		headerHandle = null;
	});

	pi.registerCommand("orgm-header", {
		description: "Reapply ORGM ASCII header: /orgm-header [no-shadow|shadow]",
		handler: async (args: string, ctx: ExtensionContext) => {
			if (!ctx.hasUI) return;
			const mode = args.trim().toLowerCase();
			if (mode === "shadow") activeGradient = SHADOW_GRADIENT;
			if (mode === "no-shadow" || mode === "sin-sombra")
				activeGradient = NO_SHADOW_GRADIENT;
			installHeader(ctx);
			ctx.ui.notify(
				`ORGM header applied (${activeGradient === NO_SHADOW_GRADIENT ? "no-shadow" : "shadow"})`,
				"success",
			);
		},
	});
}
