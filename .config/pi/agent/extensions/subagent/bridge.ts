/**
 * Subagent Bridge - Worker side of background subagents
 *
 * Loaded with `pi -e bridge.ts` into the interactive pi of a background
 * subagent, which runs in a minimized Rex pane (see `background` in index.ts).
 * It is not discovered automatically, because only index.ts of this directory
 * is loaded as an extension.
 *
 * The worker directory ($PI_SUBAGENT_DIR) connects the worker with the parent:
 *   - result.json: written by the bridge. The status ("running", "idle" or
 *     "exited") and, after each finished run, its sequence number, the last
 *     assistant text and whether the parent started the run (forParent).
 *   - inbox/: written by the parent. One JSON file per request, either
 *     {"type": "steer", "message": "..."} or {"type": "stop"}.
 *
 * Runs started by the parent (the initial task and steer requests) are reported
 * back to the parent; runs started by the user typing in the pane are not.
 */

import * as fs from "node:fs";
import * as path from "node:path";
import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";

const INBOX_INTERVAL_MS = 500;

interface WorkerResult {
  status: "running" | "idle" | "exited";
  seq: number;
  forParent: boolean;
  aborted: boolean;
  text: string;
  updatedAt: number;
  pid: number;
}

function readResult(file: string): WorkerResult | undefined {
  try {
    return JSON.parse(fs.readFileSync(file, "utf-8")) as WorkerResult;
  } catch {
    return undefined;
  }
}

/** Write the file atomically, so the parent never reads a partial file. */
function writeJson(file: string, value: unknown): void {
  const tmp = `${file}.${process.pid}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(value), { mode: 0o600 });
  fs.renameSync(tmp, file);
}

/**
 * The text of the last assistant message on the current branch, starting at
 * entry FROM (the start of the run), so an interrupted run without output does
 * not report the text of an earlier run.
 */
function lastAssistantText(ctx: ExtensionContext, from: number): string {
  const branch = ctx.sessionManager.getBranch();
  for (let i = branch.length - 1; i >= Math.max(0, from); i--) {
    const entry = branch[i] as any;
    if (entry.type !== "message" || entry.message?.role !== "assistant")
      continue;
    const content = entry.message.content;
    if (typeof content === "string") return content;
    if (Array.isArray(content)) {
      const text = content
        .filter((part: any) => part.type === "text")
        .map((part: any) => part.text)
        .join("\n")
        .trim();
      if (text) return text;
    }
  }
  return "";
}

export default function (pi: ExtensionAPI) {
  const dir = process.env.PI_SUBAGENT_DIR;
  if (!dir) return;

  const resultFile = path.join(dir, "result.json");
  const inboxDir = path.join(dir, "inbox");
  const previous = readResult(resultFile);
  const result: WorkerResult = {
    status: "idle",
    seq: previous?.seq ?? 0,
    forParent: false,
    aborted: false,
    text: previous?.text ?? "",
    updatedAt: Date.now(),
    pid: process.pid,
  };
  // The initial task, passed as the first message, comes from the parent.
  let forParent = process.env.PI_SUBAGENT_TASK === "1";
  let ctxRef: ExtensionContext | undefined;
  let runStart = 0;
  let timer: ReturnType<typeof setInterval> | undefined;

  const write = () => {
    result.updatedAt = Date.now();
    try {
      writeJson(resultFile, result);
    } catch {
      /* the parent treats a missing result as unknown */
    }
  };

  const processInbox = () => {
    const ctx = ctxRef;
    if (!ctx) return;
    let files: string[];
    try {
      files = fs.readdirSync(inboxDir).filter((f) => f.endsWith(".json"));
    } catch {
      return;
    }
    for (const name of files.sort()) {
      const file = path.join(inboxDir, name);
      let request: { type?: string; message?: string };
      try {
        request = JSON.parse(fs.readFileSync(file, "utf-8"));
      } catch {
        continue;
      } finally {
        try {
          fs.unlinkSync(file);
        } catch {
          /* ignore */
        }
      }
      if (request.type === "steer" && request.message) {
        forParent = true;
        if (ctx.isIdle()) pi.sendUserMessage(request.message);
        else pi.sendUserMessage(request.message, { deliverAs: "steer" });
      } else if (request.type === "stop") {
        // An interrupted run is not reported to the parent.
        forParent = false;
        if (!ctx.isIdle()) ctx.abort();
      }
    }
  };

  pi.on("session_start", async (_event, ctx) => {
    ctxRef = ctx;
    fs.mkdirSync(inboxDir, { recursive: true });
    write();
    if (!timer) timer = setInterval(processInbox, INBOX_INTERVAL_MS);
  });

  pi.on("agent_start", async (_event, ctx) => {
    if (result.status !== "running")
      runStart = ctx.sessionManager.getBranch().length;
    result.status = "running";
    write();
  });

  pi.on("agent_settled", async (event, ctx) => {
    result.status = "idle";
    result.seq += 1;
    result.aborted = Boolean(event.aborted);
    result.forParent = forParent && !event.aborted;
    result.text = lastAssistantText(ctx, runStart);
    forParent = false;
    write();
  });

  pi.on("session_shutdown", async () => {
    if (timer) clearInterval(timer);
    timer = undefined;
    ctxRef = undefined;
    result.status = "exited";
    write();
  });
}
