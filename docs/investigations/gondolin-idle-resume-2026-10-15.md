# Gondolin idle-resume failure — 2026-10-15

## Conclusion

The attached Pi session is consistent with an upstream **SDK/guest-helper
protocol mismatch**; it does not establish that QEMU exited. The incompatibility
reproduced here is between Gondolin SDK 0.13.0 and `sandboxd` baked into the
official `alpine-base:0.3.1` image. Pinning the extension and npm dependency alone
does not pin that image.

The export does not identify the Mac's active image build ID, so it cannot prove
that particular VM used the affected image. The official image, release build
process, and a separate reproduction provide evidence beyond the export.

No application configuration was changed during this investigation. The initial
checkout was detached at `123f1b4` (the jev-guard tip); the packaging in the export also
exists on `wip`. This report does not switch branches or reintroduce that plugin.

## What the attached session actually shows

Source: `pi-session-2026-10-15T16-08-16-099Z_01a14052-45e3-747e-bb7e-5b942c846711.html`.
Times below are UTC on October 15, 2026; indices are zero-based `entries[]` in
the decoded export.

| Time | Evidence |
| --- | --- |
| 16:12:30–16:14:02 | Bash commands execute in the Alpine guest. Early missing `/root/.config`, `jj`, and `/nix` errors are ordinary command failures, not the resume failure. |
| 16:14:02.684 | Last demonstrated shell execution, entry 42. It prints mounts, disk space, and `uid=0(root)`; its final `ls /nix` exits 1. |
| 16:15:00.763 | Next Bash request, entry 43, about 58 seconds after the preceding result. |
| 16:15:04.169 | Entry 44 returns `error sandbox_resume_failed: guest time sync timed out (update sandbox helpers)`. |
| 16:15:11–16:21:59 | Seven more Bash requests fail identically, including `echo hi`, `true`, and `date; uptime`. Each fails after approximately three seconds, before producing shell output. |
| 16:15:23–16:22:06 | Workspace reads continue to work. This does **not** demonstrate guest health. |
| 16:21:39 | User reports that a QEMU process is still running. The export contains no process listing or QMP status query. |

No write/edit calls, image rebuild, VM restart, or recovery occurs in the export.
The previous assistant's proposed version diagnosis was a hypothesis, not a
version comparison it had performed.

## Independent local verification

Using the published 0.13.0 SDK and the stock x86_64 image listed below, a forced
500 ms idle-pause test reproduced the error on both Linux/TCG and Linux/KVM:

- Initial guest exec succeeds.
- After idle pause, QEMU resumes; the guest returns `error id=0` with
  `invalid_request: unsupported request type` to the `time_sync` request
  instead of acknowledging it.
- The host times out after approximately 3,000 ms. Three consecutive attempts
  fail the same way.
- The controller remains `running`, with `paused=false` and `syncPending=true`.
  This directly distinguishes a failed admission handshake from QEMU dying.
- A separate reproduction with a host-backed workspace confirms that
  `vm.fs.readFile` still succeeds after the same resume failure.

Extracting `/usr/bin/sandboxd` from the stock image gives SHA256
`ac873ee6b8f59563e97ba8a3039da77808c065b163edff778037d1087de98cd8`.
It is **byte-identical** to the binary in the official 0.12.0 x86_64 helper
archive, whose archive checksum matches the registry:
`3fa9a20162c49d8ce6c3599bc63843f3f31a6149724a3b775f73b0d795f09d69`.
The helper manifest identifies `gondolinVersion: 0.12.0`, source `v0.12.0`,
and Zig 0.16.0. This is not merely inference from an absent binary string.

Positive controls isolate the incompatibility:

- The same SDK with a locally rebuilt image
  (`dbb5557e-ad0e-55ec-a737-52850052c9b7`) whose `sandboxd` is byte-identical to
  the official **0.13.0** helper passes three idle resumes. Each receives a
  matching `time_sync_done`, and guest time agrees with host time.
- The affected stock image with **idle pause disabled** also passes.

The checked-in reproducer was run separately against both images using Node
24.21.0 and QEMU 11.1.1 on Linux/x86_64/KVM. The stock-image test observed
timeouts of 3,009/3,005/3,003 ms; the replacement image completed resumed execs
in 22/15/122 ms and passed clock-agreement assertions. These tests validate the
mechanism on Linux, not the original Mac's exact cached image or HVF runtime.

The portable companion `gondolin-idle-resume-repro.mjs` uses an existing SDK
entry point and image directory, disables networking/host mounts, uses a
disposable COW disk, and tests three cycles. It downloads nothing. Run with
`EXPECT_RESUME=failure` for the affected stock image; the default expects a
working image and also checks guest/host clock agreement:

```sh
node docs/investigations/gondolin-idle-resume-repro.mjs \
  /path/to/installed/gondolin/dist/src/index.js /path/to/guest-image
```

Use Node >=22.19 and put QEMU's `bin` directory on `PATH` (the SDK also invokes
`qemu-img`). Optional environment settings:
`QEMU_PATH=/path/to/qemu-system-x86_64`,
`QEMU_ACCEL=tcg` if KVM is unavailable, and `IDLE_PAUSE_MS=0` to test the
no-auto-pause workaround. Do not run this against a mutable production VM;
it creates its own VM and closes it afterward.

## Why it fails partway through, rather than at boot

The SDK source at `v0.13.0` establishes this sequence:

1. `host/src/sandbox/server-options.ts` defaults macOS/QEMU-HVF to a
   **30,000 ms idle pause**. Linux does not enable that default.
2. `host/src/sandbox/controller.ts` pauses idle QEMU with QMP `stop`.
3. New activity invokes QMP `cont`, then `onResume`, before admitting an exec.
4. `host/src/sandbox/server.ts::syncGuestClock` sends a `time_sync` request
   and waits **3,000 ms** for a matching `time_sync_done` or error response.
   An old helper's `error id=0` does not match the pending request ID
   (`2147483648` and upward), so it does not satisfy that wait.
5. On timeout, `server-ops.ts::handleExec` returns `sandbox_resume_failed`
   without submitting the shell command.
6. `syncPending` is only cleared after a successful handshake. Failure leaves
   subsequent commands retrying the same prerequisite. QEMU need not exit.

The parenthetical “update sandbox helpers” is hard-coded into the timeout.
There is no version negotiation/comparison at this point. A hung guest or
broken transport could also cause this message; the text alone is not proof.

Workspace reads take a different path: the example extension calls
`vm.fs.readFile`; `host/src/vm/fs.ts` recognizes VFS-mounted paths and directly
calls the host-side provider. Here that provider is `RealFSProvider(localCwd)`.
Consequently `/workspace/README.md` can remain readable even when guest exec
is unusable. It is not evidence that a separate guest file channel is healthy.

## The upstream release mismatch

Upstream issue **#167**, opened October 11, 2026, reports the same failure on
Apple Silicon with SDK 0.13.0 and official image 0.3.1. The reporter observed
`error id=0` instead of `time_sync_done`; rebuilding helpers from 0.13.0 source
fixed the resume test. As checked October 15, the issue remains open, with no
maintainer diagnosis or linked fix. Treat its observations as a separate
reproduction, not as proof of the attached Mac's exact image.

The release history explains how a new image could still contain old helpers:

| Artifact/event | Evidence |
| --- | --- |
| Clock-sync source change | `5a13f4113aa93bfd722d9e4bd8353db3ef84bee2`, October 4, adds both host requests and guest responses. |
| Image 0.3.1 source | `afc93202b138d09841ff6c5006b6aeeb089d2e40`. This contains the clock-sync guest source, **but `host/package.json` still says 0.12.0**. |
| Image builder selection | `resolveSandboxBinaryPaths` defaults to downloading published helpers for the host package version, not compiling the checked-out guest source. At this image ref it therefore selects `gondolin:0.12.0`. |
| Misleading CI step | The image workflow first runs `zig build`, but its subsequent `make build` invokes the host image builder without selecting those binaries. The precompiled helpers are not automatically used. |
| Image release | `image-alpine-base--0.3.1` published October 4 at **22:02:21Z**. |
| SDK 0.13.0 source | `fcbcef162a73b214f79069f8430c70cebda0f827`, the extension commit pinned by this config. |
| New helper release | `sandbox-helpers--0.13.0` published October 4 at **22:06:00Z**, after image 0.3.1. |

Thus “the image was built from source containing time sync” is insufficient:
the builder can package older downloaded binaries instead.

The official image registry maps image 0.3.1 to:

| Architecture | Image build ID |
| --- | --- |
| aarch64 | `e490f153-9700-596d-bb59-9ebf69c725dc` |
| x86_64 | `39bb1ded-2995-5ce9-b1d7-b8f76cb8803b` |

These are image versions/build IDs, not SDK version numbers. Image `0.3.1`
and SDK `0.13.0` having different numbers is not itself an error.

## Where Nix's guarantees stop

The `gondolin.nix` printed in session entry 15 pins:

- the extension to `fcbcef162a73b214f79069f8430c70cebda0f827`, with a Nix hash;
- `@earendil-works/gondolin` to exactly 0.13.0, with npm-lock integrity;
- QEMU through nixpkgs/the flake lock.

But the extension calls `VM.create` **without an explicit image**. The Nix
file even documents that images download on first use into the user's home.

SDK asset resolution is outside the Nix derivation:

1. `GONDOLIN_GUEST_DIR` override;
2. a discovered `guest/image/out` development tree;
3. a local cached image ref;
4. otherwise the default selector, `GONDOLIN_DEFAULT_IMAGE` or
   **`alpine-base:latest`**.

The image registry URL follows upstream **`main`**, not the pinned SDK commit.
A locally resolved ref is reused without fetching an updated registry, so
different machines or cache histories can select different images. SDK
upgrades do not automatically replace an existing cached `latest`.

Downloaded archive checksums and content-derived build IDs verify the selected
bytes; they do not establish SDK/helper protocol compatibility. The image
manifest records assets/checksums/build configuration, not a verified
host/guest capability handshake. This is a real dependency-closure gap, not
Nix randomly mixing versions.

## Remediation

### Immediate workaround

Create a **new** VM with:

```ts
VM.create({
  // existing vfs options unchanged
  sandbox: { qemuIdlePauseMs: 0 },
});
```

This avoids the broken idle-resume path; it does not repair the guest binary.
On macOS it may restore the high idle CPU usage that auto-pause was intended
to reduce. Disabling future pauses on an already failed VM does not clear its
pending handshake; restart it. Restarting with the affected image and SDK
combination and the default pause policy will reproduce the failure after
another idle period.

### Durable Nix solution

Make the guest image an explicit dependency of the packaged extension:

1. Pin helper **bytes**, either by compiling from the same pinned source and
   compatible patch set as the SDK, or by fetching the exact 0.13.0 helper
   archive with its fixed checksum. Do not rely on the builder's default
   helper lookup.
2. Build/package a guest image that contains those helpers. Pin all other
   build inputs too; running the networked Alpine builder inside a script
   does not by itself make the result a reproducible Nix derivation.
3. Bake the resulting store path into
   `sandbox.imagePath: "${guestImage}"` in the extension. Prefer explicit
   configuration over the SDK's environment/cache/development-tree fallbacks.
   Explicitly set `rootfs: { mode: "cow" }` at the VM options' top level,
   keeping a per-VM writable COW disk rather than writing into the Nix store.
4. Exercise real exec → idle pause → resume → exec in an integration test,
   explicitly enabling idle pause on Linux CI. Include repeat resumes and
   assert clock agreement. Plain startup/read/write smoke tests miss this.
5. Log the SDK revision/patch set, image build ID, helper hashes, architecture,
   and QEMU version at startup; fail early on an incompatible image.

Pinning the unmodified official **0.3.1** image would make the failure
reproducible, not fix it. Nix can prevent accidental drift once the full
closure is declared, but cannot infer that upstream shipped incompatible
bytes from their release names.

## Primary references

- Upstream report: <https://github.com/earendil-works/gondolin/issues/167>
- SDK/extension release source: <https://github.com/earendil-works/gondolin/tree/fcbcef162a73b214f79069f8430c70cebda0f827>
- Image release: <https://github.com/earendil-works/gondolin/releases/tag/image-alpine-base--0.3.1>
- Image build source: <https://github.com/earendil-works/gondolin/tree/afc93202b138d09841ff6c5006b6aeeb089d2e40>
- Clock-sync change: <https://github.com/earendil-works/gondolin/commit/5a13f4113aa93bfd722d9e4bd8353db3ef84bee2>
- Matching helper release: <https://github.com/earendil-works/gondolin/releases/tag/sandbox-helpers--0.13.0>

Relevant upstream files at the immutable refs above:
`host/src/sandbox/{server-options,controller,server,server-ops}.ts`,
`host/src/vm/fs.ts`, `host/src/{assets,images}.ts`,
`host/src/build/{shared,sandbox-helpers}.ts`, `guest/src/sandboxd/main.zig`,
`host/package.json`, `guest/Makefile`, `.github/workflows/image-release.yml`,
and both builtin registries. The published 0.13.0 npm tarball was also inspected,
not just the newer main checkout (`0705083`).
