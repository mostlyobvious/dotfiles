import { isToolCallEventType } from "@earendil-works/pi-coding-agent";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const gitPushPattern = /(^|[\s&|;(])git\s+push/;
const forcePushPattern = /(^|\s)(-f|--force|--force-with-lease)([\s=]|$)/;
const protectedBranchPushPattern = /(^|[\s&|;(])git\s+push([^&|;]*[\s:/])(refs\/heads\/)?(master|main)([\s&|;:]|$)/;

const dangerousPatterns = [
	/git reset --hard/,
	/git clean -fd/,
	/git clean -f/,
	/git branch -D/,
	/git checkout \./,
	/git restore \./,
	/reset --hard/,
];

function block(command: string, reason: string) {
	return {
		block: true,
		reason: `'${command}' ${reason} The user has prevented you from doing this.`,
	};
}

export default function (pi: ExtensionAPI) {
	pi.on("tool_call", (event) => {
		if (!isToolCallEventType("bash", event)) return;

		const command = event.input.command;
		if (gitPushPattern.test(command)) {
			if (forcePushPattern.test(command)) return block(command, "is a force push.");
			if (protectedBranchPushPattern.test(command)) return block(command, "pushes a protected branch.");
			return;
		}

		for (const pattern of dangerousPatterns) {
			if (pattern.test(command)) {
				return block(command, `matches dangerous pattern '${pattern.source}'.`);
			}
		}
	});
}
