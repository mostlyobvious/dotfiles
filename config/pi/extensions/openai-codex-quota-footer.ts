import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";
import { isAbsolute, relative, resolve, sep } from "node:path";

type RateLimitBucket = {
	limit: number;
	remaining: number;
	resetMs?: number;
};

let quotaStatus: string | undefined;
let requestRender: (() => void) | undefined;

function formatTokens(count: number): string {
	if (count < 1000) return count.toString();
	if (count < 10000) return `${(count / 1000).toFixed(1)}k`;
	if (count < 1000000) return `${Math.round(count / 1000)}k`;
	if (count < 10000000) return `${(count / 1000000).toFixed(1)}M`;
	return `${Math.round(count / 1000000)}M`;
}

function formatCwd(cwd: string, home: string | undefined): string {
	if (!home) return cwd;

	const resolvedCwd = resolve(cwd);
	const resolvedHome = resolve(home);
	const relativeToHome = relative(resolvedHome, resolvedCwd);
	const isInsideHome =
		relativeToHome === "" ||
		(relativeToHome !== ".." && !relativeToHome.startsWith(`..${sep}`) && !isAbsolute(relativeToHome));

	if (!isInsideHome) return cwd;
	return relativeToHome === "" ? "~" : `~${sep}${relativeToHome}`;
}

function parseNumber(value: string | undefined): number | undefined {
	if (!value) return undefined;
	const match = value.match(/\d+(?:\.\d+)?/);
	if (!match) return undefined;
	const parsed = Number(match[0]);
	return Number.isFinite(parsed) ? parsed : undefined;
}

function parseResetMs(value: string | undefined): number | undefined {
	if (!value) return undefined;

	const epoch = Number(value);
	if (Number.isFinite(epoch) && epoch > 1_000_000_000) {
		return epoch * 1000 - Date.now();
	}

	const seconds = value.match(/^(\d+(?:\.\d+)?)s?$/i);
	if (seconds) return Number(seconds[1]) * 1000;

	const minutes = value.match(/^(\d+(?:\.\d+)?)m$/i);
	if (minutes) return Number(minutes[1]) * 60_000;

	const hours = value.match(/^(\d+(?:\.\d+)?)h$/i);
	if (hours) return Number(hours[1]) * 3_600_000;

	return undefined;
}

function normalizeHeaders(headers: Record<string, string>): Map<string, string> {
	const normalized = new Map<string, string>();
	for (const [key, value] of Object.entries(headers)) {
		normalized.set(key.toLowerCase(), value);
	}
	return normalized;
}

function bucketFromHeaders(headers: Record<string, string>): RateLimitBucket | undefined {
	const normalized = normalizeHeaders(headers);
	const buckets: RateLimitBucket[] = [];

	for (const [key, value] of normalized) {
		const match = key.match(/(?:^|-)ratelimit-limit[-_]?(.+)?$/);
		if (!match) continue;

		const suffix = match[1] ?? "";
		const limit = parseNumber(value);
		const remainingKey = key.replace(/limit([-_]?.*)?$/, "remaining$1");
		const remaining =
			parseNumber(normalized.get(remainingKey)) ??
			(suffix ? parseNumber(normalized.get(`x-ratelimit-remaining-${suffix}`)) : undefined) ??
			(suffix ? parseNumber(normalized.get(`ratelimit-remaining-${suffix}`)) : undefined);
		if (limit === undefined || remaining === undefined || limit <= 0) continue;

		const resetKey = key.replace(/limit([-_]?.*)?$/, "reset$1");
		const resetMs =
			parseResetMs(normalized.get(resetKey)) ??
			(suffix ? parseResetMs(normalized.get(`x-ratelimit-reset-${suffix}`)) : undefined) ??
			(suffix ? parseResetMs(normalized.get(`ratelimit-reset-${suffix}`)) : undefined);
		buckets.push({ limit, remaining, resetMs });
	}

	return (
		buckets.find((bucket) => bucket.resetMs !== undefined && bucket.resetMs > 30 * 60_000 && bucket.resetMs <= 6 * 60 * 60_000) ??
		buckets.find((bucket) => bucket.limit > 100 && bucket.limit < 100_000) ??
		buckets[0]
	);
}

function quotaFromHeaders(headers: Record<string, string>): string | undefined {
	const bucket = bucketFromHeaders(headers);
	if (!bucket) return undefined;

	const usedPercent = Math.max(0, Math.min(100, ((bucket.limit - bucket.remaining) / bucket.limit) * 100));
	return `5h ${usedPercent.toFixed(0)}%`;
}

function sanitizeStatus(text: string): string {
	return text.replace(/[\r\n\t]/g, " ").replace(/ +/g, " ").trim();
}

export default function (pi: ExtensionAPI) {
	pi.on("after_provider_response", (event, ctx) => {
		if (ctx.model?.provider !== "openai-codex") return;

		const next = quotaFromHeaders(event.headers);
		if (!next || next === quotaStatus) return;

		quotaStatus = next;
		requestRender?.();
	});

	pi.on("session_start", (_event, ctx) => {
		if (ctx.mode !== "tui") return;

		ctx.ui.setFooter((tui, theme, footerData) => {
			requestRender = () => tui.requestRender();
			const unsub = footerData.onBranchChange(() => tui.requestRender());

			return {
				dispose: () => {
					unsub();
					requestRender = undefined;
				},
				invalidate() {},
				render(width: number): string[] {
					let totalInput = 0;
					let totalOutput = 0;
					let totalCacheRead = 0;
					let totalCacheWrite = 0;
					let totalCost = 0;
					let latestCacheHitRate: number | undefined;

					for (const entry of ctx.sessionManager.getEntries()) {
						if (entry.type === "message" && entry.message.role === "assistant") {
							const message = entry.message as AssistantMessage;
							totalInput += message.usage.input;
							totalOutput += message.usage.output;
							totalCacheRead += message.usage.cacheRead;
							totalCacheWrite += message.usage.cacheWrite;
							totalCost += message.usage.cost.total;

							const latestPromptTokens = message.usage.input + message.usage.cacheRead + message.usage.cacheWrite;
							latestCacheHitRate =
								latestPromptTokens > 0 ? (message.usage.cacheRead / latestPromptTokens) * 100 : undefined;
						}
					}

					let pwd = formatCwd(ctx.sessionManager.getCwd(), process.env.HOME || process.env.USERPROFILE);
					const branch = footerData.getGitBranch();
					if (branch) pwd = `${pwd} (${branch})`;

					const sessionName = ctx.sessionManager.getSessionName();
					if (sessionName) pwd = `${pwd} • ${sessionName}`;

					const statsParts: string[] = [];
					if (totalInput) statsParts.push(`↑${formatTokens(totalInput)}`);
					if (totalOutput) statsParts.push(`↓${formatTokens(totalOutput)}`);
					if (totalCacheRead) statsParts.push(`R${formatTokens(totalCacheRead)}`);
					if (totalCacheWrite) statsParts.push(`W${formatTokens(totalCacheWrite)}`);
					if ((totalCacheRead > 0 || totalCacheWrite > 0) && latestCacheHitRate !== undefined) {
						statsParts.push(`CH${latestCacheHitRate.toFixed(1)}%`);
					}

					const usingSubscription = ctx.model ? ctx.modelRegistry.isUsingOAuth(ctx.model) : false;
					if (totalCost || usingSubscription) {
						statsParts.push(`$${totalCost.toFixed(3)}${usingSubscription ? " (sub)" : ""}`);
					}

					const contextUsage = ctx.getContextUsage();
					const contextWindow = contextUsage?.contextWindow ?? ctx.model?.contextWindow ?? 0;
					const contextPercentValue = contextUsage?.percent ?? 0;
					const contextPercent = contextUsage?.percent !== null ? contextPercentValue.toFixed(1) : "?";
					const contextDisplay =
						contextPercent === "?"
							? `?/${formatTokens(contextWindow)} (auto)`
							: `${contextPercent}%/${formatTokens(contextWindow)} (auto)`;
					statsParts.push(contextDisplay);

					let statsLeft = statsParts.join(" ");
					let statsLeftWidth = visibleWidth(statsLeft);
					if (statsLeftWidth > width) {
						statsLeft = truncateToWidth(statsLeft, width, "...");
						statsLeftWidth = visibleWidth(statsLeft);
					}

					const modelName = ctx.model?.id ?? "no-model";
					let rightSideWithoutProvider = modelName;
					if (ctx.model?.reasoning) {
						const thinkingLevel = pi.getThinkingLevel() || "off";
						rightSideWithoutProvider =
							thinkingLevel === "off" ? `${modelName} • thinking off` : `${modelName} • ${thinkingLevel}`;
					}
					if (quotaStatus && ctx.model?.provider === "openai-codex") {
						rightSideWithoutProvider = `${quotaStatus} • ${rightSideWithoutProvider}`;
					}

					let rightSide = rightSideWithoutProvider;
					if (footerData.getAvailableProviderCount() > 1 && ctx.model) {
						rightSide = `(${ctx.model.provider}) ${rightSideWithoutProvider}`;
						if (statsLeftWidth + 2 + visibleWidth(rightSide) > width) {
							rightSide = rightSideWithoutProvider;
						}
					}

					const rightSideWidth = visibleWidth(rightSide);
					let statsLine: string;
					if (statsLeftWidth + 2 + rightSideWidth <= width) {
						statsLine = statsLeft + " ".repeat(width - statsLeftWidth - rightSideWidth) + rightSide;
					} else {
						const availableForRight = width - statsLeftWidth - 2;
						if (availableForRight > 0) {
							const truncatedRight = truncateToWidth(rightSide, availableForRight, "");
							statsLine = statsLeft + " ".repeat(Math.max(0, width - statsLeftWidth - visibleWidth(truncatedRight))) + truncatedRight;
						} else {
							statsLine = statsLeft;
						}
					}

					const pwdLine = truncateToWidth(theme.fg("dim", pwd), width, theme.fg("dim", "..."));
					const lines = [pwdLine, theme.fg("dim", statsLine)];

					const statuses = footerData.getExtensionStatuses();
					if (statuses.size > 0) {
						const statusLine = Array.from(statuses.entries())
							.sort(([a], [b]) => a.localeCompare(b))
							.map(([, text]) => sanitizeStatus(text))
							.join(" ");
						lines.push(truncateToWidth(statusLine, width, theme.fg("dim", "...")));
					}

					return lines;
				},
			};
		});
	});
}
