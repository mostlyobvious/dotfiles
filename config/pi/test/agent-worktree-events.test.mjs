import assert from "node:assert/strict";
import test from "node:test";

import { worktreeEventForToolResult } from "../extensions/lib/agent-worktree-events.mjs";

test("successful Bash results can claim a started devenv", () => {
	assert.deepEqual(
		worktreeEventForToolResult({
			tool: "bash",
			isError: false,
			command: "devenv up -d",
			cwd: "/worktree",
			sessionId: "pi-42",
		}),
		{
			hook_event_name: "PostToolUse",
			session_id: "pi-42",
			tool_input: { command: "devenv up -d" },
			cwd: "/worktree",
		},
	);
});

test("failed Bash results only refresh existing ownership", () => {
	assert.deepEqual(
		worktreeEventForToolResult({
			tool: "bash",
			isError: true,
			command: "devenv up -d",
			cwd: "/worktree",
			sessionId: "pi-42",
		}),
		{
			hook_event_name: "Heartbeat",
			session_id: "pi-42",
		},
	);
});
