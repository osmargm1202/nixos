import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { getAgentDir, parseFrontmatter } from "@mariozechner/pi-coding-agent";

export const CAVEMAN_STATE_ENTRY = "caveman-level";
export const CAVEMAN_STATE_EVENT = "caveman:state-changed";

export const CAVEMAN_LEVELS = [
	"off",
	"lite",
	"full",
	"ultra",
	"wenyan-lite",
	"wenyan-full",
	"wenyan-ultra",
] as const;

export type CavemanLevel = (typeof CAVEMAN_LEVELS)[number];

export interface CavemanConfig {
	defaultLevel: CavemanLevel;
	showStatus: boolean;
	skillPath: string;
}

export interface CavemanState {
	level: CavemanLevel;
	enabled: boolean;
	skillPath: string;
	source: "session" | "config" | "default";
}

export function getDefaultCavemanSkillPath(): string {
	return join(getAgentDir(), "skills", "caveman", "SKILL.md");
}

export function getDefaultCavemanConfigPath(): string {
	return join(getAgentDir(), "caveman.json");
}

export function isCavemanLevel(value: unknown): value is CavemanLevel {
	return typeof value === "string" && (CAVEMAN_LEVELS as readonly string[]).includes(value.trim().toLowerCase());
}

export function normalizeCavemanLevel(value: unknown): CavemanLevel | undefined {
	if (typeof value !== "string") return undefined;
	const normalized = value.trim().toLowerCase();
	return isCavemanLevel(normalized) ? normalized : undefined;
}

export function formatCavemanStatus(level: CavemanLevel): string {
	return level === "off" ? "caveman:off" : `caveman:${level}`;
}

export function loadCavemanConfig(): CavemanConfig {
	const defaults: CavemanConfig = {
		defaultLevel: "off",
		showStatus: true,
		skillPath: getDefaultCavemanSkillPath(),
	};
	const configPath = getDefaultCavemanConfigPath();
	if (!existsSync(configPath)) return defaults;

	try {
		const parsed = JSON.parse(readFileSync(configPath, "utf8")) as Partial<CavemanConfig> & { defaultLevel?: string };
		return {
			defaultLevel: normalizeCavemanLevel(parsed.defaultLevel) ?? defaults.defaultLevel,
			showStatus: typeof parsed.showStatus === "boolean" ? parsed.showStatus : defaults.showStatus,
			skillPath: typeof parsed.skillPath === "string" && parsed.skillPath.trim()
				? parsed.skillPath.trim()
				: defaults.skillPath,
		};
	} catch {
		return defaults;
	}
}

export function resolveInitialCavemanState(entries: readonly any[]): CavemanState {
	const config = loadCavemanConfig();

	for (let i = entries.length - 1; i >= 0; i -= 1) {
		const entry = entries[i];
		if (entry.type !== "custom" || entry.customType !== CAVEMAN_STATE_ENTRY) continue;
		const level = normalizeCavemanLevel(entry.data?.level);
		if (!level) continue;
		return {
			level,
			enabled: level !== "off",
			skillPath: config.skillPath,
			source: "session",
		};
	}

	if (config.defaultLevel !== "off") {
		return {
			level: config.defaultLevel,
			enabled: true,
			skillPath: config.skillPath,
			source: "config",
		};
	}

	return {
		level: "off",
		enabled: false,
		skillPath: config.skillPath,
		source: "default",
	};
}

function extractLevelSection(body: string, heading: string): string | undefined {
	const escapedHeading = heading.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
	const regex = new RegExp(`^## ${escapedHeading}\\s*\\n([\\s\\S]*?)(?=^## )`, "m");
	const match = body.match(regex);
	return match?.[1]?.trim();
}

export function readCavemanSkillBody(skillPath: string, level: CavemanLevel): { body?: string; error?: string } {
	try {
		if (!existsSync(skillPath)) {
			return { error: `Missing caveman skill file: ${skillPath}` };
		}
		const raw = readFileSync(skillPath, "utf8");
		const { body } = parseFrontmatter<Record<string, string>>(raw);
		const trimmed = body.trim();
		if (!trimmed) {
			return { error: `Empty caveman skill body: ${skillPath}` };
		}
		if (level === "off") return { body: "" };
		const shared = extractLevelSection(trimmed, "Shared Rules");
		const persistence = extractLevelSection(trimmed, "Persistence");
		const autoClarity = extractLevelSection(trimmed, "Auto-Clarity");
		const boundaries = extractLevelSection(trimmed, "Boundaries");
		const levelSection = extractLevelSection(trimmed, `Level: ${level}`);
		if (!shared || !persistence || !autoClarity || !boundaries || !levelSection) {
			return { error: `Missing required caveman sections in ${skillPath} for level ${level}` };
		}
		return {
			body: [
				"Respond terse like smart caveman. All technical substance stay. Only fluff die.",
				"",
				"## Shared Rules",
				shared,
				"",
				"## Persistence",
				persistence,
				"",
				"## Active Level",
				`Selected level: ${level}`,
				levelSection,
				"",
				"## Auto-Clarity",
				autoClarity,
				"",
				"## Boundaries",
				boundaries,
			].join("\n"),
		};
	} catch (error) {
		return {
			error: error instanceof Error
				? `Failed reading caveman skill file ${skillPath}: ${error.message}`
				: `Failed reading caveman skill file ${skillPath}`,
		};
	}
}
