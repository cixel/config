# Packaged extension tests

No Pi installation, npm install, image download or network access is needed.
Use Node >=22.19 with VM modules enabled; run these files directly (not via
`node --test`, so the positional package/image arguments reach the harness):

```sh
node --experimental-vm-modules tests/extension.mjs PACKAGE_ROOT IMAGE_PATH
node --experimental-vm-modules tests/idle-resume.mjs PACKAGE_ROOT IMAGE_PATH
```

`PACKAGE_ROOT` contains `package.json`, `extensions/pi-gondolin.ts`, and the
installed patched SDK under `node_modules`. `IMAGE_PATH` is the baked image's
top-level `/nix/store/...` directory, including `manifest.json` and
`provenance.json`. An optional third argument, `LIVE_EXTENSION_PATH`, also
checks that the live extension's contents match the tested packaged extension.

`extension.mjs` needs no QEMU or hardware. It checks pins/provenance, the real
SDK's offline explicit-image resolver, and extension policy using mock SDK
objects and Pi tool constructors.

`idle-resume.mjs` uses the actual packaged SDK, VM, RealFSProvider and image.
It loads the stripped extension in native ESM with `registerHooks` intercepting
only Pi registration/tool constructors; the policy tests use SourceTextModule.
This avoids cross-realm arrays confusing the SDK's constructor-based CBOR
encoder, without wrapping or replacing real guest exec/filesystem operations.
QEMU and `qemu-img` must be
on `PATH`; `QEMU_PATH` can select the QEMU system binary. KVM on Linux or HVF
on macOS is required: the suite reports a `node:test` skip when acceleration
is unavailable. Set `REQUIRE_KVM=1` to turn that skip into a failure (also
applies to HVF). It never falls back to software emulation or escalates
privileges.

The integration test injects a 500 ms idle timer without changing the
production extension's defaults, observes the actual controller and QMP
paused state, and verifies three distinct guest time-sync acknowledgements
before successful extension `user_bash` commands. It checks the clock, the
real workspace mount, persistent COW writes and installed guest helper hashes;
captured VMs are closed on failure as well as success. The test has an overall
180-second limit and bounded startup, commands, pause waits and teardown.
