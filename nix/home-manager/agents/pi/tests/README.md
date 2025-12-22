# jev-guard tests

Table-driven bun tests for `../extensions/jev-guard.ts` (plan §8). Real
`shfmt` does the parsing; an in-memory `GuardFs` fakes the filesystem; jev
is replayed through a fake `modelRegistry`, never called for real.

```bash
cd nix/home-manager/agents/pi
PI_GUARD_SHFMT="$(nix build --no-link --print-out-paths nixpkgs#shfmt)/bin/shfmt" \
  nix run nixpkgs#bun -- test tests/
```

(`node`/`npx` are intentionally not on PATH on these machines; bun is.)

Notes

- Fixtures keep the fake home at `/home/user`, never under `/tmp`, because
  `/tmp` is a zone root and a home inside it would make every "outside the
  zone" case meaningless.
- The wiring tests (`extension wiring`) create a scratch git project under
  the real `$HOME` and point `PI_CODING_AGENT_DIR` at a scratch dir so the
  decisions log never touches `~/.pi/agent`.
- If you ever build a raw-wire harness that talks to TypeSafe without going
  through pi, remember plan §8.2: the wire format wants `type: "noul"`, not
  the `type: "bool"` pi's `ClassifierBoolQuestion` uses.

# pi-fence tests

`pi-fence.test.ts` — bun unit tests for `../extensions/pi-fence.ts`. All
host interaction is faked through `FenceHost`; the pi package import is
stubbed (`pi-coding-agent-stub.ts` via `../tsconfig.json` paths) and wiring
tests inject fake tool factories. No sandbox is ever really entered.

```bash
cd nix/home-manager/agents/pi && nix run nixpkgs#bun -- test tests/
```

`pi-fence-hardware.mjs` — the REAL kernel boundary check, run manually on
each platform (mirrors the gondolin resume-test pattern: not a nix build,
needs the actual sandbox facility):

```bash
cd nix/home-manager/agents/pi
nix run nixpkgs#bun -- tests/pi-fence-hardware.mjs            # PATH tools
# or with the exact pinned tools (what `nix run .#pi-fence-test` does):
PI_FENCE_BASH=... PI_FENCE_BWRAP=... bun tests/pi-fence-hardware.mjs
```

Verifies: zone writes allowed, $HOME//etc writes denied, /dev/null
writable, ~/.ssh read-only, background processes survive a bash call, and
(warning only) the nix daemon socket is reachable from inside the fence.
On macOS this is the check that validates the seatbelt deny-`/`-then-allow
specificity semantics after every macOS upgrade.
