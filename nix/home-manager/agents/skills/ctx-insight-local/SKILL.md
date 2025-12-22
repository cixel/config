---
name: ctx-insight-local
description: Open the context-mode Insight dashboard on this Nix-managed machine. Use this INSTEAD of the bundled `ctx_insight` MCP tool whenever the user asks to open the insight dashboard, view context-mode analytics, see past sessions, or run "ctx insight". The bundled tool shells out to `npx vite build` and fails here because `node`/`npm`/`npx` are intentionally not on PATH (Bun is). This skill uses Bun against the prebuilt cache and points at the correct per-adapter session/content roots.
---

# ctx-insight-local

The bundled `ctx_insight` MCP tool fails on this machine with:

```
Insight setup failed: Command failed: npx vite build
/bin/sh: npx: command not found
```

because the bundled tool unconditionally runs `npx vite build` on every invocation and this machine has no `node`/`npm`/`npx` in PATH, only Bun (from `nix/home-manager/home.nix`). Do NOT call `ctx_insight` here. Use this skill instead.

It also defaults `INSIGHT_SESSION_DIR` to `~/.claude/context-mode/sessions`, which on this machine holds only Claude Code's per-PID stats JSON files. The real pi session DBs live at `~/.pi/context-mode/sessions`. Pointing at the wrong root is why the dashboard ever appears empty.

## Steady-state launch (cache already populated)

The plugin source rarely changes between context-mode upgrades and `dist/` in the insight-cache stays valid across runs. Steady-state command:

```bash
CACHE=~/.claude/context-mode/insight-cache
SESSIONS=~/.pi/context-mode/sessions       # pi adapter sessions live here
CONTENT=~/.claude/context-mode/content     # FTS5 content store, shared across adapters
LOG=/tmp/ctx-insight-bun.log

# Free port 4747 in case a previous detached server is still bound.
lsof -ti:4747 | xargs -r kill 2>/dev/null
sleep 0.3

cd "$CACHE"
PORT=4747 \
  INSIGHT_SESSION_DIR="$SESSIONS" \
  INSIGHT_CONTENT_DIR="$CONTENT" \
  nohup bun server.mjs >"$LOG" 2>&1 &
PID=$!
disown $PID 2>/dev/null
sleep 1.2

# Verify the API is responding.
curl -sS -o /dev/null -w "HTTP %{http_code}\n" http://127.0.0.1:4747/api/overview

# Optional: open the browser (macOS).
open http://localhost:4747
```

Then tell the user:

- URL is http://localhost:4747
- PID is whatever `$PID` printed, log at `/tmp/ctx-insight-bun.log`
- Stop with `kill $PID` (or `lsof -ti:4747 | xargs kill`). This server is detached from the agent and outlives the session.
- Refresh the page for updated metrics.

## Why Bun is sufficient

`insight/server.mjs` picks its SQLite driver at runtime: `bun:sqlite` under Bun, `better-sqlite3` under Node. Bun is in PATH and `bun:sqlite` is built in, so no native module install is required for the server. Vite is only needed when the prebuilt `dist/` is missing or stale (see bootstrap section below).

## Resolving the live plugin source path

The insight source lives inside the Nix-store path for `pi-plugin-context-mode`. Do not `find /nix/store` (CLAUDE.md forbids it and the user's nix-search skill explains why). Resolve it via pi's settings file, which already enumerates every installed plugin store path:

```bash
# settings.json is a read-only symlink into /nix/store; jq it for the context-mode entry.
# Note: the store path looks like /nix/store/<hash>-pi-plugin-context-mode
# (no slash between the hash and the package name), so the grep pattern is
# 'pi-plugin-context-mode$', not '/pi-plugin-context-mode'.
PLUGIN_ROOT=$(jq -r '.packages[]' ~/.pi/agent/settings.json | grep 'pi-plugin-context-mode$' | head -1)
PLUGIN_INSIGHT="$PLUGIN_ROOT/insight"
[ -d "$PLUGIN_INSIGHT" ] || { echo "could not resolve plugin source"; exit 1; }
```

Fallback if `~/.pi/agent/settings.json` is missing or doesn't list it, use a direct store glob (shell glob is a single dirent scan, not a recursive `find`). The store may carry several stale GC-roots for past builds, the most recent one by mtime is the closest match to the currently-installed plugin:

```bash
PLUGIN_ROOT=$(ls -1dt /nix/store/*-pi-plugin-context-mode 2>/dev/null | head -1)
PLUGIN_INSIGHT="$PLUGIN_ROOT/insight"
```

The glob ends at `context-mode` with no trailing star or dash, that's the actual store-path suffix; adding `*` after it would also pick up `.drv` derivation files.

## Cache freshness check

Before relying on the steady-state path, confirm the cached source matches the plugin source. The cache lives at `~/.claude/context-mode/insight-cache/`.

```bash
CACHE=~/.claude/context-mode/insight-cache
diff -rq "$PLUGIN_INSIGHT/src"          "$CACHE/src"          | head
diff -q  "$PLUGIN_INSIGHT/server.mjs"   "$CACHE/server.mjs"
diff -q  "$PLUGIN_INSIGHT/package.json" "$CACHE/package.json"
ls "$CACHE/dist/index.html" 2>/dev/null && echo "dist present"
```

If `diff` shows no differences and `dist/index.html` exists, the steady-state launch is safe. Otherwise rebuild.

## Bootstrap / stale-cache rebuild (needs Node)

When `dist/` is missing or the cached source diverges from the plugin source (typically right after a `ctx-upgrade` or a fresh checkout), the dashboard needs to be rebuilt with Vite. Vite requires Node. Pull it in temporarily via a one-shot Nix shell, do not modify `home-manager` for this.

Reuse `$PLUGIN_INSIGHT` from the resolver block above, then:

```bash
CACHE=~/.claude/context-mode/insight-cache

# Resync the cache from the plugin source.
mkdir -p "$CACHE"
cp -R "$PLUGIN_INSIGHT/." "$CACHE/"
chmod -R u+w "$CACHE"   # store paths are read-only; cache needs to be writable for npm + vite

# Install deps + build inside a nix-provided node, no home-manager change.
nix shell nixpkgs#nodejs_22 -c bash -lc "
  set -e
  cd '$CACHE'
  npm install --production=false
  npx vite build
"
```

After bootstrap, return to the steady-state launch block above.

## Per-adapter directory map

This machine writes context-mode data into two adapter-specific roots. The server reads a single `SESSION_DIR` and `CONTENT_DIR` and does not auto-merge sibling adapters, so the env vars must be set explicitly.

| Source                                | Adapter      | Path                                  | Contents                                                              |
| ------------------------------------- | ------------ | ------------------------------------- | --------------------------------------------------------------------- |
| `INSIGHT_SESSION_DIR` (recommended)   | pi           | `~/.pi/context-mode/sessions`         | Real session `.db` files (events, sessions, resume snapshots).        |
| Default if unset                      | claude-code  | `~/.claude/context-mode/sessions`     | Only `stats-pid-*.json` on this machine, no `.db`. Empty dashboard.   |
| `INSIGHT_CONTENT_DIR` (recommended)   | shared       | `~/.claude/context-mode/content`      | FTS5 chunks DBs keyed by project worktree hash. Shared across adapters. |

If a future adapter (e.g. another CLI) starts writing sessions to a third root, point `INSIGHT_SESSION_DIR` at that one instead. The dashboard is single-rooted by design.

## Permanent fix (do not do this without asking)

If the user wants to make `ctx_insight` itself work, add `nodejs` to home-manager packages and `hms`. That's an explicit edit to the Nix config and should be confirmed first. The bundled tool will still rebuild on every invocation (it always runs `npx vite build`), but it will at least succeed.

## Trigger phrases

Use this skill when the user says any of:

- "open the insight dashboard"
- "run ctx insight" / "ctx-insight" / "/ctx-insight"
- "show context-mode analytics"
- "I don't see past sessions in the dashboard"
- anything else that would otherwise call the `ctx_insight` MCP tool
