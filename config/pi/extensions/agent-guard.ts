import { spawnSync } from "node:child_process";
import { resolve } from "node:path";
import {
	isBashToolResult,
	isEditToolResult,
	isReadToolResult,
	isToolCallEventType,
	isWriteToolResult,
	SessionManager,
} from "@earendil-works/pi-coding-agent";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { worktreeEventForToolResult } from "./lib/agent-worktree-events.mjs";

const changeWritingSkillPath = /(^|\/)skills\/change-writing\/SKILL\.md$/;
const linearToolName = /^mcp__.*linear__/i;

function run(executable: string, event: Record<string, unknown>) {
	return spawnSync(executable, [], {
		input: JSON.stringify(event),
		encoding: "utf8",
	});
}

export default function (pi: ExtensionAPI) {
	const sessionId = `pi-${process.pid}`;
	let pendingWorktree: string | undefined;

	pi.registerCommand("enter-worktree-session", {
		description: "Move this session into its prepared worktree",
		handler: async (_args, ctx) => {
			const destination = pendingWorktree;
			pendingWorktree = undefined;
			if (!destination) return;

			const source = ctx.sessionManager.getSessionFile();
			if (!source) throw new Error("The current session has no file to move");

			const target = SessionManager.forkFrom(source, destination);
			const sessionFile = target.getSessionFile();
			if (!sessionFile) throw new Error("The worktree session has no file");

			await ctx.switchSession(sessionFile, {
				withSession: async (replacementCtx) => {
					await replacementCtx.sendUserMessage(
						`Continue the current task from ${destination}. The session now runs in that worktree.`,
					);
				},
			});
		},
	});

	pi.registerTool({
		name: "enter_worktree",
		label: "Enter Worktree",
		description: "Create or reuse a managed worktree for the current repository and move this session into it",
		parameters: Type.Object({
			name: Type.String({
				description: "Branch and worktree name",
				minLength: 1,
			}),
		}),
		executionMode: "sequential",
		async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
			const result = run("agent-worktree", {
				hook_event_name: "WorktreeCreate",
				host: "pi",
				name: params.name,
				cwd: ctx.cwd,
			});
			if (result.error || result.status !== 0) {
				return {
					content: [{
						type: "text",
						text: result.stderr.trim() || result.error?.message || "agent-worktree failed",
					}],
					details: {},
					isError: true,
				};
			}

			const destination = result.stdout.trim();
			if (!destination) {
				return {
					content: [{ type: "text", text: "agent-worktree returned no destination" }],
					details: {},
					isError: true,
				};
			}

			pendingWorktree = destination;
			return {
				content: [{ type: "text", text: `Prepared ${destination}. Pi will continue there.` }],
				details: { destination },
				terminate: true,
			};
		},
	});

	pi.on("before_agent_start", (event) => {
		run("agent-worktree", {
			hook_event_name: "Heartbeat",
			session_id: sessionId,
		});
		run("agent-guard", {
			hook_event_name: "UserPromptSubmit",
			host: "pi",
			session_id: sessionId,
			prompt: event.prompt,
		});
	});

	pi.on("tool_call", (event, ctx) => {
		let toolInput: Record<string, unknown>;
		if (isToolCallEventType("bash", event)) {
			toolInput = { command: event.input.command };
		} else if (linearToolName.test(event.toolName)) {
			toolInput = event.input as Record<string, unknown>;
		} else {
			return;
		}

		const result = run("agent-guard", {
			hook_event_name: "PreToolUse",
			host: "pi",
			session_id: sessionId,
			tool_name: event.toolName,
			tool_input: toolInput,
			cwd: ctx.cwd,
		});
		if (result.status === 0) return;

		return {
			block: true,
			reason: result.stderr.trim().replace(/^BLOCKED:\s*/, "") || "agent-guard failed",
		};
	});

	pi.on("tool_result", (event, ctx) => {
		let toolName: string;
		let toolInput: Record<string, unknown>;
		if (isBashToolResult(event)) {
			toolName = "Bash";
			toolInput = { command: event.input.command };
			run("agent-worktree", worktreeEventForToolResult({
				tool: "bash",
				isError: event.isError,
				command: event.input.command,
				cwd: ctx.cwd,
				sessionId,
			}));
		} else {
			run("agent-worktree", worktreeEventForToolResult({ tool: "other", sessionId }));
			if (isWriteToolResult(event)) {
				toolName = "Write";
				toolInput = { file_path: resolve(ctx.cwd, event.input.path) };
			} else if (isEditToolResult(event)) {
				toolName = "Edit";
				toolInput = { file_path: resolve(ctx.cwd, event.input.path) };
			} else if (isReadToolResult(event) && changeWritingSkillPath.test(event.input.path)) {
				toolName = "Skill";
				toolInput = { skill: "change-writing" };
			} else {
				return;
			}
		}

		const result = run("agent-guard", {
			hook_event_name: "PostToolUse",
			host: "pi",
			session_id: sessionId,
			tool_name: toolName,
			tool_input: toolInput,
			cwd: ctx.cwd,
		});
		if (!result.stdout) return;

		const output = JSON.parse(result.stdout);
		const reminder = output.hookSpecificOutput?.additionalContext;
		if (typeof reminder !== "string") return;

		return { content: [...event.content, { type: "text", text: reminder }] };
	});

	pi.on("agent_settled", () => {
		if (!pendingWorktree) return;
		pi.sendUserMessage("/enter-worktree-session", { expandPromptTemplates: true });
	});

	pi.on("session_shutdown", () => {
		run("agent-guard", {
			hook_event_name: "SessionEnd",
			session_id: sessionId,
		});
		run("agent-worktree", {
			hook_event_name: "SessionEnd",
			session_id: sessionId,
		});
	});
}
