import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { getAgentDir } from "@mariozechner/pi-coding-agent";

export interface AgentStatusConfig {
	showWidget: boolean;
	showModel: boolean;
	showTokens: boolean;
	showCost: boolean;
	showPersistence: boolean;
	showSummary: boolean;
	showActivity: boolean;
	showCaveman: boolean;
}

export const AGENT_STATUS_CONFIG_DEFAULTS: AgentStatusConfig = {
	showWidget: true,
	showModel: true,
	showTokens: true,
	showCost: false,
	showPersistence: true,
	showSummary: true,
	showActivity: true,
	showCaveman: true,
};

export function getAgentStatusConfigPath(): string {
	return join(getAgentDir(), "agent-status.json");
}

export function loadAgentStatusConfig(): AgentStatusConfig {
	const path = getAgentStatusConfigPath();
	if (!existsSync(path)) return { ...AGENT_STATUS_CONFIG_DEFAULTS };
	try {
		const parsed = JSON.parse(readFileSync(path, "utf8")) as Partial<AgentStatusConfig>;
		return {
			showWidget: typeof parsed.showWidget === "boolean" ? parsed.showWidget : AGENT_STATUS_CONFIG_DEFAULTS.showWidget,
			showModel: typeof parsed.showModel === "boolean" ? parsed.showModel : AGENT_STATUS_CONFIG_DEFAULTS.showModel,
			showTokens: typeof parsed.showTokens === "boolean" ? parsed.showTokens : AGENT_STATUS_CONFIG_DEFAULTS.showTokens,
			showCost: typeof parsed.showCost === "boolean" ? parsed.showCost : AGENT_STATUS_CONFIG_DEFAULTS.showCost,
			showPersistence: typeof parsed.showPersistence === "boolean" ? parsed.showPersistence : AGENT_STATUS_CONFIG_DEFAULTS.showPersistence,
			showSummary: typeof parsed.showSummary === "boolean" ? parsed.showSummary : AGENT_STATUS_CONFIG_DEFAULTS.showSummary,
			showActivity: typeof parsed.showActivity === "boolean" ? parsed.showActivity : AGENT_STATUS_CONFIG_DEFAULTS.showActivity,
			showCaveman: typeof parsed.showCaveman === "boolean" ? parsed.showCaveman : AGENT_STATUS_CONFIG_DEFAULTS.showCaveman,
		};
	} catch {
		return { ...AGENT_STATUS_CONFIG_DEFAULTS };
	}
}

export function saveAgentStatusConfig(config: AgentStatusConfig): void {
	writeFileSync(getAgentStatusConfigPath(), `${JSON.stringify(config, null, 2)}\n`, "utf8");
}
