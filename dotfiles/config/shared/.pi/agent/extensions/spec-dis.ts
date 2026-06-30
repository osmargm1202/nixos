import { readdir, readFile, stat } from "node:fs/promises";
import { basename, dirname, extname, join, relative } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { DynamicBorder, getMarkdownTheme } from "@mariozechner/pi-coding-agent";
import { Container, Markdown, type SelectItem, SelectList, Text, matchesKey, truncateToWidth, visibleWidth } from "@mariozechner/pi-tui";

type DocKind = "spec" | "design" | "task" | "doc";

type SpecDoc = {
	path: string;
	relativePath: string;
	name: string;
	kind: DocKind;
	mtimeMs: number;
	modified: Date;
};

type Snapshot = Map<string, number>;

const MAX_SCAN_DEPTH = 8;
const MAX_SELECTOR_HEIGHT = 14;
const SPEC_SELECTOR_WIDTH = "85%";
const SPEC_SELECTOR_MAX_HEIGHT = "75%";
const VIEWER_BODY_LINES = 28;
const DOC_SCROLL_STEP = 10;
const IGNORED_DIRS = new Set([
	".git",
	"node_modules",
	".venv",
	"venv",
	"vendor",
	"dist",
	"build",
	"target",
	".cache",
	".next",
]);

function formatTimestamp(date: Date): string {
	try {
		return new Intl.DateTimeFormat(undefined, {
			year: "numeric",
			month: "2-digit",
			day: "2-digit",
			hour: "2-digit",
			minute: "2-digit",
		}).format(date);
	} catch {
		return date.toISOString().replace("T", " ").slice(0, 16);
	}
}

function padLine(text: string, width: number): string {
	if (width <= 0) return "";
	const clipped = truncateToWidth(text, width);
	return clipped + " ".repeat(Math.max(0, width - visibleWidth(clipped)));
}

function normalizeDisplayText(text: string): string {
	return text
		.replace(/\t/g, "    ")
		.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, "");
}

function wrapPlainText(text: string, width: number): string[] {
	if (width <= 0) return [""];
	const lines: string[] = [];
	for (const line of normalizeDisplayText(text).split("\n")) {
		if (!line) {
			lines.push("");
			continue;
		}
		let remaining = line;
		while (visibleWidth(remaining) > width) {
			const chunk = truncateToWidth(remaining, width);
			lines.push(chunk);
			remaining = remaining.slice(chunk.length);
		}
		lines.push(remaining);
	}
	return lines;
}

function cleanTitle(text: string): string {
	return text.replace(/[-_]+/g, " ").replace(/\s+/g, " ").trim();
}

function inferKind(relativePath: string): DocKind {
	const lower = relativePath.toLowerCase();
	if (/(^|[/.\\_-])task(s)?([/.\\_-]|$)/.test(lower)) return "task";
	if (/(^|[/.\\_-])design([/.\\_-]|$)/.test(lower)) return "design";
	if (/(^|[/.\\_-])spec(s)?([/.\\_-]|$)/.test(lower)) return "spec";
	return "doc";
}

function isCandidateMarkdown(relativePath: string): boolean {
	const lower = relativePath.toLowerCase();
	if (extname(lower) !== ".md") return false;
	if (lower.startsWith("docs/superpowers/specs/")) return true;
	if (lower.startsWith("specs/")) return true;
	if (lower.startsWith("openspec/")) return true;
	if (lower.startsWith(".openspec/")) return true;
	if (lower.startsWith("sdd-orchestrator/") && /(^|[/.\\_-])(spec|specs|design|task|tasks)([/.\\_-]|$)/.test(lower)) return true;
	return /(^|[/.\\_-])(spec|specs|design|task|tasks)([/.\\_-]|$)/.test(lower);
}

function buildDocName(relativePath: string): string {
	const file = basename(relativePath, extname(relativePath));
	const parent = basename(dirname(relativePath));
	const title = cleanTitle(file) || cleanTitle(parent) || relativePath;
	return title.length > 80 ? `${title.slice(0, 79)}…` : title;
}

async function walkMarkdown(cwd: string, dir: string, depth: number, out: string[]): Promise<void> {
	if (depth > MAX_SCAN_DEPTH) return;
	let entries;
	try {
		entries = await readdir(dir, { withFileTypes: true });
	} catch {
		return;
	}
	for (const entry of entries) {
		const fullPath = join(dir, entry.name);
		if (entry.isDirectory()) {
			if (entry.name.startsWith(".") && entry.name !== ".openspec") continue;
			if (IGNORED_DIRS.has(entry.name)) continue;
			await walkMarkdown(cwd, fullPath, depth + 1, out);
			continue;
		}
		if (!entry.isFile()) continue;
		const relativePath = relative(cwd, fullPath).replace(/\\/g, "/");
		if (isCandidateMarkdown(relativePath)) out.push(fullPath);
	}
}

async function listSpecDocs(cwd: string): Promise<SpecDoc[]> {
	const paths: string[] = [];
	await walkMarkdown(cwd, cwd, 0, paths);
	const docs: SpecDoc[] = [];
	for (const path of paths) {
		try {
			const info = await stat(path);
			const relativePath = relative(cwd, path).replace(/\\/g, "/");
			docs.push({
				path,
				relativePath,
				name: buildDocName(relativePath),
				kind: inferKind(relativePath),
				mtimeMs: info.mtimeMs,
				modified: info.mtime,
			});
		} catch {
			// File disappeared between walk and stat; ignore it.
		}
	}
	return docs.sort((a, b) => b.mtimeMs - a.mtimeMs || a.relativePath.localeCompare(b.relativePath));
}

function createSnapshot(docs: SpecDoc[]): Snapshot {
	return new Map(docs.map((doc) => [doc.path, doc.mtimeMs]));
}

function changedSince(docs: SpecDoc[], baseline: Snapshot): SpecDoc[] {
	return docs.filter((doc) => (baseline.get(doc.path) ?? 0) < doc.mtimeMs);
}

function docToSelectItem(doc: SpecDoc): SelectItem {
	return {
		value: doc.path,
		label: `${doc.kind.toUpperCase()} · ${doc.name}`,
		description: `${formatTimestamp(doc.modified)} · ${doc.relativePath}`,
	};
}

async function chooseDoc(
	ctx: ExtensionContext,
	docs: SpecDoc[],
	title: string,
): Promise<SpecDoc | null> {
	if (!ctx.hasUI) return null;
	if (docs.length === 0) {
		ctx.ui.notify("No spec documents found for this project", "warning");
		return null;
	}

	const byPath = new Map(docs.map((doc) => [doc.path, doc] as const));
	const items: SelectItem[] = docs.map(docToSelectItem);

	return await ctx.ui.custom<SpecDoc | null>((_tui, theme, _kb, done) => {
		const container = new Container();
		container.addChild(new DynamicBorder((text: string) => theme.fg("accent", text)));
		container.addChild(new Text(theme.fg("accent", theme.bold(title)), 1, 0));
		container.addChild(new Text(theme.fg("muted", `${docs.length} doc${docs.length === 1 ? "" : "s"} · latest first`), 1, 0));

		const selectList = new SelectList(items, Math.min(items.length, MAX_SELECTOR_HEIGHT), {
			selectedPrefix: (text) => theme.fg("accent", text),
			selectedText: (text) => theme.fg("accent", text),
			description: (text) => theme.fg("muted", text),
			scrollInfo: (text) => theme.fg("dim", text),
			noMatch: (text) => theme.fg("warning", text),
		});
		selectList.onSelect = (item) => {
			done(byPath.get(item.value) ?? null);
		};
		selectList.onCancel = () => done(null);
		container.addChild(selectList);
		container.addChild(new Text(theme.fg("dim", "↑↓ navigate • enter open • q/esc close"), 1, 0));
		container.addChild(new DynamicBorder((text: string) => theme.fg("accent", text)));

		return {
			render: (width: number) => container.render(width),
			invalidate: () => container.invalidate(),
			handleInput: (data: string) => {
				if (matchesKey(data, "escape") || data === "q") {
					done(null);
					return;
				}
				selectList.handleInput(data);
			},
		};
	}, {
		overlay: true,
		overlayOptions: {
			anchor: "center",
			width: SPEC_SELECTOR_WIDTH,
			maxHeight: SPEC_SELECTOR_MAX_HEIGHT,
			margin: 1,
		},
	});
}

function renderMarkdownContent(text: string, width: number): string[] {
	const safeText = normalizeDisplayText(text);
	try {
		const mdTheme = getMarkdownTheme();
		const markdown = new Markdown(safeText, 0, 0, mdTheme);
		const rendered = markdown.render(width);
		if (Array.isArray(rendered) && rendered.length > 0) return rendered;
	} catch {
		// Fallback to plain text below.
	}
	return wrapPlainText(safeText, width);
}

async function openDocViewer(ctx: ExtensionContext, doc: SpecDoc): Promise<void> {
	if (!ctx.hasUI) return;

	let rawText: string;
	try {
		rawText = await readFile(doc.path, "utf8");
	} catch (error) {
		const message = error instanceof Error ? error.message : String(error);
		ctx.ui.notify(`Failed to open ${doc.name}: ${message}`, "error");
		return;
	}

	let scrollOffset = 0;
	let cachedWidth = -1;
	let cachedBodyLines: string[] = [];
	let currentBodyLineCount = 0;
	const getBodyLines = (width: number): string[] => {
		if (width === cachedWidth) return cachedBodyLines;
		cachedWidth = width;
		cachedBodyLines = renderMarkdownContent(rawText, width);
		return cachedBodyLines;
	};

	await ctx.ui.custom<void>((tui, theme, _kb, done) => {
		const close = () => done();
		return {
			render: (width: number): string[] => {
				const innerWidth = Math.max(24, width - 2);
				const bodyWidth = Math.max(1, innerWidth - 2);
				const bodyLines = getBodyLines(bodyWidth);
				currentBodyLineCount = bodyLines.length;
				const maxScroll = Math.max(0, bodyLines.length - VIEWER_BODY_LINES);
				if (scrollOffset > maxScroll) scrollOffset = maxScroll;
				if (scrollOffset < 0) scrollOffset = 0;
				const rangeStart = scrollOffset;
				const rangeEnd = Math.min(bodyLines.length, rangeStart + VIEWER_BODY_LINES);
				const titleLine = `${doc.kind.toUpperCase()} · ${doc.name}`;
				const metaLine = `${formatTimestamp(doc.modified)} · ${doc.relativePath}`;
				const scrollLine = `Lines ${bodyLines.length === 0 ? 0 : rangeStart + 1}-${rangeEnd} of ${bodyLines.length} · offset ${scrollOffset}`;
				const helpLine = "↑/↓ or j/k scroll • pageUp/pageDown jump • esc/q close";
				const lines: string[] = [
					theme.fg("accent", `╭${"─".repeat(innerWidth)}╮`),
					theme.fg("accent", `│${padLine(theme.fg("text", titleLine), innerWidth)}│`),
					theme.fg("accent", `│${padLine(theme.fg("muted", metaLine), innerWidth)}│`),
					theme.fg("accent", `│${padLine(theme.fg("dim", scrollLine), innerWidth)}│`),
				];
				for (let i = 0; i < VIEWER_BODY_LINES; i += 1) {
					lines.push(theme.fg("accent", `│${padLine(bodyLines[rangeStart + i] ?? "", bodyWidth)}│`));
				}
				lines.push(theme.fg("accent", `│${padLine(theme.fg("dim", helpLine), innerWidth)}│`));
				lines.push(theme.fg("accent", `╰${"─".repeat(innerWidth)}╯`));
				return lines.map((line) => truncateToWidth(line, width));
			},
			invalidate: () => {},
			handleInput: (data: string) => {
				if (matchesKey(data, "escape") || data === "q") return close();
				const maxScroll = Math.max(0, currentBodyLineCount - VIEWER_BODY_LINES);
				if (matchesKey(data, "up") || data === "k") {
					scrollOffset = Math.max(0, scrollOffset - 1);
					tui.requestRender();
					return;
				}
				if (matchesKey(data, "down") || data === "j") {
					scrollOffset = Math.min(maxScroll, scrollOffset + 1);
					tui.requestRender();
					return;
				}
				if (matchesKey(data, "pageUp")) {
					scrollOffset = Math.max(0, scrollOffset - DOC_SCROLL_STEP);
					tui.requestRender();
					return;
				}
				if (matchesKey(data, "pageDown")) {
					scrollOffset = Math.min(maxScroll, scrollOffset + DOC_SCROLL_STEP);
					tui.requestRender();
				}
			},
		};
	}, {
		overlay: true,
		overlayOptions: {
			anchor: "center",
			width: "85%",
			maxHeight: "75%",
			margin: 1,
		},
	});
}

async function openSpecDis(ctx: ExtensionContext, docs?: SpecDoc[], title = "Open Specification Document"): Promise<void> {
	const entries = docs ?? await listSpecDocs(ctx.cwd);
	const selected = await chooseDoc(ctx, entries, title);
	if (!selected) return;
	await openDocViewer(ctx, selected);
}

function isSubagentToolResult(toolName: unknown): toolName is "deploy_agent" | "query_team" {
	return toolName === "deploy_agent" || toolName === "query_team";
}

async function renderChangedDocs(
	ctx: ExtensionContext,
	baseline: Snapshot,
	setBaseline: (snapshot: Snapshot) => void,
	reason: string,
): Promise<void> {
	if (!ctx.hasUI) return;

	const docs = await listSpecDocs(ctx.cwd);
	const changed = changedSince(docs, baseline);
	setBaseline(createSnapshot(docs));

	if (changed.length === 0) return;

	if (changed.length === 1) {
		const doc = changed[0];
		if (!doc) return;
		ctx.ui.notify(`1 spec artifact changed (${reason}): ${doc.name}`, "info");
		await openDocViewer(ctx, doc);
		return;
	}

	ctx.ui.notify(`${changed.length} spec artifacts changed (${reason})`, "info");
	await openSpecDis(ctx, changed, "Changed Spec / Design / Task Documents");
}

export default function (pi: ExtensionAPI) {
	let baseline: Snapshot = new Map();

	const setBaseline = (snapshot: Snapshot): void => {
		baseline = snapshot;
	};
	const refreshBaseline = async (ctx: ExtensionContext): Promise<void> => {
		setBaseline(createSnapshot(await listSpecDocs(ctx.cwd)));
	};

	pi.on("session_start", async (_event, ctx) => {
		await refreshBaseline(ctx);
	});

	pi.on("agent_start", async (_event, ctx) => {
		await refreshBaseline(ctx);
	});

	pi.on("agent_end", async (_event, ctx) => {
		await renderChangedDocs(ctx, baseline, setBaseline, "completed spec artifact");
	});

	pi.on("tool_result", async (event, ctx) => {
		if (!isSubagentToolResult(event.toolName)) return;
		await renderChangedDocs(ctx, baseline, setBaseline, "subagent spec artifact");
	});

	pi.registerCommand("spec-dis", {
		description: "List local spec/design/task/doc files and open a reader",
		handler: async (_args, ctx) => {
			await ctx.waitForIdle();
			await openSpecDis(ctx);
		},
	});

	pi.registerShortcut("alt+4", {
		description: "Open latest spec document viewer",
		handler: async (ctx) => {
			await openSpecDis(ctx);
		},
	});
}
