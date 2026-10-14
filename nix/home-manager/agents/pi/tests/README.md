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
