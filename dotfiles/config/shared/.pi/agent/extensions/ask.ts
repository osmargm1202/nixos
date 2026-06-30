import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Editor, type EditorTheme, Key, matchesKey, Text, truncateToWidth } from "@earendil-works/pi-tui";
import { Type } from "typebox";

const MAX_QUESTIONS = 4;
const MIN_OPTIONS = 2;
const MAX_OPTIONS = 4;
const ASK_CONFIG = join(homedir(), ".pi", "agent", "ask.jsonc");

const OptionSchema = Type.Object({
	label: Type.String({ maxLength: 60 }),
	description: Type.String(),
	preview: Type.Optional(Type.String()),
});

const QuestionSchema = Type.Object({
	question: Type.String(),
	header: Type.String({ maxLength: 16 }),
	options: Type.Array(OptionSchema, { minItems: MIN_OPTIONS, maxItems: MAX_OPTIONS }),
	multiSelect: Type.Optional(Type.Boolean()),
});

const QuestionParamsSchema = Type.Object({
	questions: Type.Array(QuestionSchema, { minItems: 1, maxItems: MAX_QUESTIONS }),
});

type Option = { label: string; description: string; preview?: string };
type Question = { question: string; header: string; options: Option[]; multiSelect?: boolean };
type QuestionParams = { questions: Question[] };
type ConfirmRule = { name: string; match: string; message?: string };
type AskConfig = { bash?: { confirm?: ConfirmRule[] } };

type Answer = {
	questionIndex: number;
	question: string;
	kind: "option" | "custom" | "chat" | "multi";
	answer: string | null;
	selected?: string[];
	preview?: string;
};
type QuestionnaireResult = { answers: Answer[]; cancelled: boolean; error?: string };

const ASK_USAGE_GUIDANCE = `ask_user_question guidance:
- When you need clarification, a decision, a preference, or missing requirements from the user, call ask_user_question instead of asking in plain assistant text.
- Group related clarification questions into one ask_user_question call; do not stack separate calls.
- Use multiSelect when multiple answers are valid.
- If ask_user_question returns cancelled or kind=chat, continue with normal conversation.`;

type Row =
	| { kind: "option"; option: Option; optionIndex: number }
	| { kind: "custom" }
	| { kind: "chat" };

export function stripJsonc(input: string): string {
	return input
		.replace(/\/\*[\s\S]*?\*\//g, "")
		.replace(/(^|\s)\/\/.*$/gm, "$1");
}

export function loadAskConfig(path = ASK_CONFIG): AskConfig {
	if (!existsSync(path)) return {};
	try {
		return JSON.parse(stripJsonc(readFileSync(path, "utf8"))) as AskConfig;
	} catch {
		return {};
	}
}

function matchingRule(command: string, config: AskConfig): ConfirmRule | undefined {
	for (const rule of config.bash?.confirm ?? []) {
		try {
			if (new RegExp(rule.match, "i").test(command)) return rule;
		} catch {
			continue;
		}
	}
	return undefined;
}

function validateParams(params: QuestionParams): string | undefined {
	if (!Array.isArray(params.questions) || params.questions.length < 1 || params.questions.length > MAX_QUESTIONS) {
		return `Expected 1-${MAX_QUESTIONS} questions`;
	}
	for (const [index, question] of params.questions.entries()) {
		if (!question.question?.trim()) return `Question ${index + 1} is missing question text`;
		if (!question.header?.trim()) return `Question ${index + 1} is missing a header`;
		if (!Array.isArray(question.options) || question.options.length < MIN_OPTIONS || question.options.length > MAX_OPTIONS) {
			return `Question ${index + 1} must have ${MIN_OPTIONS}-${MAX_OPTIONS} options`;
		}
		for (const [optionIndex, option] of question.options.entries()) {
			if (!option.label?.trim()) return `Question ${index + 1}, option ${optionIndex + 1} is missing a label`;
			if (typeof option.description !== "string") return `Question ${index + 1}, option ${optionIndex + 1} is missing a description`;
		}
	}
	return undefined;
}

function rowsFor(question: Question): Row[] {
	const rows: Row[] = question.options.map((option, optionIndex) => ({ kind: "option", option, optionIndex }));
	if (!question.multiSelect) {
		rows.push({ kind: "custom" }, { kind: "chat" });
	}
	return rows;
}

function answerText(answer: Answer): string {
	if (answer.kind === "multi") return `${answer.question}: ${answer.selected?.join(", ") || "(none selected)"}`;
	if (answer.kind === "chat") return `${answer.question}: user asked to chat about this`;
	if (answer.kind === "custom") return `${answer.question}: user wrote: ${answer.answer ?? ""}`;
	return `${answer.question}: user selected: ${answer.answer ?? ""}`;
}

async function runQuestionnaire(ctx: ExtensionContext, params: QuestionParams) {
	const validationError = validateParams(params);
	if (validationError) {
		return {
			content: [{ type: "text", text: `Error: ${validationError}` }],
			details: { answers: [], cancelled: true, error: validationError } satisfies QuestionnaireResult,
		};
	}

	const questions = params.questions;
	const isMultiQuestion = questions.length > 1;
	const totalTabs = questions.length + 1;

	const result = await ctx.ui.custom<QuestionnaireResult>((tui, theme, _keybindings, done) => {
		let currentTab = 0;
		let rowIndex = 0;
		let inputMode = false;
		let inputQuestionIndex: number | null = null;
		let cachedWidth: number | undefined;
		let cachedLines: string[] | undefined;
		const answers = new Map<number, Answer>();
		const multiSelections = new Map<number, Set<string>>();

		const editorTheme: EditorTheme = {
			borderColor: (s) => theme.fg("accent", s),
			selectList: {
				selectedPrefix: (t) => theme.fg("accent", t),
				selectedText: (t) => theme.fg("accent", t),
				description: (t) => theme.fg("muted", t),
				scrollInfo: (t) => theme.fg("dim", t),
				noMatch: (t) => theme.fg("warning", t),
			},
		};
		const editor = new Editor(tui, editorTheme);

		function refresh() {
			cachedWidth = undefined;
			cachedLines = undefined;
			tui.requestRender();
		}

		function currentQuestion(): Question | undefined {
			return questions[currentTab];
		}

		function currentRows(): Row[] {
			const question = currentQuestion();
			return question ? rowsFor(question) : [];
		}

		function allAnswered(): boolean {
			return questions.every((_question, index) => answers.has(index));
		}

		function selectedLabels(questionIndex: number): string[] {
			return Array.from(multiSelections.get(questionIndex) ?? []);
		}

		function saveAnswer(answer: Answer) {
			answers.set(answer.questionIndex, answer);
		}

		function advance() {
			if (!isMultiQuestion) {
				done({ answers: Array.from(answers.values()).sort((a, b) => a.questionIndex - b.questionIndex), cancelled: false });
				return;
			}
			currentTab = currentTab < questions.length - 1 ? currentTab + 1 : questions.length;
			rowIndex = 0;
			refresh();
		}

		function finish(cancelled: boolean, error?: string) {
			done({
				answers: Array.from(answers.values()).sort((a, b) => a.questionIndex - b.questionIndex),
				cancelled,
				error,
			});
		}

		editor.onSubmit = (value) => {
			if (inputQuestionIndex === null) return;
			const question = questions[inputQuestionIndex];
			const answer = value.trim() || "(no response)";
			saveAnswer({ questionIndex: inputQuestionIndex, question: question.question, kind: "custom", answer });
			inputMode = false;
			inputQuestionIndex = null;
			editor.setText("");
			advance();
		};

		function handleInput(data: string) {
			if (inputMode) {
				if (matchesKey(data, Key.escape)) {
					inputMode = false;
					inputQuestionIndex = null;
					editor.setText("");
					refresh();
					return;
				}
				editor.handleInput(data);
				refresh();
				return;
			}

			if (matchesKey(data, Key.escape)) {
				finish(true);
				return;
			}

			if (isMultiQuestion) {
				if (matchesKey(data, Key.tab) || matchesKey(data, Key.right)) {
					currentTab = (currentTab + 1) % totalTabs;
					rowIndex = 0;
					refresh();
					return;
				}
				if (matchesKey(data, Key.shift("tab")) || matchesKey(data, Key.left)) {
					currentTab = (currentTab - 1 + totalTabs) % totalTabs;
					rowIndex = 0;
					refresh();
					return;
				}
			}

			if (currentTab === questions.length) {
				if (matchesKey(data, Key.enter) && allAnswered()) finish(false);
				return;
			}

			const question = currentQuestion();
			if (!question) return;
			const rows = currentRows();

			if (matchesKey(data, Key.up)) {
				rowIndex = Math.max(0, rowIndex - 1);
				refresh();
				return;
			}
			if (matchesKey(data, Key.down)) {
				rowIndex = Math.min(rows.length - 1, rowIndex + 1);
				refresh();
				return;
			}

			const row = rows[rowIndex];
			if (!row) return;

			if (question.multiSelect && row.kind === "option" && matchesKey(data, Key.space)) {
				const selected = multiSelections.get(currentTab) ?? new Set<string>();
				if (selected.has(row.option.label)) selected.delete(row.option.label);
				else selected.add(row.option.label);
				multiSelections.set(currentTab, selected);
				saveAnswer({ questionIndex: currentTab, question: question.question, kind: "multi", answer: null, selected: Array.from(selected) });
				refresh();
				return;
			}

			if (matchesKey(data, Key.enter)) {
				if (question.multiSelect) {
					const selected = selectedLabels(currentTab);
					saveAnswer({ questionIndex: currentTab, question: question.question, kind: "multi", answer: null, selected });
					advance();
					return;
				}
				if (row.kind === "custom") {
					inputMode = true;
					inputQuestionIndex = currentTab;
					editor.setText("");
					refresh();
					return;
				}
				if (row.kind === "chat") {
					saveAnswer({ questionIndex: currentTab, question: question.question, kind: "chat", answer: null });
					advance();
					return;
				}
				saveAnswer({
					questionIndex: currentTab,
					question: question.question,
					kind: "option",
					answer: row.option.label,
					preview: row.option.preview,
				});
				advance();
			}
		}

		function render(width: number): string[] {
			if (cachedLines && cachedWidth === width) return cachedLines;
			const lines: string[] = [];
			const add = (line: string = "") => lines.push(truncateToWidth(line, width));
			const question = currentQuestion();
			const rows = currentRows();
			const activeRow = rows[rowIndex];

			add(theme.fg("accent", "─".repeat(width)));
			if (isMultiQuestion) {
				const tabs = questions.map((q, index) => {
					const done = answers.has(index) ? "■" : "□";
					const label = ` ${done} ${q.header || `Q${index + 1}`} `;
					return index === currentTab ? theme.bg("selectedBg", theme.fg("text", label)) : theme.fg(answers.has(index) ? "success" : "muted", label);
				});
				const submit = currentTab === questions.length
					? theme.bg("selectedBg", theme.fg("text", " ✓ Submit "))
					: theme.fg(allAnswered() ? "success" : "dim", " ✓ Submit ");
				add(` ${tabs.join(" ")} ${submit}`);
				add();
			}

			if (inputMode && question) {
				add(theme.fg("text", ` ${question.question}`));
				add();
				add(theme.fg("muted", " Your answer:"));
				for (const line of editor.render(Math.max(1, width - 2))) add(` ${line}`);
				add();
				add(theme.fg("dim", " Enter to submit • Esc to return"));
			} else if (currentTab === questions.length) {
				add(theme.fg("accent", theme.bold(" Ready to submit")));
				add();
				for (const [index, q] of questions.entries()) {
					const answer = answers.get(index);
					add(answer ? ` ${theme.fg("muted", q.header + ":")} ${answer.selected?.join(", ") ?? answer.answer ?? "Chat about this"}` : ` ${theme.fg("warning", q.header + ": unanswered")}`);
				}
				add();
				add(allAnswered() ? theme.fg("success", " Press Enter to submit") : theme.fg("warning", " Answer all questions before submitting"));
			} else if (question) {
				add(theme.fg("text", ` ${question.question}`));
				add();
				for (const [index, row] of rows.entries()) {
					const selected = index === rowIndex;
					const prefix = selected ? theme.fg("accent", "> ") : "  ";
					if (row.kind === "option") {
						const checked = question.multiSelect ? (selectedLabels(currentTab).includes(row.option.label) ? "[x] " : "[ ] ") : "";
						add(prefix + theme.fg(selected ? "accent" : "text", `${checked}${index + 1}. ${row.option.label}`));
						if (row.option.description) add(`     ${theme.fg("muted", row.option.description)}`);
					} else if (row.kind === "custom") {
						add(prefix + theme.fg(selected ? "accent" : "text", `${index + 1}. Type something.`));
					} else {
						add(prefix + theme.fg(selected ? "accent" : "text", `${index + 1}. Chat about this`));
					}
				}
				if (activeRow?.kind === "option" && activeRow.option.preview) {
					add();
					add(theme.fg("muted", " Preview:"));
					for (const line of activeRow.option.preview.split("\n").slice(0, 8)) add(` ${theme.fg("dim", line)}`);
				}
			}

			add();
			const help = question?.multiSelect
				? " ↑↓ select • Space toggle • Enter commit • Esc cancel"
				: isMultiQuestion
					? " Tab/←→ tabs • ↑↓ select • Enter choose • Esc cancel"
					: " ↑↓ select • Enter choose • Esc cancel";
			add(theme.fg("dim", help));
			add(theme.fg("accent", "─".repeat(width)));

			cachedWidth = width;
			cachedLines = lines;
			return lines;
		}

		return { render, handleInput, invalidate: refresh };
	});

	if (result.cancelled) {
		return { content: [{ type: "text", text: result.error ? `Error: ${result.error}` : "User cancelled the questionnaire" }], details: result };
	}

	return {
		content: [{ type: "text", text: result.answers.map(answerText).join("\n") }],
		details: result,
	};
}

export default function (pi: ExtensionAPI) {
	pi.on("before_agent_start", async (event, ctx) => {
		if (!ctx.hasUI) return;
		return { systemPrompt: `${event.systemPrompt}\n\n${ASK_USAGE_GUIDANCE}` };
	});

	pi.on("tool_call", async (event, ctx) => {
		if (event.toolName !== "bash") return;
		const command = String((event.input as { command?: unknown }).command ?? "");
		const rule = matchingRule(command, loadAskConfig());
		if (!rule) return;
		if (!ctx.hasUI) return { block: true, reason: `Command matched ask rule: ${rule.name}` };
		const ok = await ctx.ui.confirm(`Confirm command: ${rule.name}`, `${rule.message ?? "Allow command?"}\n\n${command}`);
		if (!ok) return { block: true, reason: "Blocked by ask.ts" };
	});

	pi.registerTool({
		name: "ask_user_question",
		label: "Ask User Question",
		description: "Ask the user one or more structured questions with tabs, multi-select, and text answers.",
		promptSnippet: "Ask the user up to 4 structured questions when requirements are ambiguous",
		promptGuidelines: [
			"Use ask_user_question instead of plain assistant text whenever you need clarification, a decision, a preference, or missing requirements from the user.",
			"Do not ask free-form clarification questions in chat when ask_user_question can present structured choices.",
			"Group related questions in one ask_user_question call instead of stacking multiple calls.",
			"Use multiSelect when multiple answers are valid; otherwise allow the user to pick an option, type an answer, or chat about it.",
		],
		parameters: QuestionParamsSchema,
		async execute(_id, params, _signal, _onUpdate, ctx) {
			if (!ctx.hasUI) {
				return { content: [{ type: "text", text: "Error: UI not available" }], details: { answers: [], cancelled: true, error: "no_ui" } };
			}
			return runQuestionnaire(ctx, params as QuestionParams);
		},
		renderCall(args, theme) {
			const count = Array.isArray((args as any).questions) ? (args as any).questions.length : 0;
			return new Text(theme.fg("toolTitle", theme.bold("ask_user_question ")) + theme.fg("muted", `${count} question(s)`), 0, 0);
		},
		renderResult(result, _options, theme) {
			const details = result.details as QuestionnaireResult | undefined;
			if (!details || details.cancelled) return new Text(theme.fg("warning", "Cancelled"), 0, 0);
			return new Text(details.answers.map((a) => `${theme.fg("success", "✓")} ${a.question}: ${a.selected?.join(", ") ?? a.answer ?? "chat"}`).join("\n"), 0, 0);
		},
	});
}
