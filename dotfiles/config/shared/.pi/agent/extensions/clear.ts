import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function (pi: ExtensionAPI) {
	pi.registerCommand("clear", {
		description: "Start a fresh recoverable session in the current working directory",
		handler: async (_args, ctx) => {
			await ctx.waitForIdle();

			const currentSessionFile = ctx.sessionManager.getSessionFile();
			const successMessage = currentSessionFile
				? "Started a fresh session. Previous session preserved for /sessions recovery."
				: "Started a fresh session";
			const result = await ctx.newSession({
				parentSession: currentSessionFile,
				withSession: async (replacementCtx) => {
					replacementCtx.ui.notify(successMessage, "success");
				},
			});
			if (result.cancelled) {
				ctx.ui.notify("Clear cancelled", "info");
			}
		},
	});
}
