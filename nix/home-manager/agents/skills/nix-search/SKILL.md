---
name: nix-search
description: Locate nixpkgs source files, package definitions, store paths, and attribute positions using the nix CLI instead of scanning /nix/store with find. Use when looking for a nixpkgs helper, builder, package source, or store path.
---

# nix-search

Do not `find /nix/store -path '*pkgs/...'`. `/nix/store` holds thousands of unrelated paths and many copies of nixpkgs sources, so `find` there is slow and ambiguous. Use the nix CLI to resolve exactly the thing you want, then search inside it with `rg` / `fd`.

## Pick the right entry point

| You want to find...                          | Use                                                    |
| -------------------------------------------- | ------------------------------------------------------ |
| A file/function inside nixpkgs source        | `nix eval --raw nixpkgs#path` -> rg/fd inside it       |
| Where attribute `foo` is defined             | `nix eval --raw nixpkgs#foo.meta.position` or `nix edit nixpkgs#foo` |
| Packages matching a name/description         | `nix search nixpkgs <regex>`                           |
| The store path a flake attr builds to        | `nix eval --raw nixpkgs#foo.outPath` (no build) or `nix path-info nixpkgs#foo` |
| Contents of a store path                     | `nix store ls -R -l <path>` (works on local + cache)   |
| Why something is in a closure                | `nix why-depends <referrer> <dependency>`              |
| Which package provides a binary/file         | `nix-locate <file>` if `nix-index` is installed        |

For this repo specifically, `nixpkgs` is already a flake input, so `nixpkgs#...` resolves to the locked revision from `flake.lock`. If the user is in a different repo, use `nixpkgs#` from their flake or `--inputs-from .`.

## Searching nixpkgs source

The right way to find something like `pkgs/build-support/node/import-npm-lock`:

```bash
NIXPKGS=$(nix eval --raw nixpkgs#path)
rg --files "$NIXPKGS/pkgs/build-support/node/import-npm-lock"
# or for a function/string across nixpkgs:
rg -n 'importNpmLock' "$NIXPKGS/pkgs/build-support"
fd -t f import-npm-lock "$NIXPKGS"
```

`$NIXPKGS` is one canonical store path (e.g. `/nix/store/...-source`), not the whole store. `rg`/`fd` over it is fast and unambiguous.

Caching tip: stash the path in a shell var for the session instead of re-evaling.

## Jumping to a definition

```bash
nix eval --raw nixpkgs#hello.meta.position
# -> /nix/store/...-source/pkgs/by-name/he/hello/package.nix:52
```

`meta.position` works for any attribute that sets `meta` (most top-level packages). For arbitrary attrs without `meta`, use `unsafeGetAttrPos`:

```bash
nix eval --impure --expr \
  'let p = import (builtins.getFlake "nixpkgs") {}; \
   in builtins.unsafeGetAttrPos "importNpmLock" p'
# -> { column = ...; file = "/nix/store/...-source/.../default.nix"; line = ...; }
```

`nix edit nixpkgs#foo` does the same lookup and opens `$EDITOR`. Don't run it from an agent (it's interactive). Use `meta.position` to print the location, then `read` the file.

## Looking up store paths and packages

```bash
nix search nixpkgs ripgrep             # name/description regex search
nix search nixpkgs '^ripgrep$'         # anchored
nix eval --raw nixpkgs#ripgrep.outPath # store path without building
nix path-info nixpkgs#ripgrep          # store path; builds/substitutes if missing
nix path-info --closure-size -h nixpkgs#ripgrep
```

`outPath` is pure evaluation, no network. `path-info` may fetch.

## Inspecting store contents

```bash
nix store ls -R -l /nix/store/...-foo          # list files in a store path
nix store ls /nix/store/...-foo/bin            # specific subdir
nix store cat /nix/store/...-foo/share/x.txt   # read a file from the store
```

These work against the local store and configured substituters, so you can inspect paths without realizing them locally.

## Interactive exploration

For ad-hoc poking, `nix repl nixpkgs` (or `nix repl --expr 'import <nixpkgs> {}'`) is faster than chaining `nix eval` calls. From an agent prefer one-shot `nix eval` so output is captured.

## When to fall back

- `find /nix/store` is only appropriate when you genuinely need to scan _all_ store paths (e.g. forensics on what's installed). Even then, prefer `nix store gc --print-roots`, `nix path-info --all`, or `nix store ls`.
- If `nix eval` complains about flakes/experimental features, add `--extra-experimental-features 'nix-command flakes'`.
- "SQLite database ... is busy" warnings from `nix eval` are ignorable; the result on stdout is still correct.
