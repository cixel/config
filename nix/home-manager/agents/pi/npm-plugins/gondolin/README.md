# Pinned Gondolin compatibility unit

The Pi extension and SDK remain at **0.13.0** (release source
`fcbcef162a73b214f79069f8430c70cebda0f827`). The SDK retains the reviewed
fs-rpc serialization/path-validation and chmod security backports in
`sdk-patches/`; their regression tests exercise the **installed** SDK.
This change is independent of the Gondolin workspace/lifecycle/toolbox branch.

## Image contract

`image.nix` composes the hash-pinned official Alpine base **0.3.1** with
**all four official 0.13.0 helpers**: sandboxd, sandboxfs, sandboxssh and
sandboxingress. The stock base has 0.12.0 helpers despite its newer image
version; pinning it alone does not fix idle resume. The input URLs/checksums
for both x86_64 and aarch64 are in `image-inputs.json`. Native host tools
modify the ext4 image without mounts, guest execution, or build-time network
access; only Nix fixed-output fetchers download inputs. Darwin hosts select
Linux helpers matching their CPU, not Darwin binaries.

The extension embeds `sandbox.imagePath` pointing into the Nix store and
sets **top-level** `rootfs: { mode: "cow" }`. Each VM gets a disposable
writable overlay. Auto-pause is **not disabled** or retuned in production;
macOS keeps the SDK's default 30-second pause. Existing VFS mounts, host/guest
path handling and fail-closed user `!` commands are unchanged.

Startup reports the immutable image's `provenance.json` path. That file
records architecture, SDK/source/security-patch provenance, base image and
archive identity, helper archive and individual helper hashes, and resulting
image identity. The regenerated `manifest.json` covers the modified rootfs,
not the old upstream rootfs checksum. There is no runtime `latest` lookup,
image download or mutable cache dependency.

## Guest tools

`home.nix` passes `guestTools = gp: [ gp.nix gp.jujutsu (go.nix) ]`, where
`gp` is `pkgs.pkgsLinux`: the same nixpkgs, overlays and config for the
Linux flavour of the host CPU. Darwin hosts therefore need a Linux builder.
`image.nix` builds a `buildEnv` of the tools, its `closureInfo`, and a small
Linux "guest root" containing `/etc/nix/nix.conf` (flakes on, no build users,
no Nix sandbox), `/usr/local/bin` links into the env, a GC root, and a Nix DB
loaded from the closure registration by the guest's own `nix-store`.

`image-manifest.mjs` then grows the rootfs (`resize2fs`, by the closure size
plus `guestHeadroomMb`, default 1024) and copies the guest root and every
closure path in with `debugfs`: root-owned, normalized modes, time 1, Darwin
case-hack suffixes stripped. Only existing *directories* (`/etc`,
`/usr/local/bin`) may be reused, because `mkdir`/`write` over an existing
name leaks an inode. Every entry's type, mode, owner and size are re-read
from the image, and every file and symlink is dumped back and compared.
`provenance.json` gains a `guest` section (tools, env, store paths, sizes).
The hardware test runs the tools' version commands and
`nix store verify --recursive --no-trust` on the env inside the VM.

With tools, the uncompressed ext4 references the whole Linux closure, so
`allowedReferences = [ sdk ]` only applies to the tool-less image.

## Verification and updates

```sh
nix build .#pi-gondolin .#pi-gondolin-image \
  .#pi-gondolin-sdk-tests .#pi-gondolin-extension-tests .#pi-gondolin-helper-tests
nix run .#pi-gondolin-resume-test
```

The build checks the real SDK's offline image resolution and the patched
extension's VM options, VFS/path guards and startup failure behavior.
Helper-contract tests check both real release bundles, including rejection of
wrong versions/architectures, missing helpers and corrupted bytes. The
hardware runner loads the **packaged extension and SDK**, preserving its
image and mounts; only Pi registration/tool factories are replaced with a
small harness. It explicitly enables 500 ms idle pause on Linux, waits for
actual QEMU pauses, and tests initial exec plus three resume/exec/clock-sync
cycles through the extension's user-bash operations. This is not a startup
or host-backed-read smoke test.

The runner skips clearly when KVM/HVF is unavailable. On Linux,
`REQUIRE_KVM=1` makes missing KVM access an error. If necessary, build the
runner, then run its absolute store executable under sudo with
`REQUIRE_KVM=1`; do not change `/dev/kvm` permissions. Hardware tests run
outside the ordinary Nix build sandbox. Never test using a production VM.

Treat SDK tarball/lockfile, extension revision/patch, security backports,
helper bytes and image as **one compatibility-tested update unit**. Update
pins and provenance together; rerun packaged security/extension checks and
repeated accelerated idle/resume tests (including macOS/HVF on a Mac). An SDK
version bump or successful initial exec is not sufficient compatibility
proof. See `docs/investigations/gondolin-idle-resume-2026-10-15.md` for the
original failure and standalone reproducer.

The locked nixpkgs no longer supports x86_64-darwin; Intel Mac configuration
evaluation is blocked upstream, independently of this image fix. Both Linux
guest architectures are pinned and buildable with native supported host tools.
