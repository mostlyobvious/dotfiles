import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";
import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { isAbsolute, join, relative, resolve, sep } from "node:path";

type CodexRateWindow = {
	reset_at?: number;
	limit_window_seconds?: number;
	used_percent?: number;
	window_minutes?: number;
};

type CodexUsageResponse = {
	rate_limit?: CodexRateLimit;
	additional_rate_limits?: Array<{
		limit_name?: string;
		metered_feature?: string;
		rate_limit?: CodexRateLimit;
	}>;
};

type CodexRateLimit = {
	primary_window?: CodexRateWindow;
	secondary_window?: CodexRateWindow;
};

type CodexCredentials = {
	accessToken: string;
	accountId?: string;
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

function loadCodexCredentials(): CodexCredentials | undefined {
	const authPath = join(homedir(), ".pi", "agent", "auth.json");
	if (!existsSync(authPath)) return undefined;

	try {
		const data = JSON.parse(readFileSync(authPath, "utf8")) as {
			"openai-codex"?: { access?: string; accountId?: string };
		};
		const codexAuth = data["openai-codex"];
		if (!codexAuth?.access) return undefined;
		return { accessToken: codexAuth.access, accountId: codexAuth.accountId };
	} catch {
		return undefined;
	}
}

function windowSeconds(window: CodexRateWindow): number | undefined {
	if (typeof window.limit_window_seconds === "number") return window.limit_window_seconds;
	if (typeof window.window_minutes === "number") return window.window_minutes * 60;
	return undefined;
}

function formatWindowLabel(window: CodexRateWindow): string {
	const seconds = windowSeconds(window);
	if (!seconds || seconds <= 0) return "5h";
	const minutes = Math.round(seconds / 60);
	if (minutes === 300) return "5h";
	if (minutes === 10080) return "W";
	const hours = Math.round(seconds / 3600);
	if (hours >= 144) return "W";
	if (hours >= 24) return "D";
	return `${hours}h`;
}

function hasQuotaUsage(window: CodexRateWindow | undefined): window is CodexRateWindow {
	return !!window && typeof window.used_percent === "number" && Number.isFinite(window.used_percent);
}

function isSessionWindow(window: CodexRateWindow | undefined): window is CodexRateWindow {
	if (!hasQuotaUsage(window)) return false;
	const seconds = windowSeconds(window);
	return !seconds || seconds <= 24 * 60 * 60;
}

function windowRole(window: CodexRateWindow): "session" | "weekly" | "unknown" {
	const minutes = windowSeconds(window);
	if (!minutes) return "session";
	switch (Math.round(minutes / 60)) {
		case 300:
			return "session";
		case 10080:
			return "weekly";
		default:
			return "unknown";
	}
}

function normalizeWindows(primary: CodexRateWindow | undefined, secondary: CodexRateWindow | undefined) {
	if (primary && secondary) {
		const primaryRole = windowRole(primary);
		const secondaryRole = windowRole(secondary);
		if (primaryRole === "weekly" && secondaryRole !== "weekly") return { session: secondary, weekly: primary };
		return { session: primary, weekly: secondary };
	}
	if (primary && windowRole(primary) === "weekly") return { session: undefined, weekly: primary };
	if (secondary && windowRole(secondary) !== "weekly") return { session: secondary, weekly: undefined };
	return { session: primary, weekly: secondary };
}

function formatCodexWindow(window: CodexRateWindow): string {
	const usedPercent = Math.max(0, Math.min(100, window.used_percent ?? 0));
	return `${formatWindowLabel(window)} ${usedPercent.toFixed(0)}%`;
}

function formatRateLimit(rateLimit: CodexRateLimit | undefined): string | undefined {
	const windows = normalizeWindows(rateLimit?.primary_window, rateLimit?.secondary_window);
	return [windows.session, windows.weekly].filter(hasQuotaUsage).map(formatCodexWindow).join(" ") || undefined;
}

function formatAdditionalRateLimit(limit: NonNullable<CodexUsageResponse["additional_rate_limits"]>[number]): string | undefined {
	const status = formatRateLimit(limit.rate_limit);
	if (!status) return undefined;
	const name = limit.limit_name ?? limit.metered_feature;
	if (!name) return status;
	return `${name.replace(/^GPT-/, "").replace(/-Codex-/i, " ")} ${status}`;
}

function formatCodexQuota(data: CodexUsageResponse): string | undefined {
	const limits = [formatRateLimit(data.rate_limit), ...(data.additional_rate_limits ?? []).map(formatAdditionalRateLimit)].filter(
		(status): status is string => !!status,
	);
	return limits.join(" • ") || undefined;
}

function codexWindowFromHeaders(headers: Record<string, string>, prefix: "primary" | "secondary"): CodexRateWindow | undefined {
	const normalized = new Map(Object.entries(headers).map(([key, value]) => [key.toLowerCase(), value]));
	const used = Number(normalized.get(`x-codex-${prefix}-used-percent`));
	if (!Number.isFinite(used)) return undefined;

	const minutes = Number(normalized.get(`x-codex-${prefix}-window-minutes`));
	return {
		used_percent: used,
		window_minutes: Number.isFinite(minutes) ? minutes : undefined,
	};
}

function codexQuotaFromHeaders(headers: Record<string, string>): string | undefined {
	return formatRateLimit({
		primary_window: codexWindowFromHeaders(headers, "primary"),
		secondary_window: codexWindowFromHeaders(headers, "secondary"),
	});
}

async function fetchCodexQuota(): Promise<string | undefined> {
	const credentials = loadCodexCredentials();
	if (!credentials) return undefined;

	const controller = new AbortController();
	const timeout = setTimeout(() => controller.abort(), 10_000);
	try {
		const headers: Record<string, string> = {
			Authorization: `Bearer ${credentials.accessToken}`,
			Accept: "application/json",
		};
		if (credentials.accountId) headers["ChatGPT-Account-Id"] = credentials.accountId;

		const response = await fetch("https://chatgpt.com/backend-api/wham/usage", {
			headers,
			signal: controller.signal,
		});
		if (!response.ok) return undefined;

		return formatCodexQuota((await response.json()) as CodexUsageResponse);
	} catch {
		return undefined;
	} finally {
		clearTimeout(timeout);
	}
}

function sanitizeStatus(text: string): string {
	return text.replace(/[\r\n\t]/g, " ").replace(/ +/g, " ").trim();
}

export default function (pi: ExtensionAPI) {
	let refreshTimer: ReturnType<typeof setInterval> | undefined;
	let refreshing = false;

	pi.on("after_provider_response", (event, ctx) => {
		if (ctx.model?.provider !== "openai-codex") return;

		const next = codexQuotaFromHeaders(event.headers);
		if (!next || next === quotaStatus) return;

		quotaStatus = next;
		requestRender?.();
	});

	async function refreshCodexQuota(): Promise<void> {
		if (refreshing) return;
		refreshing = true;
		try {
			const next = await fetchCodexQuota();
			if (!next || next === quotaStatus) return;
			quotaStatus = next;
			requestRender?.();
		} finally {
			refreshing = false;
		}
	}

	pi.on("message_end", (event, ctx) => {
		if (event.message.role !== "assistant" || ctx.model?.provider !== "openai-codex") return;
		void refreshCodexQuota();
	});

	pi.on("session_shutdown", () => {
		if (refreshTimer) clearInterval(refreshTimer);
		refreshTimer = undefined;
		requestRender = undefined;
	});

	pi.on("session_start", (_event, ctx) => {
		if (ctx.mode !== "tui") return;

		void refreshCodexQuota();
		refreshTimer = setInterval(() => void refreshCodexQuota(), 5 * 60_000);

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

					const statuses = Array.from(footerData.getExtensionStatuses().entries())
						.filter(([name]) => name !== "mcp")
						.sort(([a], [b]) => a.localeCompare(b));
					if (statuses.length > 0) {
						const statusLine = statuses
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
