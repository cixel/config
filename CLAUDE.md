# CLAUDE.md

Multi-machine NixOS/nix-darwin config repo (~/.config). Nix Flakes + Home Manager across 7 machines (3 macOS, 4 Linux).

## Commands

```bash
hms                    # Apply config (auto-selects darwin/nixos rebuild)
nix build .#nvim       # Build standalone nvim package
nix flake update       # Update all inputs
nix flake lock --update-input nixpkgs  # Update single input
```

## Architecture

`flake.nix` → `nix/mkSystem.nix` → `nix/machines/<hostname>.nix` → base configs (`darwin.nix`/`nixos.nix`) + `nix/home-manager/`

- Work machines (`ESINAI-*`) import `nix/work.nix` (Netskope certs, AWS SSO, Tailscale, work git/jj config)
- `nix/home-manager/home.nix` — packages, aliases, scripts (incl. `ghmerge`)
- `nix/home-manager/nvim/` — declarative neovim config; `default.nix` + `config/*.lua`

## Critical Rules

- **Never `find /nix/store`** — `/nix/store` holds thousands of unrelated paths and many copies of nixpkgs sources, so scanning it is slow and ambiguous. Use the `nix-search` skill (`nix/home-manager/agents/skills/nix-search/SKILL.md`) which covers the right entry points: `nix eval --raw nixpkgs#foo.outPath` to resolve store paths, `nix eval --raw nixpkgs#foo.meta.position` to jump to definitions, `nix store ls -R -l <path>` / `nix store cat` to inspect, and `rg`/`fd` rooted at `$(nix eval --raw nixpkgs#path)` to grep nixpkgs source. Same rule when looking up a flake input (e.g. home-manager source): `nix eval --raw --impure --expr '(builtins.getFlake (toString ./.)).inputs.home-manager.outPath'`, then `rg` inside the returned path. Read the skill before reaching for `find`.
- **Never edit generated files** — most app configs under `~/.config/` are Nix-generated (nvim/init.lua, git/config, tmux.conf, starship.toml, ghostty/config, jj/config.toml, etc.). Edit the `.nix` source in `nix/home-manager/` instead, then `hms`.
- **Source of truth**: `nix/home-manager/*.nix`, `nix/home-manager/nvim/config/*.lua`, `flake.nix`, `flake.lock`
- **`docker` is aliased to `podman`** — this repo uses podman, not Docker.
- Both **Git** and **Jujutsu (jj)** are used — jj for local operations, git for remotes. Config in `nix/home-manager/jujutsu.nix`.
- Machine-specific overrides go in `nix/machines/<hostname>.nix`.
