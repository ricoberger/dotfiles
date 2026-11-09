/**
 * Pi Status Line Extension
 *
 * Replaces the built-in footer (via `ctx.ui.setFooter`) with a
 * re-implementation of it that adds a timer to the stats line:
 *
 *   ~/path/to/repo (branch) • session name
 *   ↑in ↓out R… W… CH…% $cost ctx%/window (auto) ⏱ active (Σ total)   model • thinking
 *   extension statuses (from ctx.ui.setStatus)
 *
 * Timers (both start with the first message of the session):
 * - Active time: Time the agent was working. It stops counting when the agent
 *   has settled (and while it waits on a blocking UI prompt) and resumes with
 *   the next message.
 * - Total time: Wall-clock time since the first message, including idle time.
 *
 * Limitations compared to the built-in footer:
 * - Auto-compaction state is not exposed to extensions, so "(auto)" is always
 *   shown.
 * - The experimental features marker and routed virtual models are not shown.
 * - Changes to the built-in footer in new Pi versions must be ported manually.
 * - Only one extension can own the footer; other `setFooter` users conflict.
 *
 * Timers are kept in memory and reset when a new session starts, is resumed,
 * forked or reloaded.
 */

import type { AssistantMessage } from "@earendil-works/pi-ai";
import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

type Theme = ExtensionContext["ui"]["theme"];

interface Usage {
  input: number;
  output: number;
  cacheRead: number;
  cacheWrite: number;
  cost: { total: number };
}

interface UsageTotals {
  input: number;
  output: number;
  cacheRead: number;
  cacheWrite: number;
  cost: number;
}

function formatDuration(ms: number): string {
  const total = Math.floor(ms / 1000);
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = total % 60;
  const pad = (n: number) => n.toString().padStart(2, "0");
  if (h > 0) return `${h}h${pad(m)}m${pad(s)}s`;
  if (m > 0) return `${m}m${pad(s)}s`;
  return `${s}s`;
}

// Same formatting as the built-in footer.
function formatTokens(count: number): string {
  if (count < 1000) return count.toString();
  if (count < 10000) return `${(count / 1000).toFixed(1)}k`;
  if (count < 1000000) return `${Math.round(count / 1000)}k`;
  if (count < 10000000) return `${(count / 1000000).toFixed(1)}M`;
  return `${Math.round(count / 1000000)}M`;
}

function formatCwd(cwd: string): string {
  const home = process.env.HOME || process.env.USERPROFILE;
  if (!home) return cwd;
  if (cwd === home) return "~";
  if (cwd.startsWith(`${home}/`)) return `~${cwd.slice(home.length)}`;
  return cwd;
}

function sanitizeStatusText(text: string): string {
  return text
    .replace(/[\r\n\t]/g, " ")
    .replace(/ +/g, " ")
    .trim();
}

export default function (pi: ExtensionAPI) {
  let firstStartedAt: number | undefined;
  let activeAccumulated = 0;
  let activeSince: number | undefined;
  let ctxRef: ExtensionContext | undefined;
  let requestRender: (() => void) | undefined;

  // Cache the usage scan; it only changes when entries are appended or the
  // leaf moves.
  let usageCache:
    | {
        key: string;
        totals: UsageTotals;
        latestCacheHitRate: number | undefined;
      }
    | undefined;

  const activeMs = (now: number) =>
    activeAccumulated + (activeSince !== undefined ? now - activeSince : 0);

  function startActive() {
    const now = Date.now();
    firstStartedAt ??= now;
    activeSince ??= now;
    requestRender?.();
  }

  function stopActive() {
    if (activeSince === undefined) return;
    activeAccumulated += Date.now() - activeSince;
    activeSince = undefined;
    requestRender?.();
  }

  function reset() {
    firstStartedAt = undefined;
    activeAccumulated = 0;
    activeSince = undefined;
    usageCache = undefined;
  }

  function getUsage(ctx: ExtensionContext) {
    const sm = ctx.sessionManager;
    const entries = sm.getEntries();
    const key = `${sm.getSessionId()}:${sm.getLeafId()}:${entries.length}`;
    if (usageCache?.key === key) return usageCache;

    const totals: UsageTotals = {
      input: 0,
      output: 0,
      cacheRead: 0,
      cacheWrite: 0,
      cost: 0,
    };
    const add = (u: Usage) => {
      totals.input += u.input;
      totals.output += u.output;
      totals.cacheRead += u.cacheRead;
      totals.cacheWrite += u.cacheWrite;
      totals.cost += u.cost.total;
    };

    let latestCacheHitRate: number | undefined;
    for (const entry of entries as any[]) {
      if (entry.type === "usage") {
        add(entry.usage);
      } else if (entry.type === "message" && entry.message.role === "assistant") {
        const u = (entry.message as AssistantMessage).usage;
        add(u);
        const prompt = u.input + u.cacheRead + u.cacheWrite;
        latestCacheHitRate = prompt > 0 ? (u.cacheRead / prompt) * 100 : undefined;
      } else if (
        entry.type === "message" &&
        entry.message.role === "toolResult" &&
        entry.message.usage
      ) {
        add(entry.message.usage);
      } else if (
        (entry.type === "branch_summary" || entry.type === "compaction") &&
        entry.usage
      ) {
        add(entry.usage);
      }
    }

    usageCache = { key, totals, latestCacheHitRate };
    return usageCache;
  }

  function isUsingSubscription(ctx: ExtensionContext): boolean {
    const model = ctx.model;
    if (!model) return false;
    if (model.provider === "kimi-coding") return true;
    try {
      const provider = ctx.modelRegistry.getProvider(model.provider) as any;
      return (
        ctx.modelRegistry.isUsingOAuth(model) &&
        provider?.auth?.oauth?.isSubscription === true
      );
    } catch {
      return false;
    }
  }

  function renderTimer(theme: Theme): string | undefined {
    if (firstStartedAt === undefined) return undefined;
    const now = Date.now();
    const active = formatDuration(activeMs(now));
    const total = formatDuration(now - firstStartedAt);
    return theme.fg("dim", `⏱ ${active} (Σ ${total})`);
  }

  function renderFooter(
    ctx: ExtensionContext,
    theme: Theme,
    footerData: {
      getGitBranch(): string | null;
      getExtensionStatuses(): ReadonlyMap<string, string>;
      getAvailableProviderCount(): number;
    },
    width: number,
  ): string[] {
    const sm = ctx.sessionManager;
    const model = ctx.model;

    // Line 1: pwd (branch) • session name
    let pwd = formatCwd(sm.getCwd());
    const branch = footerData.getGitBranch();
    if (branch) pwd = `${pwd} (${branch})`;
    const sessionName = sm.getSessionName();
    if (sessionName) pwd = `${pwd} • ${sessionName}`;

    // Line 2: stats + timer on the left, model on the right
    const { totals, latestCacheHitRate } = getUsage(ctx);
    const parts: string[] = [];
    if (totals.input) parts.push(`↑${formatTokens(totals.input)}`);
    if (totals.output) parts.push(`↓${formatTokens(totals.output)}`);
    if (totals.cacheRead) parts.push(`R${formatTokens(totals.cacheRead)}`);
    if (totals.cacheWrite) parts.push(`W${formatTokens(totals.cacheWrite)}`);
    if (
      (totals.cacheRead > 0 || totals.cacheWrite > 0) &&
      latestCacheHitRate !== undefined
    ) {
      parts.push(`CH${latestCacheHitRate.toFixed(1)}%`);
    }
    const subscription = isUsingSubscription(ctx);
    if (totals.cost || subscription) {
      parts.push(`$${totals.cost.toFixed(3)}${subscription ? " (sub)" : ""}`);
    }

    const contextUsage = ctx.getContextUsage();
    const contextWindow = contextUsage?.contextWindow ?? model?.contextWindow ?? 0;
    const percentValue = contextUsage?.percent ?? 0;
    const percent =
      contextUsage?.percent !== null && contextUsage?.percent !== undefined
        ? `${percentValue.toFixed(1)}%`
        : "?";
    // Auto-compaction state is not exposed to extensions; it is enabled in
    // settings.json, so always show the indicator like the built-in footer.
    const contextDisplay = `${percent}/${formatTokens(contextWindow)} (auto)`;
    const dimStats = theme.fg("dim", parts.join(" "));
    const contextStr =
      percentValue > 90
        ? theme.fg("error", contextDisplay)
        : percentValue > 70
          ? theme.fg("warning", contextDisplay)
          : theme.fg("dim", contextDisplay);

    const leftParts = [parts.length ? dimStats : "", contextStr];
    const timer = renderTimer(theme);
    if (timer) leftParts.push(timer);
    let left = leftParts.filter(Boolean).join(theme.fg("dim", " "));
    if (visibleWidth(left) > width) left = truncateToWidth(left, width, "...");
    const leftWidth = visibleWidth(left);

    const modelName = model?.id || "no-model";
    let rightNoProvider = modelName;
    if (model?.reasoning) {
      const level = ctx.thinkingLevel ?? pi.getThinkingLevel() ?? "off";
      rightNoProvider =
        level === "off" ? `${modelName} • thinking off` : `${modelName} • ${level}`;
    }
    const minPadding = 2;
    let right = rightNoProvider;
    if (footerData.getAvailableProviderCount() > 1 && model) {
      right = `(${model.provider}) ${rightNoProvider}`;
      if (leftWidth + minPadding + visibleWidth(right) > width) right = rightNoProvider;
    }

    let statsLine = left;
    const available = width - leftWidth - minPadding;
    if (available > 0) {
      const r = truncateToWidth(right, available, "");
      const padding = " ".repeat(Math.max(minPadding, width - leftWidth - visibleWidth(r)));
      statsLine = left + theme.fg("dim", padding + r);
    }

    const lines = [
      truncateToWidth(theme.fg("dim", pwd), width, theme.fg("dim", "...")),
      statsLine,
    ];

    // Line 3: other extension statuses, sorted by key
    const statuses = footerData.getExtensionStatuses();
    if (statuses.size > 0) {
      const line = Array.from(statuses.entries())
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([, text]) => sanitizeStatusText(text))
        .join(" ");
      lines.push(truncateToWidth(line, width, theme.fg("dim", "...")));
    }

    return lines;
  }

  pi.on("session_start", async (_event, ctx) => {
    reset();
    ctxRef = ctx;
    if (ctx.mode !== "tui") return;

    ctx.ui.setFooter((tui, theme, footerData) => {
      const unsubBranch = footerData.onBranchChange(() => tui.requestRender());
      const interval = setInterval(() => {
        if (firstStartedAt !== undefined) tui.requestRender();
      }, 1000);
      interval.unref?.();
      requestRender = () => tui.requestRender();

      return {
        dispose() {
          unsubBranch();
          clearInterval(interval);
          requestRender = undefined;
        },
        invalidate() {},
        render(width: number): string[] {
          const c = ctxRef;
          return c ? renderFooter(c, theme, footerData, width) : [];
        },
      };
    });
  });

  // `agent_start` can fire multiple times per prompt (retries, compaction,
  // queued messages); `startActive` is idempotent, so only the first counts.
  pi.on("agent_start", async (_event, ctx) => {
    ctxRef = ctx;
    startActive();
  });

  // Only stop once Pi has fully settled, not after each low-level run.
  pi.on("agent_settled", async (_event, ctx) => {
    ctxRef = ctx;
    stopActive();
  });

  // Don't count time spent waiting for the user to answer a prompt.
  pi.on("ui_prompt_start", async (_event, ctx) => {
    ctxRef = ctx;
    stopActive();
  });

  pi.on("ui_prompt_end", async (_event, ctx) => {
    ctxRef = ctx;
    if (firstStartedAt !== undefined && !ctx.isIdle()) startActive();
  });

  pi.on("session_shutdown", async () => {
    requestRender = undefined;
    ctxRef = undefined;
  });
}
