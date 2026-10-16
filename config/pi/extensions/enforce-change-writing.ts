import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { isAbsolute, join } from "node:path";
import { isToolCallEventType } from "@earendil-works/pi-coding-agent";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const changeWritingSkillPath = /(^|\/)skills\/change-writing\/SKILL\.md$/;
const mergeRequestPattern = /(^|[\s&|;(])(glab\s+mr\s+(create|edit|update)|gh\s+pr\s+(create|edit))([\s&|;)]|$)/;
const commitPattern = /(^|[\s&|;(])git(\s+-C\s+\S+)?\s+commit(\s|$)/;
const keepsMessagePattern = /--no-edit|--fixup/;
const scriptPattern = /[^\s"';|&()]+\.sh/g;

function scriptPublishesMergeRequest(script: string, cwd: string) {
	const path = script.startsWith("~/")
		? join(homedir(), script.slice(2))
		: isAbsolute(script)
			? script
			: join(cwd, script);
	return existsSync(path) && mergeRequestPattern.test(readFileSync(path, "utf8"));
}

function writesProse(command: string, cwd: string) {
	if (mergeRequestPattern.test(command)) return true;
	if (commitPattern.test(command) && !keepsMessagePattern.test(command)) return true;
	return (command.match(scriptPattern) ?? []).some((script) => scriptPublishesMergeRequest(script, cwd));
}

export default function (pi: ExtensionAPI) {
	let appliedChangeWriting = false;

	pi.on("before_agent_start", () => {
		appliedChangeWriting = false;
	});

	pi.on("tool_call", (event, ctx) => {
		if (isToolCallEventType("read", event)) {
			if (changeWritingSkillPath.test(event.input.path)) appliedChangeWriting = true;
			return;
		}

		if (!isToolCallEventType("bash", event)) return;
		if (appliedChangeWriting || !writesProse(event.input.command, ctx.cwd)) return;

		return {
			block: true,
			reason:
				"Commit messages and MR/PR descriptions require reading and applying " +
				`${join(homedir(), ".pi/agent/skills/change-writing/SKILL.md")} ` +
				"in the current turn before running the command.",
		};
	});
}
