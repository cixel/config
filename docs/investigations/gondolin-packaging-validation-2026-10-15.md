# Gondolin packaging fix validation — October 15, 2026

Implemented independently on the existing empty `uuzsuslv` revision above
`ylxtsqlw` (`7c59ea87`), not on the `gondolin` development line. Carried the
investigation/reproducer from `6dd53dd` unchanged and the two SDK backports
and their regression tests from the later development work. No workspace
lifecycle/toolbox changes were imported, and no existing bookmark was moved.

## Implemented compatibility unit

- SDK/extension 0.13.0, with retained fs-rpc serialization and chmod backports.
- Exact, fixed-output Nix-fetched Alpine 0.3.1 base and official 0.13.0
  sandboxd/sandboxfs/sandboxssh/sandboxingress bundles for both architectures.
- Native host-only ext4 helper replacement; verified helper bytes/modes/ELF
  architecture, filesystem integrity, regenerated manifest checksums/build ID.
- Explicit immutable extension `sandbox.imagePath`, top-level COW rootfs,
  startup provenance path; unchanged production pause policy and VFS.
- SDK store path, source/patch revisions, archive identities, per-helper
  hashes, architecture and final image identity recorded in provenance.

## Results

Ordinary builds ran with Nix `sandbox = true`; downloads were fixed-output
fetches, not network calls from the image composition or npm build.

| Check | Result |
| --- | --- |
| x86_64 image build and `--rebuild` | Pass, byte-identical output |
| aarch64 image composition on native x86_64 host tools | Pass, including both archive hashes and all guest-helper bytes |
| Helper compatibility/negative tests | 34 pass, both real release bundles |
| Packaged extension/offline resolver/native loader tests | 8 pass |
| Installed SDK security-backport regression tests | 4 pass |
| Actual packaged extension + SDK + image, Linux/KVM | Pass: initial user-bash exec, then three actual idle pauses/resumes with matching time-sync, guest/host clock, real VFS, COW persistence/cleanup and guest helper-hash checks |
| Missing KVM access | Explicit skip; `REQUIRE_KVM=1` fails instead |
| Apple Silicon full Darwin system configuration evaluation | Pass (`ESINAI-Q6K2T5H20N`) |
| Native macOS/HVF or aarch64 VM execution | Not available on this x86_64 Linux VM |
| Intel Mac evaluation | Blocked by existing locked nixpkgs dropping x86_64-darwin support; no lock changes made |

The final accelerated test used the Nix-packaged Node 24.21.0 and QEMU 11.1.1
runner under `sudo env REQUIRE_KVM=1`; it passed in 15.5 seconds. Each cycle
waited for actual QMP `paused` state, spent another 3.1 seconds paused, then
executed through the packaged extension's user-bash operations. Linux's
normally disabled pause policy was explicitly enabled **only in the test**.
No `/dev/kvm` permission changes, production timeout increases, cache clearing
or permanent pause disabling were used. No QEMU processes remained afterward.

The hardware test imports the packaged extension in native ESM with only Pi
registration/tool constructors stubbed. A separate regression guards against
cross-realm test arrays being CBOR-encoded as maps; SDK exec/fs/protocol
behavior is not mocked or marshalled by the integration test.

Final image identities:

| Architecture | Build ID | Rootfs SHA256 |
| --- | --- | --- |
| x86_64 | `da956b4b-fe0d-59be-bad8-98971161cc5c` | `df43216b19cb99daedb65438f09f3c77e47e5b892bba6d019a230c9af7265f5b` |
| aarch64 | `6ddcd95a-e9bf-5088-be56-c4adc4840841` | `015e7e5755a2382cbc91569a33fcfaa4435b84e9dc961a1d30ca40a83aec971b` |

Reproduction commands and the update contract are in
`nix/home-manager/agents/pi/npm-plugins/gondolin/README.md`.
