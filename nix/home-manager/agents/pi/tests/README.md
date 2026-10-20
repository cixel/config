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
