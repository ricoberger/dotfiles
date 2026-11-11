/**
 * Background subagents in minimized Rex panes
 *
 * With `background: true` (single mode), the subagent runs as an interactive
 * pi in a minimized floating Rex pane of the parent's tab instead of a hidden
 * `pi -p` process. The tool returns immediately; the user can open the pane to
 * watch and chat with the agent, and the result of each run started by the
 * parent (the task and later steer messages) is delivered to the parent as a
 * follow-up message.
 *
 * The worker loads bridge.ts and talks to the parent through its worker
 * directory (<agentDir>/subagent-sessions/workers/<sessionId>): result.json is
 * written by the worker, inbox/ by the parent (steer and stop requests).
 *
 * Workers keep running when the parent stops. The parent records every worker
 * it started in its session ("subagent-worker" entries), every steer and stop
 * request ("subagent-worker-request") and every delivered result
 * ("subagent-worker-delivered"), so it reconnects to its workers and delivers
 * results that finished in the meantime when the session is started or resumed
 * again. When a worker exits (its pane is closed) during a run started by the
 * parent, the parent is told that no result will come.
 */

import { execFile } from "node:child_process";
import { randomBytes } from "node:crypto";
import * as fs from "node:fs";
import * as path from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";
import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import type { AgentConfig } from "./agents.ts";

const execFileAsync = promisify(execFile);
const BRIDGE_PATH = path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  "bridge.ts",
);

const POLL_INTERVAL_MS = 1000;
const PANE_BOUNDS = [0.1, 0.1, 0.8, 0.8];
const PANE_SIZE = { columns: 120, rows: 36 };
const STATUS_PREVIEW_CHARS = 300;
const WORKER_ENTRY = "subagent-worker";
const DELIVERED_ENTRY = "subagent-worker-delivered";
const REQUEST_ENTRY = "subagent-worker-request";
export const RESULT_MESSAGE_TYPE = "subagent-result";

interface WorkerResult {
  status: "running" | "idle" | "exited";
  seq: number;
  forParent: boolean;
  aborted: boolean;
  text: string;
  updatedAt: number;
  pid?: number;
}

interface WorkerRecord {
  sessionId: string;
  agent: string;
  dir: string;
  /** Rex session, block and layer of the worker's pane. */
  rexSession: string;
  block: string;
  layer: string;
  cwd: string;
  task: string;
  startedAt: number;
  /** Sequence number of the last finished run before this worker started. */
  startSeq: number;
}

interface TrackedWorker {
  record: WorkerRecord;
  /** Sequence number of the last finished run that was handled. */
  delivered: number;
  /** Whether a run started by the parent has not reported back yet. */
  pending: boolean;
  /** The last task or steer message sent by the parent. */
  lastRequest: string;
}

export interface BackgroundDeps {
  sessionDir: string;
  sessionIdPattern: RegExp;
  safeAgentName: (name: string) => string;
  newSessionId: (agentName: string) => string;
  findSessionFile: (sessionId: string) => string | undefined;
  getPiInvocation: (args: string[]) => { command: string; args: string[] };
  isSessionRunning: (sessionId: string) => boolean;
}

export interface StartOptions {
  agent: AgentConfig;
  task: string;
  cwd: string;
  resumeSessionId?: string;
  model?: string;
  thinking?: string;
}

export interface ToolText {
  text: string;
  isError?: boolean;
}

function readResult(dir: string): WorkerResult | undefined {
  try {
    return JSON.parse(
      fs.readFileSync(path.join(dir, "result.json"), "utf-8"),
    ) as WorkerResult;
  } catch {
    return undefined;
  }
}

function processAlive(pid: number | undefined): boolean {
  if (!pid) return false;
  try {
    process.kill(pid, 0);
    return true;
  } catch (error) {
    return (error as NodeJS.ErrnoException).code === "EPERM";
  }
}

function preview(text: string, max: number): string {
  const flat = text.replace(/\s+/g, " ").trim();
  return flat.length > max ? `${flat.slice(0, max)}…` : flat;
}

/** Why background workers are not available, or undefined when they are. */
export function backgroundUnavailableReason(
  ctx: ExtensionContext,
): string | undefined {
  if (!ctx.hasUI) return "pi runs without an interactive UI";
  if (!process.env.REX_SESSION || !process.env.REX_BLOCK)
    return "pi does not run in a Rex pane";
  return undefined;
}

export class BackgroundWorkers {
  private workers = new Map<string, TrackedWorker>();
  private timer: ReturnType<typeof setInterval> | undefined;

  constructor(
    private pi: ExtensionAPI,
    private deps: BackgroundDeps,
  ) {}

  private workerDir(sessionId: string): string {
    return path.join(this.deps.sessionDir, "workers", sessionId);
  }

  /**
   * Whether a pane worker currently runs the session (its pi process is
   * alive). Used to refuse a second process on the same session file.
   */
  isActive(sessionId: string): boolean {
    const result = readResult(this.workerDir(sessionId));
    return Boolean(
      result && result.status !== "exited" && processAlive(result.pid),
    );
  }

  // ---------- Rex ----------

  private rexBin(): string {
    const dir = process.env.REX_BIN_DIR;
    return dir ? path.join(dir, "rex") : "rex";
  }

  private async rexCall<T>(
    method: string,
    args: Record<string, unknown>,
    rexSession = process.env.REX_SESSION,
  ): Promise<T> {
    const { stdout } = await execFileAsync(
      this.rexBin(),
      [
        "--autostart=false",
        "api",
        "call",
        method,
        JSON.stringify({ session_id: rexSession, ...args }),
      ],
      { timeout: 15_000, maxBuffer: 4 * 1024 * 1024 },
    );
    return JSON.parse(stdout) as T;
  }

  private async paneAlive(record: WorkerRecord): Promise<boolean> {
    try {
      await this.rexCall(
        "session.describe_block",
        { block_id: record.block },
        record.rexSession,
      );
      return true;
    } catch {
      return false;
    }
  }

  // ---------- Lifecycle ----------

  /** Reconnect to the workers recorded in the parent's session. */
  restore(ctx: ExtensionContext): void {
    this.workers.clear();
    // Replay the entries in order: a worker entry (re)starts a worker, a
    // request entry starts (steer) or ends (stop) a pending run, a delivered
    // entry ends it.
    for (const entry of ctx.sessionManager.getEntries() as any[]) {
      if (entry.type !== "custom" || !entry.data?.sessionId) continue;
      const data = entry.data;
      if (entry.customType === WORKER_ENTRY) {
        const record = data as WorkerRecord;
        this.workers.set(record.sessionId, {
          record,
          delivered: record.startSeq ?? 0,
          pending: true,
          lastRequest: record.task,
        });
        continue;
      }
      const worker = this.workers.get(data.sessionId);
      if (!worker) continue;
      if (entry.customType === REQUEST_ENTRY) {
        worker.pending = data.type === "steer";
        if (data.type === "steer" && typeof data.message === "string")
          worker.lastRequest = data.message;
      } else if (entry.customType === DELIVERED_ENTRY) {
        if (typeof data.seq === "number")
          worker.delivered = Math.max(worker.delivered, data.seq);
        worker.pending = false;
      }
    }
    if (this.workers.size > 0) this.startPolling();
  }

  stop(): void {
    if (this.timer) clearInterval(this.timer);
    this.timer = undefined;
    this.workers.clear();
  }

  private startPolling(): void {
    if (this.timer) return;
    this.timer = setInterval(() => this.poll(), POLL_INTERVAL_MS);
    this.timer.unref?.();
    this.poll();
  }

  private poll(): void {
    for (const worker of this.workers.values()) {
      const result = readResult(worker.record.dir);
      if (!result) continue;
      if (result.seq > worker.delivered) {
        worker.delivered = result.seq;
        if (!result.forParent) continue;
        worker.pending = false;
        this.pi.appendEntry(DELIVERED_ENTRY, {
          sessionId: worker.record.sessionId,
          seq: result.seq,
        });
        this.deliver(worker.record, result);
      } else if (
        worker.pending &&
        result.updatedAt >= worker.record.startedAt &&
        !processAlive(result.pid)
      ) {
        // The worker's pi is gone (pane closed) before its run finished. The
        // pid check instead of the status ignores a /reload in the worker,
        // which briefly reports "exited"; the time check ignores the result of
        // an earlier pane of a resumed session.
        worker.pending = false;
        this.pi.appendEntry(DELIVERED_ENTRY, {
          sessionId: worker.record.sessionId,
          seq: result.seq,
          exited: true,
        });
        this.deliverExit(worker.record);
      }
    }
  }

  private deliverExit(record: WorkerRecord): void {
    const content = [
      `Background subagent "${record.agent}" exited before it finished its run (its pane was closed), so no result will be delivered (session ${record.sessionId}).`,
      "",
      `[subagent session: ${record.sessionId} — pass as sessionId with agent "${record.agent}" to continue, optionally with background: true]`,
    ].join("\n");
    this.pi.sendMessage(
      {
        customType: RESULT_MESSAGE_TYPE,
        content,
        display: true,
        details: {
          sessionId: record.sessionId,
          agent: record.agent,
          exited: true,
        },
      },
      { deliverAs: "followUp", triggerTurn: true },
    );
  }

  private deliver(record: WorkerRecord, result: WorkerResult): void {
    const content = [
      `Background subagent "${record.agent}" finished a run (session ${record.sessionId}).`,
      "",
      result.text || "(no output)",
      "",
      `[subagent session: ${record.sessionId} — use subagent_control to steer it while its pane is open, or pass as sessionId with agent "${record.agent}" to continue]`,
    ].join("\n");
    this.pi.sendMessage(
      {
        customType: RESULT_MESSAGE_TYPE,
        content,
        display: true,
        details: { sessionId: record.sessionId, agent: record.agent },
      },
      { deliverAs: "followUp", triggerTurn: true },
    );
  }

  // ---------- Start ----------

  async start(options: StartOptions): Promise<ToolText> {
    const { agent, task, cwd } = options;
    const deps = this.deps;
    const args: string[] = ["--session-dir", deps.sessionDir];
    let sessionId: string;

    if (options.resumeSessionId) {
      const id = options.resumeSessionId;
      if (!deps.sessionIdPattern.test(id))
        return { text: `Invalid sessionId: "${id}".`, isError: true };
      if (!id.startsWith(`${deps.safeAgentName(agent.name)}-`))
        return {
          text: `Session "${id}" does not belong to agent "${agent.name}".`,
          isError: true,
        };
      const sessionFile = deps.findSessionFile(id);
      if (!sessionFile)
        return {
          text: `Unknown subagent session: "${id}" (looked in ${deps.sessionDir}).`,
          isError: true,
        };
      sessionId = id;
      args.push("--session", sessionFile);
    } else {
      sessionId = deps.newSessionId(agent.name);
      args.push("--session-id", sessionId);
    }

    if (deps.isSessionRunning(sessionId) || this.isActive(sessionId))
      return {
        text: `Subagent session "${sessionId}" is already running. Use subagent_control to steer it.`,
        isError: true,
      };

    const dir = this.workerDir(sessionId);
    fs.rmSync(path.join(dir, "inbox"), { recursive: true, force: true });
    fs.mkdirSync(path.join(dir, "inbox"), { recursive: true, mode: 0o700 });

    if (options.model) args.push("--model", options.model);
    if (options.thinking) args.push("--thinking", options.thinking);
    if (agent.tools && agent.tools.length > 0)
      args.push("--tools", agent.tools.join(","));
    args.push("--exclude-tools", "subagent,subagent_control");
    if (agent.systemPrompt.trim()) {
      const promptFile = path.join(dir, "system-prompt.md");
      fs.writeFileSync(promptFile, agent.systemPrompt, { mode: 0o600 });
      args.push("--append-system-prompt", promptFile);
    }
    args.push("-e", BRIDGE_PATH);
    args.push(`Task: ${task}`);

    const invocation = deps.getPiInvocation(args);
    const command = [
      "env",
      `PI_SUBAGENT_DIR=${dir}`,
      "PI_SUBAGENT_TASK=1",
      invocation.command,
      ...invocation.args,
    ];

    let record: WorkerRecord;
    try {
      const parent = await this.rexCall<{ block: { window_id?: string } }>(
        "session.describe_block",
        { block_id: process.env.REX_BLOCK },
      );
      if (!parent.block.window_id)
        throw new Error("the parent pi pane is not attached to a Rex tab");
      const created = await this.rexCall<{
        layer_id: string;
        block_ids: string[];
      }>("session.new_layer", {
        window_id: parent.block.window_id,
        bounds: PANE_BOUNDS,
        focus: false,
        layout: {
          block: {
            flavor: "com.superlogical.terminal.shell",
            label: `subagent:${agent.name}:${sessionId}`,
            options: {
              command,
              cwd,
              path_prepend: (process.env.PATH ?? "")
                .split(path.delimiter)
                .filter(Boolean),
              size: PANE_SIZE,
            },
          },
        },
      });
      await this.rexCall("session.set_layer_state", {
        layer_id: created.layer_id,
        state: "minimized",
      });
      record = {
        sessionId,
        agent: agent.name,
        dir,
        rexSession: process.env.REX_SESSION as string,
        block: created.block_ids[0],
        layer: created.layer_id,
        cwd,
        task,
        startedAt: Date.now(),
        startSeq: readResult(dir)?.seq ?? 0,
      };
    } catch (error) {
      return {
        text: `Failed to start the background subagent in Rex: ${(error as Error).message}`,
        isError: true,
      };
    }

    this.pi.appendEntry(WORKER_ENTRY, record);
    this.workers.set(sessionId, {
      record,
      delivered: record.startSeq,
      pending: true,
      lastRequest: task,
    });
    this.startPolling();

    return {
      text: [
        `Started background subagent "${agent.name}" in a minimized Rex pane (block ${record.block}).`,
        "Its result is delivered to you automatically as a follow-up message when it finishes; do not poll for it.",
        "Use subagent_control (status, steer, stop) to check on or redirect it.",
        "",
        `[subagent session: ${sessionId}]`,
      ].join("\n"),
    };
  }

  // ---------- Control ----------

  private async describe(worker: TrackedWorker): Promise<string> {
    const { record } = worker;
    const result = readResult(record.dir);
    const alive = result?.status !== "exited" && processAlive(result?.pid);
    const pane = alive ? await this.paneAlive(record) : false;
    const status = !result
      ? "starting"
      : alive
        ? result.status
        : "exited (pane closed)";
    const lines = [
      `- ${record.agent} (session ${record.sessionId}): ${status}${pane ? "" : alive ? ", pane not found" : ""}`,
      `  last request: ${preview(worker.lastRequest, 120)}`,
    ];
    if (result?.aborted)
      lines.push(
        `  last run: interrupted${result.text ? `, partial output: ${preview(result.text, STATUS_PREVIEW_CHARS)}` : ""}`,
      );
    else if (result?.text)
      lines.push(
        `  last result: ${preview(result.text, STATUS_PREVIEW_CHARS)}`,
      );
    return lines.join("\n");
  }

  private find(sessionId: string | undefined): TrackedWorker | undefined {
    return sessionId ? this.workers.get(sessionId) : undefined;
  }

  async status(sessionId?: string): Promise<ToolText> {
    if (sessionId) {
      const worker = this.find(sessionId);
      if (!worker)
        return {
          text: `No background subagent with session "${sessionId}" was started from this session.`,
          isError: true,
        };
      return { text: await this.describe(worker) };
    }
    if (this.workers.size === 0)
      return {
        text: "No background subagents were started from this session.",
      };
    const parts = await Promise.all(
      [...this.workers.values()].map((w) => this.describe(w)),
    );
    return { text: parts.join("\n") };
  }

  private send(
    sessionId: string | undefined,
    request: Record<string, unknown>,
  ): ToolText | undefined {
    const worker = this.find(sessionId);
    if (!worker)
      return {
        text: `No background subagent with session "${sessionId ?? ""}" was started from this session.`,
        isError: true,
      };
    if (!this.isActive(worker.record.sessionId))
      return {
        text: `The background subagent "${worker.record.agent}" is no longer running (its pane was closed). Continue it with subagent (agent "${worker.record.agent}", sessionId "${worker.record.sessionId}", optionally background: true).`,
        isError: true,
      };
    const inbox = path.join(worker.record.dir, "inbox");
    const name = `${Date.now()}-${randomBytes(4).toString("hex")}`;
    const tmp = path.join(inbox, `${name}.tmp`);
    fs.writeFileSync(tmp, JSON.stringify(request), { mode: 0o600 });
    fs.renameSync(tmp, path.join(inbox, `${name}.json`));
    return undefined;
  }

  /** Record a steer or stop request in the parent's session. */
  private request(
    sessionId: string,
    type: "steer" | "stop",
    message?: string,
  ): void {
    const worker = this.workers.get(sessionId);
    if (!worker) return;
    worker.pending = type === "steer";
    if (message) worker.lastRequest = message;
    this.pi.appendEntry(REQUEST_ENTRY, { sessionId, type, message });
  }

  steer(sessionId: string | undefined, message: string | undefined): ToolText {
    if (!message?.trim())
      return { text: "steer needs a message.", isError: true };
    const error = this.send(sessionId, { type: "steer", message });
    if (error) return error;
    this.request(sessionId as string, "steer", message);
    return {
      text: "Message sent to the background subagent. If it was idle, it starts a new run; its result is delivered to you automatically.",
    };
  }

  stopRun(sessionId: string | undefined): ToolText {
    const error = this.send(sessionId, { type: "stop" });
    if (error) return error;
    this.request(sessionId as string, "stop");
    return {
      text: "Stop requested: the current run of the background subagent is interrupted (no result is delivered for it). Its pane and session stay open.",
    };
  }
}
