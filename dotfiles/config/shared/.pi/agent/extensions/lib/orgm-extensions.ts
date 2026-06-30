import { existsSync, readdirSync } from "node:fs";
import { extname, join } from "node:path";

function collectExtensionFiles(dir: string): string[] {
	if (!existsSync(dir)) return [];
	try {
		return readdirSync(dir, { withFileTypes: true })
			.filter((entry) => entry.isFile())
			.map((entry) => entry.name)
			.filter((name) => extname(name) === ".ts")
			.filter((name) => !name.endsWith(".disabled.ts"))
			.filter((name) => !name.includes(".disabled"))
			.map((name) => join(dir, name));
	} catch {
		return [];
	}
}

export function countActiveExtensions(extensionDir: string, settingsExtensions?: unknown): number {
	const active = new Set<string>();
	for (const file of collectExtensionFiles(extensionDir)) active.add(file);
	if (Array.isArray(settingsExtensions)) {
		for (const entry of settingsExtensions) {
			if (typeof entry === "string" && entry.trim()) active.add(entry.trim());
			else if (entry && typeof entry === "object" && "path" in entry) {
				const path = (entry as { path?: unknown }).path;
				if (typeof path === "string" && path.trim()) active.add(path.trim());
			}
		}
	}
	return active.size;
}
