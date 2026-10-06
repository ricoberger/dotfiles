/**
 * Copilot-style progress log for `pi -p` runs started by tower.
 *
 * Writes intermediate assistant text, tool calls, and their results to stderr
 * (tower appends stdout and stderr to the run log). The final answer is still
 * printed by pi on stdout. Does nothing outside print mode.
 *
 * Usage: pi -e /path/to/pi-progress.ts --session-id <id> -p <prompt>
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const MAX_ARG_LINES = 5;
const MAX_COLS = 100;

const write = (s: string) =>
  process.stderr.write(`${s.replace(/\s+$/, "")}\n\n`);

const clip = (s: string, n = MAX_COLS) =>
  s.length > n ? `${s.slice(0, n - 1)}…` : s;

/** Render a multi-line block with a `│ ` gutter, truncated like copilot. */
function block(text: string): string[] {
  const lines = text.replace(/\s+$/, "").split("\n");
  const out = lines.slice(0, MAX_ARG_LINES).map((l, i) => {
    const last = i === MAX_ARG_LINES - 1 && lines.length > MAX_ARG_LINES;
    return `  │ ${clip(l)}${last ? "…" : ""}`;
  });
  return out;
}

function header(
  toolName: string,
  args: any,
): { title: string; body: string[] } {
  args = args ?? {};
  switch (toolName) {
    case "bash":
      return { title: "bash", body: block(String(args.command ?? "")) };
    case "read": {
      const path = String(args.path ?? "");
      const skill = path.match(/([^/]+)\/SKILL\.md$/);
      if (skill) return { title: `skill(${skill[1]})`, body: [] };
      const range =
        args.offset || args.limit
          ? ` (${args.offset ?? 1}${args.limit ? `-${(args.offset ?? 1) + args.limit - 1}` : ""})`
          : "";
      return { title: `read ${path}${range}`, body: [] };
    }
    case "edit":
    case "write":
      return { title: `${toolName} ${args.path ?? ""}`, body: [] };
    default: {
      const json = JSON.stringify(args);
      return {
        title: toolName,
        body: json && json !== "{}" ? block(json) : [],
      };
    }
  }
}

function resultText(result: any): string {
  const content = result?.content;
  if (!Array.isArray(content)) return "";
  return content
    .filter((c: any) => c?.type === "text")
    .map((c: any) => c.text as string)
    .join("\n");
}

export default function (pi: ExtensionAPI) {
  let enabled = false;
  const pending = new Map<
    string,
    { toolName: string; args: any; start: number }
  >();

  pi.on("session_start", (_event, ctx) => {
    enabled = ctx.mode === "print";
  });

  pi.on("tool_execution_start", (event) => {
    if (!enabled) return;
    pending.set(event.toolCallId, {
      toolName: event.toolName,
      args: event.args,
      start: Date.now(),
    });
  });

  // Print on completion so parallel tool calls don't interleave.
  pi.on("tool_execution_end", (event) => {
    if (!enabled) return;
    const call = pending.get(event.toolCallId);
    pending.delete(event.toolCallId);
    const { title, body } = header(event.toolName, call?.args);
    const secs = call ? ((Date.now() - call.start) / 1000).toFixed(1) : "?";
    const indent = event.parentToolCallId ? "  " : "";
    const text = resultText(event.result).replace(/\s+$/, "");
    const lines = text ? text.split("\n").length : 0;
    const summary = event.isError
      ? `└ error: ${clip(text.split("\n")[0] ?? "", MAX_COLS - 10)}`
      : `└ ${lines} line${lines === 1 ? "" : "s"}… (${secs}s)`;
    write(
      [
        `${indent}${event.isError ? "✗" : "●"} ${title}`,
        ...body,
        `  ${summary}`,
      ]
        .map((l, i) => (i === 0 ? l : indent + l))
        .join("\n") + "\n",
    );
  });

  // Intermediate assistant text (the final answer is printed by pi on stdout).
  pi.on("message_end", (event) => {
    if (!enabled) return;
    const msg: any = event.message;
    if (msg?.role !== "assistant") return;
    if (msg.stopReason === "error" || msg.stopReason === "aborted") {
      write(`✗ ${msg.stopReason}: ${msg.errorMessage ?? "unknown error"}\n`);
      return;
    }
    const hasToolCalls = msg.content?.some((c: any) => c?.type === "toolCall");
    if (!hasToolCalls) return;
    const text = (msg.content ?? [])
      .filter((c: any) => c?.type === "text")
      .map((c: any) => c.text as string)
      .join("\n")
      .trim();
    if (text) write(`${text}\n`);
  });

  pi.on("session_compact", () => {
    if (enabled) write("… context compacted\n");
  });
}
