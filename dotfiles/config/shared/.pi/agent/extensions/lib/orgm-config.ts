import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { isAbsolute, join, normalize, resolve } from "node:path";

export type OrgmFlowName = "normal" | "pi-orchestrator" | "sdd-tdd" | string;

export interface OrgmGitConfig {
	autoInit: boolean;
	autoCommitCompletedWork: boolean;
	preferWorktreesForLongWork: boolean;
	ignoreRoots: string[];
}

export interface OrgmHostConfig {
	defaultPrimaryAgent: string;
	flows: Record<string, OrgmFlowName>;
	git: OrgmGitConfig;
}

export const DEFAULT_ORGM_CONFIG: OrgmHostConfig = {
	defaultPrimaryAgent: "pi",
	flows: {
		pi: "normal",
		"pi-orchestrator": "pi-orchestrator",
		"sdd-orchestrator": "sdd-tdd",
	},
	git: {
		autoInit: false,
		autoCommitCompletedWork: false,
		preferWorktreesForLongWork: true,
		ignoreRoots: ["~", "~/Nextcloud", "~/Nextcloud/**"],
	},
};

function isRecord(value: unknown): value is Record<string, unknown> {
	return typeof value === "object" && value !== null && !Array.isArray(value);
}

function mergeGitConfig(value: unknown): OrgmGitConfig {
	const raw = isRecord(value) ? value : {};
	return {
		autoInit: typeof raw.autoInit === "boolean" ? raw.autoInit : DEFAULT_ORGM_CONFIG.git.autoInit,
		autoCommitCompletedWork: typeof raw.autoCommitCompletedWork === "boolean"
			? raw.autoCommitCompletedWork
			: DEFAULT_ORGM_CONFIG.git.autoCommitCompletedWork,
		preferWorktreesForLongWork: typeof raw.preferWorktreesForLongWork === "boolean"
			? raw.preferWorktreesForLongWork
			: DEFAULT_ORGM_CONFIG.git.preferWorktreesForLongWork,
		ignoreRoots: Array.isArray(raw.ignoreRoots)
			? raw.ignoreRoots.filter((entry): entry is string => typeof entry === "string" && entry.trim().length > 0)
			: [...DEFAULT_ORGM_CONFIG.git.ignoreRoots],
	};
}

export function expandHomePath(path: string, home = homedir()): string {
	if (path === "~") return home;
	if (path.startsWith("~/")) return join(home, path.slice(2));
	return path;
}

export function normalizeFsPath(path: string, base = process.cwd(), home = homedir()): string {
	const expanded = expandHomePath(path, home);
	return normalize(isAbsolute(expanded) ? expanded : resolve(base, expanded));
}

export function isBlockedGitRoot(cwd: string, ignoreRoots = DEFAULT_ORGM_CONFIG.git.ignoreRoots, home = homedir()): boolean {
	const current = normalizeFsPath(cwd, process.cwd(), home);
	for (const root of ignoreRoots) {
		const isGlobChildren = root.endsWith("/**");
		const withoutGlob = isGlobChildren ? root.slice(0, -3) : root;
		const normalizedRoot = normalizeFsPath(withoutGlob, process.cwd(), home);
		if (isGlobChildren) {
			if (current === normalizedRoot || current.startsWith(`${normalizedRoot}/`)) return true;
			continue;
		}
		if (current === normalizedRoot) return true;
	}
	return false;
}

export function orgmConfigPath(home = homedir()): string {
	return join(home, ".pi", "agent", "orgm.json");
}

export function loadOrgmConfig(configPath = orgmConfigPath()): OrgmHostConfig {
	if (!existsSync(configPath)) return structuredClone(DEFAULT_ORGM_CONFIG);
	try {
		const raw = JSON.parse(readFileSync(configPath, "utf8"));
		if (!isRecord(raw)) return structuredClone(DEFAULT_ORGM_CONFIG);
		const flows = isRecord(raw.flows)
			? Object.fromEntries(Object.entries(raw.flows).filter(([, value]) => typeof value === "string")) as Record<string, string>
			: DEFAULT_ORGM_CONFIG.flows;
		return {
			defaultPrimaryAgent: typeof raw.defaultPrimaryAgent === "string" && raw.defaultPrimaryAgent.trim()
				? raw.defaultPrimaryAgent.trim()
				: DEFAULT_ORGM_CONFIG.defaultPrimaryAgent,
			flows: { ...DEFAULT_ORGM_CONFIG.flows, ...flows },
			git: mergeGitConfig(raw.git),
		};
	} catch {
		return structuredClone(DEFAULT_ORGM_CONFIG);
	}
}
