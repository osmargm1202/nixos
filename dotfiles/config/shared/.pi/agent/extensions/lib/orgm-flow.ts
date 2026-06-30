import { findPrimaryAgent, SYSTEM_AGENT } from "./agent-discovery";
import { loadOrgmConfig, type OrgmHostConfig } from "./orgm-config";

export function resolveConfiguredPrimary(cwd: string, currentPrimary = SYSTEM_AGENT, config: OrgmHostConfig = loadOrgmConfig()): string {
	if (currentPrimary && currentPrimary !== SYSTEM_AGENT) return currentPrimary;
	const configured = config.defaultPrimaryAgent || SYSTEM_AGENT;
	if (configured === SYSTEM_AGENT) return SYSTEM_AGENT;
	return findPrimaryAgent(cwd, configured, "both") ? configured : SYSTEM_AGENT;
}

export function resolvePrimaryFlow(primaryAgent: string, config: OrgmHostConfig = loadOrgmConfig()): string {
	return config.flows[primaryAgent] ?? (primaryAgent === SYSTEM_AGENT ? "normal" : primaryAgent);
}

export function applySavedModelConfig(_cwd: string): { updated: number; skipped: number; invalidPath?: string } {
	return { updated: 0, skipped: 0 };
}

export function registerSddCompatibilityCommands(pi: any): void {
	pi.registerCommand("orgm-status", {
		description: "Show ORGM flow status",
		handler: async (_args, ctx) => {
			const config = loadOrgmConfig();
			const primary = resolveConfiguredPrimary(ctx.cwd, SYSTEM_AGENT, config);
			const flow = resolvePrimaryFlow(primary, config);
			ctx.ui.notify(`ORGM flow: ${primary} (${flow})`, "info");
		},
	});
}
