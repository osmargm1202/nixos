import { basename } from "node:path";
import type { ExtensionAPI, ExtensionCommandContext } from "@mariozechner/pi-coding-agent";
import { DynamicBorder, SessionManager, type SessionInfo } from "@mariozechner/pi-coding-agent";
import { Container, type SelectItem, SelectList, Text } from "@mariozechner/pi-tui";

const MAX_SELECTOR_HEIGHT = 12;

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

function truncate(text: string, max = 88): string {
	const clean = text.replace(/\s+/g, " ").trim();
	if (!clean) return "Untitled session";
	if (clean.length <= max) return clean;
	return `${clean.slice(0, Math.max(0, max - 1))}…`;
}

function buildSessionLabel(session: SessionInfo, isCurrent: boolean): string {
	const primary = session.name?.trim() || truncate(session.firstMessage || "Untitled session", 72);
	return isCurrent ? `${primary}  ✓ current` : primary;
}

function buildSessionDescription(session: SessionInfo, isCurrent: boolean): string {
	const parts = [
		formatTimestamp(session.modified),
		`${session.messageCount} msgs`,
		basename(session.path),
	];
	if (session.parentSessionPath) parts.push("fork/new-from-parent");
	if (isCurrent) parts.unshift("current");
	return parts.join(" · ");
}

function sortSessionsNewestFirst(sessions: SessionInfo[]): SessionInfo[] {
	return [...sessions].sort((a, b) => b.modified.getTime() - a.modified.getTime());
}

async function openSessionSelector(ctx: ExtensionCommandContext): Promise<string | null> {
	const currentSessionFile = ctx.sessionManager.getSessionFile();
	const sessions = sortSessionsNewestFirst(await SessionManager.list(ctx.cwd));

	if (sessions.length === 0) {
		ctx.ui.notify("No saved sessions found for this project", "warning");
		return null;
	}

	const items: SelectItem[] = sessions.map((session) => ({
		value: session.path,
		label: buildSessionLabel(session, session.path === currentSessionFile),
		description: buildSessionDescription(session, session.path === currentSessionFile),
	}));

	return await ctx.ui.custom<string | null>((tui, theme, _kb, done) => {
		const container = new Container();
		container.addChild(new DynamicBorder((s: string) => theme.fg("accent", s)));
		container.addChild(new Text(theme.fg("accent", theme.bold("Project Sessions")), 1, 0));
		container.addChild(new Text(theme.fg("muted", `Newest first · ${sessions.length} session${sessions.length === 1 ? "" : "s"}`), 1, 0));

		const selectList = new SelectList(items, Math.min(items.length, MAX_SELECTOR_HEIGHT), {
			selectedPrefix: (text) => theme.fg("accent", text),
			selectedText: (text) => theme.fg("accent", text),
			description: (text) => theme.fg("muted", text),
			scrollInfo: (text) => theme.fg("dim", text),
			noMatch: (text) => theme.fg("warning", text),
		});
		selectList.onSelect = (item) => done(item.value);
		selectList.onCancel = () => done(null);
		container.addChild(selectList);

		container.addChild(new Text(theme.fg("dim", "↑↓ navigate • enter recover/open • esc cancel"), 1, 0));
		container.addChild(new DynamicBorder((s: string) => theme.fg("accent", s)));

		return {
			render: (width: number) => container.render(width),
			invalidate: () => container.invalidate(),
			handleInput: (data: string) => {
				selectList.handleInput(data);
				tui.requestRender();
			},
		};
	}, { overlay: true });
}

export default function (pi: ExtensionAPI) {
	pi.registerCommand("sessions", {
		description: "List saved sessions for the current project and recover one",
		handler: async (_args, ctx) => {
			await ctx.waitForIdle();

			const selectedSession = await openSessionSelector(ctx);
			if (!selectedSession) return;

			const currentSessionFile = ctx.sessionManager.getSessionFile();
			if (selectedSession === currentSessionFile) {
				ctx.ui.notify("That session is already active", "info");
				return;
			}

			const recoveredMessage = `Recovered session: ${basename(selectedSession)}`;
			const result = await ctx.switchSession(selectedSession, {
				withSession: async (replacementCtx) => {
					replacementCtx.ui.notify(recoveredMessage, "success");
				},
			});
			if (result.cancelled) {
				ctx.ui.notify("Session switch cancelled", "info");
			}
		},
	});
}
