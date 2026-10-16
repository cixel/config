# Plan: `jev-guard` — gate dangerous pi actions (deterministic rules + jev)

Status: v4, APPROVED by user — ready for an implementing agent.
Target pi version: **1.0.4** (nixpkgs, what the 7 machines run; the VM's
`~/.local/pi` 1.1.0 binary is not representative).

v4 (review outcome): replace the hand-rolled shell simulation with
`shfmt --to-json` (§4.1); replace scope tiers / project-root / VCS-root
detection with a single **write zone = cwd + temp** model (§4.2); jev is an
always-on second opinion, never a tiebreaker (§2, §6); no per-session
approvals or LRU; `write`/`edit` tools are zone-checked too.
v3.1: `PI_GUARD=off` = fully off. v3: motivation, cwd semantics (App. A).

Post-v4 additions: `cd`-carried sub-script resolution + `writes_outside`
question wording (red-team F1/F4, jev-experiment V5); **sandbox mode** for
gondolin VM execution — the zone derives from the guest mount table (§4.6).

## 0. Motivation

A pi agent ran `rm -rf $(pwd)` in the user's home directory right after a
`cd ..`, believing it was in nested temp dirs. Goal: a second barrier between
the agent and destructive/unauthorized actions. Key fact (App. A): pi's bash
tool is **stateless per call** — `cd` never carries over; every call starts in
the session cwd, so a model used to persistent shells can be wrong about where
it is. The incident is a deterministic hard-block from day 1 (§4.2 examples).

## 1. Goal & threat model

| # | Class | Default (interactive / headless) |
|---|-------|----------------------------------|
| 1 | **publish to remote** — `git push`, `jj git push`, force variants, `gh pr merge`, `gh release`, `npm publish` | confirm / block |
| 2 | **writes/deletes outside the zone** (§4.2); zone roots, `~`, `/` and their ancestors | confirm / block; roots: **hard-block** |
| 3 | **unrecoverable repo-state destruction** (narrow, §5) | hard-block / block |

**Threat model: accident prevention, not containment.** Scripts on disk,
`make release`, heredocs, background jobs, direct API calls, and extensions
that exec directly (jj-footer) sit around the gate; adversarial agents need
OS sandboxing — out of scope (see §4.5 for the natural complement).

**Design stance: when the parser doesn't know, it confirms.** The user is
fine being prompted again; false "allow" is the only failure mode that
matters. Nothing is remembered across prompts — the same command asks again.

Non-goals v1: gating user-typed `!commands` (user is trusted), MCP tools (user
has none today; if added later, confirm only on `annotations.destructiveHint
=== true`), read-only tools.

## 2. Architecture: standalone single-file extension

Standalone, no npm deps, ~250–300 LOC, at
`nix/home-manager/agents/pi/extensions/jev-guard.ts`, registered via the
existing `mkPiPluginFromFile`, listed **last** in `programs.pi.plugins` (later
handlers could mutate approved commands). Parsing is delegated to `shfmt`
(nixpkgs, §4.1). Not built on `@gotgenes/pi-permission-system`.

### Decision flow — `tool_call` on `bash` (incl. nested codemode calls)

```
1. parse:   shfmt --to-json  (spawn, ~2 ms; parse error -> det = confirm)
2. det:     deterministic verdict from the AST (§4, §5)
            allow | confirm(reason, resolved targets) | hard-block(reason)
3. jev:     IN PARALLEL with 1–2, on EVERY bash call (§6)
            allow | confirm(class, p)       -- jev can never allow past det
4. final = max(det, jev)   with  allow < confirm < hard-block
            hard-block comes only from det; jev only raises allow -> confirm
5. jev unavailable / r.stopReason !== "stop" / timeout 1500 ms
            -> final = det, footer status "guard: jev DOWN" (circuit breaker:
            3 consecutive failures -> skip jev for 10 min)
```

There is no "grey zone" and no fast path: every bash call gets both
opinions. Step 1–2 cost ~2 ms; step 3 costs 70–500 ms and runs concurrently.

### `tool_call` on `write` / `edit`
Zone check only (§4.2) on `input.path`; no jev. Outside zone -> confirm;
zone root itself / `.git` / `.jj` / `.pi` -> hard-block.

### Executing session-written scripts (TOCTOU)
Pi prepares every call in a batch before any executes, so `./deploy.sh` may
be gated before its `write` lands. Track paths written/edited this session,
including pending writes earlier in the same batch (visible in their
`tool_call` inputs). Executing one (`./x.sh`, `bash x.sh`, `sh -c "$(cat
x.sh)"`): if the known content is a shell script, run it through the same
`decide()` (same cwd) and include it in jev `state.script`; otherwise
confirm.

### UX — one confirm style, nothing remembered
- Every confirm is `ctx.ui.select(title, ["No", "Yes"], { timeout: 600_000 })`.
  **"No" is first and the default.** The title says plainly what will happen
  with the real resolved path and the cwd: "Delete /home/user/Documents
  (outside /home/user/src/foo)?", "Push bookmark main to origin?",
  "rm -rf $(pwd): target is not static; this call runs in /home/user.
  Continue?". No typed confirmations, **no "allow for this session"**, no
  LRU — identical commands prompt again. Unanswered/timeout -> block +
  `terminate: true`.
- Headless (`hasUI=false`, incl. in-process subagents): confirm -> block +
  `terminate: true`.
- Block reasons teach the model: "refused: `rm -rf .` is /home/user/src/foo,
  the session's working directory"; "push blocked by policy; ask the user".
- Status key `guard` (jj-footer uses `jj`); footer shows gated/allowed
  counts and jev/shfmt health.
- `PI_GUARD=off|log` env. `off` = FULLY off, no hard-blocks either (user
  decision). `log` = decide and log, never ask or block.
- Log every decision (cmd, cwd, zone, targets, det verdict, jev probs, final,
  latency) to `~/.pi/agent/jev-guard/decisions.jsonl`, size-capped rotation.
  Because jev runs on everything, the log is the tuning dataset.
- Self-protection: any write under `**/.pi/**` or `~/.pi/agent/**` except the
  guard's own log -> hard-block.

## 3. Alias & flag normalization

jev alone misses the user's own aliases: `git put` (=push) scored 0.22,
`jj dependabot` (=git push) 0.08.
- At `session_start`: `git config --get-regexp '^alias\.'`,
  `jj config list aliases`; cache.
- Expand the first sub-token (recursively, bounded) before matching and put
  the expansion in jev `state.alias_expansion`.
- Normalize global flags: `git -C/-c/--git-dir/--work-tree`,
  `jj -R/--repository/--at-op`.
- Shell aliases don't apply: pi runs `bash -c`, non-interactive.

## 4. Writes & deletes: the zone model

**Write-class** verbs: `rm`, `rmdir`, `unlink`, `shred`, `truncate`,
`dd of=`, `mv` (both operands), `cp` (dest), `rsync` (dest; `--delete`),
`find … -delete` / `-exec rm` (find's start paths are the targets),
`xargs rm|mv` (stdin targets -> unresolvable), redirects `>`/`>>`/`<>`
(target word; `/dev/*` always allowed), `tee`, `install`, `ln -f`.

### 4.1 Parsing & target resolution (shfmt, not simulation)
- `shfmt --to-json` (mvdan/sh — the canonical bash parser) is spawned with
  the command on stdin. The AST has `CallExpr`, `BinaryCmd{&&,||,|,;}`,
  `Subshell`, `Block`, `CmdSubst`, `ParamExp`, `ArithmExp`, `Lit`,
  `SglQuoted`, `DblQuoted`, `Redirs`. Non-zero exit (unparseable) -> confirm.
  shfmt missing -> everything confirms + status "guard: NO shfmt".
- Walk all `CallExpr`s at any depth. For each write-class call, collect
  target words.
- A target is **literal** iff every part is `Lit`/`SglQuoted`/`DblQuoted`-of-
  `Lit`, after expanding exactly `~`, `~/`, `$HOME`, `$TMPDIR` (the only
  expansions performed). Any `CmdSubst`, `ParamExp`, `ArithmExp`, brace
  expansion, or glob in a non-final component -> **unresolvable -> confirm**.
  Never substitute `$(pwd)`/`$PWD` into a path.
  - Exception, because it is the incident: the exact shapes `.`, `./`,
    `$PWD`, `$(pwd)`, `` `pwd` ``, `${PWD}` with **no `cd` in the command**
    mean "the cwd" and are resolved to `ctx.cwd` so they hit the hard-block
    with a precise message.
- If `cd`, `pushd`, `popd`, or `cd -` appears **anywhere** in the AST, every
  relative target in the command is unresolvable -> confirm. Absolute and
  `~`-anchored targets are still resolved. No cwd walking, no "strictest of
  both candidates".
- Literal resolution: `path.resolve(ctx.cwd, t)` then `realpathSync` of the
  longest existing prefix (catches `~/link -> /`). Zone roots are realpath'd
  the same way (macOS: `/tmp` -> `/private/tmp`, `$TMPDIR` ->
  `/private/var/folders/…`).
- A glob in the final component (`X/*`, `X/.*`) counts as "all of X".
- No recursion-flag parsing. The root/ancestor hard-block applies regardless
  of `-r`; `rm ~` without `-r` just fails on its own.
- Indirection: `bash -c S`, `sh -c S`, `eval S` with a literal `S` -> parse
  `S` recursively (same cwd). Non-literal `S`, `xargs`, `ssh`, `python -c`,
  … -> det says nothing (jev is the opinion there); `xargs rm|mv` -> confirm.

### 4.2 The zone
```
Z = { realpath(ctx.cwd)  (only in project mode, §4.3),
      /tmp, /var/tmp, realpath($TMPDIR), ~/.cache }
```
| resolved target | verdict |
|---|---|
| strictly inside a Z root, not inside any `.git`/`.jj`/`.pi` | **allow** |
| equals a Z root, or `~`, or `/`, or an ancestor of any of them | **hard-block** |
| glob directly at a Z root (`*`, `.*`, `./*` when cwd is the root) | confirm |
| inside `.git`/`.jj` (any repo) | §5 |
| anything else, incl. unresolvable | **confirm** |

No tiers, no project-root detection, no other-workspace VCS-root search, no
cache allow-list: `rm -rf ~/.cache` is a zone root -> hard-block,
`rm -rf ~/.cache/jj` is inside -> allow, `rm -rf node_modules` in the project
-> allow, `rm -rf ../other-proj` -> outside -> confirm.

Examples, session cwd `~/src/foo` (a jj/git repo):

| Command | Resolves to | Result |
|---|---|---|
| `rm -rf $(pwd)` / `rm -rf .` / `rm -rf $PWD` | `~/src/foo` (zone root) | hard-block |
| `rm -rf ..`, `rm -rf ~`, `rm -rf ~/*`, `rm -rf /` | ancestor / home / root | hard-block |
| `cd .. && rm -rf $PWD` | `$PWD` after `cd` -> unresolvable | confirm, shows cwd |
| `cd /tmp/x; rm -rf *` | relative after `cd` | confirm |
| `rm -rf *` (no `cd`) | glob at zone root | confirm |
| `rm -rf build dist node_modules` | inside zone | allow |
| `rm -rf /tmp/pi-scratch`, `rm ~/.cache/foo/x` | inside temp / cache | allow |
| `rm ~/.zshrc`, `mv ~/Documents /tmp` | outside zone | confirm |
| `echo x > ~/.bashrc`; `echo x > /dev/null` | outside; /dev | confirm; allow |
| `rm -rf "$DIR"` | ParamExp | confirm |
| `find . -name '*.pyc' -delete` | `.` -> inside zone | allow |
| `git ls-files \| xargs rm` | xargs | confirm |
| `bash -c 'rm -rf ~'` | recursive parse -> home | hard-block |

Same cwd but session started in `~` (incident): `ctx.cwd` = `~` -> §4.3
no-project mode -> `rm -rf $(pwd)` = `~` -> hard-block; `rm -rf tmp-a` ->
not in Z -> confirm.

### 4.3 Project mode vs no-project mode (one check at `session_start`)
`ctx.cwd` is added to Z **only if** it is inside a `.git`/`.jj` repo whose
root is not `$HOME` or an ancestor of it (a dotfiles repo at `~` doesn't
count). Otherwise (pi launched in `~`, `~/src`, `/tmp/x`, …) Z is temp +
cache only, every other write/delete confirms, and the footer says
`guard: no project — writes outside temp confirm`. Computed once; no
per-command VCS walking.

### 4.4 Stale-cd note (`tool_result` hook)
After a bash call whose last top-level command is `cd`/`pushd`, append one
line to its tool result: "note: cwd does not persist between bash calls; the
next call starts in <ctx.cwd>". No cross-call cd tracking rule — the zone
already bounds the blast radius and §4.2's glob-at-root rule catches the
`cd /tmp/x` -> `rm -rf *` confusion.

### 4.5 Not in scope: OS sandbox
`examples/extensions/sandbox` (`@anthropic-ai/sandbox-runtime`, bubblewrap /
sandbox-exec) enforces exactly `allowWrite: [".", "/tmp"]` at the OS level
and would also cover scripts, heredocs and `eval`. It's an npm dep + bwrap,
has no prompts, and doesn't cover pushes or deleting the cwd itself. Possible
later complement; not part of v1.

### 4.6 Sandbox mode (gondolin VM)
When the gondolin extension (`npm-plugins/gondolin/`) is active, every
bash/write/edit call executes inside a micro-VM with the session cwd mounted
at `/workspace`; the rest of the guest filesystem is a disposable CoW overlay.
Running the host zone model there is wrong in both directions: guest paths
like `/workspace/build` classify as "outside" (confirm noise), and disposable
guest dirs (`/etc`, guest `~`) get host-grade protection they don't need.

**Handshake:** the gondolin extension sets the symbol-keyed global
`globalThis[Symbol.for("pi-gondolin.workspace")] = "/workspace"` (and
optionally `"pi-gondolin.guest-home"`, default `/root`) at load time —
fail-closed is safe because all tool execution routes through the VM. A
global, not an env var: the gondolin test harness poisons `process.env`
access in extensions, and both extensions share pi's module realm. The
guard reads the marker per session, so extension load order doesn't matter.

**Zone derivation:** the guard's domain becomes the guest. `cwd` =
`$PI_GONDOLIN_WORKSPACE`, `home` = guest home, `tmpdir` = `/tmp`, zone =
[guestWorkspace, /tmp, /var/tmp] — the workspace is in the zone
unconditionally (the mount *is* the declared writable domain), while
`projectMode`/`vcs` are still detected on the *host* workspace so jj snapshot
and alias loading work. Resolution (`exists`/`realpath`/`read`) maps
workspace paths back onto the host filesystem; symlinks escaping the mount
are left at their literal guest path (the guest VFS refuses them anyway).

**Classification:** targets at/inside the workspace classify exactly as in
host mode (`rm -rf /workspace` hard-blocks — it deletes real host files;
`.git`/`.jj`/`.pi` under it are protected; `/` and globs over it hard-block).
Every other guest path — guest home, `/etc`, temp roots, host paths outside
the mount (which don't exist in the guest) — is **allow**: clobbering them is
discarded with the VM. Absolute host paths under the mounted directory are
mapped to their guest equivalents before classification (pi's tool
descriptions use host paths; gondolin's `toGuestPath` accepts both).

**jev:** state gains `sandbox: "gondolin"` and `persistent_roots:
[guestWorkspace]`, and `writes_outside` gets one appended sentence: the VM is
disposable, only writes under `persistent_roots` reach the user's real files,
but deleting a persistent root or `cwd` itself still counts. Same
question-wording lever as the V5 experiment; no new questions or state-field
arithmetic (V6/V7 false positives).

The footer shows `vm:/workspace`; `decisions.jsonl` records `sandbox` per
decision.

## 5. Class-3 precise scope (jj-aware)

jj's op log makes nearly everything recoverable — hard-block only what
destroys recoverability: `rm`/`mv`/redirect into any `.git` or `.jj` dir
(resolved path has such a component; colocated `.git` is jj's backend),
`jj op abandon`, `jj util gc`, `git reflog expire`, `git gc --prune=now`,
`git update-ref -d`, `mkfs*`, `dd of=<block device or path under ~>`.
Recoverable jj ops (`abandon`, `undo`, `op restore`, `rebase`, `squash`) are
NEVER gated. Colocated jj + mutating raw git (`checkout -- .`,
`reset --hard`, `clean -fdx`, `stash drop`) -> confirm ("prefer jj; raw git
can lose un-snapshotted edits"). Optional (default on): `jj debug snapshot`
before running any confirmed command in a jj repo.

## 6. jev: always-on second opinion (TypeSafe direct)

- Provider `typesafe`, model `jev-latest` ($0.042/M-in ≈ $0.000012/check;
  70–500 ms). Called on **every** bash call, concurrently with the parse.
- jev's verdict can only be `allow` or `confirm`; it never lowers det's
  verdict and never hard-blocks. Rationale: the user wants a prompt if
  *either* side sees a problem; jev also sees what the parser can't
  (`python -c "shutil.rmtree(…)"`, `curl -X DELETE`, `terraform destroy`).
- State (facts only, not det's verdict, so jev stays an independent opinion):
  `{ command, alias_expansion, cwd, zone: string[], project_mode: bool,
     vcs: "jj-colocated"|"jj"|"git"|null, resolved_targets,
     unresolved_targets, script?: string }`
- Questions (`type: "bool"` **requires `criteria: { true, false }`** in pi's
  `ClassifierQuestion`; answer is `{ type: "bool", probability }`):
  - `publishes`: publishes commits, bookmarks, tags, PRs, releases or
    packages to any remote or registry
  - `writes_outside`: deletes or overwrites files outside `zone`, or
    deletes a `zone` root / `cwd` itself (temp and cache dirs are inside)
  - `repo_loss`: UNRECOVERABLE loss of version-control state (jj op log
    makes most jj ops recoverable; only metadata deletion / gc count)
  - `other_irreversible`: destroys data or infra outside the above classes
    in a way the user would want to confirm first (catch-all)
- Threshold: single constant `JEV_CONFIRM_P = 0.5` per question; the dialog
  names the class and p. Tune from `decisions.jsonl`, which records all four
  probabilities for every command.
- Call contract:
  ```ts
  const jev = ctx.modelRegistry.findOfType("classifier", "typesafe", "jev-latest");
  if (!jev || !ctx.modelRegistry.hasConfiguredAuth(jev))
    -> det only + setStatus("guard", "guard: NO JEV — /login typesafe")
  const r = await ctx.modelRegistry.classify(jev, { state, questions }, {
    timeoutMs: 1500, maxRetries: 1, maxRetryDelayMs: 0, signal: ctx.signal,
  }); // never throws; check r.stopReason === "stop"
  ```
- **Key deployment: `/login typesafe`** once per machine (7 machines,
  manual); stored in `~/.pi/agent/auth.json`, outside nix. Variant: an
  auth.json `"key": "!op read …"` entry.
- Privacy: every bash command goes to TypeSafe (their ToS applies). Per-host
  nix option `programs.pi.jevGuard.jev = false` for work machines
  (ESINAI-*, Netskope) -> det only there. Not via shelley/exe.dev.

## 7. Nix integration

- New: `nix/home-manager/agents/pi/extensions/jev-guard.ts`
- `home.nix`: one `mkPiPluginFromFile` entry, last in `plugins`.
- `shfmt`: bake `${pkgs.shfmt}/bin/shfmt` into the extension at build time
  (add a `substitutions` arg to `mkPiPluginFromFile`, or `sed` in a
  `postBuild`) so it doesn't depend on pi's PATH; fall back to `shfmt` on
  PATH, then to "NO shfmt" mode. `PI_GUARD_SHFMT` env override for the
  offline test harness.
- Optional per-host `jevGuard.jev` toggle in the `programs.pi` module.
- `hms` applies fleet-wide.

## 8. Testing

1. Pure `decide(ast, env) -> {verdict, class, reason, targets}` over a fake
   fs (home, project, `/tmp` clone, dotfiles repo in `~`, symlink-to-root),
   table-driven bun tests; jev responses recorded/replayed. Corpus ~80: all
   §4.2 rows in project and no-project mode, `cd` anywhere -> relative
   unresolvable, the incident as 3 calls (`cd /tmp/a/b` · `cd ..` ·
   `rm -rf $(pwd)`, session cwd `~`), user's aliases, jj op commands,
   colocated raw git, redirects incl. `/dev/null` and `2>&1`, comment
   injection, same-batch write+exec, `git -C`/`jj -R`, `.pi/` writes,
   `bash -c` recursion, parse errors, `max(det, jev)` combination incl. jev
   down.
2. Raw-wire harness sends `type: "noul"` (not `bool`) when bypassing pi.
3. Live smoke on **1.0.4** (`nix shell nixpkgs#pi-coding-agent`): headless
   block test + one interactive tmux run (dialog timeout, "No" default,
   pi-vim keys, footer counter, stale-cd note in tool output, jev latency
   visible in log).
4. Latency assertion: parse ≤ 10 ms; jev call concurrent, not serial.

## 9. Rollout: install -> enforce

1. `/login typesafe` on each machine, add the plugin, `hms`. Hard-blocks and
   confirms are live immediately.
2. Tune as you go: when a prompt is noise or a miss shows up, check
   `decisions.jsonl` (det verdict + 4 jev probabilities per command), adjust
   `JEV_CONFIRM_P` / zone roots, `hms`.

## 10. Open questions for the user

None. Review items resolved: shfmt for parsing; zone = cwd + temp + cache
with no-project mode; no session approvals; jev always on, `max(det, jev)`.

## Appendix A: pi bash tool cwd semantics (verified, pi v1.0.4 source)

- `docs/shell-aliases.md`: "Pi starts a separate non-interactive shell process
  for each Bash command" (`bash -c`).
- `coding-agent/src/core/tools/bash.ts`: `execute()` uses `ctx?.cwd || cwd`
  (L271) -> `spawn(shell, [...args, command], { cwd })` (L112–113); `cwd` is
  captured once by `createShellToolDefinition(cwd, …)`; no pwd tracking.
- `core/agent-session.ts`: `_cwd = config.cwd` only in the constructor (L481;
  ~L493 on main) -> `createAllToolDefinitions(this._cwd, …)`.
  `core/extensions/runner.ts` L894: `ctx.cwd` returns the constructor-set cwd.
- `BashToolCallEvent.input` is `{ command, timeout? }` — no cwd. **The
  extension reads `ctx.cwd` in `tool_call`; that is the command's start cwd.**
- Caveats: `shellCommandPrefix` is prepended after `tool_call` (verify it has
  no `cd`); an extension replacing `bash` (ssh/sandbox) or a `spawnHook` can
  change cwd — warn at session_start if `bash` isn't the built-in.

## Appendix B: shfmt AST shape (verified, shfmt 3.14.1)

`printf 'cd .. && rm -rf "$(pwd)"/x ~/* $FOO; echo hi > /dev/null | wc' | shfmt --to-json`
yields `File.Stmts[]`, each `{Cmd, Redirs?}`; `Cmd.Type` ∈ `BinaryCmd{Op,X,Y}`
| `CallExpr{Args[].Parts[]}` | `Subshell` | `Block` | …; word parts `Type` ∈
`Lit{Value}` | `DblQuoted{Parts}` | `SglQuoted{Value}` | `CmdSubst{Stmts}` |
`ParamExp{Param.Value}`; `Redirs[]{Op, Word}`. Strip `Pos`/`End`/`*Pos`
keys before matching. ~2 ms per invocation; exit 1 + message on parse error.

## Appendix C: implementation notes (v4 as shipped)

Implemented in `extensions/jev-guard.ts` (nix: `programs.pi.jevGuard`),
tests in `tests/`. Verified live on pi 1.0.4 (headless + tmux TUI) with a
scripted mock model. Deviations and findings worth knowing:

- **jev runs right after det, not concurrently.** det costs 1–8 ms and the
  jev `state` carries det's `resolved_targets` / `unresolved_targets` /
  `script` / `alias_expansion`, which are worth more than the ~5 ms. jev is
  always awaited (≤ 1.5 s) before a prompt so `decisions.jsonl` has all
  four probabilities for every command.
- **The cwd is a guarded root even in no-project mode.** §4.2 only lists Z
  roots, `~`, `/`; deleting the cwd itself is the incident, so `rm -rf .`
  hard-blocks everywhere. In no-project mode "everything in cwd" (`rm -rf
  *`) confirms like any other outside write.
- **`find` start paths:** allowed when the start path is a zone root or
  inside the zone, otherwise *confirm* (never hard-block) — `find ~ -name x
  -delete` is a filtered delete, not "all of `~`".
- **`mv`/`cp`/`install`/`ln` into an existing directory** are judged as
  `dir/<src>`, so `mv x /tmp` is allowed and `mv ~/Documents /tmp` confirms
  on the source, as the §4.2 table expects.
- **Publish class** also covers `bun|cargo|gem|twine|docker|podman|helm|nix
  copy|crane|oras` publishing subcommands and `gh repo delete|archive|
  rename|sync`; `git svn dcommit`, `git send-email`, `rsync` to a remote.
- **Not write-class (det says nothing):** `touch`, `mkdir`, `chmod`,
  `chown`, `sed -i`, `curl -o`, `git init`. jev is the opinion there.
- **Session scripts** are keyed by realpath'd absolute path; `edit`ed files
  are read from disk at exec time; a pending edit whose file is not on disk
  yet confirms. `$(cat x.sh)` substitution is recognised only for tracked
  files. `bash -c "$NONLITERAL"` says nothing (as planned).
- **pi 1.0.4 behaviour:** `tool_result` does not fire for blocked calls and
  later extensions' `tool_call` handlers are skipped once one blocks (so
  the guard being last is what makes "no later mutation" true). `terminate:
  true` really ends the run in print/json/TUI modes: a headless-blocked `-p`
  run prints nothing and exits 0; the reason is only in `--mode json` or
  `decisions.jsonl`. Esc on the dialog is logged as `user: "cancelled"`,
  the 600 s countdown as `"timeout"`.
- **`PI_GUARD=off`** also skips the `session_start` log line — zero trace.
- **Sandbox mode (§4.6)** is keyed off a `Symbol.for` global set by the
  gondolin extension at load time rather than a pi API or env var — pi has
  no extension-to-extension channel, and the gondolin test harness poisons
  `process.env` access. `jj debug snapshot` and alias loading run on the
  host mount path, not the guest cwd.
- **Footer** key `guard`: `guard ✓N ?N ✗N · [LOG ONLY] · [no project — writes
  outside temp confirm] · [NO shfmt] · [NO JEV — /login typesafe | jev DOWN
  | jev off]`.
- Env knobs: `PI_GUARD=off|log`, `PI_GUARD_JEV=0`, `PI_GUARD_SNAPSHOT=0`
  (skip `jj debug snapshot` before a confirmed command), `PI_GUARD_SHFMT`.
