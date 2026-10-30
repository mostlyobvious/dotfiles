export function worktreeEventForToolResult({ tool, isError, command, cwd, sessionId }) {
	if (tool === "bash" && !isError) {
		return {
			hook_event_name: "PostToolUse",
			session_id: sessionId,
			tool_input: { command },
			cwd,
		};
	}

	return {
		hook_event_name: "Heartbeat",
		session_id: sessionId,
	};
}
