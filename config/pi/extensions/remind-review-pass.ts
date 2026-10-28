import { basename } from "node:path";
import { isEditToolResult, isWriteToolResult } from "@earendil-works/pi-coding-agent";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const reminder =
	"Run the change-writing Review Pass on mr-description.md before presenting it for approval (merge-request skill, step 6).";

export default function (pi: ExtensionAPI) {
	pi.on("tool_result", (event) => {
		if (!isWriteToolResult(event) && !isEditToolResult(event)) return;
		if (basename(String(event.input.path)) !== "mr-description.md") return;

		return { content: [...event.content, { type: "text", text: reminder }] };
	});
}
