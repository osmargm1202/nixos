import { existsSync, lstatSync, readFileSync, readdirSync } from "node:fs";
import { dirname, join, parse, relative } from "node:path";
import { getAgentDir, parseFrontmatter } from "@mariozechner/pi-coding-agent";

export type AgentSource = "user" | "project";
export type AgentScope = "user" | "project" | "both";

export const SYSTEM_AGENT = "pi";
export const DEFAULT_PRIMARY_AGENT = SYSTEM_AGENT;
export const PRIMARY_STATE_ENTRY = "pdd-primary-agent";
export const PRIMARY_STATE_EVENT = "pdd:primary-agent-changed";

const LEGACY_PRIMARY_ALIASES: Record<string, string> = {
	"nec-engeneer": "nec-engineer",
};

export interface AgentConfig {
	name: string;
	description: string;
	tools: string[];
	model?: string;
	systemPrompt: string;
	source: AgentSource;
	filePath: string;
	namespace?: string;
	displayName: string;
}

export interface PrimaryAgent {
	name: string;
	description: string;
	systemPrompt: string;
	filePath: string;
	dirPath: string;
	source: AgentSource;
}

export function parseTools(value: unknown): string[] {
	if (typeof value !== "string") return [];
	return value.split(",").map((tool) => tool.trim()).filter(Boolean);
}

function isReadableAgentFile(filePath: string): boolean {
	try {
		const stat = lstatSync(filePath);
		return stat.isFile() || stat.isSymbolicLink();
	} catch {
		return false;
	}
}

export function normalizePrimaryName(name: string): string {
	return LEGACY_PRIMARY_ALIASES[name] ?? name;
}

export function findNearestProjectAgentsDir(cwd: string): string | null {
	let current = cwd;
	while (true) {
		const candidate = join(current, ".pi", "agents");
		try {
			if (lstatSync(candidate).isDirectory()) return candidate;
		} catch {
			// keep walking
		}
		const parentPath = dirname(current);
		if (parentPath === current) return null;
		current = parentPath;
	}
}

function mergeByName<T extends { name: string }>(
	userItems: T[],
	projectItems: T[],
	scope: AgentScope,
): T[] {
	const merged = new Map<string, T>();
	if (scope !== "project") {
		for (const item of userItems) merged.set(item.name, item);
	}
	if (scope !== "user") {
		for (const item of projectItems) merged.set(item.name, item);
	}
	return Array.from(merged.values()).sort((a, b) => a.name.localeCompare(b.name));
}

export function readAgentConfig(filePath: string, source: AgentSource, rootDir?: string): AgentConfig | undefined {
	try {
		const raw = readFileSync(filePath, "utf8");
		const { frontmatter, body } = parseFrontmatter<Record<string, string>>(raw);
		const namespacePath = rootDir ? relative(rootDir, dirname(filePath)) : "";
		const namespace = namespacePath && namespacePath !== "." ? namespacePath.split("\\").join("/") : undefined;
		const name = frontmatter.name || parse(filePath).name;
		return {
			name,
			description: frontmatter.description || name,
			tools: parseTools(frontmatter.tools),
			model: frontmatter.model,
			systemPrompt: body.trim(),
			source,
			filePath,
			namespace,
			displayName: namespace ? `${namespace}/${name}` : name,
		} satisfies AgentConfig;
	} catch {
		return undefined;
	}
}

function loadAgentsRecursiveFromDir(
	dir: string,
	source: AgentSource,
	options?: {
		excludeDirNames?: Set<string>;
		excludeFileNames?: Set<string>;
	},
): AgentConfig[] {
	if (!existsSync(dir)) return [];
	const agents: AgentConfig[] = [];
	const excludeDirNames = options?.excludeDirNames ?? new Set<string>();
	const excludeFileNames = options?.excludeFileNames ?? new Set<string>();

	const walk = (currentDir: string) => {
		let entries: string[];
		try {
			entries = readdirSync(currentDir);
		} catch {
			return;
		}
		for (const entry of entries) {
			const fullPath = join(currentDir, entry);
			let stat;
			try {
				stat = lstatSync(fullPath);
			} catch {
				continue;
			}
			if (stat.isDirectory()) {
				if (excludeDirNames.has(entry)) continue;
				walk(fullPath);
				continue;
			}
			if (!(stat.isFile() || stat.isSymbolicLink()) || !entry.endsWith(".md")) continue;
			if (excludeFileNames.has(entry)) continue;
			const agent = readAgentConfig(fullPath, source, dir);
			if (agent) agents.push(agent);
		}
	};

	walk(dir);
	return agents;
}

function listPrimaryAgentsFromRoot(rootDir: string, source: AgentSource): PrimaryAgent[] {
	if (!existsSync(rootDir)) return [];
	try {
		return readdirSync(rootDir)
			.map((entry) => ({ entry, dirPath: join(rootDir, entry) }))
			.filter(({ dirPath }) => {
				try {
					return lstatSync(dirPath).isDirectory();
				} catch {
					return false;
				}
			})
			.map(({ entry, dirPath }) => ({ entry, dirPath, filePath: join(dirPath, "index.md") }))
			.filter(({ filePath }) => isReadableAgentFile(filePath))
			.map(({ entry, dirPath, filePath }) => {
				const raw = readFileSync(filePath, "utf8");
				const { frontmatter, body } = parseFrontmatter<Record<string, string>>(raw);
				const folderName = normalizePrimaryName(entry);
				const name = normalizePrimaryName(frontmatter.name || folderName);
				return {
					name,
					description: frontmatter.description || name,
					systemPrompt: body.trim(),
					filePath,
					dirPath,
					source,
				} satisfies PrimaryAgent;
			})
			.sort((a, b) => a.name.localeCompare(b.name));
	} catch {
		return [];
	}
}

export function discoverDeployableAgents(cwd: string, scope: AgentScope = "both"): AgentConfig[] {
	const userDir = join(getAgentDir(), "agents");
	const projectDir = findNearestProjectAgentsDir(cwd);
	const options = {
		excludeFileNames: new Set(["index.md"]),
	};
	const userAgents = scope === "project" ? [] : loadAgentsRecursiveFromDir(userDir, "user", options);
	const projectAgents = scope === "user" || !projectDir ? [] : loadAgentsRecursiveFromDir(projectDir, "project", options);
	return mergeByName(userAgents, projectAgents, scope);
}

export function discoverPrimaryAgents(cwd?: string, scope: AgentScope = "both"): PrimaryAgent[] {
	const userDir = join(getAgentDir(), "agents");
	const projectDir = cwd ? findNearestProjectAgentsDir(cwd) : null;
	const userAgents = scope === "project" ? [] : listPrimaryAgentsFromRoot(userDir, "user");
	const projectAgents = scope === "user" || !projectDir ? [] : listPrimaryAgentsFromRoot(projectDir, "project");
	return mergeByName(userAgents, projectAgents, scope);
}

export function findDeployableAgent(cwd: string, name: string, scope: AgentScope = "both"): AgentConfig | undefined {
	return discoverDeployableAgents(cwd, scope).find((agent) => agent.name === name);
}

export function findPrimaryAgent(cwd: string | undefined, name: string, scope: AgentScope = "both"): PrimaryAgent | undefined {
	const normalized = normalizePrimaryName(name);
	return discoverPrimaryAgents(cwd, scope).find((agent) => agent.name === normalized);
}

export function resolveDefaultPrimary(cwd?: string, scope: AgentScope = "both"): string {
	const primaries = discoverPrimaryAgents(cwd, scope);
	if (primaries.some((agent) => agent.name === DEFAULT_PRIMARY_AGENT)) return DEFAULT_PRIMARY_AGENT;
	return SYSTEM_AGENT;
}

export function restorePrimaryState(entries: readonly any[], cwd?: string, scope: AgentScope = "both"): string {
	for (let i = entries.length - 1; i >= 0; i -= 1) {
		const entry = entries[i];
		if (entry.type === "custom" && entry.customType === PRIMARY_STATE_ENTRY) {
			const rawName = entry.data?.selectedName;
			if (typeof rawName === "string") {
				const name = normalizePrimaryName(rawName);
				if (name === SYSTEM_AGENT) return SYSTEM_AGENT;
				if (findPrimaryAgent(cwd, name, scope)) return name;
			}
		}
	}
	return resolveDefaultPrimary(cwd, scope);
}

export function formatPrimaryLabel(name: string): string {
	return name === SYSTEM_AGENT ? SYSTEM_AGENT : `primary:${normalizePrimaryName(name)}`;
}
