import { execFile } from "node:child_process";
import { promisify } from "node:util";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { isBlockedGitRoot, loadOrgmConfig } from "./lib/orgm-config";

const execFileAsync = promisify(execFile);

async function isInsideGit(cwd: string): Promise<boolean> {
	try {
		const { stdout } = await execFileAsync("git", ["rev-parse", "--is-inside-work-tree"], { cwd });
		return stdout.trim() === "true";
	} catch {
		return false;
	}
}

async function hasGitAvailable(): Promise<boolean> {
	try {
		await execFileAsync("git", ["--version"]);
		return true;
	} catch {
		return false;
	}
}

async function maybeInitGit(ctx: ExtensionContext): Promise<void> {
	const config = loadOrgmConfig();
	if (!config.git.autoInit) return;
	if (isBlockedGitRoot(ctx.cwd, config.git.ignoreRoots)) {
		if (ctx.hasUI) ctx.ui.notify("Git auto-init skipped for protected folder", "info");
		return;
	}
	if (await isInsideGit(ctx.cwd)) return;
	if (!(await hasGitAvailable())) return;
	try {
		await execFileAsync("git", ["init"], { cwd: ctx.cwd });
		if (ctx.hasUI) ctx.ui.notify("Git repository initialized for this project", "success");
	} catch (error) {
		console.error("git auto-init failed:", error);
		if (ctx.hasUI) ctx.ui.notify("Git auto-init failed; see logs", "warning");
	}
}

export default function (pi: ExtensionAPI) {
	pi.on("session_start", async (_event: unknown, ctx: ExtensionContext) => {
		await maybeInitGit(ctx);
	});

	pi.registerCommand("orgm-git", {
		description: "Show ORGM git automation status for current folder",
		handler: async (_args: string, ctx: ExtensionContext) => {
			const config = loadOrgmConfig();
			const blocked = isBlockedGitRoot(ctx.cwd, config.git.ignoreRoots);
			const inside = await isInsideGit(ctx.cwd);
			ctx.ui.notify(
				`git: ${inside ? "repo" : "no repo"}; autoInit=${config.git.autoInit}; blocked=${blocked}`,
				blocked ? "warning" : "info",
			);
		},
	});
}
