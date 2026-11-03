import { spawnSync } from "node:child_process";
import {
	isBashToolResult,
	isEditToolResult,
	isToolCallEventType,
	isWriteToolResult,
} from "@earendil-works/pi-coding-agent";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { worktreeEventForToolResult } from "./lib/agent-worktree-events.mjs";

const changeWritingSkillPath = /(^|\/)skills\/change-writing\/SKILL\.md$/;
const mergeRequestDescriptionPath = /(^|\/)[^/]*(?:desc|description)[^/]*\.md$/i;
const sharedToolName = /^mcp__.*(?:linear|slack)__/i;

function approvalMessages(ctx: any) {
	return ctx.sessionManager.getBranch().flatMap((entry: any) => {
		if (entry.type !== "message") return [];
		const role = entry.message.role;
		const content = entry.message.content;
		if (typeof content === "string") return [{ role, text: content }];
		if (!Array.isArray(content)) return [];

		const messages: Array<Record<string, unknown>> = [];
		for (const item of content) {
			if (item.type === "text") messages.push({ role, text: item.text });
			if (item.type === "toolCall" || item.type === "tool_use") {
				messages.push({
					role,
					tool_name: item.name,
					tool_input: item.arguments ?? item.input,
				});
			}
			if (item.type === "tool_result") messages.push({ role: "result" });
		}
		return messages;
	});
}

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
		run("agent-worktree", {
			hook_event_name: "Heartbeat",
			session_id: sessionId,
		});
	});

	pi.on("tool_call", (event, ctx) => {
		if (isToolCallEventType("read", event)) {
			if (changeWritingSkillPath.test(event.input.path)) changeWritingApplied = true;
			return;
		}
		let toolInput: Record<string, unknown>;
		if (isToolCallEventType("bash", event)) {
			toolInput = event.input as Record<string, unknown>;
		} else if (sharedToolName.test(event.toolName)) {
			toolInput = event.input as Record<string, unknown>;
		} else {
			return;
		}

		const result = run("agent-guard", {
			hook_event_name: "PreToolUse",
			tool_name: event.toolName,
			tool_input: toolInput,
			cwd: ctx.cwd,
			change_writing_applied: changeWritingApplied,
			approval_messages: approvalMessages(ctx),
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
			run("agent-worktree", worktreeEventForToolResult({
				tool: "bash",
				isError: event.isError,
				command: event.input.command,
				cwd: ctx.cwd,
				sessionId,
			}));
		} else {
			run("agent-worktree", worktreeEventForToolResult({ tool: "other", sessionId }));
			if (isWriteToolResult(event) || isEditToolResult(event)) {
				toolInput = { path: event.input.path };
				if (mergeRequestDescriptionPath.test(event.input.path)) {
					changeWritingApplied = false;
				}
			} else {
				return;
			}
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
