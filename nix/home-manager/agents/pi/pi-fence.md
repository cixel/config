# pi-fence — OS write fence for pi's bash tool

Status: implemented (extensions/pi-fence.ts). Design decisions below were
grilled out interactively; keep this file in sync when they change.

## What it is

Every bash tool call runs inside an OS sandbox — `sandbox-exec` on macOS,
`bubblewrap` on Linux — whose writable set is the session **zone**:

| Path | Why |
|---|---|
| repo root of the session cwd (jj root / git toplevel, realpath'd) | the work. Broader than jev-guard's cwd-only zone on purpose: the fence is the outer bound, the guard the inner one; `git`/`jj` write at the root |
| `/tmp`, `/var/tmp`, `$TMPDIR`, `~/.cache` | scratch |
| `go env GOCACHE`, `go env GOMODCACHE` | Go build and module caches. Asked of the user's `go` at session start (from `/`, `GOTOOLCHAIN=local`) so env/`~/.config/go/env` overrides are honoured; on macOS GOCACHE is `~/Library/Caches/go-build`, outside `~/.cache`. Skipped if `go` is absent, `GOCACHE=off`, or a path would widen the fence to `$HOME`/an ancestor or overlap `~/.pi/agent`. `GOBIN` (`go install`) is deliberately not included |
| `~/.local/state/nix` | `nix build` registers indirect gcroots client-side. Store writes go through the daemon; `hms`/`nix profile` stay fenced out — agents never run them |

Everything else is read-only for the call. Reads and network are open
(agents inspect the whole machine and fetch freely; `git push` is a
jev-guard policy gate, not a fence concern). No read-denials: credential
stores that must be readable (`~/.ssh`, `~/.config/gh`) defeat partial
lists, and exfiltration is the adversarial threat model — gondolin's job,
not the fence's. `~/.aws` gets no exception (agents don't run aws).

## Layering

1. **pi-fence** (this): kernel-enforced outer bound. Catches every bash
   bypass shape (heredocs, `bash -c`, `make`, scripts) that jev-guard's
   parser can't see through.
2. **jev-guard**: policy + UX. Confirms for legit-but-risky (pushes,
   out-of-zone writes the user approves), hard-blocks deleting the zone
   root itself (the fence can't distinguish that — the root is writable),
   jev second opinion.
3. **gondolin**: for when the *code* is the threat (untrusted repo, agent
   needs root). NOT co-installed with pi-fence: both override the bash
   tool via `registerTool` and last-registration silently wins. A
   per-session mode switch is a followup (cheapest form: a `pi-vm` entry
   point using `PI_CODING_AGENT_DIR` with a gondolin-instead-of-fence
   plugin list). A fence-denied → retry-in-VM escalation loop is
   explicitly out of scope.

`write`/`edit` are not fenced: their target path is exact and jev-guard's
zone check on them has no parser to bypass. User `!` commands never touch
the fence (BashSession spawns /bin/bash directly) — the user is trusted.

## Why a pi extension and not a launcher wrapper + shellPath shim

Chosen deliberately. The wrapper would fail closed harder (broken fence =
pi doesn't start); the extension puts the fence at the *same trust level
as jev-guard* (if it fails to load, pi runs unfenced). Accepted, with two
mitigations: a build-time tripwire (flake `pi-fence-api-check`) that fails
`hms` if the pinned pi stops exporting `createBashTool` /
`createLocalBashOperations` or stops aliasing the package specifier, and a
loud footer status (`fence ✓ <repo>` / `fence ✗ BLOCKED` / `fence ✗ DOWN`)
— absence of the footer line means something is wrong.

## Failure semantics

Fail closed, at launch: `session_start` computes the zone, writes the
profile + session shell under `~/.pi/agent/pi-fence/`, then probes —
trivial command, in-zone write, ~/.cache write must succeed; a `$HOME`
write must fail. Probe failure → the bash tool refuses every call with an
explanatory error (`down`). Outside a repo, or a repo rooted at/above
`$HOME` → `blocked`. There are no env-var overrides; the escape hatch is
`programs.pi.fence.enable = false` + `hms`. (A "different pi binary" is
NOT a hatch: it reads the same nix-managed settings.json and loads the
same extension.)

The generated profile/shell live under `~/.pi/agent/pi-fence/` — outside
the zone, so a fenced command cannot rewrite its own boundary (and
jev-guard hard-blocks agent writes there). Files are named
`shell-<pid>-<nonce>` / `profile-<pid>-<nonce>.sb`: the nonce is per
extension runtime, so a `/reload` (same pid, new runtime) can never have
the old runtime's `session_shutdown` delete the new runtime's shell.
Housekeeping at session start removes files whose pid is no longer alive
(`kill -0`; EPERM counts as alive). It used to be age-based (24h), which
deleted the shell of any session older than a day the moment another
session started — every bash call in the old session then failed with
"Custom shell path not found".

## Known boundaries

- Filesystem boundary only: fenced commands share PID/network namespaces
  and can signal same-uid processes. Accidents, not adversaries.
- Background processes (`npm run dev &`) survive a bash call — bwrap
  creates no PID namespace (pinned by a hardware-test check).
- Zone is fixed at session_start; no mid-session cwd following (same as
  jev-guard).
- Per-command bypass for guard-approved out-of-zone writes was designed
  for but deferred: v1 answers "the fence denied it" with "run it
  yourself". Revisit if decisions.jsonl / annoyance says otherwise.
- Instead, the fence tells jev-guard it is on: while `active` it publishes
  `globalThis[Symbol.for("pi-fence.zone")]` (frozen zone list), removed on
  shutdown and never set in `blocked`/`down` (where bash refuses anyway).
  The guard then skips confirms for writes the fence would refuse
  (jev-guard-plan.md §4.7).

## Testing

- `tests/pi-fence.test.ts` — bun unit tests, fake `FenceHost`, fake tool
  factories (the pi package import is stubbed via tsconfig paths).
  Build-time: `nix build .#pi-fence-tests`.
- `nix build .#pi-fence-api-check` — API drift tripwire (above).
- `nix run .#pi-fence-test` — hardware boundary suite (not a nix build;
  needs the real sandbox). Run on macOS after every macOS upgrade: it is
  what proves the seatbelt deny-`/`-then-allow-subpath specificity
  semantics this design rests on.

First-run checklist for a new macOS machine: `nix run .#pi-fence-test`,
then launch pi in a repo, confirm the `fence ✓` footer, ask the agent to
`touch ~/Documents/x` (should EPERM), run a `nix build` from the agent
(daemon socket rule), and confirm a `!` command is unfenced.
