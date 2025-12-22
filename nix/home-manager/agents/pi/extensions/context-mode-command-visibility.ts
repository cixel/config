/**
 * context-mode-command-visibility
 *
 * Problem: context-mode registers its `ctx_*` tools with a custom Pi
 * `renderCall` that prints only the bold tool name (e.g. "ctx_execute").
 * The actual command/code being proxied through context-mode never shows
 * up in the transcript, so during long-running calls there's no way to see
 * what's executing short of inspecting the children of the pi process.
 *
 * We can't override that renderer: Pi resolves tools "first registration
 * per name wins" and the real `execute` lives in context-mode's MCP bridge,
 * so re-registering the name would hijack execution. Instead this extension
 * is a passive observer. It hooks the tool execution lifecycle and surfaces
 * the underlying command in a live widget above the editor, with a
 * per-command elapsed-time counter that ticks while a call is in flight.
 *
 * Scope: only context-mode's `ctx_*` tools. Built-in bash/read/edit/etc.
 * already render their arguments inline, so they're left alone.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const WIDGET_KEY = "ctx-cmd-visibility";

// context-mode tool surface (see openclaw.plugin.json `contracts.tools`).
const CTX_TOOLS = new Set([
  "ctx_execute",
  "ctx_execute_file",
  "ctx_index",
  "ctx_search",
  "ctx_fetch_and_index",
  "ctx_batch_execute",
  "ctx_stats",
  "ctx_doctor",
  "ctx_upgrade",
  "ctx_purge",
  "ctx_insight",
]);

const MAX_DETAIL = 96; // per-command command text budget
const MAX_BATCH_ROWS = 8; // commands listed for ctx_batch_execute
const HISTORY_KEEP = 4; // recently-finished rows retained in the widget

type InFlight = { tool: string; detail: string; start: number };
type Finished = { tool: string; detail: string; ms: number; ok: boolean };

// Collapse arbitrary text to a single readable line within `n` chars.
function oneLine(value: unknown, n = MAX_DETAIL): string {
  const s = String(value ?? "")
    .replace(/\r?\n+/g, " ⏎ ")
    .replace(/\s+/g, " ")
    .trim();
  return s.length > n ? s.slice(0, n - 1) + "…" : s;
}

// Turn a tool's arguments into a human-readable command summary. Best-effort
// and defensive: unknown shapes fall back to compact JSON.
function summarize(tool: string, args: any): string {
  try {
    switch (tool) {
      case "ctx_execute":
        return `(${args?.language ?? "?"}) ${oneLine(args?.code)}`;
      case "ctx_execute_file":
        return `(${args?.language ?? "?"}) ${oneLine(args?.path)} ⟶ ${oneLine(
          args?.code,
          48,
        )}`;
      case "ctx_batch_execute": {
        const cmds: any[] = Array.isArray(args?.commands) ? args.commands : [];
        const rows = cmds
          .slice(0, MAX_BATCH_ROWS)
          .map((c) => `· ${oneLine(c?.command, MAX_DETAIL + 20)}`);
        if (cmds.length > MAX_BATCH_ROWS) {
          rows.push(`· …+${cmds.length - MAX_BATCH_ROWS} more`);
        }
        // Encode multi-row payloads with newlines; the renderer splits them.
        return rows.join("\n");
      }
      case "ctx_fetch_and_index": {
        if (args?.url) return oneLine(args.url);
        const reqs: any[] = Array.isArray(args?.requests) ? args.requests : [];
        const urls = reqs.map((r) => r?.url).filter(Boolean);
        const head = urls.slice(0, 3).map((u) => oneLine(u, 70)).join("  ");
        return urls.length > 3 ? `${head}  …+${urls.length - 3}` : head;
      }
      case "ctx_search": {
        const q: any[] = Array.isArray(args?.queries) ? args.queries : [];
        const scope = args?.source ? ` @${args.source}` : "";
        return `${oneLine(q.join(" | "))}${scope}`;
      }
      case "ctx_index":
        return oneLine(args?.path ?? args?.source ?? "(inline content)");
      default:
        return ""; // ctx_stats / ctx_doctor / etc. are self-explanatory
    }
  } catch {
    try {
      return oneLine(JSON.stringify(args));
    } catch {
      return "";
    }
  }
}

export default function (pi: ExtensionAPI) {
  const inflight = new Map<string, InFlight>();
  const finished: Finished[] = [];
  let lastUI: any = null; // most recent ctx.ui, used by the ticking timer
  let timer: ReturnType<typeof setInterval> | null = null;

  function fmtMs(ms: number): string {
    if (ms < 1000) return `${ms}ms`;
    return `${(ms / 1000).toFixed(ms < 10_000 ? 1 : 0)}s`;
  }

  function detailLines(prefix: string, detail: string): string[] {
    if (!detail) return [prefix.trimEnd()];
    const parts = detail.split("\n");
    // First row carries the prefix; continuation rows are indented.
    const out = [`${prefix}${parts[0]}`];
    for (const p of parts.slice(1)) out.push(`        ${p}`);
    return out;
  }

  function render() {
    if (!lastUI?.setWidget) return;

    if (inflight.size === 0 && finished.length === 0) {
      lastUI.setWidget(WIDGET_KEY, []);
      return;
    }

    const now = Date.now();
    const lines: string[] = [];
    const active = inflight.size;
    lines.push(
      active > 0
        ? `context-mode · ${active} running`
        : "context-mode · idle",
    );

    for (const { tool, detail, start } of inflight.values()) {
      const elapsed = fmtMs(now - start);
      lines.push(...detailLines(`  ▶ ${tool} [${elapsed}]  `, detail));
    }

    const tail = finished.slice(-HISTORY_KEEP);
    for (const { tool, detail, ms, ok } of tail) {
      const mark = ok ? "✓" : "✗";
      lines.push(...detailLines(`  ${mark} ${tool} (${fmtMs(ms)})  `, detail));
    }

    lastUI.setWidget(WIDGET_KEY, lines);
  }

  function ensureTimer() {
    if (timer || inflight.size === 0) return;
    timer = setInterval(() => {
      if (inflight.size === 0) {
        if (timer) clearInterval(timer);
        timer = null;
        return;
      }
      render();
    }, 1000);
    // Don't keep the event loop alive on our account.
    (timer as any)?.unref?.();
  }

  pi.on("tool_execution_start", (event, ctx) => {
    if (!CTX_TOOLS.has(event.toolName)) return;
    lastUI = ctx.ui;
    inflight.set(event.toolCallId, {
      tool: event.toolName,
      detail: summarize(event.toolName, (event as any).args),
      start: Date.now(),
    });
    ensureTimer();
    render();
  });

  pi.on("tool_execution_end", (event, ctx) => {
    if (!CTX_TOOLS.has(event.toolName)) return;
    lastUI = ctx.ui;
    const entry = inflight.get(event.toolCallId);
    inflight.delete(event.toolCallId);
    finished.push({
      tool: event.toolName,
      detail: entry?.detail ?? "",
      ms: entry ? Date.now() - entry.start : 0,
      ok: !event.isError,
    });
    while (finished.length > HISTORY_KEEP) finished.shift();
    render();
  });

  // Tidy up the widget and timer when the session goes away.
  pi.on("session_shutdown", (_event, ctx) => {
    if (timer) clearInterval(timer);
    timer = null;
    inflight.clear();
    finished.length = 0;
    (ctx.ui ?? lastUI)?.setWidget?.(WIDGET_KEY, []);
  });
}
