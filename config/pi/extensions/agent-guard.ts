import { spawnSync } from "node:child_process";
import { resolve } from "node:path";
import {
	isBashToolResult,
	isEditToolResult,
	isReadToolResult,
	isToolCallEventType,
	isWriteToolResult,
} from "@earendil-works/pi-coding-agent";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
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

	pi.on("before_agent_start", (event) => {
		run("agent-worktree", {
			hook_event_name: "Heartbeat",
			session_id: sessionId,
		});
		run("agent-guard", {
			hook_event_name: "UserPromptSubmit",
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
