import { isToolCallEventType } from "@earendil-works/pi-coding-agent";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const gitPushPattern = /(^|[\s&|;(])git\s+push/;
const forcePushPattern = /(^|\s)(-f|--force)([\s=]|$)/;
const protectedBranchPushPattern = /(^|[\s&|;(])git\s+push([^&|;]*[\s:/])(refs\/heads\/)?(master|main)([\s&|;:]|$)/;
const worktreeAddPattern = /(^|[\s&|;(])git(\s+-C\s+\S+)?\s+worktree\s+add/;
const dotfilesPathPattern = /(Code|worktrees)\/dotfiles/;

const dangerousPatterns = [
	/git reset --hard/,
	/git clean -fd/,
	/git clean -f/,
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
	pi.on("tool_call", (event, ctx) => {
		if (!isToolCallEventType("bash", event)) return;

		const command = event.input.command;
		if (worktreeAddPattern.test(command) && (dotfilesPathPattern.test(command) || dotfilesPathPattern.test(ctx.cwd))) {
			return block(command, "adds a worktree to dotfiles, which is edited in its main checkout.");
		}

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
