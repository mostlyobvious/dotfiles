import { isBashToolResult } from "@earendil-works/pi-coding-agent";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const gitPushPattern = /(^|[\s&|;(])git(\s+-C\s+\S+)?\s+push(\s|$)/;
const reminder =
	"If the pushed branch has an open MR, compare its description with the new diff and propose an update when they disagree (merge-request skill, step 8).";

export default function (pi: ExtensionAPI) {
	pi.on("tool_result", (event) => {
		if (!isBashToolResult(event) || !gitPushPattern.test(String(event.input.command))) return;

		return { content: [...event.content, { type: "text", text: reminder }] };
	});
}
