import { spawnSync } from "node:child_process";
import {
	isBashToolResult,
	isEditToolResult,
	isToolCallEventType,
	isWriteToolResult,
} from "@earendil-works/pi-coding-agent";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const changeWritingSkillPath = /(^|\/)skills\/change-writing\/SKILL\.md$/;

function run(executable: string, event: Record<string, unknown>) {
	return spawnSync(executable, [], {
		input: JSON.stringify(event),
		encoding: "utf8",
	});
}

export default function (pi: ExtensionAPI) {
	let changeWritingApplied = false;
	const sessionId = `pi-${process.pid}`;

	pi.on("before_agent_start", () => {
		changeWritingApplied = false;
	});

	pi.on("tool_call", (event, ctx) => {
		if (isToolCallEventType("read", event)) {
			if (changeWritingSkillPath.test(event.input.path)) changeWritingApplied = true;
			return;
		}
		if (!isToolCallEventType("bash", event)) return;

		const result = run("agent-guard", {
			hook_event_name: "PreToolUse",
			tool_input: { command: event.input.command },
			cwd: ctx.cwd,
			change_writing_applied: changeWritingApplied,
		});
		if (result.status === 0) return;

		return {
			block: true,
			reason: result.stderr.trim().replace(/^BLOCKED:\s*/, "") || "agent-guard failed",
		};
	});

	pi.on("tool_result", (event, ctx) => {
		let toolInput: Record<string, unknown>;
		if (isBashToolResult(event)) {
			toolInput = { command: event.input.command };
			if (!event.isError) {
				run("agent-worktree", {
					hook_event_name: "PostToolUse",
					session_id: sessionId,
					tool_input: toolInput,
					cwd: ctx.cwd,
				});
			}
		} else if (isWriteToolResult(event) || isEditToolResult(event)) {
			toolInput = { path: event.input.path };
		} else {
			return;
		}

		const result = run("agent-guard", {
			hook_event_name: "PostToolUse",
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
		run("agent-worktree", {
			hook_event_name: "SessionEnd",
			session_id: sessionId,
		});
	});
}
